require("config")

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
    return true
end

function startNextResearch(force)
    if not global["auto_research_enabled"] then
        return
    end
    -- see if there are some techs we should research first
    local next_research = nil
    local least_effort = nil
    local least_ingredients = nil
    for _, techname in ipairs(auto_research_first) do
        local tech = force.technologies[techname]
        if canResearch(tech) then
            tech = getPretechIfNeeded(tech)
            if not least_ingredients or #tech.research_unit_ingredients < least_ingredients then
                next_research = techname
                least_effort = 0
                least_ingredients = #tech.research_unit_ingredients
            end
        end
    end

    -- if no prioritized tech should be researched first then research the cheapest/quickest tech not researched yet
    for name, tech in pairs(force.technologies) do
        local should_replace = false
        local effort = tech.research_unit_count * tech.research_unit_energy
        if not least_ingredients or #tech.research_unit_ingredients < least_ingredients then
            should_replace = true
        elseif #tech.research_unit_ingredients == least_ingredients and (not least_effort or effort < least_effort) then
            should_replace = true
        end
        if should_replace and canResearch(force.technologies[name]) then
            next_research = name
            least_effort = effort
            least_ingredients = #tech.research_unit_ingredients
        end
    end

    force.current_research = next_research
end

function tellAll(message)
    for _, player in pairs(game.players) do
        player.print("[Auto Research] " .. message)
    end
end

function init()
    -- Enable Auto Research by default
    global["auto_research_enabled"] = true

    -- Disable RQ popup
    if remote.interfaces.RQ and remote.interfaces.RQ["popup"] then
        remote.call("RQ", "popup", false)
    end

    -- Start research for any force that haven't already
    for _, force in pairs(game.forces) do
        if not force.current_research then
            startNextResearch(force)
        end
    end
end

script.on_event(defines.events.on_research_finished, function(event)
    local force_techs = event.research.force.technologies
    -- remove stuff from auto_research_first so we don't iterate the entire list all the time
    for i = #auto_research_first, 1, -1 do
        local tech = force_techs[auto_research_first[i]]
        if not tech or tech.researched then
            table.remove(auto_research_first, i)
        end
    end

    startNextResearch(event.research.force)
end)

script.on_configuration_changed(function()
    init()
end)

script.on_event(defines.events.on_player_created, function(event)
    init()
end)

-- Add remote interfaces for enabling/disabling Auto Research
remote.add_interface("auto_research", {
    enabled = function(enabled)
        global["auto_research_enabled"] = enabled
        tellAll(enabled and "Enabled" or "Disabled") -- "ternary" expression, lua style
    end
})
