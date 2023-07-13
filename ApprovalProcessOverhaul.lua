--[[
    Author: Zyruvias (Discord/Youtube: @Zyruvias, twitch: zyruvias)
]]
ModUtil.Mod.Register("ApprovalProcessOverhaul")

local config = {
    Enabled = true,
    InitialHealthCost = 5,
    InitialObolCost = 50,
    InitialHealthCostScaling = 5,
    InitialObolCostScaling = 25,
}

-- TODO: fix give-up cost resets

ApprovalProcessOverhaul.config = config

-- dynamic, do not set directly.
ApprovalProcessOverhaul.HealthCostScaling = nil
ApprovalProcessOverhaul.ObolCostScaling = nil
ApprovalProcessOverhaul.HealthCost = nil
ApprovalProcessOverhaul.ObolCost = nil
ApprovalProcessOverhaul.UseObols = false
ApprovalProcessOverhaul.Components = {}

ModUtil.Path.Context.Wrap("CreateBoonLootButtons", function()
    ApprovalProcessOverhaul.UseObols = CoinFlip()
    local useObols = ApprovalProcessOverhaul.UseObols
    

    ModUtil.Path.Wrap("TraitLockedPresentation", function (baseFunc, args)
        -- resort to default behavior if disabled
        if not ApprovalProcessOverhaul.config.Enabled then
            return baseFunc(args)
        end

        local components = args.Components
        local purchaseButtonKey = args.Id
        local offsetX = args.OffsetX
        local offsetY = args.OffsetY
        local components = args.Components
        local text, cost, amount

        -- use local var since we need to flip it BEFORE the cross-off display
        useObols = ApprovalProcessOverhaul.UseObols
        ApprovalProcessOverhaul.UseObols = not ApprovalProcessOverhaul
        if useObols then
            text = "-" .. tostring(ApprovalProcessOverhaul.ObolCost) .."{!Icons.Currency_Small}"
            cost = ApprovalProcessOverhaul.ObolCost
            amount = CurrentRun.Money
        else
            text = "-" .. tostring(ApprovalProcessOverhaul.HealthCost) .."{!Icons.HealthDown_Small}"
            cost = ApprovalProcessOverhaul.HealthCost
            amount = CurrentRun.Hero.MaxHealth
        end

        -- reset component and button costs on case of reroll or something else idk
        if components[components[args.Id].Id .. "ApprovalProcessOverhaulCost"] ~= nil then
            components[args.Id].ObolCost = nil
            components[args.Id].HealthCost = nil
            Destroy({ Id = components[components[args.Id].Id .. "ApprovalProcessOverhaulCost"] })
        end

        components[components[args.Id].Id .. "ApprovalProcessOverhaulCost"] = CreateScreenComponent({
            Name = "BlankObstacle",
            Group = "ApprovalProcessOverhaul",
            X = offsetX,
            Y = offsetY
        })
        local anchor = components[components[args.Id].Id .. "ApprovalProcessOverhaulCost"].Id
        
        
        CreateTextBox({
            Id = anchor,
            Text = text,
            OffsetX = 450,
            OffsetY = 60,
            Font = "AlegreyaSansSCBold",
            FontSize = 22,
            Justification = "Right" 
        })
        FadeObstacleIn({ Id = anchor, Duration = CombatUI.FadeInDuration, IncludeText = true, Distance = CombatUI.FadeDistance.Money, Direction = 180 })
            
        -- change opacity
        if cost > amount then
            return baseFunc(args)
        end

        -- can afford, setup costs on button
        UseableOn({ Id = components[args.Id].Id })
        if useObols then
            components[args.Id].ObolCost = ApprovalProcessOverhaul.ObolCost
        else
            components[args.Id].HealthCost = ApprovalProcessOverhaul.HealthCost
        end
        useObols = not useObols
    end, ApprovalProcessOverhaul)
        
end, ApprovalProcessOverhaul)

OnAnyLoad{
    function ()
        if ApprovalProcessOverhaul.ObolCost == nil then
            if CurrentRun.ApprovalProcessOverhaulObolCost then
                ApprovalProcessOverhaul.ObolCost = CurrentRun.ApprovalProcessOverhaulObolCost
            else
                ApprovalProcessOverhaul.ObolCost = ApprovalProcessOverhaul.config.InitialObolCost
            end
            -- initialize obol costs from config and pact of punishment
            ApprovalProcessOverhaul.ObolCostScaling = ApprovalProcessOverhaul.config.InitialObolCostScaling
            local costMultiplier = 1 + ( GetNumMetaUpgrades( "ShopPricesShrineUpgrade" ) * ( MetaUpgradeData.ShopPricesShrineUpgrade.ChangeValue - 1 ) )
            costMultiplier = costMultiplier * GetTotalHeroTraitValue("StoreCostMultiplier", {IsMultiplier = true})
            if costMultiplier ~= 1 then
                ApprovalProcessOverhaul.ObolCost = round( ApprovalProcessOverhaul.ObolCost * costMultiplier )
                ApprovalProcessOverhaul.ObolCostScaling =  round( ApprovalProcessOverhaul.ObolCostScaling * costMultiplier )
            end
            
            -- initialize health costs from config and pact of punishment
            ApprovalProcessOverhaul.HealthCost = ApprovalProcessOverhaul.config.InitialHealthCost
            ApprovalProcessOverhaul.HealthCostScaling = ApprovalProcessOverhaul.config.InitialHealthCostScaling
            if GetNumMetaUpgrades( "EnemyDamageShrineUpgrade" ) > 0 then
                local damageIncrease = GetNumMetaUpgrades( "EnemyDamageShrineUpgrade" ) * ( MetaUpgradeData.EnemyDamageShrineUpgrade.ChangeValue - 1 )
                DebugPrint { Text = "Increasing health scaling by a factor of (1 + " .. tostring(damageIncrease).. ")"}
                ApprovalProcessOverhaul.HealthCost = ApprovalProcessOverhaul.HealthCost * (damageIncrease + 1)
                ApprovalProcessOverhaul.HealthCostScaling = ApprovalProcessOverhaul.HealthCostScaling * (damageIncrease + 1)
            end
        end
    end
}

ModUtil.Path.Wrap("HandleUpgradeChoiceSelection", function (baseFunc, screen, button)
    if button.HealthCost then
        local healthRemaining = CurrentRun.Hero.Health
        local maxHealth = CurrentRun.Hero.MaxHealth
        local cost = math.min(healthRemaining - 1, button.HealthCost, maxHealth - 1)
        CreateAnimation({ Name = "SacrificeHealthFx", DestinationId = CurrentRun.Hero.ObjectId })
        AddMaxHealth(-1 * cost, "ApprovalProcessOverhaulCost")
        ValidateMaxHealth()
        --increment health cost
        ApprovalProcessOverhaul.HealthCost = ApprovalProcessOverhaul.HealthCost + ApprovalProcessOverhaul.HealthCostScaling
        CurrentRun.ApprovalProcessOverhaulHealthCost = ApprovalProcessOverhaul.HealthCost
    elseif button.ObolCost then
        SpendMoney(button.ObolCost, "ApprovalProcessOverhaulCost")
        -- increment obol cost
        ApprovalProcessOverhaul.ObolCost = ApprovalProcessOverhaul.ObolCost + ApprovalProcessOverhaul.ObolCostScaling
        CurrentRun.ApprovalProcessOverhaulObolCost = ApprovalProcessOverhaul.ObolCost
    end
    return baseFunc(screen, button)
end, ApprovalProcessOverhaul)
    
ModUtil.Path.Wrap("DestroyBoonLootButtons", function( baseFunc, lootData )
	local components = ScreenAnchors.ChoiceScreen.Components
	local toDestroy = {}
	for index = 1, 3 do
		local destroyIndexes = {
            "PurchaseButton"..index .. "ApprovalProcessOverhaulCost",
        }
            for i, indexName in pairs( destroyIndexes ) do
                if components[indexName] then            components[args.Id].ObolCost = nil
                    components[args.Id].HealthCost = nil
                    components[args.Id].ObolCost = nil
                    table.insert(toDestroy, components[indexName].Id)
                    components[indexName] = nil
                end
            end
        end
	Destroy({ Ids = toDestroy })
    return baseFunc(lootData)
end, ApprovalProcessOverhaul)
