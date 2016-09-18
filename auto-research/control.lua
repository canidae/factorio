function init()
    if not global.auto_research then
        global.auto_research = {}
    end

    -- Init config for forces
    for _, force in pairs(game.forces) do
        initForce(force)
    end

    -- Disable Research Queue popup
    if remote.interfaces.RQ and remote.interfaces.RQ["popup"] then
        remote.call("RQ", "popup", false)
    end
end

function initForce(force)
    -- Disable Auto Research by default
    setAutoResearchEnabled(force, false)

    -- Research technologies requiring fewest ingredients first by default
    setAutoResearchFewestIngredientsEnabled(force, true)

    -- Check if force has research recipes that require something else than science packs
    local nonstandard_recipes = false
    for techname, tech in pairs(force.technologies) do
        for _, ingredient in ipairs(tech.research_unit_ingredients) do
            nonstandard_recipes = nonStandardIngredient(ingredient)
            if nonstandard_recipes then
                -- disable non-standard recipes and tell user how to enable it again
                setAutoResearchExtendedEnabled(force, false)
                goto hell -- ahmagawd! this will surely goto hell!
            end
        end
    end
    ::hell::
end

function getForceConfig(force)
    if not global.auto_research[force.name] then
        global.auto_research[force.name] = {}
    end
    return global.auto_research[force.name]
end

function findTechnologyForSignal(force, signal, count)
    if not signal then
        return nil
    end
    local technologies = force.technologies
    if count and technologies[signal .. "-1"] then
        -- signal is technology with multiple levels
        local techname = signal .. "-" .. count
        if technologies[techname] then
            -- tech exist at the given level
            return techname
        else
            -- user probably set too high tech level, search for highest tech level
            for i = 1, count, 1 do
                if not technologies[signal .. "-" .. i] then
                    return signal .. "-" .. (i - 1)
                end
            end
        end
    elseif technologies[signal] then
        -- signal is technology
        return signal
    else
        -- signal is likely item, search for a technology that unlocks item
        for name, tech in pairs(force.technologies) do
            for _, effect in pairs(tech.effects) do
                if effect.type == "unlock-recipe" then
                    if effect.recipe == signal then
                        return name
                    end
                end
            end
        end
    end
end

function findResearchCenterTechnologies(force)
    local researchCenterTechnologies = {}
    local researchCenterParameters = getForceConfig(force).researchCenterParameters
    if researchCenterParameters then
        local technologies = force.technologies
        for index, parameter in pairs(researchCenterParameters.parameters) do
            local techname = findTechnologyForSignal(force, parameter.signal.name, parameter.count)
            if techname then
                local pretech = getPretechIfNeeded(technologies[techname])
                researchCenterTechnologies[pretech.name] = parameter.count
            end
        end
    end
    return researchCenterTechnologies
end

function getPretechIfNeeded(tech)
    for _, pretech in pairs(tech.prerequisites) do
        if not pretech.researched and pretech.enabled then
            return getPretechIfNeeded(pretech)
        end
    end
    return tech
end

function canResearch(force, tech)
    if not tech or tech.researched or not tech.enabled then
        return false
    end
    for _, pretech in pairs(tech.prerequisites) do
        if not pretech.researched then
            return false
        end
    end
    if not getForceConfig(force).auto_research_extended_enabled then
        for _, ingredient in ipairs(tech.research_unit_ingredients) do
            if nonStandardIngredient(ingredient) then
                return false
            end
        end
    end
    return true
end

function nonStandardIngredient(ingredient)
    local name = ingredient.name
    return name ~= "science-pack-1" and name ~= "science-pack-2" and name ~= "science-pack-3" and name ~= "alien-science-pack"
end

function startNextResearch(force)
    local config = getForceConfig(force)
    if not config.auto_research_enabled then
        return
    end

    -- TODO: technologies won't change during game (well, it may if user adds a mod)
    --       it's possible to iterate all technologies and do necessary calculations once instead of each time a research finishes (which is causing a slight lag)

    -- see if there are some techs we should research first
    local auto_research_fewest_ingredients = config.auto_research_fewest_ingredients
    local researchCenterTechnologies = findResearchCenterTechnologies(force)
    local next_research = nil
    local least_effort = nil
    local fewest_ingredients = nil
    for techname, count in pairs(researchCenterTechnologies) do
        if researchCenterTechnologies[techname] >= 1 or not next_research then
            local tech = getPretechIfNeeded(force.technologies[techname])
            if canResearch(force, tech) then
                if not next_research or (auto_research_fewest_ingredients and #tech.research_unit_ingredients < fewest_ingredients) then
                    next_research = techname
                    least_effort = 0
                    fewest_ingredients = #tech.research_unit_ingredients
                end
            end
        end
    end

    -- if no prioritized tech should be researched first then research the "least effort" tech not researched yet
    for techname, tech in pairs(force.technologies) do
        if (researchCenterTechnologies[techname] or 1) >= 1 or not next_research then
            local should_replace = false
            local effort = tech.research_unit_count * tech.research_unit_energy
            if not next_research or (researchCenterTechnologies[next_research] or 1) < 1 or (auto_research_fewest_ingredients and #tech.research_unit_ingredients < fewest_ingredients) then
                should_replace = true
            elseif (not auto_research_fewest_ingredients or #tech.research_unit_ingredients == fewest_ingredients) and effort < least_effort then
                should_replace = true
            end
            if should_replace and canResearch(force, force.technologies[techname]) then
                next_research = techname
                least_effort = effort
                fewest_ingredients = #tech.research_unit_ingredients
            end
        end
    end

    force.current_research = next_research
end

function setAutoResearchEnabled(force, enabled)
    if not force then
        return
    end
    getForceConfig(force).auto_research_enabled = enabled
    tellForce(force, {"auto-research.toggle_msg", enabled and {"gui-mod-info.status-enabled"} or {"gui-mod-info.status-disabled"}}) -- "ternary" expression, lua style

    -- Start research for force if it haven't already
    if not force.current_research then
        startNextResearch(force)
    end
end

function setAutoResearchExtendedEnabled(force, enabled)
    if not force then
        return
    end
    getForceConfig(force).auto_research_extended_enabled = enabled
    tellForce(force, {"auto-research.toggle_extended_msg", enabled and {"gui-mod-info.status-enabled"} or {"gui-mod-info.status-disabled"}}) -- "ternary" expression, lua style
end

function setAutoResearchFewestIngredientsEnabled(force, enabled)
    if not force then
        return
    end
    getForceConfig(force).auto_research_fewest_ingredients = enabled
    tellForce(force, {"auto-research.toggle_fewest_ingredients_msg", enabled and {"gui-mod-info.status-enabled"} or {"gui-mod-info.status-disabled"}}) -- "ternary" expression, lua style
end

function tellForce(force, message)
    for _, player in pairs(force.players) do
        player.print{"auto-research.prefix", message}
    end
end

function onResearchFinished(event)
    local force = event.research.force
    local config = getForceConfig(force)
    -- remove researched stuff from config.researchCenterParameters
    if config.researchCenterParameters then
        for i = #config.researchCenterParameters.parameters, 1, -1 do
            local parameter = config.researchCenterParameters.parameters[i]
            local techname = findTechnologyForSignal(force, parameter.signal.name, parameter.count)
            if techname then
                local tech = force.technologies[techname]
                if tech and tech.researched then
                    table.remove(config.researchCenterParameters.parameters, i)
                end
            end
        end
        local researchCenter = config.researchCenter
        if researchCenter and researchCenter.valid then
            researchCenter.get_or_create_control_behavior().parameters = config.researchCenterParameters
        end
    end

    startNextResearch(event.research.force)
end

function onBuiltEntity(event)
    local entity = event.created_entity
    local force = entity.force
    local config = getForceConfig(force)
	if entity.name == "research-center" then
        local researchCenter = config.researchCenter
		if researchCenter and researchCenter.valid then
            -- explode last Research Center
            researchCenter.die()
            tellForce(force, {"auto-research.explode_msg"})
            -- TODO: allow multiple research centers instead of blowing them up? then we need some clever mechanics to set parameters
		end
        if config.researchCenterParameters then
            entity.get_or_create_control_behavior().parameters = config.researchCenterParameters
        end
        config.researchCenter = entity
    end
end

-- TODO: this is dirty, but unavoidable for good user experience?
--       we can't save settings when Research Center is mined/destroyed, because then it's already invalid
--       we could save settings when research is completed, but that means if the user changes settings and the research center is destroyed before research is finished then the changes will be lost
function onTick()
    if game.tick % 60 ~= 0 then
        return
    end
    for _, force in pairs(game.forces) do
        local config = getForceConfig(force)
        local researchCenter = config.researchCenter
        if not researchCenter or not researchCenter.valid or game.tick % 60 ~= 0 then
            return
        end

        -- save Research Center settings
        config.researchCenterParameters = config.researchCenter.get_or_create_control_behavior().parameters
    end
end

-- event hooks
script.on_event(defines.events.on_research_finished, onResearchFinished)
script.on_configuration_changed(init)
script.on_event(defines.events.on_player_created, init)
script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)
script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_force_created, function(event)
    initForce(event.force)
end)

-- keybinding hooks
script.on_event("auto-research_toggle", function(event)
    local force = game.players[event.player_index].force
    setAutoResearchEnabled(force, not getForceConfig(force).auto_research_enabled)
end)

script.on_event("auto-research_toggle_extended", function(event)
    local force = game.players[event.player_index].force
    setAutoResearchExtendedEnabled(force, not getForceConfig(force).auto_research_extended_enabled)
end)

script.on_event("auto-research_toggle_fewest_ingredients", function(event)
    local force = game.players[event.player_index].force
    setAutoResearchFewestIngredientsEnabled(force, not getForceConfig(force).auto_research_fewest_ingredients)
end)

-- Add remote interfaces for enabling/disabling Auto Research
remote.add_interface("auto-research", {
    enabled = setAutoResearchEnabled,
    extended = setAutoResearchExtendedEnabled,
    fewest_ingredients = setAutoResearchFewestIngredientsEnabled
})
