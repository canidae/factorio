function getConfig(force, rescan_allowed_ingredients)
    if not global.auto_research_config then
        global.auto_research_config = {}

        -- Disable Research Queue popup
        if remote.interfaces.RQ and remote.interfaces.RQ["popup"] then
            remote.call("RQ", "popup", false)
        end
    end
    if not global.auto_research_config[force.name] then
        global.auto_research_config[force.name] = {
            prioritized_techs = {}, -- "prioritized" is "queued". kept for backwards compatability (because i'm lazy and don't want migration code)
            deprioritized_techs = {} -- "deprioritized" is "blacklisted". kept for backwards compatability (because i'm lazy and don't want migration code)
        }
        -- Enable Auto Research
        setAutoResearch(force, true)

        -- Disable queued only
        setQueuedOnly(force, false)

        -- Allow switching research
        setAllowSwitching(force, true)

        -- Print researched technology
        setAnnounceCompletedResearch(force, true)
    end
    if not global.auto_research_config[force.name].allowed_ingredients or rescan_allowed_ingredients then
        -- remember any old ingredients
        local old_ingredients = {}
        if global.auto_research_config[force.name].allowed_ingredients then
            for name, enabled in pairs(global.auto_research_config[force.name].allowed_ingredients) do
                old_ingredients[name] = enabled
            end
        end
        -- find all possible tech ingredients
        global.auto_research_config[force.name].allowed_ingredients = {}
        for _, tech in pairs(force.technologies) do
            for _, ingredient in pairs(tech.research_unit_ingredients) do
                global.auto_research_config[force.name].allowed_ingredients[ingredient.name] = (old_ingredients[ingredient.name] == nil or old_ingredients[ingredient.name])
            end
        end
    end
    return global.auto_research_config[force.name]
end

function setAutoResearch(force, enabled)
    if not force then
        return
    end
    local config = getConfig(force)
    config.enabled = enabled

    -- start new research
    startNextResearch(force)
end

function setQueuedOnly(force, enabled)
    if not force then
        return
    end
    getConfig(force).prioritized_only = enabled

    -- start new research
    startNextResearch(force)
end

function setAllowSwitching(force, enabled)
    if not force then
        return
    end
    getConfig(force).allow_switching = enabled

    -- start new research
    startNextResearch(force)
end

function setAnnounceCompletedResearch(force, enabled)
    if not force then
        return
    end
    getConfig(force).announce_completed = enabled
end

function getPretechs(tech)
    local pretechs = {}
    pretechs[#pretechs + 1] = tech
    local index = 1
    while (index <= #pretechs) do
        for _, pretech in pairs(pretechs[index].prerequisites) do
            if pretech.enabled and not pretech.researched then
                pretechs[#pretechs + 1]  = pretech
            end
        end
        index = index + 1
    end
    return pretechs
end

function canResearch(force, tech, config)
    if not tech or tech.researched or not tech.enabled then
        return false
    end
    for _, pretech in pairs(tech.prerequisites) do
        if not pretech.researched then
            return false
        end
    end
    for _, ingredient in pairs(tech.research_unit_ingredients) do
        if not config.allowed_ingredients[ingredient.name] then
            return false
        end
    end
    for _, deprioritized in pairs(config.deprioritized_techs) do
        if tech.name == deprioritized then
            return false
        end
    end
    return true
end

function startNextResearch(force)
    local config = getConfig(force)
    if not config.enabled or (force.current_research and not config.allow_switching) or config.last_research_finish_tick == game.tick then
        return
    end
    config.last_research_finish_tick = game.tick -- if multiple research finish same tick for same force, the user probably enabled all techs

    -- function for calculating tech effort
    local calcEffort = function(tech)
        local tech_ingredients = 0
        for _, ingredient in pairs(tech.research_unit_ingredients) do
            tech_ingredients = tech_ingredients + ingredient.amount
        end
        return tech.research_unit_count * tech.research_unit_energy * tech_ingredients
    end

    -- see if there are some techs we should research first
    local next_research = nil
    local least_effort = nil
    for _, techname in pairs(config.prioritized_techs) do
        local tech = force.technologies[techname]
        if tech then
            local pretechs = getPretechs(tech)
            for _, pretech in pairs(pretechs) do
                local effort = calcEffort(pretech)
                if (not least_effort or effort < least_effort) and canResearch(force, pretech, config) then
                    next_research = pretech.name
                    least_effort = effort
                end
            end
        end
    end

    -- if no queued tech should be researched then research the "least effort" tech not researched yet
    if not config.prioritized_only and not next_research then
        for techname, tech in pairs(force.technologies) do
            local effort = calcEffort(tech)
            if (not least_effort or effort < least_effort) and canResearch(force, tech, config) then
                next_research = techname
                least_effort = effort
            end
        end
    end

    force.current_research = next_research
end

function onResearchFinished(event)
    local force = event.research.force
    local config = getConfig(force)
    -- remove researched stuff from prioritized_techs and deprioritized_techs
    for i = #config.prioritized_techs, 1, -1 do
        local tech = force.technologies[config.prioritized_techs[i]]
        if not tech or tech.researched then
            table.remove(config.prioritized_techs, i)
        end
    end
    for i = #config.deprioritized_techs, 1, -1 do
        local tech = force.technologies[config.deprioritized_techs[i]]
        if not tech or tech.researched then
            table.remove(config.deprioritized_techs, i)
        end
    end
    -- announce completed research
    if config.announce_completed then
        local level = ""
        if event.research.research_unit_count_formula then
            level = (event.research.researched and event.research.level) or (event.research.level - 1)
        end
        force.print{"auto_research.announce_completed", event.research.localised_name, level}
    end

    startNextResearch(event.research.force)
end

-- user interface
gui = {
    toggleGui = function(player)
        if player.gui.top.auto_research_gui then
            player.gui.top.auto_research_gui.destroy()
        else
            local force = player.force
            local config = getConfig(force)
            local frame = player.gui.top.add{
                type = "frame",
                name = "auto_research_gui",
                direction = "vertical",
                caption = {"auto_research_gui.title"}
            }
            local frameflow = frame.add{
                type = "flow",
                style = "auto_research_list_flow",
                name = "flow",
                direction = "vertical"
            }

            -- checkboxes
            frameflow.add{type = "checkbox", name = "auto_research_enabled", caption = {"auto_research_gui.enabled"}, tooltip = {"auto_research_gui.enabled_tooltip"}, state = config.enabled or false}
            frameflow.add{type = "checkbox", name = "auto_research_queued_only", caption = {"auto_research_gui.prioritized_only"}, tooltip = {"auto_research_gui.prioritized_only_tooltip"}, state = config.prioritized_only or false}
            frameflow.add{type = "checkbox", name = "auto_research_allow_switching", caption = {"auto_research_gui.allow_switching"}, tooltip = {"auto_research_gui.allow_switching_tooltip"}, state = config.allow_switching or false}
            frameflow.add{type = "checkbox", name = "auto_research_announce_completed", caption = {"auto_research_gui.announce_completed"}, tooltip = {"auto_research_gui.announce_completed_tooltip"}, state = config.announce_completed or false}

            -- allowed ingredients
            frameflow.add{
                type = "label",
                style = "auto_research_header_label",
                caption = {"auto_research_gui.allowed_ingredients_label"}
            }
            local allowed_ingredients = frameflow.add{
                type = "flow",
                style = "auto_research_list_flow",
                name = "allowed_ingredients",
                direction = "vertical"
            }
            gui.updateAllowedIngredientsList(player.gui.top.auto_research_gui.flow.allowed_ingredients, player, config)

            -- prioritized techs
            frameflow.add{
                type = "label",
                style = "auto_research_header_label",
                caption = {"auto_research_gui.prioritized_label"}
            }
            local prioritized = frameflow.add{
                type = "scroll-pane",
                name = "prioritized",
                horizontal_scroll_policy = "never",
                vertical_scroll_policy = "auto"
            }
            prioritized.style.top_padding = 5
            prioritized.style.bottom_padding = 5
            prioritized.style.maximal_height = 192
            -- draw prioritized tech list
            gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.prioritized, config.prioritized_techs, player)

            -- deprioritized techs
            frameflow.add{
                type = "label",
                style = "auto_research_header_label",
                caption = {"auto_research_gui.deprioritized_label"}
            }
            local deprioritized = frameflow.add{
                type = "scroll-pane",
                name = "deprioritized",
                horizontal_scroll_policy = "never",
                vertical_scroll_policy = "auto"
            }
            deprioritized.style.top_padding = 5
            deprioritized.style.bottom_padding = 5
            deprioritized.style.maximal_height = 192
            -- draw deprioritized tech list
            gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.deprioritized, config.deprioritized_techs, player)

            -- search for techs
            local searchflow = frameflow.add{
                type = "flow",
                style = "auto_research_tech_flow",
                direction = "horizontal"
            }
            searchflow.add{
                type = "label",
                style = "auto_research_header_label",
                caption = {"auto_research_gui.search_label"}
            }
            searchflow.add{
                type = "textfield",
                name = "auto_research_search_text",
                tooltip = {"auto_research_gui.search_tooltip"}
            }
            local search = frameflow.add{
                type = "scroll-pane",
                name = "search",
                horizontal_scroll_policy = "never",
                vertical_scroll_policy = "auto"
            }
            search.style.top_padding = 5
            search.style.bottom_padding = 5
            search.style.maximal_height = 192
            -- draw search result list
            gui.updateSearchResult(player, "")
        end
    end,

    onClick = function(event)
        local player = game.players[event.player_index]
        local force = player.force
        local config = getConfig(force)
        local name = event.element.name
        if name == "auto_research_enabled" then
            setAutoResearch(force, event.element.state)
        elseif name == "auto_research_queued_only" then
            setQueuedOnly(force, event.element.state)
        elseif name == "auto_research_allow_switching" then
            setAllowSwitching(force, event.element.state)
        elseif name == "auto_research_announce_completed" then
            setAnnounceCompletedResearch(force, event.element.state)
        else
            local prefix, name = string.match(name, "^auto_research_([^-]*)-(.*)$")
            if prefix == "allow_ingredient" then
                config.allowed_ingredients[name] = not config.allowed_ingredients[name]
                gui.updateAllowedIngredientsList(player.gui.top.auto_research_gui.flow.allowed_ingredients, player, config)
                startNextResearch(force)
            elseif name and force.technologies[name] then
                -- remove tech from prioritized list
                for i = #config.prioritized_techs, 1, -1 do
                    if config.prioritized_techs[i] == name then
                        table.remove(config.prioritized_techs, i)
                    end
                end
                -- and from deprioritized list
                for i = #config.deprioritized_techs, 1, -1 do
                    if config.deprioritized_techs[i] == name then
                        table.remove(config.deprioritized_techs, i)
                    end
                end
                if prefix == "queue_top" then
                    -- add tech to top of prioritized list
                    table.insert(config.prioritized_techs, 1, name)
                elseif prefix == "queue_bottom" then
                    -- add tech to bottom of prioritized list
                    table.insert(config.prioritized_techs, name)
                elseif prefix == "blacklist" then
                    -- add tech to list of deprioritized techs
                    table.insert(config.deprioritized_techs, name)
                end
                gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.prioritized, config.prioritized_techs, player)
                gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.deprioritized, config.deprioritized_techs, player)

                -- start new research
                startNextResearch(force)
            end
        end
    end,

    updateAllowedIngredientsList = function(flow, player, config)
        local counter = 1
        while flow["flow" .. counter] do
            flow["flow" .. counter].destroy()
            counter = counter + 1
        end
        counter = 1
        for ingredientname, allowed in pairs(config.allowed_ingredients) do
            local flowname = "flow" .. math.floor(counter / 10) + 1
            local ingredientflow = flow[flowname]
            if not ingredientflow then
                ingredientflow = flow.add {
                    type = "flow",
                    style = "auto_research_tech_flow",
                    name = flowname,
                    direction = "horizontal"
                }
            end
            local sprite = "auto_research_tool_" .. ingredientname
            if not player.gui.is_valid_sprite_path(sprite) then
                sprite = "auto_research_unknown"
            end
            ingredientflow.add{type = "sprite-button", style = "auto_research_sprite_button_toggle" .. (allowed and "_pressed" or ""), name = "auto_research_allow_ingredient-" .. ingredientname, sprite = sprite}
            counter = counter + 1
        end
    end,

    updateTechnologyList = function(scrollpane, technologies, player)
        if scrollpane.flow then
            scrollpane.flow.destroy()
        end
        local flow = scrollpane.add{
            type = "flow",
            style = "auto_research_list_flow",
            name = "flow",
            direction = "vertical"
        }
        if #technologies > 0 then
            for _, techname in pairs(technologies) do
                local tech = player.force.technologies[techname]
                if tech then
                    local entryflow = flow.add{type = "flow", style = "auto_research_tech_flow", direction = "horizontal"}
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "auto_research_delete-" .. techname, sprite = "auto_research_delete"}
                    entryflow.add{type = "label", style = "auto_research_tech_label", caption = tech.localised_name}
                    for _, ingredient in pairs(tech.research_unit_ingredients) do
                        local sprite = "auto_research_tool_" .. ingredient.name
                        if not player.gui.is_valid_sprite_path(sprite) then
                            sprite = "auto_research_unknown"
                        end
                        entryflow.add{type = "sprite", style = "auto_research_sprite", sprite = sprite}
                    end
                end
            end
        else
            local entryflow = flow.add{type = "flow", direction = "horizontal"}
            entryflow.add{type = "label", caption = {"auto_research_gui.none"}}
        end
    end,

    updateSearchResult = function(player, text)
        local scrollpane = player.gui.top.auto_research_gui.flow.search
        if scrollpane.flow then
            scrollpane.flow.destroy()
        end
        local flow = scrollpane.add{
            type = "flow",
            style = "auto_research_list_flow",
            name = "flow",
            direction = "vertical"
        }
        local shown = 0
        text = string.lower(text)
        for name, tech in pairs(player.force.technologies) do
            if not tech.researched and tech.enabled then
                if shown > 30 then
                    goto skip_rest
                end
                local showtech = false
                if string.find(string.lower(name), text, 1, true) then
                    showtech = true
                else
                    for _, effect in pairs(tech.effects) do
                        if string.find(effect.type, text, 1, true) then
                            showtech = true
                        elseif effect.type == "unlock-recipe" then
                            if string.find(effect.recipe, text, 1, true) then
                                showtech = true
                            end
                        end
                    end
                end
                if showtech then
                    shown = shown + 1
                    local entryflow = flow.add{type = "flow", style = "auto_research_tech_flow", direction = "horizontal"}
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "auto_research_queue_top-" .. name, sprite = "auto_research_prioritize_top"}
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "auto_research_queue_bottom-" .. name, sprite = "auto_research_prioritize_bottom"}
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "auto_research_blacklist-" .. name, sprite = "auto_research_deprioritize"}
                    entryflow.add{type = "label", style = "auto_research_tech_label", name = name, caption = tech.localised_name}
                    for _, ingredient in pairs(tech.research_unit_ingredients) do
                        local sprite = "auto_research_tool_" .. ingredient.name
                        if not player.gui.is_valid_sprite_path(sprite) then
                            sprite = "auto_research_unknown"
                        end
                        entryflow.add{type = "sprite", style = "auto_research_sprite", sprite = sprite}
                    end
                end
            end
        end
        ::skip_rest::
    end
}

-- event hooks
script.on_configuration_changed(function()
    for _, force in pairs(game.forces) do
        getConfig(force, true) -- triggers initialization of force config
    end
end)
script.on_event(defines.events.on_player_created, function(event)
    getConfig(game.players[event.player_index].force) -- triggers initialization of force config
end)
script.on_event(defines.events.on_force_created, function(event)
    getConfig(event.force) -- triggers initialization of force config
end)
script.on_event(defines.events.on_research_finished, onResearchFinished)
script.on_event(defines.events.on_gui_click, gui.onClick)
script.on_event(defines.events.on_gui_text_changed, function(event)
    if event.element.name ~= "auto_research_search_text" then
        return
    end
    gui.updateSearchResult(game.players[event.player_index], event.element.text)
end)

-- keybinding hooks
script.on_event("auto_research_toggle", function(event)
    local player = game.players[event.player_index]
    gui.toggleGui(player)
end)

-- Add remote interfaces for enabling/disabling Auto Research
remote.add_interface("auto_research", {
    enabled = setAutoResearch,
    queued_only = setQueuedOnly,
    allow_switching = setAllowSwitching,
    announce_completed = setAnnounceCompletedResearch
})
