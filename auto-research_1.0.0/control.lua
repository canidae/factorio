function init()
    -- Default Auto Research config
    global.researchCenterParameters = {
        parameters = {
            {
                signal = {
                    type = "item",
                    name = "assembling-machine-1"
                },
                count = 1,
                index = 1
            },
            {
                signal = {
                    type = "item",
                    name = "splitter"
                },
                count = 1,
                index = 6
            },
            {
                signal = {
                    type = "item",
                    name = "steel-plate"
                },
                count = 1,
                index = 11
            },
            {
                signal = {
                    type = "item",
                    name = "storage-tank"
                },
                count = 1,
                index = 16
            },
            {
                signal = {
                    type = "item",
                    name = "steel-furnace"
                },
                count = 1,
                index = 21
            }
        }
    }

    -- Enable Auto Research by default
    setAutoResearchEnabled(true)

    -- Check if game contains research recipies that require something else than science packs
    local nonstandard_recipies = false
    for _, force in pairs(game.forces) do
        for techname, tech in pairs(force.technologies) do
            for _, ingredient in ipairs(tech.research_unit_ingredients) do
                nonstandard_recipies = nonStandardIngredient(ingredient)
                if nonstandard_recipies then
                    -- disable non-standard recipies and tell user how to enable it again
                    setAutoResearchExtendedEnabled(false)
                    return
                end
            end
        end
    end
end

function findTechnologyForSignal(force, signal)
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

function findResearchCenterTechnologies(force)
    local researchCenterTechnologies = {}
    if global.researchCenterParameters then
        for index, parameter in pairs(global.researchCenterParameters.parameters) do
            local techname = findTechnologyForSignal(force, parameter.signal.name)
            if techname then
                local pretech = getPretechIfNeeded(force.technologies[techname])
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

function canResearch(tech)
    if not tech or tech.researched or not tech.enabled then
        return false
    end
    for _, pretech in pairs(tech.prerequisites) do
        if not pretech.researched then
            return false
        end
    end
    if not global["auto_research_extended_enabled"] then
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
    if not global["auto_research_enabled"] then
        return
    end

    -- TODO: setting for ignoring "least_ingredients"
    --
    -- TODO: technologies won't change during game (well, it may if user adds a mod)
    --       it's possible to iterate all technologies and do necessary calculations once instead of each time a research finishes (which is causing a slight lag)

    -- see if there are some techs we should research first
    local researchCenterTechnologies = findResearchCenterTechnologies(force)
    local next_research = nil
    local least_effort = nil
    local least_ingredients = nil
    for techname, count in pairs(researchCenterTechnologies) do
        if researchCenterTechnologies[techname] >= 1 or not next_research then
            local tech = getPretechIfNeeded(force.technologies[techname])
            if canResearch(tech) then
                if not next_research or (researchCenterTechnologies[next_research] or 1) < 1 or #tech.research_unit_ingredients < least_ingredients then
                    next_research = techname
                    least_effort = 0
                    least_ingredients = #tech.research_unit_ingredients
                end
            end
        end
    end

    -- if no prioritized tech should be researched first then research the "least effort" tech not researched yet
    if not next_research then
        for techname, tech in pairs(force.technologies) do
            if (researchCenterTechnologies[techname] or 1) >= 1 or not next_research then
                local should_replace = false
                local effort = tech.research_unit_count * tech.research_unit_energy
                if not next_research or (researchCenterTechnologies[next_research] or 1) < 1 or #tech.research_unit_ingredients < least_ingredients then
                    should_replace = true
                elseif #tech.research_unit_ingredients == least_ingredients and effort < least_effort then
                    should_replace = true
                end
                if should_replace and canResearch(force.technologies[techname]) then
                    next_research = techname
                    least_effort = effort
                    least_ingredients = #tech.research_unit_ingredients
                end
            end
        end
    end

    force.current_research = next_research
end

function setAutoResearchEnabled(enabled)
    global["auto_research_enabled"] = enabled
    tellAll({"auto_research.toggle_msg", enabled and {"gui-mod-info.status-enabled"} or {"gui-mod-info.status-disabled"}}) -- "ternary" expression, lua style

    -- Start research for any force that haven't already
    for _, force in pairs(game.forces) do
        if not force.current_research then
            startNextResearch(force)
        end
    end

    -- Disable/Enable RQ popup if AR is Enabled/Disabled
    if remote.interfaces.RQ and remote.interfaces.RQ["popup"] then
        remote.call("RQ", "popup", not enabled)
    end
end

function setAutoResearchExtendedEnabled(enabled)
    global["auto_research_extended_enabled"] = enabled
    tellAll({"auto_research.toggle_extended_msg", enabled and {"gui-mod-info.status-enabled"} or {"gui-mod-info.status-disabled"}}) -- "ternary" expression, lua style
end

function tellAll(message)
    for _, player in pairs(game.players) do
        player.print{"auto_research.prefix", message}
    end
end

function onResearchFinished(event)
    local force = event.research.force
    -- remove researched stuff from global.researchCenterParameters
    for i = #global.researchCenterParameters.parameters, 1, -1 do
        local parameter = global.researchCenterParameters.parameters[i]
        local techname = findTechnologyForSignal(force, parameter.signal.name)
        if techname then
            local tech = force.technologies[techname]
            if tech and tech.researched then
                table.remove(global.researchCenterParameters.parameters, i)
            end
        end
    end
    if global.researchCenter and global.researchCenter.valid then
        global.researchCenter.get_or_create_control_behavior().parameters = global.researchCenterParameters
    end

    startNextResearch(event.research.force)
end

function onBuiltEntity(event)
    local entity = event.created_entity
	if entity.name == "research-center" then
		if global.researchCenter and global.researchCenter.valid then
            -- save Research Center settings
            global.researchCenterParameters = global.researchCenter.get_or_create_control_behavior().parameters

            -- explode last Research Center
            global.researchCenter.die()
            -- TODO: tell user that old research center exploded due to some circuit overload?
            -- TODO: actually allow multiple research centers?
		end
        entity.get_or_create_control_behavior().parameters = global.researchCenterParameters
        global.researchCenter = entity
    end
end

-- TODO: this is dirty, but unavoidable for good user experience?
--       we can't save settings when Research Center is mined/destroyed, because then it's already invalid
--       we could save settings when research is completed, but that means if the user changes settings and the research center is destroyed before research is finished then the changes will be lost
function onTick()
    if not global.researchCenter or not global.researchCenter.valid or game.tick % 60 ~= 0 then
        return
    end

    -- save Research Center settings
    global.researchCenterParameters = global.researchCenter.get_or_create_control_behavior().parameters
end

-- event hooks
script.on_event(defines.events.on_research_finished, onResearchFinished)
script.on_configuration_changed(init)
script.on_event(defines.events.on_player_created, init)
script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)
script.on_event(defines.events.on_tick, onTick)

-- keybinding hooks
script.on_event("auto-research_toggle", function(event)
    setAutoResearchEnabled(not global["auto_research_enabled"])
end)

script.on_event("auto-research_toggle_extended", function(event)
    setAutoResearchExtendedEnabled(not global["auto_research_extended_enabled"])
end)

-- Add remote interfaces for enabling/disabling Auto Research
remote.add_interface("auto_research", {
    enabled = setAutoResearchEnabled,
    extended = setAutoResearchExtendedEnabled
})
