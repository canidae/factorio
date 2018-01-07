function forceConfig(forcename)
    return global.brave_new_world.forces[forcename]
end

function inventoryChanged(event)
    local player = game.players[event.player_index]
    -- player is only allowed to carry blueprints and some whitelisted items
    -- everything else goes into entity opened or entity beneath mouse cursor
    local entity = player.selected or player.opened
    local inventory_main = player.get_inventory(defines.inventory.god_main)
    local inventory_bar = player.get_inventory(defines.inventory.god_quickbar)
    local scanInventory = function(inventory, blueprints, items)
        for i = 1, #inventory do
            local item_stack = inventory[i]
            if item_stack and item_stack.valid_for_read then
                if item_stack.is_blueprint then
                    blueprints[item_stack.label] = true
                else
                    local name = item_stack.name
                    if items[name] then
                        items[name].count = items[name].count + item_stack.count
                    else
                        items[name] = {
                            count = item_stack.count,
                            slot = item_stack
                        }
                    end
                end
            end
        end
    end
    local blueprints = {}
    local items = {}
    scanInventory(inventory_bar, blueprints, items)
    scanInventory(inventory_main, blueprints, items)

    for name, item in pairs(items) do
        local allowed = itemCountAllowed(name, item.count)
        local to_remove = item.count - allowed
        if to_remove > 0 then
            local inserted = entity and entity.insert{name = name, count = to_remove} or 0
            local remaining = to_remove - inserted
            if allowed == 0 and not blueprints[name] then
                replaceWithBlueprint(item.slot)
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
    elseif name == "car" or name == "tank" then
        -- let users put down cars & tanks
        return count
    elseif name == "landfill" or name == "cliff-explosives" then
        -- let users fill in water and remove cliffs
        return count
    elseif name == "droid-selection-tool" then
        -- let users have the command tool for Robot Army mod (but not the pickup tool)
        return 1
    elseif string.match(name, ".*module.*") then
        -- allow modules
        return count
    end
    return 0
end

function replaceWithBlueprint(item_stack)
    local prototype = item_stack.prototype
    local place_entity = prototype.place_result
    local place_tile = prototype.place_as_tile_result
    local setBlueprintEntities = function()
        item_stack.set_stack{name = "blueprint", count = 1}
        if place_entity then
            item_stack.set_blueprint_entities({
                {
                    entity_number = 1,
                    name = place_entity.name,
                    position = {x = 0, y = 0}
                }
            })
        end
        if place_tile then
            item_stack.set_blueprint_tiles({
                {
                    name = place_tile.name,
                    position = {x = 0, y = 0}
                }
            })
        end
        item_stack.blueprint_icons = {
            {
                signal = {type = "item", name = prototype.name},
                index = 1
            }
        }
        item_stack.label = prototype.name
    end
    local status, err = pcall(setBlueprintEntities)
    if not status then
        -- this was the easiest way to check if a valid blueprint was made
        -- (some items produce entities that aren't blueprintable, but there doesn't seem to be a reliable way to detect this)
        --game.print("Blueprint failed: " .. prototype.name .. " - " .. err)
        item_stack.clear()
    end
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
    -- set disable light
    player.disable_flashlight()

    local force = player.force
    -- prevent mining and crafting
    force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
    force.manual_crafting_speed_modifier = -1

    local config = forceConfig(force.name)

    -- force start location
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
    -- electric pole
    local electric_pole = surface.create_entity{name = "medium-electric-pole", position = {x + 1, y}, force = force}
    -- radar
    surface.create_entity{name = "radar", position = {x - 1, y - 1}, force = force}
    -- let's build a small lamp to brighten up the night
    surface.create_entity{name = "inserter", position = {x + 1, y - 2}, direction = defines.direction.south, force = force}
    -- storage chest, contains the items the force starts with
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y - 1}, force = force}
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    chest_inventory.insert{name = "transport-belt", count = 400}
    chest_inventory.insert{name = "underground-belt", count = 40}
    chest_inventory.insert{name = "splitter", count = 20}
    chest_inventory.insert{name = "pipe", count = 40}
    chest_inventory.insert{name = "pipe-to-ground", count = 10}
    chest_inventory.insert{name = "burner-inserter", count = 12}
    chest_inventory.insert{name = "inserter", count = 48}
    chest_inventory.insert{name = "medium-electric-pole", count = 80}
    chest_inventory.insert{name = "small-lamp", count = 40}
    chest_inventory.insert{name = "stone-furnace", count = 20}
    chest_inventory.insert{name = "offshore-pump", count = 2}
    chest_inventory.insert{name = "boiler", count = 2}
    chest_inventory.insert{name = "steam-engine", count = 4}
    chest_inventory.insert{name = "assembling-machine-3", count = 6}
    chest_inventory.insert{name = "electric-mining-drill", count = 6}
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
    surface.create_entity{name = "small-lamp", position = {x - 6, y - 4}, force = force}
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
    surface.create_entity{name = "small-lamp", position = {x + 5, y - 4}, force = force}
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
            if count_remaining > 0 then
                cursor.count = count_remaining
            else
                replaceWithBlueprint(cursor)
            end
        end
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    -- check if roboport was destroyed
    local config = forceConfig(entity.force.name)
    if not config.roboport.valid or (entity.position.x == config.roboport.position.x and entity.position.y == config.roboport.position.y) then
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
