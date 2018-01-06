function forceConfig(forcename)
    return global.brave_new_world.forces[forcename]
end

script.on_event(defines.events.on_player_created, function(event)
    if not global.brave_new_world then
        global.brave_new_world = {
            players = {},
            forces = {}
        }
    end
    local player = game.players[event.player_index]
    local force = player.force
    if not global.brave_new_world.forces[force.name] then
        global.brave_new_world.forces[force.name] = {
            event = {}
        }
    end
    local character = player.character
    player.character = nil
    if character then
        character.destroy()
    end
    local force = player.force
    -- prevent mining and crafting
    force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
    force.manual_crafting_speed_modifier = -1

    local config = forceConfig(force.name)

    -- player/force start location
    local x = 0
    local y = 0

    -- oil is rare, but mandatory to continue research. add some oil patches near spawn point
    local xx = math.random(32, 64) * (math.random(1, 2) == 1 and 1 or -1)
    local yy = math.random(32, 64) * (math.random(1, 2) == 1 and 1 or -1)
    local surface = player.surface
    local tiles = {}
    surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xx, yy}}
    for xxx = xx - 2, xx + 2 do
        for yyy = yy - 2, yy + 2 do
            table.insert(tiles, {name = "dirt-3", position = {xxx, yyy}})
        end
    end
    xxx = xx + math.random(-8, 8)
    yyy = yy - math.random(4, 8)
    for xxxx = xxx - 2, xxx + 2 do
        for yyyy = yyy - 2, yyy + 2 do
            table.insert(tiles, {name = "dirt-3", position = {xxxx, yyyy}})
        end
    end
    surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xxx, yyy}}
    xxx = xx + math.random(-8, 8)
    yyy = yy + math.random(4, 8)
    for xxxx = xxx - 2, xxx + 2 do
        for yyyy = yyy - 2, yyy + 2 do
            table.insert(tiles, {name = "dirt-3", position = {xxxx, yyyy}})
        end
    end
    surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xxx, yyy}}
    surface.set_tiles(tiles)

    -- setup exploration boundary
    config.explore_boundary = {{x - 96, y - 96}, {x + 96, y + 96}}
    force.chart(surface, {{x - 192, y - 192}, {x + 192, y + 192}})

    -- place dirt beneath structures
    tiles = {}
    for xx = x - 14, x + 13 do
        for yy = y - 9, y + 3 do
            table.insert(tiles, {name = "dirt-3", position = {xx, yy}})
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
    config.roboport = surface.create_entity{name = "roboport", position = {x, y - 4}, force = force}
    config.roboport.minable = false
    config.roboport.energy = 100000000
    local roboport_inventory = config.roboport.get_inventory(defines.inventory.roboport_robot)
    roboport_inventory.insert{name = "construction-robot", count = 100}
    roboport_inventory.insert{name = "logistic-robot", count = 50}
    roboport_inventory = config.roboport.get_inventory(defines.inventory.roboport_material)
    roboport_inventory.insert{name = "repair-pack", count = 10}
    -- radar
    config.radar = surface.create_entity{name = "radar", position = {x - 1, y - 1}, force = force}
    config.radar.minable = false
    -- electric pole
    local electric_pole = surface.create_entity{name = "medium-electric-pole", position = {x + 1, y - 2}, force = force}
    electric_pole.minable = false
    -- "spill" chest, items that would be spilled will be moved to this active provider chest
    config.spill_chest = surface.create_entity{name = "logistic-chest-active-provider", position = {x + 1, y - 1}, force = force}
    config.spill_chest.minable = false
    -- "storage" chest, contains the items the player starts with
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y}, force = force}
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
    chest_inventory.insert{name = "boiler", count = 3}
    chest_inventory.insert{name = "steam-engine", count = 5}
    chest_inventory.insert{name = "assembling-machine-3", count = 6}
    chest_inventory.insert{name = "electric-mining-drill", count = 6}
    chest_inventory.insert{name = "stone-furnace", count = 20}
    chest_inventory.insert{name = "roboport", count = 4}
    chest_inventory.insert{name = "logistic-chest-storage", count = 4}
    chest_inventory.insert{name = "logistic-chest-passive-provider", count = 8}
    chest_inventory.insert{name = "logistic-chest-requester", count = 8}
    chest_inventory.insert{name = "lab", count = 2}
    -- solar panels and accumulators (left side)
    surface.create_entity{name = "solar-panel", position = {x - 11, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 11, y - 3}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 11, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 8, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 5, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 5, y}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x - 7, y - 4}, force = force}
    local accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y - 6}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y - 4}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y - 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 6, y - 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 4, y - 2}, force = force}
    accumulator.energy = 5000000
    -- solar panels and accumulators (right side)
    surface.create_entity{name = "solar-panel", position = {x + 4, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 4, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 7, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y - 3}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x + 6, y - 4}, force = force}
    accumulator = surface.create_entity{name = "accumulator", position = {x + 4, y - 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 6, y - 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y - 6}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y - 4}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y - 2}, force = force}
    accumulator.energy = 5000000
end)

script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity
    if entity.name == "entity-ghost" then
        -- do nothing when placing ghosts
        return
    elseif entity.type == "locomotive" or entity.type == "cargo-wagon" or entity.type == "fluid-wagon" or entity.type == "artillery-wagon" then
        -- can neither ghost locomotives nor wagons
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
    if cursor and cursor.valid_for_read and cursor.name == entity.name then
        -- happens when we build eg. a transport belt on top of a transport belt
        -- only rotates belt, cursor already contains right item and we don't want to build a ghost
        return
    end
    -- put item back on cursor
    for _, item in pairs(entity.prototype.items_to_place_this) do
        cursor.set_stack{name = item.name, count = 1}
        break
    end

    -- disable built entity
    entity.active = false
    entity.minable = false
    entity.operable = false
    if entity.type == "electric-pole" then
        entity.disconnect_neighbour() -- disconnect power poles as they work even when disabled
    end

    local config = forceConfig(player.force.name)
    if entity.get_item_count() > 0 then
        -- new entity contains items, so later it'll be deconstructed instead of destroyed. we'll have to remove an item creating this entity to prevent duplication of items
        local network = config.roboport.logistic_network
        local items = entity.prototype.items_to_place_this
        local item_removed = false
        if network then
            for name, _ in pairs(items) do
                if network.remove_item{name = name, count = 1} >= 1 then
                    item_removed = true
                    break
                end
            end
        end
        if not item_removed then
            -- try to remove from player inventory
            for name, _ in pairs(items) do
                if player.remove_item{name = name, count = 1} >= 1 then
                    item_removed = true
                    break
                end
            end
        end
        if not item_removed then
            -- either player is being a smart-ass or something weird is going on. move items to spill_chest and clear entity inventory. entity will be destroyed instead of deconstructed later
            for _, slot in pairs(defines.inventory) do
                local inventory = entity.get_inventory(slot)
                if inventory then
                    for name, count in pairs(inventory.get_contents()) do
                        spillItems(force, name, count)
                    end
                    inventory.clear()
                end
            end
        end
    end

    -- add entity to list of entities we will later place as ghosts
    local ghost_tick = game.tick + 60
    while config.event[ghost_tick] do
        -- already an event on this tick. max one event per tick
        ghost_tick = ghost_tick + 1
    end
    config.event[ghost_tick] = {
        create_ghost = entity
    }
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    -- this happens when a player replaced one building with another
    local player = game.players[event.player_index]
    local config = forceConfig(player.force.name)
    -- move buffer items to spill chest
    for name, count in pairs(event.buffer.get_contents()) do
        spillItems(player.force, name, count)
    end
    event.buffer.clear()
end)

function inventoryChanged(event)
    local player = game.players[event.player_index]
    -- player is only allowed to carry 1 of each item that can be placed as entity
    -- everything else goes into entity opened or entity beneath mouse cursor
    local entity = player.selected or player.opened
    local inventory = player.get_inventory(defines.inventory.god_main).get_contents()
    for name, count in pairs(player.get_inventory(defines.inventory.god_quickbar).get_contents()) do
        inventory[name] = inventory[name] and (inventory[name] + count) or count
    end
    for name, count in pairs(inventory) do
        local to_remove = count - itemCountAllowed(name, count)
        if to_remove > 0 then
            local inserted = entity and entity.insert{name = name, count = to_remove} or 0
            local remaining = to_remove - inserted
            if remaining > 0 then
                spillItems(player.force, name, remaining)
            end
            player.remove_item{name = name, count = to_remove}
        end
    end
end

function itemCountAllowed(name, count)
    if name == "red-wire" or name == "green-wire" then
        -- need these for circuitry, one stack is enough
        return math.min(200, count)
    elseif name == "copper-cable" then
        -- need this for manually connecting poles, but don't want player to manually move stuff around so we'll limit it
        return math.min(20, count)
    elseif name == "blueprint" or name == "deconstruction-planner" or name == "blueprint-book" then
        -- these only place ghosts
        return count
    elseif name == "locomotive" or name == "cargo-wagon" or name == "fluid-wagon" or name == "artillery-wagon" then
        -- locomotives and wagons must be placed manually
        return count
    elseif name == "construction-robot" or name == "logistic-robot" then
        -- disallow carrying robots
        return 0
    elseif name == "stone-brick" or name == "concrete" or name == "hazard-concrete" or name == "landfill" then
        -- can be used for paving. primarily esthetic feature, we'll allow this
        return count
    elseif name == "cliff-explosives" then
        -- allow cliff explosives, let the user remove cliffs
        return count
    elseif name == "droid-selection-tool" then
        -- let users have the command tool for Robot Army mod (but not the pickup tool)
        return 1
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
            local remaining = to_remove - inserted
            if remaining > 0 then
                spillItems(player.force, cursor.name, to_remove)
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
    -- check if roboport, radar or spill chest was destroyed
    local config = forceConfig(entity.force.name)
    local lose = false
    if entity.type == "roboport" then
        if not config.roboport.valid or (entity.position.x == config.roboport.position.x and entity.position.y == config.roboport.position.y) then
            lose = true
        end
    elseif entity.type == "radar" then
        if not config.radar.valid or (entity.position.x == config.radar.position.x and entity.position.y == config.radar.position.y) then
            lose = true
        end
    elseif entity.type == "logistic-container" then
        if not config.spill_chest.valid or (entity.position.x == config.spill_chest.position.x and entity.position.y == config.spill_chest.position.y) then
            lose = true
        end
    end
    if lose then
        game.set_game_state{game_finished = true, player_won = false, can_continue = false}
    end
end)

script.on_event(defines.events.on_sector_scanned, function(event)
    local position = event.chunk_position
    local radar = event.radar
    local config = forceConfig(radar.force.name)
    local x = ((position.x <= 0 and (position.x + 5)) or (position.x > 0 and (position.x - 5))) * 32
    local y = ((position.y <= 0 and (position.y + 5)) or (position.y > 0 and (position.y - 5))) * 32
    if x < config.explore_boundary[1][1] then
        config.explore_boundary[1][1] = x
    elseif x > config.explore_boundary[2][1] then
        config.explore_boundary[2][1] = x
    end
    if y < config.explore_boundary[1][2] then
        config.explore_boundary[1][2] = y
    elseif y > config.explore_boundary[2][2] then
        config.explore_boundary[2][2] = y
    end
end)

function spillItems(force, name, count)
    local config = forceConfig(force.name)
    local chest = config.spill_chest
    local inserted = chest.insert{name = name, count = count}
    local remaining = count - inserted
    if remaining > 0 then
        -- chest is full, explode items around chest
        chest.surface.spill_item_stack(chest.position, {name = name, count = remaining})
        local spilled = surface.find_entities_filtered{area = {{pos.x - 16, pos.y - 16}, {pos.x + 16, pos.y + 16}}, force = "neutral", type = "item-entity"}
        for _, item in pairs(spilled) do
            item.order_deconstruction(force)
        end
    end
end

script.on_event(defines.events.on_tick, function(event)
    for _, player in pairs(game.players) do
        local config = forceConfig(player.force.name)
        -- prevent player from exploring
        local teleport = player.vehicle and player.vehicle.position or player.position
        if teleport.x < config.explore_boundary[1][1] then
            teleport.x = config.explore_boundary[1][1]
        elseif teleport.x > config.explore_boundary[2][1] then
            teleport.x = config.explore_boundary[2][1]
        end
        if teleport.y < config.explore_boundary[1][2] then
            teleport.y = config.explore_boundary[1][2]
        elseif teleport.y > config.explore_boundary[2][2] then
            teleport.y = config.explore_boundary[2][2]
        end
        if player.vehicle then
            player.vehicle.teleport(teleport)
        else
            player.teleport(teleport)
        end

        -- remove player placed entities (this is a "hack" to make placing eg. power poles less aggravating, can't hold down button and move for placing ghosts)
        local force_event = config.event[game.tick]
        if force_event then
            local entity = force_event.create_ghost
            if entity and entity.valid then
                local surface = entity.surface
                local force = entity.force
                local position = entity.position
                local ghost_placed = false

                local prev_cursor
                if player.cursor_stack and player.cursor_stack.valid_for_read then
                    prev_cursor = {name = player.cursor_stack.name, count = player.cursor_stack.count}
                end
                -- create blueprint of entity
                player.cursor_stack.set_stack{name = "blueprint", count = 1}
                player.cursor_stack.create_blueprint{surface = surface, force = force, area = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}}
                -- place blueprint
                if player.cursor_stack.get_blueprint_entities() then
                    -- backup entity data and contents
                    local backup_entity = {name = entity.name, position = entity.position, direction = entity.direction, force = entity.force}
                    if entity.get_item_count() > 0 then
                        -- order entity deconstruction
                        entity.active = true
                        entity.minable = true
                        entity.operable = true
                        entity.order_deconstruction(force)
                        -- this makes it deconstruct the new entity, giving us one more of it! we want to destroy it, but also make the robots move the items!
                    else
                        -- remove entity
                        entity.destroy()
                    end
                    player.cursor_stack.build_blueprint{surface = surface, force = force, position = position, force_build = true}
                    local ghost_entity = surface.find_entity("entity-ghost", position)
                    if not ghost_entity then
                        if backup_entity.name ~= "land-mine" then
                            -- placing ghost failed, we'll have to build the entity immediately. except land mines, they cause robots to get stuck
                            entity = surface.create_entity(backup_entity)
                        end
                    else
                        ghost_placed = true
                    end
                end
                -- reset player cursor
                if prev_cursor then
                    player.cursor_stack.set_stack(prev_cursor)
                else
                    player.cursor_stack.clear()
                end

                if not ghost_placed and entity and entity.valid then
                    -- didn't place a ghost/remove built entity, enable entity for player to use
                    entity.active = true
                    entity.minable = true
                    entity.operable = true
                    -- and we must find an item producing the built entity in a chest/inventory and remove it (or player gets stuff for free, which is bad)
                    local network = config.roboport.logistic_network
                    local items = entity.prototype.items_to_place_this
                    local item_removed = false
                    if network then
                        for name, _ in pairs(items) do
                            if network.remove_item{name = name, count = 1} >= 1 then
                                item_removed = true
                                break
                            end
                        end
                    end
                    if not item_removed then
                        -- try to remove from player inventory
                        for name, _ in pairs(items) do
                            if player.remove_item{name = name, count = 1} >= 1 then
                                item_removed = true
                                break
                            end
                        end
                    end
                    if not item_removed then
                        -- either player is being a smart-ass or something weird is going on. move items to spill_chest
                        for _, slot in pairs(defines.inventory) do
                            local inventory = entity.get_inventory(slot)
                            if inventory then
                                for name, count in pairs(inventory.get_contents()) do
                                    spillItems(force, name, count)
                                end
                            end
                        end
                        entity.destroy()
                    end
                end
            end
        end
        config.event[game.tick] = nil
    end
end)
