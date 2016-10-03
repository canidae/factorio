function getConfig(force)
    if not global.auto_research_config then
        global.auto_research_config = {}

        -- Disable Research Queue popup
        if remote.interfaces.RQ and remote.interfaces.RQ["popup"] then
            remote.call("RQ", "popup", false)
        end
    end
    if not global.auto_research_config[force.name] then
        global.auto_research_config[force.name] = {
            prioritized_techs = {},
            deprioritized_techs = {}
        }
        -- Enable Auto Research
        setAutoResearchEnabled(force, true)

        -- Research technologies requiring fewest ingredients first
        setFewestIngredientsEnabled(force, true)

        -- Disallow non-standard recipies
        setExtendedEnabled(force, false)

        -- Allow switching research
        setAllowSwitchingEnabled(force, true)
    end
    return global.auto_research_config[force.name]
end

function setAutoResearchEnabled(force, enabled)
    if not force then
        return
    end
    local config = getConfig(force)
    config.enabled = enabled

    -- start new research
    startNextResearch(force)
end

function setExtendedEnabled(force, enabled)
    if not force then
        return
    end
    getConfig(force).extended_enabled = enabled

    -- start new research
    startNextResearch(force)
end

function setFewestIngredientsEnabled(force, enabled)
    if not force then
        return
    end
    getConfig(force).fewest_ingredients = enabled

    -- start new research
    startNextResearch(force)
end

function setAllowSwitchingEnabled(force, enabled)
    if not force then
        return
    end
    getConfig(force).allow_switching = enabled

    -- start new research
    startNextResearch(force)
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
    if not getConfig(force).extended_enabled then
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
    local config = getConfig(force)
    if not config.enabled or (force.current_research and not config.allow_switching) then
        return
    end

    -- see if there are some techs we should research first
    local next_research = nil
    local least_effort = nil
    local fewest_ingredients = nil
    for _, techname in ipairs(config.prioritized_techs) do
        local tech = getPretechIfNeeded(force.technologies[techname])
        local should_replace = false
        -- so easy to get this wrong (which i already did), so we'll take the less compact, but more readable route
        if not next_research then
            should_replace = true
        elseif config.fewest_ingredients then
            if #tech.research_unit_ingredients < fewest_ingredients then
                should_replace = true
            end
        end
        if should_replace and canResearch(force, tech) then
            next_research = techname
            least_effort = 0
            fewest_ingredients = #tech.research_unit_ingredients
        end
    end

    -- if no prioritized tech should be researched first then research the "least effort" tech not researched yet
    local isDeprioritized = function(config, techname)
        for _, deprioritized in ipairs(config.deprioritized_techs) do
            if techname == deprioritized then
                return true
            end
        end
        return false
    end
    for techname, tech in pairs(force.technologies) do
        local effort = tech.research_unit_count * tech.research_unit_energy
        local should_replace = false
        if not next_research then
            should_replace = true
        elseif isDeprioritized(config, techname) then
            if config.fewest_ingredients then
                if #tech.research_unit_ingredients < fewest_ingredients then
                    should_replace = true
                elseif #tech.research_unit_ingredients == fewest_ingredients then
                    if isDeprioritized(config, next_research) then
                        if effort < least_effort then
                            should_replace = true
                        end
                    end
                end
            elseif isDeprioritized(config, next_research) then
                if effort < least_effort then
                    should_replace = true
                end
            end
        elseif config.fewest_ingredients then
            if #tech.research_unit_ingredients < fewest_ingredients then
                should_replace = true
            elseif #tech.research_unit_ingredients == fewest_ingredients then
                if effort < least_effort then
                    should_replace = true
                end
            end
        elseif effort < least_effort then
            should_replace = true
        end
        if should_replace and canResearch(force, tech) then
            next_research = techname
            least_effort = effort
            fewest_ingredients = #tech.research_unit_ingredients
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
        if tech and tech.researched then
            table.remove(config.prioritized_techs, i)
        end
    end
    for i = #config.deprioritized_techs, 1, -1 do
        local tech = force.technologies[config.deprioritized_techs[i]]
        if tech and tech.researched then
            table.remove(config.deprioritized_techs, i)
        end
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
            frameflow.add{type = "checkbox", name = "auto_research_fewest_ingredients", caption = {"auto_research_gui.fewest_ingredients"}, tooltip = {"auto_research_gui.fewest_ingredients_tooltip"}, state = config.fewest_ingredients or false}
            frameflow.add{type = "checkbox", name = "auto_research_extended_enabled", caption = {"auto_research_gui.extended_enabled"}, tooltip = {"auto_research_gui.extended_enabled_tooltip"}, state = config.extended_enabled or false}
            frameflow.add{type = "checkbox", name = "auto_research_allow_switching", caption = {"auto_research_gui.allow_switching"}, tooltip = {"auto_research_gui.allow_switching_tooltip"}, state = config.allow_switching or false}

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
            gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.prioritized, config.prioritized_techs, force)

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
            gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.deprioritized, config.deprioritized_techs, force)

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
            setAutoResearchEnabled(force, event.element.state)
        elseif name == "auto_research_fewest_ingredients" then
            setFewestIngredientsEnabled(force, event.element.state)
        elseif name == "auto_research_extended_enabled" then
            setExtendedEnabled(force, event.element.state)
        elseif name == "auto_research_allow_switching" then
            setAllowSwitchingEnabled(force, event.element.state)
        elseif string.len(name) > 5 then
            local prefix = string.sub(name, 1, 5)
            local techname = string.sub(name, 6)
            if force.technologies[techname] then
                -- remove tech from prioritized list
                for i = #config.prioritized_techs, 1, -1 do
                    if config.prioritized_techs[i] == techname then
                        table.remove(config.prioritized_techs, i)
                    end
                end
                -- and from deprioritized list
                for i = #config.deprioritized_techs, 1, -1 do
                    if config.deprioritized_techs[i] == techname then
                        table.remove(config.deprioritized_techs, i)
                    end
                end
                -- TODO: fix button names and use string.match
                if prefix == "ar_t_" then
                    -- add tech to top of prioritized list
                    table.insert(config.prioritized_techs, 1, techname)
                elseif prefix == "ar_b_" then
                    -- add tech to bottom of prioritized list
                    table.insert(config.prioritized_techs, techname)
                elseif prefix == "ar_a_" then
                    -- add tech to list of deprioritized techs
                    table.insert(config.deprioritized_techs, techname)
                end
                gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.prioritized, config.prioritized_techs, force)
                gui.updateTechnologyList(player.gui.top.auto_research_gui.flow.deprioritized, config.deprioritized_techs, force)
        
                -- start new research
                startNextResearch(force)
            end
        end
    end,


    updateTechnologyList = function(scrollpane, technologies, force)
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
            for _, techname in ipairs(technologies) do
                local entryflow = flow.add{type = "flow", direction = "horizontal"}
                entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "ar_d_" .. techname, sprite = "auto_research_delete"}
                entryflow.add{type = "label", caption = force.technologies[techname].localised_name}
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
                if string.find(name, text, 1, true) then
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
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "ar_t_" .. name, sprite = "auto_research_prioritize_top"}
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "ar_b_" .. name, sprite = "auto_research_prioritize_bottom"}
                    entryflow.add{type = "sprite-button", style = "auto_research_sprite_button", name = "ar_a_" .. name, sprite = "auto_research_deprioritize"}
                    entryflow.add{type = "label", style = "auto_research_tech_label", name = name, caption = tech.localised_name}
                end
            end
        end
        ::skip_rest::
    end
}

-- event hooks
script.on_configuration_changed(function()
    for _, force in pairs(game.forces) do
        getConfig(force) -- triggers initialization of force config
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
    enabled = setAutoResearchEnabled,
    extended = setExtendedEnabled,
    fewest_ingredients = setFewestIngredientsEnabled,
    allow_switching = setAllowSwitchingEnabled
})
