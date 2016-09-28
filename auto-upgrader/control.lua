upgrade_config = {
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

function getConfig(force)
    if not global.auto_upgrade_config then
        global.auto_upgrade_config = {}
    end
    if not global.auto_upgrade_config[force.name] then
        global.auto_upgrade_config[force.name] = {
            entities = {},
            entity = 1,
            upgrade_loc = {}
        }
    end
    return global.auto_upgrade_config[force.name]
end

function onBuiltEntity(event)
    local entity = event.created_entity
    if entity.get_module_inventory() then -- or if entity can be upgraded to a better type (ie belts, assemblers)
        local force = entity.force
        local config = getConfig(force)
        config.entities[#config.entities + 1] = entity
    end
end

function findBestModules(network, requested)
    if not network or not requested then
        return nil
    end
    local result = {}
    for _, entry in pairs(requested) do
        local pre_item_name, level_cap = string.match(entry.item, "^(.*)-(%d)$")
        if level_cap then
            -- likely multiple levels of this module, search in logistic network how many are available, starting at highest level
            local remaining = entry.count
            for i = level_cap, 1, -1 do
                local item_name = i > 1 and (pre_item_name .. "-" .. i) or pre_item_name
                if game.item_prototypes[item_name] then
                    local count = network.get_item_count(item_name)
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
            local count = network.get_item_count(entry.item)
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

function upgradeEntityIfNecessary(entity)
    local upgrade = upgrade_config[entity.name]
    if upgrade then
        local network = entity.force.find_logistic_network_by_position(entity.position, entity.surface)
        local replace = false
        if upgrade.target and entity.name ~= upgrade.target and network.get_item_count(upgrade.target) > 1 then
            -- upgrading from one entity to another, and we got the target entity in our logistic network
            replace = true
        end
        local best_modules = (replace or upgrade.modules) and findBestModules(network, upgrade.modules)
        if not replace and upgrade.modules then
            -- possibly only upgrading modules, check if any modules can be upgraded
            local inventory = entity.get_module_inventory()
            for _, module in pairs(best_modules) do
                local item_count = inventory.get_item_count(module.item)
                if item_count < module.count then
                    -- TODO: need to check if modules in existing entity is better or same
                    replace = true
                    break
                end
            end
        end
        if replace then
            replaceEntity(entity, upgrade.target or entity.name, findBestModules(network, upgrade.modules))
        end
    end
end

script.on_event(defines.events.on_built_entity, onBuiltEntity)
script.on_event(defines.events.on_robot_built_entity, onBuiltEntity)

script.on_event(defines.events.on_tick, function(event)
    if game.tick % 600 > 0 then
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
