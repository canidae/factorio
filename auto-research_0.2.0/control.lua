require("config")

function addPretechsRecursive(tech)
    for _, pretech in pairs(tech.prerequisites) do
        if not pretech.researched and pretech.enabled then
            local already_added = false
            for _, added_tech in ipairs(auto_research_first) do
                if pretech.name == added_tech then
                    already_added = true
                    break
                end
            end
            if not already_added then
                for _, player in pairs(game.players) do
                    player.print("[Auto Research] Adding '" .. pretech.name .. "' to prioritised list, it's a prerequisite for '" .. tech.name .. "'")
                    table.remove(auto_research_first, i)
                end
                auto_research_first[#auto_research_first + 1] = pretech.name
            end
            addPretechsRecursive(pretech)
        end
    end
end

function canResearch(tech)
    if tech.researched or not tech.enabled then
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
        if (not least_ingredients or #tech.research_unit_ingredients < least_ingredients) and canResearch(tech) then
            next_research = techname
            least_effort = 0
            least_ingredients = #tech.research_unit_ingredients
        end
    end

    -- if no prioritized tech should be researched first then research the cheapest/quickets tech not researched yet
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

script.on_event(defines.events.on_research_finished, function(event)
    local force_techs = event.research.force.technologies
    -- remove stuff from auto_research_first so we don't iterate the list all the time
    for i = #auto_research_first, 1, -1 do
        if force_techs[auto_research_first[i]].researched then
            table.remove(auto_research_first, i)
        end
    end

    startNextResearch(event.research.force)
end)

script.on_event(defines.events.on_player_created, function(event)
    local force = game.players[event.player_index].force
    -- Disable RQ popup
    if remote.interfaces.RQ and remote.interfaces.RQ["popup"] then
        remote.call("RQ", "popup", false)
    end

    -- Add remote interfaces for enabling/disabling Auto Research
    global["auto_research_enabled"] = true
    remote.add_interface("auto_research", {
        enabled = function(enabled)
            global["auto_research_enabled"] = enabled
            for _, player in pairs(game.players) do
                if enabled then
                    player.print("[Auto Research] Enabled")
                else
                    player.print("[Auto Research] Disabled")
                end
            end
        end
    })

    -- Check that the technologies listed exist and add any prerequisites to the prioritized technology list
    for i = #auto_research_first, 1, -1 do
        local techname = auto_research_first[i]
        local tech = force.technologies[techname]
        if not tech then
            for _, player in pairs(game.players) do
                player.print("[Auto Research] Technology '" .. techname .. "' doesn't exist, ignoring")
                table.remove(auto_research_first, i)
            end
        else
            addPretechsRecursive(force.technologies[techname])
        end
    end

    startNextResearch(force)
end)
