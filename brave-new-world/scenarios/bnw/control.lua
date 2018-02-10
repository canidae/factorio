local water_replace_tile = "dirt-3"
local factory_replace_tile = "concrete"

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
    global.players[event.player_index].inventory_items = items

    for name, item in pairs(items) do
        local allowed = itemCountAllowed(name, item.count)
        local to_remove = item.count - allowed
        if to_remove > 0 then
            local entity = player.selected or player.opened
            local inserted = 0
            if entity and entity.insert then
                for _, inventory_id in pairs(defines.inventory) do
                    local inventory = entity.get_inventory(inventory_id)
                    if inventory then
                        local barpos = inventory.hasbar() and inventory.getbar() or nil
                        if inventory.hasbar() then
                            inventory.setbar() -- clear bar (the chest size limiter)
                        end
                        inserted = inserted + inventory.insert{name = name, count = to_remove - inserted}
                        if inventory.hasbar() then
                            inventory.setbar(barpos) -- reset bar
                        end
                        if to_remove - inserted <= 0 then
                            break
                        end
                    end
                end
            end
            if allowed == 0 and not blueprints[name] then
                if not replaceWithBlueprint(item.slot) then
                    item.slot.clear()
                end
            end
            local remaining = to_remove - inserted
            if remaining > 0 then
                local insert_into = (entity and entity.logistic_network and entity) or global.forces[player.force.name].roboport
                remaining = remaining - insert_into.logistic_network.insert({name = name, count = remaining}, "storage")
                if remaining > 0 then
                    -- network storage is full, explode items around entity
                    player.print({"out-of-storage"})
                    insert_into.surface.spill_item_stack(insert_into.position, {name = name, count = remaining})
                end
            end
            player.remove_item{name = name, count = to_remove}
        end
    end
end

function itemCountAllowed(name, count)
    local item = game.item_prototypes[name]
    local place_result = item.place_result
            or (item.place_as_tile_result and {type="tile"})
            or {}
    if name == "red-wire" or name == "green-wire" then
        -- need these for circuitry, one stack is enough
        return math.min(200, count)
    elseif name == "copper-cable" then
        -- need this for manually connecting poles, but don't want player to manually move stuff around so we'll limit it
        return math.min(20, count)
    elseif place_result.type and place_result.type == "electric-pole" then
        -- allow user to carry one of each power pole, makes it easier to place poles at max distance
        return 1
    elseif place_result.type and place_result.type == "roboport"
            or place_result.type == "construction-robot"
            or (place_result.type == "logistic-container" and place_result.logistic_mode == "storage") then
        -- allow user to carry one of each for mods that adds surfaces
        return 1
    elseif item.type and item.type == "blueprint"
            or item.type == "deconstruction-item"
            or item.type == "blueprint-book"
            or item.type == "selection-tool" then
        -- these only place ghosts or are utility items
        return count
    elseif place_result.type and place_result.type == "locomotive"
            or place_result.type == "cargo-wagon"
            or place_result.type == "fluid-wagon"
            or place_result.type == "artillery-wagon" then
        -- locomotives and wagons must be placed manually
        return count
    elseif name == "rail" then
        -- rail stuff can't be (correctly) built directly with blueprints, allow 10 rails for the short range rail planner
        return 10
    elseif name == "train-stop" or name == "rail-signal" or name == "rail-chain-signal" then
        -- rail stuff can't be (correctly) built directly with blueprints, allow one that we'll later replace with a ghost
        return 1
    elseif place_result.type and place_result.type == "car" then
        -- let users put down cars & tanks
        return count
    elseif place_result.type and place_result.type == "tile" then
        -- can be used for paving. primarily esthetic feature, we'll allow one to prioritize the use of ghost
        return 1
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
    return 0
end

function replaceWithBlueprint(item_stack, direction)
    local prototype = item_stack.prototype
    local place_entity = prototype.place_result
    local place_tile = prototype.place_as_tile_result
    local setBlueprintEntities = function()
        item_stack.set_stack{name = "blueprint", count = 1}
        if place_entity then
            local width = (math.ceil(place_entity.selection_box.right_bottom.x * 2) % 2) / 2 - 0.5
            local height = (math.ceil(place_entity.selection_box.right_bottom.y * 2) % 2) / 2 - 0.5
            if direction and direction % 4 == 2 then
                -- entity is rotated, swap width & height
                local tmp = width
                width = height
                height = tmp
            end
            item_stack.set_blueprint_entities({
                {
                    entity_number = 1,
                    name = place_entity.name,
                    direction = direction,
                    position = {x = width, y = height}
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
    -- pcall was the easiest way to check if a valid blueprint was made
    -- (some items produce entities that aren't blueprintable, but there doesn't seem to be a reliable way to detect this)
    return pcall(setBlueprintEntities)
end

function setupForce(force, surface, x, y)
    if not global.forces then
        global.forces = {}
    end
    global.forces[force.name] = {
        surfaces = {},
        rewires = {}
    }
    local config = global.forces[force.name]
    -- prevent mining and crafting
    force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
    force.manual_crafting_speed_modifier = -1

    -- setup exploration boundary
    config.explore_boundary = {{x - 96, y - 96}, {x + 96, y + 96}}
    force.chart(surface, {{x - 192, y - 192}, {x + 192, y + 192}})

    -- setup starting location
    -- remove trees/stones/resources
    local entities = surface.find_entities_filtered{area = {{x - 14, y - 8}, {x + 17, y + 3}}, force = "neutral"}
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- place dirt beneath structures
    tiles = {}
    for xx = x - 13, x + 15 do
        for yy = y - 7, y + 1 do
            local tile = surface.get_tile(xx, yy)
            local name = tile.name
            name = factory_replace_tile
            tiles[#tiles + 1] = {name = name, position = {xx, yy}}
        end
    end
    surface.set_tiles(tiles)

    -- place walls
    for xx = x - 3, x + 5 do
        surface.create_entity{name = "stone-wall", position = {xx, y - 7}, force = force}
        surface.create_entity{name = "stone-wall", position = {xx, y + 1}, force = force}
    end
    for yy = y - 7, y + 1 do
        surface.create_entity{name = "stone-wall", position = {x - 3, yy}, force = force}
        surface.create_entity{name = "stone-wall", position = {x + 5, yy}, force = force}
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
	 -- pumpjacks
	 surface.create_entity{name = "crude-oil", amount = math.random(100000, 250000), position = {x + 3, y -5}}
	 surface.create_entity{name = "pumpjack", position = {x + 3, y -5}, direction = 4, force = force}
	 surface.create_entity{name = "storage-tank", position = {x + 3, y - 2}, force = force}
	 surface.create_entity{name = "pipe-to-ground", position = {x + 4, y}, force = force}
    -- storage chest
	 surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y}, force = force}
	 surface.create_entity{name = "logistic-chest-storage", position = {x + 2, y}, force = force}
	 surface.create_entity{name = "logistic-chest-storage", position = {x + 3, y}, force = force}
    -- storage chest, contains the items the force starts with
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y - 1}, force = force}
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    chest_inventory.insert{name = "transport-belt", count = 400}
    chest_inventory.insert{name = "underground-belt", count = 16}
    chest_inventory.insert{name = "splitter", count = 8}
    chest_inventory.insert{name = "pipe", count = 20}
    chest_inventory.insert{name = "pipe-to-ground", count = 10}
    chest_inventory.insert{name = "burner-inserter", count = 4}
    chest_inventory.insert{name = "inserter", count = 16}
    chest_inventory.insert{name = "medium-electric-pole", count = 50}
    chest_inventory.insert{name = "small-lamp", count = 10}
    chest_inventory.insert{name = "stone-furnace", count = 4}
    chest_inventory.insert{name = "offshore-pump", count = 1}
    chest_inventory.insert{name = "boiler", count = 1}
    chest_inventory.insert{name = "steam-engine", count = 2}
    chest_inventory.insert{name = "assembling-machine-3", count = 4}
    chest_inventory.insert{name = "electric-mining-drill", count = 4}
    chest_inventory.insert{name = "roboport", count = 4}
    chest_inventory.insert{name = "logistic-chest-storage", count = 4}
    chest_inventory.insert{name = "logistic-chest-passive-provider", count = 4}
    chest_inventory.insert{name = "logistic-chest-requester", count = 4}
    chest_inventory.insert{name = "lab", count = 2}
    -- solar panels and accumulators (left side)
    surface.create_entity{name = "solar-panel", position = {x - 12, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 12, y - 3}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 12, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 9, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 6, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 6, y}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x - 8, y - 2}, force = force}
    surface.create_entity{name = "small-lamp", position = {x - 7, y - 2}, force = force}
    surface.create_entity{name = "accumulator", position = {x - 9, y + 1}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x - 9, y - 1}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x - 9, y - 3}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x - 7, y - 3}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x - 5, y - 3}, force = force}.energy = 5000000
    -- solar panels and accumulators (right side)
    surface.create_entity{name = "solar-panel", position = {x + 8, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 8, y}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 11, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 14, y - 6}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 14, y - 3}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 14, y}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x + 10, y - 2}, force = force}
    surface.create_entity{name = "small-lamp", position = {x + 9, y - 2}, force = force}
    surface.create_entity{name = "accumulator", position = {x + 8, y - 3}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x + 10, y - 3}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x + 12, y - 3}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x + 12, y - 1}, force = force}.energy = 5000000
    surface.create_entity{name = "accumulator", position = {x + 12, y + 1}, force = force}.energy = 5000000

    -- prevent adding new roboports and logistic-chest on force surface
    config.surfaces[surface.name] = config.surfaces[surface.name] or {}
    surface = config.surfaces[surface.name]
    surface["roboport"] = (surface["roboport"] or 0) + 1
    surface["logistic-chest-storage"] = (surface["logistic-chest-storage"] or 0) + 2

end

function convertToGhost(entity)
    if not entity or not entity.valid then
        return
    end
    -- permit to keep track of entity allowed on specific surfaces
    if entity.name == "roboport"
            or entity.name == "logistic-chest-storage" then
        local config = global.forces[entity.force.name]
        config.surfaces[entity.surface.name] = config.surfaces[entity.surface.name] or {}
        surface = config.surfaces[entity.surface.name]
        surface[entity.name] = (surface[entity.name] or 1) - 1
        game.print(entity.surface.name.." : -"..entity.name.." : "..tostring(surface[entity.name]))
        if surface[entity.name] == 0 then surface[entity.name] = nil end
    end
    -- replace last built entity with ghost
    local surface = entity.surface
    local pos = entity.position
    local force = entity.force
    global.tmpstack.set_stack{name = "blueprint", count = 1}
    local width = (math.ceil(entity.selection_box.right_bottom.x * 2) % 2) / 2 - 0.5
    local height = (math.ceil(entity.selection_box.right_bottom.y * 2) % 2) / 2 - 0.5
    if direction and direction % 4 == 2 then
        -- entity is rotated, swap width & height
        local tmp = width
        width = height
        height = tmp
    end
    global.tmpstack.set_blueprint_entities({
        {
            entity_number = 1,
            name = entity.name,
            direction = entity.direction,
            position = {x = width, y = height}
        }
    })
    -- place blueprint
    if global.tmpstack.get_blueprint_entities() then
        -- remove entity
        entity.destroy()
        global.tmpstack.build_blueprint{surface = surface, force = force, position = pos, force_build = true}
    end
end

script.on_event(defines.events.on_player_created, function(event)
    if not global.players then
        global.players = {}
    end
    global.players[event.player_index] = {
        crafted = {},
        inventory_items = {}
    }

    -- create a "staging" surface that helps with the magic
    if not game.surfaces.staging then
        game.create_surface("staging", {width = 1, height = 1, seed = 42})
        global.chest = game.surfaces.staging.create_entity{name = "wooden-chest", position = {0, 0}}
        global.tmpstack = global.chest.get_inventory(defines.inventory.chest)[1]
    end

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

script.on_event(defines.events.on_built_entity, function(event)
    local player = game.players[event.player_index]
    local entity = event.created_entity
    local last_entity = global.players[event.player_index].last_built_entity
    if last_entity then
        convertToGhost(last_entity)
        global.players[event.player_index].last_built_entity = nil
    end

    -- allowing the first roboport and logistic container on that surface
    local name = entity.name
    if entity.name == "roboport"
            or entity.name == "logistic-chest-storage" then
        local config = global.forces[entity.force.name]
        config.surfaces[entity.surface.name] = config.surfaces[entity.surface.name] or {}
        surface = config.surfaces[entity.surface.name]
        surface[entity.name] = (surface[entity.name] or 0) + 1
        game.print(entity.surface.name.." : +"..entity.name.." : "..tostring(surface[entity.name]))
        if surface[entity.name] == 1 then return end
    end

    if entity.type ~= "entity-ghost" and entity.type ~= "tile-ghost" then
        -- disconnect electric poles
        if entity.type == "electric-pole" then
            entity.disconnect_neighbour()
        end
        entity.active = false -- permit to disable the entity if needed
        global.tmpstack.set_stack(player.cursor_stack)
        player.cursor_stack.set_stack(event.stack)
        local blueprintable = replaceWithBlueprint(player.cursor_stack)
        player.cursor_stack.set_stack(global.tmpstack)
        -- if entity can be blueprinted then set last_built_entity and put item back on cursor
        if blueprintable then
            global.players[event.player_index].last_built_entity = event.created_entity
            -- put item back on cursor
            if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == event.stack.name then
                player.cursor_stack.count = player.cursor_stack.count + event.stack.count
            else
                player.cursor_stack.set_stack(event.stack)
            end
        end
    elseif player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.is_blueprint then
        -- if player holds blueprint of pipe or underground belt, rotate blueprint
        local entities = player.cursor_stack.get_blueprint_entities()
        if entities and #entities == 1 then
            local direction = entities.direction or 0
            local name = entities[1].name
            if name == "pipe-to-ground" or name == "underground-belt" or name == "fast-underground-belt" or name == "express-underground-belt" then
                entities[1].direction = ((entities[1].direction or 0) + 4) % 8
                player.cursor_stack.set_blueprint_entities(entities)
            end
        end
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    -- TODO: upgrading and removing ghosts leaves stale entries (memory leak). probably not serious, so issue is ignored for now
    local entity = event.created_entity
    local rewires = global.forces[entity.force.name].rewires[entity.position.x .. ";" .. entity.position.y]
    if rewires then
        for _, wire in pairs(rewires) do
            if not wire.target_entity.valid then
                -- target entity is gone, try to connect to entity at target location
                local entities = entity.surface.find_entities_filtered{position = wire.position, force = entity.force}
                if #entities > 0 then
                    wire.target_entity = entities[1]
                end
            end
            if wire.target_entity.valid then
                entity.connect_neighbour(wire)
            end
        end
        global.forces[entity.force.name].rewires[entity.position.x .. ";" .. entity.position.y] = nil
    end
	 -- permit to keep track of entity allowed on specific surfaces
    local name = entity.name
    if entity.name == "roboport"
            or entity.name == "logistic-chest-storage" then
        local config = global.forces[entity.force.name]
        config.surfaces[entity.surface.name] = config.surfaces[entity.surface.name] or {}
        surface = config.surfaces[entity.surface.name]
        surface[entity.name] = (surface[entity.name] or 0) + 1
        game.print(entity.surface.name.." : +"..entity.name.." : "..tostring(surface[entity.name]))
        if surface[entity.name] == 1 then return end
    end
end)

script.on_event(defines.events.on_player_crafted_item, function(event)
    local crafted = global.players[event.player_index].crafted
    crafted[#crafted + 1] = event.item_stack
end)

script.on_event(defines.events.on_player_pipette, function(event)
    local player = game.players[event.player_index]
    local name = player.cursor_stack.name
    if itemCountAllowed(name, player.cursor_stack.count) > 0 then
        -- some entities may be carried, but only allow pipetting if player got item in inventory (or cheat mode will make some)
        if not global.players[event.player_index].inventory_items[name] then
            player.cursor_stack.clear()
        end
    else
        if not replaceWithBlueprint(player.cursor_stack, (player.selected and player.selected.direction) or nil) then
            player.cursor_stack.clear()
        end
    end
end)

script.on_event(defines.events.on_player_main_inventory_changed, inventoryChanged)
script.on_event(defines.events.on_player_quickbar_inventory_changed, inventoryChanged)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.players[event.player_index]
    local cursor = player.cursor_stack
    local last_entity = global.players[event.player_index].last_built_entity
    if last_entity and (not cursor or not cursor.valid_for_read) then
        convertToGhost(last_entity)
        global.players[event.player_index].last_built_entity = nil
    end
    if cursor and cursor.valid_for_read then
        if cursor.is_deconstruction_item then
            local was_replacing = global.players[event.player_index].replace_entity and next(global.players[event.player_index].replace_entity)
            global.players[event.player_index].replace_entity = {}
            for i = 11, cursor.entity_filter_count - 10 do
                local from = cursor.get_entity_filter(i)
                local to = cursor.get_entity_filter(i + 10)
                if from and to then
                    global.players[event.player_index].replace_entity[from] = to
                    -- remove "to" filter to prevent user from removing ghosts of target entity
                    cursor.set_entity_filter(i + 10, nil)
                    player.print({"replace_entity", {"entity-name." .. from}, {"entity-name." .. to}})
                end
            end
            if was_replacing and not next(global.players[event.player_index].replace_entity) then
                player.print{"stopped_replacing"}
            end
        end
        local count_remaining = itemCountAllowed(cursor.name, cursor.count)
        local to_remove = cursor.count - count_remaining
        if to_remove > 0 then
            local entity = player.opened or player.selected
            local inserted = entity and entity.insert and entity.insert{name = cursor.name, count = to_remove} or 0
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
    -- check if user is in trouble due to insufficient storage
    local alerts = player.get_alerts{type = defines.alert_type.no_storage}
    local out_of_storage = false
    for _, surface in pairs(alerts) do
        for _, alert_type in pairs(surface) do
            for _, alert in pairs(alert_type) do
                local entity = alert.target
                if entity.name == "construction-robot" then
                    out_of_storage = true
                    local inventory = entity.get_inventory(defines.inventory.robot_cargo)
                    if inventory then
                        for name, count in pairs(inventory.get_contents()) do
                            entity.surface.spill_item_stack(entity.position, {name = name, count = count})
                        end
                    end
                    entity.clear_items_inside()
                end
            end
        end
    end
    if out_of_storage then
        player.print({"out-of-storage"})
    end
end)

script.on_event(defines.events.on_marked_for_deconstruction, function(event)
    if not event.player_index then
        return
    end
    local entity = event.entity
    local player = game.players[event.player_index]
    if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.is_deconstruction_item then
        if global.players[event.player_index].replace_entity and global.players[event.player_index].replace_entity[entity.name] then
            -- using pcall in case someone tries to create a ghost of a fish or something
            local create_ghost = function()
                global.tmpstack.set_stack{name = "blueprint", count = 1}
                entity.cancel_deconstruction(entity.force) -- must cancel deconstruction or it won't be added to blueprint
                global.tmpstack.create_blueprint{surface = entity.surface, force = entity.force, area = {entity.position, entity.position}}
                entity.order_deconstruction(entity.force)
                local blueprint = nil
                for _, bp_entity in pairs(global.tmpstack.get_blueprint_entities()) do
                    if bp_entity.name == entity.name then
                        bp_entity.name = global.players[event.player_index].replace_entity[entity.name]
                        blueprint = {bp_entity}
                    end
                end
                global.tmpstack.set_blueprint_entities(blueprint)
                global.tmpstack.build_blueprint{surface = entity.surface, force = entity.force, position = entity.position, direction = defines.direction.north}
                -- any wires connected to entity?
                local wires = entity.circuit_connection_definitions
                if wires and #wires > 0 then
                    for i = 1, #wires do
                        -- in case target entity is lost
                        wires[i].position = wires[i].target_entity.position
                    end
                    global.forces[entity.force.name].rewires[entity.position.x .. ";" .. entity.position.y] = wires
                end
            end
            pcall(create_ghost)
        end
    end
end)

script.on_event(defines.events.on_entity_died, function(event)
    local entity = event.entity
    -- check if roboport was destroyed
    local config = global.forces[entity.force.name]
    if config and entity == config.robport then
        game.set_game_state{game_finished = true, player_won = false, can_continue = false}
    end
    -- permit to keep track of entity allowed on specific surfaces
    if entity.name == "roboport"
            or entity.name == "logistic-chest-storage" then
        local config = global.forces[entity.force.name]
        config.surfaces[entity.surface.name] = config.surfaces[entity.surface.name] or {}
        surface = config.surfaces[entity.surface.name]
        surface[entity.name] = (surface[entity.name] or 1) - 1
        game.print(entity.surface.name.." : -"..entity.name.." : "..tostring(surface[entity.name]))
        if surface[entity.name] == 0 then surface[entity.name] = nil end
    end
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    local entity = event.entity
	 -- permit to keep track of entity allowed on specific surfaces
    if entity.name == "roboport"
            or entity.name == "logistic-chest-storage" then
        local config = global.forces[entity.force.name]
        config.surfaces[entity.surface.name] = config.surfaces[entity.surface.name] or {}
        surface = config.surfaces[entity.surface.name]
        surface[entity.name] = (surface[entity.name] or 1) - 1
        game.print(entity.surface.name.." : -"..entity.name.." : "..tostring(surface[entity.name]))
        if surface[entity.name] == 0 then surface[entity.name] = nil end
    end
end)

script.on_event(defines.events.on_sector_scanned, function(event)
    local position = event.chunk_position
    local radar = event.radar
    local config = global.forces[radar.force.name]
    local x = ((position.x <= 0 and (position.x + 4)) or (position.x > 0 and (position.x - 4))) * 32
    local y = ((position.y <= 0 and (position.y + 4)) or (position.y > 0 and (position.y - 4))) * 32
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
script.on_event(defines.events.on_tick, function(event)
    for _, player in pairs(game.players) do
        local config = global.forces[player.force.name]
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
    end
end)
