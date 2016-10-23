function playerConfig(playername)
    return global.brave_new_world.players[playername]
end

function forceConfig(forcename)
    return global.brave_new_world.forces[forcename]
end

script.on_event(defines.events.on_player_created, function(event)
    -- TODO: setup player & force config properly
    if not global.brave_new_world then
        global.brave_new_world = {
            players = {},
            forces = {}
        }
    end
    local player = game.players[event.player_index]
    if not global.brave_new_world.players[player.name] then
        global.brave_new_world.players[player.name] = {
            ghost_entities = {}
        }
    end
    local force = player.force
    if not global.brave_new_world.forces[force.name] then
        global.brave_new_world.forces[force.name] = {}
    end
    local character = player.character
    player.character = nil
    if character then
        character.destroy()
    end
    player.force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
    player.force.manual_crafting_speed_modifier = -1
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}

    -- player/force start location
    local x = 0
    local y = 0

    -- oil is rare, but mandatory to continue research. add some oil patches near spawn point
    local xx = math.random(32, 64) * (math.random(1, 2) == 1 and 1 or -1)
    local yy = math.random(32, 64) * (math.random(1, 2) == 1 and 1 or -1)
    local surface = player.surface
    local tiles = {}
    surface.create_entity{name = "crude-oil", amount = math.random(8000, 16000), position = {xx, yy}}
    for xxx = xx - 2, xx + 2 do
        for yyy = yy - 2, yy + 2 do
            table.insert(tiles, {name = "grass-dry", position = {xxx, yyy}})
        end
    end
    xxx = xx + math.random(-8, 8)
    yyy = yy - math.random(4, 8)
    for xxxx = xxx - 2, xxx + 2 do
        for yyyy = yyy - 2, yyy + 2 do
            table.insert(tiles, {name = "grass-dry", position = {xxxx, yyyy}})
        end
    end
    surface.create_entity{name = "crude-oil", amount = math.random(10000, 25000), position = {xxx, yyy}}
    xxx = xx + math.random(-8, 8)
    yyy = yy + math.random(4, 8)
    for xxxx = xxx - 2, xxx + 2 do
        for yyyy = yyy - 2, yyy + 2 do
            table.insert(tiles, {name = "grass-dry", position = {xxxx, yyyy}})
        end
    end
    surface.create_entity{name = "crude-oil", amount = math.random(10000, 25000), position = {xxx, yyy}}
    surface.set_tiles(tiles)

    -- setup exploration boundary
    forceConfig(force.name).explore_boundary = {{x - 96, y - 96}, {x + 96, y + 96}}
    force.chart(surface, {{x - 192, y - 192}, {x + 192, y + 192}})

    -- place dirt beneath structures
    tiles = {}
    for xx = x - 14, x + 13 do
        for yy = y - 9, y + 3 do
            table.insert(tiles, {name = "grass-dry", position = {xx, yy}})
        end
    end
    surface.set_tiles(tiles)
    -- remove trees/stones/resources
    local entities = surface.find_entities_filtered{area = {{x - 16, y - 11}, {x + 15, y + 5}}, force = "neutral"}
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- place walls
    for xx = x - 3, x + 2 do
        surface.create_entity{name = "stone-wall", position = {xx, y - 7}, force = force}
        surface.create_entity{name = "stone-wall", position = {xx, y + 1}, force = force}
    end
    for yy = y - 7, y + 1 do
        surface.create_entity{name = "stone-wall", position = {x - 3, yy}, force = force}
        surface.create_entity{name = "stone-wall", position = {x + 2, yy}, force = force}
    end
    -- roboport
    local roboport = surface.create_entity{name = "roboport", position = {x, y - 4}, force = force}
    roboport.minable = false
    local roboport_inventory = roboport.get_inventory(defines.inventory.roboport_robot)
    roboport_inventory.insert{name = "construction-robot", count = 100}
    roboport_inventory.insert{name = "logistic-robot", count = 50}
    roboport_inventory = roboport.get_inventory(defines.inventory.roboport_material)
    roboport_inventory.insert{name = "repair-pack", count = 10}
    -- radar
    local radar = surface.create_entity{name = "radar", position = {x - 1, y - 1}, force = force}
    radar.minable = false
    -- electric pole
    local electric_pole = surface.create_entity{name = "medium-electric-pole", position = {x + 1, y - 2}, force = force}
    electric_pole.minable = false
    -- chests
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y - 1}, force = force}
    chest.minable = false
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    chest_inventory.insert{name = "transport-belt", count = 500}
    chest_inventory.insert{name = "underground-belt", count = 20}
    chest_inventory.insert{name = "splitter", count = 10}
    chest_inventory.insert{name = "medium-electric-pole", count = 100}
    chest_inventory.insert{name = "inserter", count = 50}
    chest_inventory.insert{name = "offshore-pump", count = 2}
    chest_inventory.insert{name = "pipe", count = 50}
    chest_inventory.insert{name = "pipe-to-ground", count = 10}
    chest_inventory.insert{name = "boiler", count = 7}
    chest_inventory.insert{name = "steam-engine", count = 5}
    chest_inventory.insert{name = "assembling-machine-3", count = 6}
    chest_inventory.insert{name = "electric-mining-drill", count = 6}
    chest_inventory.insert{name = "stone-furnace", count = 20}
    chest_inventory.insert{name = "roboport", count = 4}
    chest_inventory.insert{name = "logistic-chest-storage", count = 4}
    chest_inventory.insert{name = "logistic-chest-passive-provider", count = 8}
    chest_inventory.insert{name = "logistic-chest-requester", count = 8}
    chest_inventory.insert{name = "lab", count = 2}
    chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y}, force = force}
    chest.minable = false
    -- solar panels and accumulators (left side)
    surface.create_entity{name = "solar-panel", position = {x - 11, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 11, y - 3}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 11, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 8, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 5, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 5, y}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x - 7, y - 4}, force = force}
    surface.create_entity{name = "accumulator", position = {x - 8, y - 6}, force = force}
    surface.create_entity{name = "accumulator", position = {x - 8, y - 4}, force = force}
    surface.create_entity{name = "accumulator", position = {x - 8, y - 2}, force = force}
    surface.create_entity{name = "accumulator", position = {x - 6, y - 2}, force = force}
    surface.create_entity{name = "accumulator", position = {x - 4, y - 2}, force = force}
    -- solar panels and accumulators (right side)
    surface.create_entity{name = "solar-panel", position = {x + 4, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 4, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 7, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y - 3}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x + 6, y - 4}, force = force}
    surface.create_entity{name = "accumulator", position = {x + 4, y - 2}, force = force}
    surface.create_entity{name = "accumulator", position = {x + 6, y - 2}, force = force}
    surface.create_entity{name = "accumulator", position = {x + 8, y - 6}, force = force}
    surface.create_entity{name = "accumulator", position = {x + 8, y - 4}, force = force}
    surface.create_entity{name = "accumulator", position = {x + 8, y - 2}, force = force}
end)

script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity
    if entity.name == "entity-ghost" then
        -- do nothing when placing ghosts
        return
    elseif entity.name == "straight-rail" or entity.name == "curved-rail" then
        -- rail laying is a bit annoying. ghosting won't work, so just allow it
        return
    elseif entity.type == "locomotive" or entity.type == "cargo-wagon" or entity.type == "car" then
        -- can't ghost locomotives/wagons/cars either
        return
    elseif entity.name == "logistic-chest-storage" then
        local network = entity.logistic_network
        if network and network.all_construction_robots > 0 and network.available_construction_robots == 0 then
            -- if there are no available construction robots and player place a logistic storage chest,
            -- then that player is probably in trouble. we'll allow placing the storage chest without using robots
            return
        end
    end
    local player = game.players[event.player_index]
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read then
        -- happens when we build eg. a transport belt on top of a transport belt
        if cursor.name ~= entity.name then
            -- TODO: check if this ever happens
            game.print("Cursor unexpectedly valid for read: " .. cursor.name .. " - " .. entity.name)
        end
    else
        -- put item back on cursor
        cursor.set_stack{name = entity.name, count = 1}

        -- disable built entity
        entity.active = false
        entity.minable = false
        entity.operable = false
        if entity.type == "electric-pole" then
            entity.disconnect_neighbour() -- disconnect power poles as they work even when disabled
        end

        -- add entity to list to entities to create ghosts of
        local config = playerConfig(player.name)
        local remove_tick = game.tick + 60
        while config.ghost_entities[remove_tick] do
            -- somehow it's actually possible to get two entities on same tick, this loop will find an available slot if that happens
            remove_tick = remove_tick + 1
        end
        config.ghost_entities[remove_tick] = entity
    end
end)

function inventoryChanged(event)
    local player = game.players[event.player_index]
    -- player is only allowed to carry 1 of each item that can be placed as entity
    -- everything else goes into entity opened or entity beneath mouse cursor
    -- if no opened entity nor entity beneath mouse cursor, drop on ground
    local entity = player.selected or player.opened
    local inventory = player.get_inventory(defines.inventory.god_main).get_contents()
    for name, count in pairs(player.get_inventory(defines.inventory.god_quickbar).get_contents()) do
        inventory[name] = inventory[name] and (inventory[name] + count) or count
    end
    for name, count in pairs(inventory) do
        local to_remove = count - itemCountAllowed(name, count)
        if to_remove > 0 then
            local inserted = entity and entity.insert{name = name, count = to_remove} or 0
            if to_remove - inserted > 0 then
                local pos = entity and entity.position or player.position
                player.surface.spill_item_stack(pos, {name = name, count = to_remove - inserted})
                pickupSpilledItems(player.surface, pos, player.force)
            end
            player.remove_item{name = name, count = to_remove}
        end
    end
end

function itemCountAllowed(name, count)
    if name == "red-wire" or name == "green-wire" or name == "copper-cable" then
        -- need these for circuitry
        return count
    elseif name == "blueprint" or name == "deconstruction-planner" or name == "blueprint-book" then
        -- these only place ghosts
        return count
    elseif name == "diesel-locomotive" or name == "cargo-wagon" or name == "rail" then
        -- locomotives and wagons must be placed manually
        -- also allowing rails due to issue with placing rail ghosts beneath deconstructed rails
        return count
    elseif name == "stone-brick" or name == "concrete" or name == "hazard-concrete" or name == "landfill" then
        -- can be used for paving. primarily esthetic feature, we'll allow this
        return count
    elseif string.match(name, ".*module.*") then
        -- allow modules
        return count
    end
    local place_result = game.item_prototypes[name].place_result
    if place_result then
        if place_result.type == "unit" then
            -- don't allow units in inventory
            return 0
        end
        -- allow player to keep one of items that place entities
        return 1
    end
    return 0
end

script.on_event(defines.events.on_player_main_inventory_changed, inventoryChanged)
script.on_event(defines.events.on_player_quickbar_inventory_changed, inventoryChanged)
script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.players[event.player_index]
    local cursor = player.cursor_stack
    if cursor and cursor.valid_for_read then
        local count_remaining = itemCountAllowed(cursor.name, cursor.count)
        local to_remove = cursor.count - count_remaining
        if to_remove > 0 then
            local entity = player.opened or player.selected
            local inserted = entity and entity.insert{name = cursor.name, count = to_remove} or 0
            if to_remove - inserted > 0 then
                local pos = entity and entity.position or player.position
                player.surface.spill_item_stack(pos, {name = cursor.name, count = to_remove - inserted})
                pickupSpilledItems(player.surface, pos, player.force)
            end
            if count_remaining > 0 then
                cursor.count = count_remaining
            else
                cursor.clear()
            end
        end
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    if entity.force.name == "enemy" then
        -- spawn alien artifact
        entity.surface.spill_item_stack(entity.position, {name = "alien-artifact", count = 1})
    end
end)

script.on_event(defines.events.on_sector_scanned, function(event)
    local position = event.chunk_position
    local radar = event.radar
    local force_config = forceConfig(radar.force.name)
    local x = ((position.x <= 0 and (position.x + 5)) or (position.x > 0 and (position.x - 5))) * 32
    local y = ((position.y <= 0 and (position.y + 5)) or (position.y > 0 and (position.y - 5))) * 32
    if x < force_config.explore_boundary[1][1] then
        force_config.explore_boundary[1][1] = x
    elseif x > force_config.explore_boundary[2][1] then
        force_config.explore_boundary[2][1] = x
    end
    if y < force_config.explore_boundary[1][2] then
        force_config.explore_boundary[1][2] = y
    elseif y > force_config.explore_boundary[2][2] then
        force_config.explore_boundary[2][2] = y
    end
end)

function pickupSpilledItems(surface, pos, force)
    local spilled = surface.find_entities_filtered{area = {{pos.x - 10, pos.y - 10}, {pos.x + 10, pos.y + 10}}, force = "neutral", type = "item-entity"}
    for _, item in pairs(spilled) do
        item.order_deconstruction(force)
    end
end

script.on_event(defines.events.on_tick, function(event)
    for _, player in pairs(game.players) do
        local force_config = forceConfig(player.force.name)
        -- prevent player from exploring
        local teleport = player.vehicle and player.vehicle.position or player.position
        if teleport.x < force_config.explore_boundary[1][1] then
            teleport.x = force_config.explore_boundary[1][1]
        elseif teleport.x > force_config.explore_boundary[2][1] then
            teleport.x = force_config.explore_boundary[2][1]
        end
        if teleport.y < force_config.explore_boundary[1][2] then
            teleport.y = force_config.explore_boundary[1][2]
        elseif teleport.y > force_config.explore_boundary[2][2] then
            teleport.y = force_config.explore_boundary[2][2]
        end
        if player.vehicle then
            player.vehicle.teleport(teleport)
        else
            player.teleport(teleport)
        end

        -- remove player placed entities (this is a "hack" to make placing eg. power poles less aggravating, can't hold down button and move for placing ghosts)
        local player_config = playerConfig(player.name)
        local entity = player_config.ghost_entities[game.tick]
        if entity then
            if entity.valid then
                local prev_cursor
                if player.cursor_stack and player.cursor_stack.valid_for_read then
                    prev_cursor = {name = player.cursor_stack.name, count = player.cursor_stack.count}
                end
                local surface = entity.surface
                local force = entity.force
                local position = entity.position
                -- create blueprint of entity
                player.cursor_stack.set_stack{name = "blueprint", count = 1}
                player.cursor_stack.create_blueprint{surface = surface, force = force, area = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}}
                -- if any items made it into the new entity, spill it
                for _, slot in pairs({defines.inventory.item_main, defines.inventory.item_active}) do
                    local inventory = entity.get_inventory(slot)
                    if inventory then
                        for name, count in pairs(inventory.get_contents()) do
                            surface.spill_item_stack(position, {name = name, count = count})
                        end
                        pickupSpilledItems(surface, position, force)
                    end
                end
                -- place blueprint
                if player.cursor_stack.get_blueprint_entities() then
                    local backup_entity = {name = entity.name, position = entity.position, direction = entity.direction, force = entity.force}
                    -- remove entity
                    entity.destroy()
                    player.cursor_stack.build_blueprint{surface = surface, force = force, position = position, force_build = true}
                    local ghost_entity = surface.find_entity("entity-ghost", position)
                    if not ghost_entity then
                        if backup_entity.name ~= "land-mine" then
                            -- placing ghost failed, we'll have to build the entity immediately. except land mines, they cause robots to get stuck
                            surface.create_entity(backup_entity)
                        end
                    end
                else
                end
                -- reset player cursor
                if prev_cursor then
                    player.cursor_stack.set_stack(prev_cursor)
                else
                    player.cursor_stack.clear()
                end
            end
            player_config.ghost_entities[game.tick] = nil
        end
    end
end)
