auto_upgrade_config_version = 1

function init()
    if not global.auto_upgrade then
        global.auto_upgrade = {
            enabled = true
        }
    end
    for _, force in pairs(game.forces) do
        if not global.auto_upgrade[force.name] or global.auto_upgrade[force.name].version ~= auto_upgrade_config_version then
            global.auto_upgrade[force.name] = {
                version = auto_upgrade_config_version,
                enabled = true,
                cap_module_level = false,
                upgrade = {},
                roboports = {},
                module_max_level = {}
            }
            -- find roboports
            for _, surface in pairs(game.surfaces) do
                for _, entity in pairs(surface.find_entities_filtered{name = "roboport", force = force.name}) do
                    global.auto_upgrade[force.name].roboports[#global.auto_upgrade[force.name].roboports + 1] = entity
                end
            end
        else
            -- check that entities and modules still exist in game (and remove from settings if not)
            for entityname, settings in pairs(global.auto_upgrade[force.name].upgrade) do
                if not game.entity_prototypes[entityname] then
                    global.auto_upgrade[force.name].upgrade[entityname] = nil
                else
                    for modulename, _ in pairs(settings.modules) do
                        if not game.item_prototypes[modulename] then
                            settings.modules[modulename] = nil
                        end
                    end
                end
            end
            -- update max cap level for known modules
            for modulebasename, _ in pairs(global.auto_upgrade[force.name].module_max_level) do
                updateModuleMaxLevel(modulebasename, global.auto_upgrade[force.name])
            end
        end
    end
end

function updateModuleMaxLevel(modulebasename, config)
    if not game.item_prototypes[modulebasename] then
        config.module_max_level[modulebasename] = nil
    else
        local level = 1
        while game.item_prototypes[modulebasename .. "-" .. (level + 1)] do
            level = level + 1
        end
        config.module_max_level[modulebasename] = level
    end
end

function getConfig(force)
    return global.auto_upgrade[force.name]
end

function onBuiltEntity(event)
    local entity = event.created_entity
    local config = getConfig(entity.force)
    if entity.logistic_cell then
        -- seems like a roboport
        config.roboports[#config.roboports + 1] = entity
    end
    if config.upgrade[entity.name] then
        config.upgrade[entity.name].entities[#config.upgrade[entity.name].entities + 1] = entity
    end
end

function findBestModules(network, requested, include_modules, config)
    if not network or not requested then
        return nil
    end
    local result = {}
    for module, count in pairs(requested) do
        local modulebasename, level_cap = string.match(module, "^(.*)-(%d*)$")
        if not modulebasename then
            modulebasename = module
            level_cap = 1
        end
        if not config.cap_module_level then
            if not config.module_max_level[modulebasename] then
                updateModuleMaxLevel(modulebasename, config)
            end
            level_cap = config.module_max_level[modulebasename] or level_cap
        end
        local remaining = count
        for i = level_cap, 1, -1 do
            local item_name = i > 1 and (modulebasename .. "-" .. i) or modulebasename
            if game.item_prototypes[item_name] then
                local count = network.get_item_count(item_name)
                if include_modules and include_modules[item_name] then
                    count = count + include_modules[item_name]
                end
                if count > 0 then
                    local min = math.min(count, remaining)
                    result[#result + 1] = {
                        item = item_name,
                        count = min
                    }
                    remaining = remaining - min
                    if remaining <= 0 then
                        break
                    end
                end
            end
        end
    end
    return result
end

function findNetwork(entity, config)
    for i = #config.roboports, 1, -1 do
        local roboport = config.roboports[i]
        if roboport.valid then
            local range = roboport.logistic_cell.construction_radius
            if range > 0 then
                local position = roboport.position
                if entity.position.x >= position.x - range and entity.position.x <= position.x + range then
                    if entity.position.y >= position.y - range and entity.position.y <= position.y + range then
                        -- entity within reach of this roboport
                        if roboport.logistic_network.available_construction_robots > 5 then
                            -- and we got available construction robots (more than 5 to avoid some DUTDUT)
                            return roboport.logistic_network
                        end
                    end
                end
            end
        else
            table.remove(config.roboports, i)
        end
    end
end

function upgradeEntityIfNecessary(entity, config)
    local upgrade = config.upgrade[entity.name]
    if not upgrade then
        return
    end
    local network = findNetwork(entity, config)
    if not network then
        return
    end
    local area = {{entity.position.x - 0.5, entity.position.y - 0.5}, {entity.position.x + 0.5, entity.position.y + 0.5}}
    local proxy = entity.surface.find_entities_filtered{area = area, name = "item-request-proxy"}
    if proxy[1] ~= nil then
        -- there's an "item-request-proxy" for this entity, don't attempt to upgrade
        return
    end

    local replace = false
    if upgrade.target and entity.name ~= upgrade.target and network.get_item_count(upgrade.target) > 0 then
        -- upgrading from one entity to another, and we got the target entity in our logistic network
        replace = true
    end
    local module_inventory = entity.get_module_inventory()
    local current_modules = module_inventory and module_inventory.get_contents() or nil
    local best_modules = (replace or upgrade.modules) and findBestModules(network, upgrade.modules, current_modules, config)
    if not replace and upgrade.modules and current_modules then
        -- possibly only upgrading modules, check if any modules can be upgraded
        for _, module in pairs(best_modules) do
            if current_modules[module.item] ~= module.count then
                replace = true
                break
            end
        end
        if replace then
            local current_count = 0
            for modulename, count in pairs(current_modules) do
                current_count = current_count + count
            end
            local best_count = 0
            for _, module in pairs(best_modules) do
                best_count = best_count + module.count
            end
            if best_count > current_count and not module_inventory.can_insert{name = best_modules[1].item} then
                -- can't place any more modules into this entity
                replace = false
            end
        end
    end
    if replace then
        replaceEntity(entity, upgrade.target or entity.name, best_modules)
    end
end

function replaceEntity(entity, target_prototype, modules)
    local recipe = (entity.type == "crafting-machine" and entity.recipe) or nil
    entity.order_deconstruction(entity.force)
    local data = {
        name = "entity-ghost",
        inner_name = target_prototype,
        direction = entity.direction,
        position = entity.position,
        force = entity.force
    }
    if entity.type == "underground-belt" then
        data.type = entity.belt_to_ground_type
    end
    local new_entity = game.surfaces[entity.surface.name].create_entity(data)
    if modules then
        new_entity.item_requests = modules
    end
    if entity.type == "assembling-machine" and entity.recipe then
        new_entity.recipe = entity.recipe
    end
end

function tellPlayer(player, message)
    player.print{"auto_upgrade_messages.prefix", message}
end

gui = {
    toggleGui = function(player)
        local force = player.force
        local config = getConfig(force)
        if player.gui.top.auto_upgrade_gui then
            player.gui.top.auto_upgrade_gui.destroy()
        else
            local frame = player.gui.top.add{
                type = "frame",
                name = "auto_upgrade_gui",
                direction = "vertical",
                caption = {"auto_upgrade_gui.title"}
            }
            local frameflow = frame.add{
                type = "flow",
                style = "auto_upgrade_list_flow",
                name = "flow",
                direction = "vertical"
            }

            -- checkboxes
            frameflow.add{type = "checkbox", style = "auto_upgrade_checkbox", name = "auto_upgrade_enabled", caption = {"auto_upgrade_gui.enabled"}, tooltip = {"auto_upgrade_gui.enabled_tooltip"}, state = config.enabled or false}
            frameflow.add{type = "checkbox", style = "auto_upgrade_checkbox", name = "auto_upgrade_cap_module_level", caption = {"auto_upgrade_gui.cap_module_level"}, tooltip = {"auto_upgrade_gui.cap_module_level_tooltip"}, state = config.cap_module_level or false}

            -- add "<new entity>" entry
            local entryflow = frameflow.add{type = "flow", direction = "horizontal"}
            entryflow.style.top_padding = 12
            entryflow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_add", sprite = "auto_upgrade_add"}
            entryflow.add{type = "label", style = "auto_upgrade_label", caption = {"auto_upgrade_gui.add_entity"}}

            -- scrollpane
            local scrollpane = frameflow.add{
                type = "scroll-pane",
                name = "scrollpane",
                horizontal_scroll_policy = "never",
                vertical_scroll_policy = "auto"
            }
            scrollpane.style.top_padding = 5
            scrollpane.style.bottom_padding = 5
            scrollpane.style.maximal_height = 536
            gui.updateUpgradeList(scrollpane, force)
        end
    end,

    onClick = function(event)
        local player = game.players[event.player_index]
        local force = player.force
        local config = getConfig(force)
        local name = event.element.name
        if name == "auto_upgrade_enabled" then
            config.enabled = event.element.state
        elseif name == "auto_upgrade_cap_module_level" then
            config.cap_module_level = event.element.state
        elseif string.match(name, "^auto_upgrade_add$") then
            local stack = player.cursor_stack
            if stack.valid_for_read and not config.upgrade[stack.name] and game.entity_prototypes[stack.name] then
                config.upgrade[stack.name] = {
                    modules = {},
                    entities = {},
                    index = 1
                }

                -- find the entities for player force
                local settings = config.upgrade[stack.name]
                for _, surface in pairs(game.surfaces) do
                    for _, entity in pairs(surface.find_entities_filtered{name = stack.name, force = force.name}) do
                        settings.entities[#settings.entities + 1] = entity
                    end
                end
            end
        else
            -- TODO: fix naming like in auto-research (use "-" as delimiter)
            local entityname = string.match(name, "^auto_upgrade_delete_(.*)$")
            if entityname then
                config.upgrade[entityname] = nil
            end

            local entityname = string.match(name, "^auto_upgrade_target_(.*)$")
            if entityname then
                local stack = player.cursor_stack
                if stack.valid_for_read and entityname ~= stack.name then
                    local e_cb = game.entity_prototypes[entityname].collision_box
                    local t_cb = game.entity_prototypes[stack.name].collision_box
                    if e_cb.left_top.x == t_cb.left_top.x and e_cb.left_top.y == t_cb.left_top.y and e_cb.right_bottom.x == t_cb.right_bottom.x and e_cb.right_bottom.y == t_cb.right_bottom.y then
                        config.upgrade[entityname].target = stack.name
                    else
                        tellPlayer(player, {"auto_upgrade_messages.cant_upgrade", entityname, stack.name}) 
                    end
                else
                    config.upgrade[entityname].target = nil
                end
            end

            local entityname = string.match(name, "^auto_upgrade_add_module_(.*)$")
            if entityname then
                local stack = player.cursor_stack
                if stack.valid_for_read and game.item_prototypes[stack.name].type == "module" then
                    -- check if we got no more than 8 modules set up for entity
                    local module_count = 0
                    for modulename, count in pairs(config.upgrade[entityname].modules) do
                        module_count = module_count + count
                    end
                    if module_count < 8 then
                        config.upgrade[entityname].modules[stack.name] = (config.upgrade[entityname].modules[stack.name] or 0) + 1
                    end
                end
            end

            local entityname, modulename = string.match(name, "^auto_upgrade_remove_module_(.*)_%d+_(.*)$")
            if entityname then
                if config.upgrade[entityname].modules[modulename] > 1 then
                    config.upgrade[entityname].modules[modulename] = config.upgrade[entityname].modules[modulename] - 1
                else
                    config.upgrade[entityname].modules[modulename] = nil
                end
                -- if we happen to hold a module on cursor, add that
                local stack = player.cursor_stack
                if stack.valid_for_read and game.item_prototypes[stack.name].type == "module" then
                    config.upgrade[entityname].modules[stack.name] = (config.upgrade[entityname].modules[stack.name] or 0) + 1
                end
            end
        end
        if player.gui.top.auto_upgrade_gui then
            gui.updateUpgradeList(player.gui.top.auto_upgrade_gui.flow.scrollpane, force)
        end
    end,

    updateUpgradeList = function(scrollpane, force)
        if scrollpane.table then
            scrollpane.table.destroy()
        end

        -- add table
        local table = scrollpane.add{
            type = "table",
            name = "table",
            colspan = 3
        }

        -- add list of entities to upgrade
        local config = getConfig(force)
        for entityname, settings in pairs(config.upgrade) do
            local col1flow = table.add{type = "flow", direction = "horizontal"}
            col1flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_delete_" .. entityname, sprite = "auto_upgrade_delete"}
            col1flow.add{type = "label", style = "auto_upgrade_label", caption = game.entity_prototypes[entityname].localised_name}

            -- button for adding/removing modules
            local col2flow = table.add{type = "flow", direction = "horizontal"}
            col2flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_add_module_" .. entityname, sprite = "auto_upgrade_add_module"}
            if settings.modules then
                local button_id = 0
                for modulename, count in pairs(settings.modules) do
                    for i = 1, count do
                        button_id = button_id + 1
                        col2flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_remove_module_" .. entityname .. "_" .. button_id .. "_" .. modulename, sprite = "auto_upgrade_module_" .. modulename}
                    end
                end
            end

            -- button for upgrading entity
            local col3flow = table.add{type = "flow", direction = "horizontal"}
            col3flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_target_" .. entityname, sprite = "auto_upgrade_target"}
            col3flow.add{type = "label", style = "auto_upgrade_label", caption = settings.target and game.entity_prototypes[settings.target].localised_name or {"auto_upgrade_gui.upgrade_target"}}
        end
    end
}


script.on_init(init)
script.on_configuration_changed(init)
script.on_event(defines.events.on_force_created, init)
script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)
script.on_event(defines.events.on_gui_click, gui.onClick)

script.on_event(defines.events.on_tick, function(event)
    if game.tick % 16 > 0 then
        return
    end
    -- TODO: remove on_tick handler when AU is disabled?
    -- TODO: only upgrade modules if we can fill with best modules?
    -- TODO: need to track how many we're currently upgrading and see how many items there are in storage, or we'll upgrade stuff too soon and run out of materials
    -- TODO: also keep track of player requested stuff, if stuff gets moved to player then we also will run out of materials
    for _, force in pairs(game.forces) do
        local config = getConfig(force)
        if config.enabled then
            for entityname, settings in pairs(config.upgrade) do
                settings.index = settings.index - 1
                if settings.index < 1 then
                    settings.index = #settings.entities
                end
                if settings.index > 0 then
                    local entity = settings.entities[settings.index]
                    if entity.valid then
                        if not entity.to_be_deconstructed(force) then
                            upgradeEntityIfNecessary(entity, config)
                        end
                    else
                        table.remove(settings.entities, settings.index)
                    end
                end
            end
        end
    end
end)

-- keybinding hooks
script.on_event("auto_upgrade_toggle", function(event)
    local player = game.players[event.player_index]
    gui.toggleGui(player)
end)
