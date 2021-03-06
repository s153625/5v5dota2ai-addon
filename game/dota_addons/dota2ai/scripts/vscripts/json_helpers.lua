-- This file contains functions that serialise game entities into JSON

function Dota2AI:JSONChat(event)
    jsonEvent = {}
    jsonEvent.teamOnly = event.teamonly -- we should probably test one day if the bot is on the same team
    jsonEvent.player = event.userid
    jsonEvent.text = event.text

    return package.loaded["game/dkjson"].encode(jsonEvent)
end

function Dota2AI:JSONtree(eTree)
    local tree = {}
    tree.origin = VectorToArray(eTree:GetOrigin())
    tree.type = "Tree"
    return tree
end

function Dota2AI:JSONitems(eHero)
    local items = {}
    for i = DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_6, 1 do
        local item = eHero:GetItemInSlot(i)
        items[i] = {}
        if item then
            items[i].name = item:GetName()
            items[i].slot = item:GetItemSlot()
            items[i].charges = item:GetCurrentCharges()
            items[i].castRange = item:GetCastRange()
        end
    end
    return items
end

function Dota2AI:JSONunit(eUnit)
    local unit = {}
    unit.level = eUnit:GetLevel()
    unit.origin = VectorToArray(eUnit:GetOrigin())
    --unit.absOrigin = VectorToArray(eUnit:GetAbsOrigin())
    --unit.center = VectorToArray(eUnit:GetCenter())
    --unit.velocity = VectorToArray(eUnit:GetVelocity())
    --unit.localVelocity = VectorToArray(eUnit:GetForwardVector())
    unit.health = eUnit:GetHealth()
    unit.maxHealth = eUnit:GetMaxHealth()
    unit.mana = eUnit:GetMana()
    unit.maxMana = eUnit:GetMaxMana()
    unit.alive = eUnit:IsAlive()
    unit.blind = eUnit:IsBlind()
    unit.dominated = eUnit:IsDominated()
    unit.deniable = eUnit:Script_IsDeniable()
    unit.disarmed = eUnit:IsDisarmed()
    unit.rooted = eUnit:IsRooted()
    unit.name = eUnit:GetName()
    unit.team = eUnit:GetTeamNumber()
    unit.attackRange = eUnit:Script_GetAttackRange()
    unit.forwardVector = VectorToArray(eUnit:GetForwardVector())
    unit.isAttacking = eUnit:IsAttacking()

    if eUnit:IsHero() then
        unit.hasTowerAggro = self:HasTowerAggro(eUnit)
        unit.abilityPoints = eUnit:GetAbilityPoints()
        unit.gold = eUnit:GetGold()
        unit.type = "Hero"
        unit.xp = eUnit:GetCurrentXP()
        unit.deaths = eUnit:GetDeaths()
        unit.denies = eUnit:GetDenies()
        unit.items = self:JSONitems(eUnit)

        -- Abilities are actually in CBaseNPC, but we'll just send them for Heros to avoid cluttering the JSON--
        unit.abilities = {}
        local abilityCount = eUnit:GetAbilityCount() - 1 --minus 1 because lua for loops are upper boundary inclusive

        for index = 0, abilityCount, 1 do
            local eAbility = eUnit:GetAbilityByIndex(index)
            -- abilityCount returned 16 for me even though the hero had only 5 slots (maybe it's actually max slots?). We fix that by checking for null pointer
            if eAbility then
                unit.abilities[index] = {}
                unit.abilities[index].type = "Ability"
                unit.abilities[index].name = eAbility:GetAbilityName()
                unit.abilities[index].targetFlags = eAbility:GetAbilityTargetFlags()
                unit.abilities[index].targetTeam = eAbility:GetAbilityTargetTeam()
                unit.abilities[index].targetType = eAbility:GetAbilityTargetType()
                unit.abilities[index].abilityType = eAbility:GetAbilityType()
                unit.abilities[index].abilityIndex = eAbility:GetAbilityIndex()
                unit.abilities[index].level = eAbility:GetLevel()
                unit.abilities[index].maxLevel = eAbility:GetMaxLevel()
                unit.abilities[index].abilityDamage = eAbility:GetAbilityDamage()
                unit.abilities[index].abilityDamageType = eAbility:GetAbilityDamage()
                unit.abilities[index].cooldownTime = eAbility:GetCooldownTime()
                unit.abilities[index].cooldownTimeRemaining = eAbility:GetCooldownTimeRemaining()
                unit.abilities[index].behavior = eAbility:GetBehavior()
                unit.abilities[index].toggleState = eAbility:GetToggleState()
            end
        end
    elseif eUnit:IsBuilding() then
        if eUnit:IsTower() then
            unit.type = "Tower"
        else
            unit.type = "Building"
        end
    else
        unit.type = "BaseNPC"
    end

    local attackTarget = eUnit:GetAttackTarget()
    if attackTarget then
        unit.attackTarget = attackTarget:entindex()
    end

    return unit
end

function Dota2AI:HasTowerAggro(hero)
    local buildings = self:GetStandingBuildings()

    local heroName = hero:GetName()

    for i, unit in ipairs(buildings) do
        local aggrohandle = buildings[i]:GetAggroTarget()
        if aggrohandle ~= nil and aggrohandle:GetName() == heroName then
            return true
        end
    end
    return false
end

-- At the moment, we serialise the whole game state visible to a team
-- a future TODO would be only sending those entities that have changed
function Dota2AI:JSONWorld(eHero)
    local world = {}
    world.entities = {}

    --there are apparently around 2300 trees on the map. Sending those that are NOT standing is much more efficient
    --TODO provide the client with a list of tree entities at the beginning of the match
    local tree = Entities:FindByClassname(nil, "ent_dota_tree")
    while tree ~= nil do
        if eHero:CanEntityBeSeenByMyTeam(tree) and not tree:IsStanding() then
            world.entities[tree:entindex()] = self:JSONtree(tree)
        end
        tree = Entities:FindByClassname(tree, "ent_dota_tree")
    end

    local allUnits =
        FindUnitsInRadius(
        eHero:GetTeamNumber(),
        eHero:GetOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
        FIND_ANY_ORDER,
        true
    )

    for _, unit in pairs(allUnits) do
        world.entities[unit:entindex()] = self:JSONunit(unit)
    end

    --so FindUnitsInRadius somehow ignores all the buildings
    local buildings = self.GetStandingBuildings()

    for i, unit in ipairs(buildings) do
        world.entities[unit:entindex()] = self:JSONunit(unit)
    end

    return world
end

function VectorToArray(v)
    return {v.x, v.y, v.z}
end

function Dota2AI:GetStandingBuildings()
    local buildingNames = {
        "dota_goodguys_tower1_bot",
        "dota_goodguys_tower2_bot",
        "dota_goodguys_tower3_bot",
        "dota_goodguys_tower1_mid",
        "dota_goodguys_tower2_mid",
        "dota_goodguys_tower3_mid",
        "dota_goodguys_tower1_top",
        "dota_goodguys_tower2_top",
        "dota_goodguys_tower3_top",
        "dota_goodguys_tower4_top",
        "dota_goodguys_tower4_bot",
        "good_rax_melee_bot",
        "good_rax_range_bot",
        "good_rax_melee_mid",
        "good_rax_range_mid",
        "good_rax_melee_top",
        "good_rax_range_top",
        "ent_dota_fountain_good",
        "dota_badguys_tower1_bot",
        "dota_badguys_tower2_bot",
        "dota_badguys_tower3_bot",
        "dota_badguys_tower1_mid",
        "dota_badguys_tower2_mid",
        "dota_badguys_tower3_mid",
        "dota_badguys_tower1_top",
        "dota_badguys_tower2_top",
        "dota_badguys_tower3_top",
        "dota_badguys_tower4_top",
        "dota_badguys_tower4_bot",
        "bad_rax_melee_bot",
        "bad_rax_range_bot",
        "bad_rax_melee_mid",
        "bad_rax_range_mid",
        "bad_rax_melee_top",
        "bad_rax_range_top",
        "ent_dota_fountain_bad",
        "dota_goodguys_fort",
        "dota_badguys_fort"
    }
    local buildings = {}
    local count = 0
    for i, name in pairs(buildingNames) do
        local e = Entities:FindByName(nil, name)
        if e ~= nil then
            buildings[count] = e
            count = count + 1
        end
    end
    return buildings
end

function Dota2AI:JSONGetGoodGuys(eHero)
    local heroes = Dota2AI:GetGoodGuys(eHero)
    local jsonHeroes = {}
    for i, hero in pairs(heroes) do
        jsonHeroes[i] = Dota2AI:JSONunit(hero)
    end
    return jsonHeroes
end

function Dota2AI:GetGoodGuy(eHero, who)
    local heroes = Dota2AI:GetGoodGuys(eHero)
    for i, hero in pairs(heroes) do
        if hero:GetName() == who then
            return hero
        end
    end
end

function Dota2AI:GetGoodGuys(eHero)
    local heroes = {}

    local allUnits =
        FindUnitsInRadius(
        eHero:GetTeamNumber(),
        eHero:GetOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
        FIND_ANY_ORDER,
        true
    )

    for _, unit in pairs(allUnits) do
        if unit:IsHero() and (unit:GetTeamNumber() == 2) then
            -- print("--")
            -- print("unit name is: " .. unit:GetName())
            -- print("--")
            -- unit:SetContextThink(
            --     "Dota2AI:BotThinking",
            --     function()
            --         return Dota2AI:BotThinking(unit)
            --     end,
            --     0.33
            -- )
            table.insert(heroes, unit)
        end
    end

    return heroes
end
