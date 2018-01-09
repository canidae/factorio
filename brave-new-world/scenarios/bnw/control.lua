local water_replace_tile = "dirt-3"

function inventoryChanged(event)
    local player = game.players[event.player_index]
    -- remove any crafted items (and possibly make blueprint of item on cursor)
    for _, stack in pairs(global.players[event.player_index].crafted) do
        if itemCountAllowed(stack.name, stack.count) == 0 then
            -- not allowed to carry item, but can we make a blueprint of it?
            if player.clean_cursor() then
                player.cursor_stack.set_stack(stack)
                if not replaceWithBlueprint(player.cursor_stack) then
                    player.cursor_stack.clear()
                end
            end
        end
        player.remove_item{name = stack.name, count = stack.count}
    end
    global.players[event.player_index].crafted = {}

    -- player is only allowed to carry blueprints and some whitelisted items
    -- everything else goes into entity opened or entity beneath mouse cursor
    local inventory_main = player.get_inventory(defines.inventory.god_main)
    local inventory_bar = player.get_inventory(defines.inventory.god_quickbar)
    local scanInventory = function(inventory, blueprints, items)
        for i = 1, #inventory do
            local item_stack = inventory[i]
            if item_stack and item_stack.valid_for_read then
                if item_stack.is_blueprint and item_stack.label then
                    if blueprints[item_stack.label] then
                        -- duplicate blueprint, remove it
                        item_stack.clear()
                    else
                        blueprints[item_stack.label] = true
                    end
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
            local entity = player.selected or player.opened
            local inserted = entity and entity.insert{name = name, count = to_remove} or 0
            local remaining = to_remove - inserted
            if allowed == 0 and not blueprints[name] then
                if not replaceWithBlueprint(item.slot) then
                    item.slot.clear()
                end
            end
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
    elseif name == "car" or name == "tank" then
        -- let users put down cars & tanks
        return count
    elseif name == "landfill" or name == "cliff-explosives" then
        -- let users fill in water and remove cliffs
        return count
    elseif name == "droid-selection-tool" then
        -- let users have the command tool for Robot Army mod (but not the pickup tool)
        return 1
    -- TODO: klonan upgrade tool
    elseif string.match(name, ".*module.*") then
        -- allow modules
        return count
    end
    return 0
end

function replaceWithBlueprint(item_stack, direction)
    local prototype = item_stack.prototype
    local place_entity = prototype.place_result
    local place_tile = prototype.place_as_tile_result
    local setBlueprintEntities = function()
        item_stack.set_stack{name = "blueprint", count = 1}
        if place_entity then
            local x = (math.ceil(place_entity.selection_box.right_bottom.x * 2) % 2) / 2 - 0.5
            local y = (math.ceil(place_entity.selection_box.right_bottom.y * 2) % 2) / 2 - 0.5
            item_stack.set_blueprint_entities({
                {
                    entity_number = 1,
                    name = place_entity.name,
                    direction = direction,
                    position = {x = x, y = y}
                }
            })
        end
        if place_tile then
            item_stack.set_blueprint_tiles({
                {
                    name = place_tile.result.name,
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
    -- pcall was the easiest way to check if a valid blueprint was made
    -- (some items produce entities that aren't blueprintable, but there doesn't seem to be a reliable way to detect this)
    if not status then
        game.print("Blueprint failed: " .. prototype.name .. " - " .. err)
    end
    return status
end

function spillItems(force, name, count)
    local config = global.forces[force.name]
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

function setupForce(force, surface, x, y)
    if not global.forces then
        global.forces = {}
    end
    global.forces[force.name] = {}
    local config = global.forces[force.name]
    -- prevent mining and crafting
    force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
    force.manual_crafting_speed_modifier = -1

    -- setup exploration boundary
    config.explore_boundary = {{x - 96, y - 96}, {x + 96, y + 96}}
    force.chart(surface, {{x - 192, y - 192}, {x + 192, y + 192}})

    -- setup starting location
    -- oil is rare, but mandatory to continue research. add some oil patches near spawn point
    local xx = math.random(32, 64) * (math.random(1, 2) == 1 and 1 or -1)
    local yy = math.random(32, 64) * (math.random(1, 2) == 1 and 1 or -1)
    local tiles = {}
    surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xx, yy}}
    for xxx = xx - 2, xx + 2 do
        for yyy = yy - 2, yy + 2 do
            local tile = surface.get_tile(xxx, yyy)
            local name = tile.name
            if tile.prototype.layer <= 4 then
                name = water_replace_tile
            end
            tiles[#tiles + 1] = {name = name, position = {xxx, yyy}}
        end
    end
    xxx = xx + math.random(-8, 8)
    yyy = yy - math.random(4, 8)
    for xxxx = xxx - 2, xxx + 2 do
        for yyyy = yyy - 2, yyy + 2 do
            local tile = surface.get_tile(xxxx, yyyy)
            local name = tile.name
            if tile.prototype.layer <= 4 then
                name = water_replace_tile
            end
            tiles[#tiles + 1] = {name = name, position = {xxxx, yyyy}}
        end
    end
    surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xxx, yyy}}
    xxx = xx + math.random(-8, 8)
    yyy = yy + math.random(4, 8)
    for xxxx = xxx - 2, xxx + 2 do
        for yyyy = yyy - 2, yyy + 2 do
            local tile = surface.get_tile(xxxx, yyyy)
            local name = tile.name
            if tile.prototype.layer <= 4 then
                name = water_replace_tile
            end
            tiles[#tiles + 1] = {name = name, position = {xxxx, yyyy}}
        end
    end
    surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {xxx, yyy}}
    surface.set_tiles(tiles)

    -- remove trees/stones/resources
    local entities = surface.find_entities_filtered{area = {{x - 16, y - 11}, {x + 15, y + 5}}, force = "neutral"}
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- place dirt beneath structures
    tiles = {}
    for xx = x - 14, x + 13 do
        for yy = y - 9, y + 3 do
            local tile = surface.get_tile(xx, yy)
            local name = tile.name
            if tile.prototype.layer <= 4 then
                name = water_replace_tile
            end
            tiles[#tiles + 1] = {name = name, position = {xx, yy}}
        end
    end
    surface.set_tiles(tiles)

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
    local electric_pole = surface.create_entity{name = "medium-electric-pole", position = {x + 1, y - 2}, force = force}
    -- radar
    surface.create_entity{name = "radar", position = {x - 1, y - 1}, force = force}
    -- spill chest, items otherwise lost end up here
    config.spill_chest = surface.create_entity{name = "logistic-chest-active-provider", position = {x + 1, y - 1}, force = force}
    config.spill_chest.minable = false
    -- storage chest, contains the items the force starts with
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y}, force = force}
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
end

script.on_event(defines.events.on_player_created, function(event)
    if not global.players then
        global.players = {}
    end
    global.players[event.player_index] = {
        crafted = {}
    }
    local player = game.players[event.player_index]
    if player.character then
        player.character.destroy()
        player.character = nil
    end
    -- disable light
    player.disable_flashlight()
    -- enable cheat mode
    player.cheat_mode = true

    -- setup force
    setupForce(player.force, player.surface, 0, 0)
end)

script.on_event(defines.events.on_player_crafted_item, function(event)
    local crafted = global.players[event.player_index].crafted
    crafted[#crafted + 1] = event.item_stack
end)

script.on_event(defines.events.on_player_pipette, function(event)
    local player = game.players[event.player_index]
    if not replaceWithBlueprint(player.cursor_stack, (player.selected and player.selected.direction) or nil) then
        player.cursor_stack.clear()
    end
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
                if not replaceWithBlueprint(cursor) then
                    cursor.clear()
                end
            end
        end
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    -- check if roboport was destroyed
    local config = global.forces[entity.force.name]
    if config and (entity == config.robport or entity == config.spill_chest) then
        game.set_game_state{game_finished = true, player_won = false, can_continue = false}
    end
end)

script.on_event(defines.events.on_sector_scanned, function(event)
    local position = event.chunk_position
    local radar = event.radar
    local config = global.forces[radar.force.name]
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
