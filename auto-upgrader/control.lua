auto_upgrade_config_version = 1

function getConfig(force)
    -- TODO: don't do this shit all the time :|
    if not global.auto_upgrade then
        global.auto_upgrade = {}
    end
    if not global.auto_upgrade[force.name] or global.auto_upgrade[force.name].version ~= auto_upgrade_version then
        global.auto_upgrade[force.name] = {
            version = auto_upgrade_version,
            entities = {},
            entity = 1,
            upgrade = {},
            upgrade_loc = {},
            roboports = {}
        }

        -- can we improve this? why is it even so demanding? :s
        for _, surface in pairs(game.surfaces) do
            for _, entity in pairs(surface.find_entities_filtered{force = force.name}) do
                global.auto_upgrade[force.name].entities[#global.auto_upgrade[force.name].entities + 1] = entity
                if entity.logistic_cell then
                    global.auto_upgrade[force.name].roboports[#global.auto_upgrade[force.name].roboports + 1] = entity
                end
            end
        end
    end
    return global.auto_upgrade[force.name]
end

function onBuiltEntity(event)
    local entity = event.created_entity
    local force = entity.force
    local config = getConfig(force)
    if entity.logistic_cell then
        -- seems like a roboport
        config.roboports[#config.roboports + 1] = entity
    end
    config.entities[#config.entities + 1] = entity
end

function findBestModules(inventory, requested, include_modules)
    -- note: "inventory" may be LuaInventory or LuaLogisticsNetwork, they both provide (nearly) identical "get_item_count()" methods
    if not inventory or not requested then
        return nil
    end
    local result = {}
    for _, entry in pairs(requested) do
        local pre_item_name, level_cap = string.match(entry.item, "^(.*)-(%d)$")
        if level_cap then
            -- likely multiple levels of this module, search in inventory how many are available, starting at highest level
            local remaining = entry.count
            for i = level_cap, 1, -1 do
                local item_name = i > 1 and (pre_item_name .. "-" .. i) or pre_item_name
                if game.item_prototypes[item_name] then
                    local count = inventory.get_item_count(item_name)
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
        else
            -- doesn't look like there are multiple levels of this module
            local count = inventory.get_item_count(entry.item)
            if count > 0 then
                result[#result + 1] = {
                    item = entry.item,
                    count = min
                }
            end
        end
    end
    return result
end

function replaceEntity(entity, target_prototype, modules)
    entity.order_deconstruction(entity.force)
    local new_entity = game.surfaces[entity.surface.name].create_entity{name = "entity-ghost", inner_name = target_prototype, direction = entity.direction, position = entity.position, force = entity.force}
    if modules then
        new_entity.item_requests = modules
    end
    if entity.recipe then
        new_entity.recipe = entity.recipe
    end
end

function findNetworkOrPlayerInventory(entity)
    --local network = entity.force.find_logistic_network_by_position(entity.position, entity.surface)
    local config = getConfig(entity.force)
    for i = #config.roboports, 1, -1 do
        local roboport = config.roboports[i]
        if roboport.valid then
            local range = roboport.logistic_cell.construction_radius
            if range > 0 then
                local position = roboport.position
                if entity.position["x"] >= position.x - range and entity.position["x"] <= position.x + range then
                    if entity.position["y"] >= position.y - range and entity.position["y"] <= position.y + range then
                        -- entity within reach of this roboport
                        return roboport.logistic_network
                    end
                end
            end
        else
            table.remove(config.roboports, i)
        end
    end

    -- TODO: check if player has personal roboport, construction robots and is within reach of entity
end

function upgradeEntityIfNecessary(entity)
    local config = getConfig(entity.force)
    local upgrade = config.upgrade[entity.name]
    if not upgrade then
        return
    end
    local network = findNetworkOrPlayerInventory(entity)
    if not network or network.get_item_count(upgrade.target) < 1 then
        return
    end
    local replace = false
    if upgrade.target and entity.name ~= upgrade.target then
        -- upgrading from one entity to another, and we got the target entity in our logistic network
        replace = true
    end
    local current_modules = entity.get_module_inventory() and entity.get_module_inventory().get_contents() or nil
    local best_modules = (replace or upgrade.modules) and findBestModules(network, upgrade.modules, current_modules)
    if not replace and upgrade.modules and current_modules then
        -- possibly only upgrading modules, check if any modules can be upgraded
        for _, module in pairs(best_modules) do
            if current_modules[module.item] ~= module.count then
                replace = true
                break
            end
        end
    end
    if replace then
        replaceEntity(entity, upgrade.target or entity.name, best_modules)
    end
end

gui = {
    toggleGui = function(player)
        if player.gui.top.auto_upgrader_gui then
            player.gui.top.auto_upgrader_gui.destroy()
        else
            local force = player.force
            local config = getConfig(force)
            local frame = player.gui.top.add{
                type = "frame",
                name = "auto_upgrader_gui",
                direction = "vertical",
                caption = {"gui.title"}
            }
            local frameflow = frame.add{
                type = "flow",
                style = "auto_upgrader_list_flow",
                name = "flow",
                direction = "vertical"
            }

            -- checkboxes
            frameflow.add{type = "checkbox", name = "auto_upgrader_enabled", caption = {"gui.enabled"}, tooltip = {"gui.enabled_tooltip"}, state = config.enabled or false}

            -- add "<new entity>" entry
            local entryflow = frameflow.add{type = "flow", direction = "horizontal"}
            -- add button for adding new entities to upgrade
            entryflow.add{type = "sprite-button", style = "auto_upgrader_sprite_button", name = "auto_upgrader_add", sprite = "auto_upgrader_add"}
            entryflow.add{type = "label", caption = {"gui.add_entity"}}

            -- scrollpane
            local scrollpane = frameflow.add{
                type = "scroll-pane",
                name = "scrollpane",
                horizontal_scroll_policy = "never",
                vertical_scroll_policy = "auto"
            }
            scrollpane.style.top_padding = 5
            scrollpane.style.bottom_padding = 5
            scrollpane.style.maximal_height = 192
            gui.updateUpgradeList(scrollpane, force)
        end
    end,

    onClick = function(event)
        local player = game.players[event.player_index]
        local force = player.force
        local config = getConfig(force)
        local name = event.element.name
        if name == "auto_upgrader_enabled" then
            --setAutoUpgraderEnabled(force, event.element.state)
        elseif string.match(name, "auto_upgrader_add") then
            local stack = player.cursor_stack

            if stack.valid_for_read then
                config.upgrade[stack.name] = {}
                gui.updateUpgradeList(player.gui.top.auto_upgrader_gui.flow.scrollpane, force)
            end
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
            col1flow.add{type = "sprite-button", style = "auto_upgrader_sprite_button", name = "auto_upgrader_delete_" .. entityname, sprite = "auto_upgrader_delete"}
            col1flow.add{type = "label", caption = game.entity_prototypes[entityname].localised_name} -- TODO: must check if entity exists, entities may disappear when user change active mods

            -- button for adding modules
            local col2flow = table.add{type = "flow", direction = "horizontal"}
            col2flow.add{type = "sprite-button", style = "auto_upgrader_sprite_button", name = "auto_upgrader_add_module", sprite = "auto_upgrader_add_module"}
            -- TODO: list added modules

            -- button for upgrading entity
            local col3flow = table.add{type = "flow", direction = "horizontal"}
            col3flow.add{type = "sprite-button", style = "auto_upgrader_sprite_button", name = "auto_upgrader_upgrade_target", sprite = "auto_upgrader_upgrade_target"}
            col3flow.add{type = "label", caption = settings.target or {"gui.upgrade_target"}}
        end
    end
}


script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)
script.on_event(defines.events.on_gui_click, gui.onClick)

script.on_event(defines.events.on_tick, function(event)
    if game.tick % 60 > 0 then
        return
    end
    for _, force in pairs(game.forces) do
        local config = getConfig(force)
        config.entity = config.entity - 1
        if config.entity < 1 then
            config.entity = #config.entities
        end
        if config.entity > 0 then
            local entity = config.entities[config.entity]
            if entity.valid then
                upgradeEntityIfNecessary(entity)
            else
                table.remove(config.entities, config.entity)
            end
        end
    end
end)

-- keybinding hooks
script.on_event("auto_upgrader_toggle", function(event)
    local player = game.players[event.player_index]
    gui.toggleGui(player)
end)
