auto_upgrade_config_version = 1

function init()
    if not global.auto_upgrade then
        global.auto_upgrade = {}
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
                        if roboport.logistic_network.available_construction_robots > 9 then
                            -- and we got available construction robots (checking that we got a few to avoid DUTDUT)
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
        return false
    end
    local player
    for _, force_player in pairs(entity.force.players) do
        if not force_player.cursor_stack.valid_for_read then
            player = force_player
        end
    end
    if not player then
        return false
    end
    local network = findNetwork(entity, config)
    if not network then
        return false
    end
    local area = {{entity.position.x - 0.5, entity.position.y - 0.5}, {entity.position.x + 0.5, entity.position.y + 0.5}}
    local proxy = entity.surface.find_entities_filtered{area = area, name = "item-request-proxy"}
    if proxy[1] ~= nil then
        -- there's an "item-request-proxy" for this entity, don't attempt to upgrade
        return false
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
            if not current_modules[module.item] then
                if module_inventory.can_insert{name = module.item} then
                    replace = true
                    break
                end
            elseif current_modules[module.item] ~= module.count then
                replace = true
                break
            end
        end
    end
    if replace then
        replaceEntity(player, entity, upgrade.target or entity.name, best_modules)
    end
    return replace
end

function replaceEntity(player, entity, target_prototype, modules)
    local force = player.force
    local position = entity.position
    local area = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}
    player.cursor_stack.set_stack{name = "blueprint", count = 1}
    player.cursor_stack.create_blueprint{surface = entity.surface, force = force, area = area}
    local blueprint = player.cursor_stack.get_blueprint_entities()
    blueprint[1].name = target_prototype
    player.cursor_stack.set_stack{name = "blueprint", count = 1}
    player.cursor_stack.set_blueprint_entities(blueprint)
    entity.order_deconstruction(force)
    player.cursor_stack.build_blueprint{surface = entity.surface, force = force, position = position}
    player.cursor_stack.clear()
    -- request modules, if any
    local new_entity = entity.surface.find_entity("entity-ghost", {position.x, position.y})
    if modules then
        new_entity.item_requests = modules
    end
    -- reconnect wires
    if entity.circuit_connection_definitions then
        for _, connection in pairs(entity.circuit_connection_definitions) do
            if connection.target_entity.to_be_deconstructed(entity.force) then
                local ghost_entity = connection.target_entity.surface.find_entity("entity-ghost", {connection.target_entity.position.x, connection.target_entity.position.y})
                if not ghost_entity or not ghost_entity.valid then
                    say(force, {"auto_upgrade_messages.reconnect_wire_fail", game.entity_prototypes[target_prototype].localised_name, new_entity.position.x, new_entity.position.y})
                else
                    connection.target_entity = ghost_entity
                end
            end
            new_entity.connect_neighbour(connection)
        end
    end
end

function say(to, message)
    to.print{"auto_upgrade_messages.prefix", message}
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
            entryflow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_add", sprite = "auto_upgrade_add", tooltip = {"auto_upgrade_gui.add_entity_tooltip"}}

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
            gui.updateUpgradeList(scrollpane, player)
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
        elseif name == "auto_upgrade_add" then
            local stack = player.cursor_stack
            if not stack.valid_for_read then
                say(player, {"auto_upgrade_messages.item_required"}) 
            elseif not game.entity_prototypes[stack.name] then
                say(player, {"auto_upgrade_messages.not_an_entity"}) 
            elseif config.upgrade[stack.name] then
                say(player, {"auto_upgrade_messages.already_added", game.entity_prototypes[stack.name].localised_name}) 
            else
                config.upgrade[stack.name] = {
                    modules = {},
                    entities = {},
                    index = 1
                }

                -- find the entities for player force
                local settings = config.upgrade[stack.name]
                for _, surface in pairs(game.surfaces) do
                    settings.entities = surface.find_entities_filtered{name = stack.name, force = force.name}
                end
            end
        else
            local prefix, entityname = string.match(name, "^auto_upgrade_([^-]*)-(.*)$")
            if prefix == "delete" then
                config.upgrade[entityname] = nil
            elseif prefix == "target" then
                local stack = player.cursor_stack
                if not stack.valid_for_read then
                    if config.upgrade[entityname].target then
                        config.upgrade[entityname].target = nil
                    else
                        say(player, {"auto_upgrade_messages.item_required"}) 
                    end
                elseif not game.entity_prototypes[stack.name] then
                    say(player, {"auto_upgrade_messages.not_an_entity"}) 
                elseif game.entity_prototypes[entityname].type ~= game.entity_prototypes[stack.name].type then
                    say(player, {"auto_upgrade_messages.entity_mismatch", game.entity_prototypes[entityname].localised_name, game.entity_prototypes[stack.name].localised_name}) 
                elseif stack.name == config.upgrade[entityname].target then
                    config.upgrade[entityname].target = nil
                elseif stack.name == entityname then
                    say(player, {"auto_upgrade_messages.target_equals_source", game.entity_prototypes[entityname].localised_name}) 
                else
                    config.upgrade[entityname].target = stack.name
                end
            elseif prefix == "add_module" then
                local stack = player.cursor_stack
                if not stack.valid_for_read then
                    say(player, {"auto_upgrade_messages.item_required"}) 
                elseif stack.type ~= "module" then
                    say(player, {"auto_upgrade_messages.not_a_module"}) 
                else
                    -- check if we got no more than 8 modules set up for entity
                    local module_count = 0
                    for modulename, count in pairs(config.upgrade[entityname].modules) do
                        module_count = module_count + count
                    end
                    if module_count < 8 then
                        config.upgrade[entityname].modules[stack.name] = (config.upgrade[entityname].modules[stack.name] or 0) + 1
                    end
                end
            elseif prefix == "remove_module" then
                local entityname, modulename = string.match(entityname, "(.*)_%d+_(.*)$")
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
            gui.updateUpgradeList(player.gui.top.auto_upgrade_gui.flow.scrollpane, player)
        end
    end,

    updateUpgradeList = function(scrollpane, player)
        local force = player.force
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
            col1flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_delete-" .. entityname, sprite = "auto_upgrade_delete"}
            col1flow.add{type = "label", style = "auto_upgrade_label", caption = game.entity_prototypes[entityname].localised_name}

            -- button for adding/removing modules
            local col2flow = table.add{type = "flow", direction = "horizontal"}
            col2flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_add_module-" .. entityname, sprite = "auto_upgrade_add_module"}
            if settings.modules then
                local button_id = 0
                for modulename, count in pairs(settings.modules) do
                    for i = 1, count do
                        button_id = button_id + 1
                        local sprite = "auto_upgrade_module_" .. modulename
                        if not player.gui.is_valid_sprite_path(sprite) then
                            sprite = "auto_upgrade_unknown"
                        end
                        col2flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_remove_module-" .. entityname .. "_" .. button_id .. "_" .. modulename, sprite = sprite, tooltip = game.item_prototypes[modulename] and game.item_prototypes[modulename].localised_name or modulename}
                    end
                end
            end

            -- button for upgrading entity
            local col3flow = table.add{type = "flow", direction = "horizontal"}
            col3flow.add{type = "sprite-button", style = "auto_upgrade_sprite_button", name = "auto_upgrade_target-" .. entityname, sprite = "auto_upgrade_target"}
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
    for _, force in pairs(game.forces) do
        local config = getConfig(force)
        if config.enabled then
            local upgrade_index = config.upgrade_index or 1
            local valid_upgrade_index = false
            for _, settings in pairs(config.upgrade) do
                upgrade_index = upgrade_index - 1
                if upgrade_index == 0 then
                    valid_upgrade_index = true
                    settings.index = settings.index - 1
                    if settings.index < 1 then
                        settings.index = #settings.entities
                        config.upgrade_index = (config.upgrade_index or 1) + 1
                    end
                    if settings.index > 0 then
                        local entity = settings.entities[settings.index]
                        if entity.valid and not entity.to_be_deconstructed(force) then
                            if upgradeEntityIfNecessary(entity, config) then
                                table.remove(settings.entities, settings.index)
                            end
                        else
                            table.remove(settings.entities, settings.index)
                        end
                    end
                elseif upgrade_index < 0 then
                    break
                end
            end
            if not valid_upgrade_index then
                config.upgrade_index = 1
            end
        end
    end
end)

-- keybinding hooks
script.on_event("auto_upgrade_toggle", function(event)
    local player = game.players[event.player_index]
    gui.toggleGui(player)
end)
