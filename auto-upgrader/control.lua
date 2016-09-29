upgrade_config = { -- TODO: delete, replace with GUI
    ["assembling-machine-2"] = {
        modules = {
            {
                item = "speed-module-3",
                count = 2
            }
        },
        target = "assembling-machine-3"
    },
    ["assembling-machine-3"] = {
        modules = {
            {
                item = "speed-module-3",
                count = 2
            },
            {
                item = "productivity-module-3",
                count = 2
            }
        }
    }
}

auto_upgrade_config_version = 1

function getConfig(force)
    -- TODO: don't do this shit all the time :|
    if not global.auto_upgrade_config then
        global.auto_upgrade_config = {}
    end
    if not global.auto_upgrade_config[force.name] or global.auto_upgrade_config[force.name].version ~= auto_upgrade_config_version then
        global.auto_upgrade_config[force.name] = {
            version = auto_upgrade_config_version,
            entities = {},
            entity = 1,
            upgrade_loc = {},
            roboports = {}
        }

        -- can we improve this? why is it even so demanding? :s
        for _, surface in pairs(game.surfaces) do
            for _, entity in pairs(surface.find_entities_filtered{force = force.name}) do
                global.auto_upgrade_config[force.name].entities[#global.auto_upgrade_config[force.name].entities + 1] = entity
                if entity.logistic_cell then
                    global.auto_upgrade_config[force.name].roboports[#global.auto_upgrade_config[force.name].roboports + 1] = entity
                end
            end
        end
    end
    return global.auto_upgrade_config[force.name]
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
    local upgrade = upgrade_config[entity.name]
    if not upgrade then
        return
    end
    local network = findNetworkOrPlayerInventory(entity)
    if network.get_item_count(upgrade.target) < 1 then
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
        end
    end
}


script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)

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
