function inventoryChanged(event)
    if global.creative then
        return
    end
    local player = game.players[event.player_index]
    if not global.seablocked then
        -- tiny hack to work around that SeaBlock sets up stuff after BNW on load
        global.seablocked = true
        -- move everything from the Home rock to the other chest
        local home_rock = player.surface.find_entity("rock-chest", {0.5, 0.5})
        if home_rock then
            for name, count in pairs(home_rock.get_inventory(defines.inventory.chest).get_contents()) do
                global.seablock_chest.insert{name = name, count = count}
            end
        end
        home_rock.destroy()
        global.seablock_chest = nil

        -- and clear the starting items from player inventory
        player.clear_items_inside()
    end
    -- remove any crafted items
    for _, stack in pairs(global.players[event.player_index].crafted) do
	if stack.valid and itemCountAllowed(stack.name, stack.count, player) == 0 then
            player.remove_item{name = stack.name, count = stack.count}
        end
    end
    global.players[event.player_index].crafted = {}

    -- player is only allowed to carry blueprints and some whitelisted items
    -- everything else goes into entity opened or entity beneath mouse cursor
    local inventory_main = player.get_inventory(defines.inventory.god_main)
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
    scanInventory(inventory_main, blueprints, items)
    global.players[event.player_index].inventory_items = items

    for name, item in pairs(items) do
        local allowed = itemCountAllowed(name, item.count, player)
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
            local spill_entity = entity or global.forces[player.force.name].roboport
            remaining = remaining - (remaining > 0 and spill_entity.insert({name = name, count = remaining}) or 0)
            if remaining > 0 then
                -- player is not allowed to pick up stuff
                spill_entity.surface.spill_item_stack(spill_entity.position, {name = name, count = remaining})
                -- mark spilled items for deconstruction/pickup
                local pos = spill_entity.position
                local spilled = spill_entity.surface.find_entities_filtered{area = {{pos.x - 16, pos.y - 16}, {pos.x + 16, pos.y + 16}}, force = "neutral", type = "item-entity"}
                for _, item in pairs(spilled) do
                    item.order_deconstruction(spill_entity.force)
                end
            end
            player.remove_item{name = name, count = to_remove}
        end
    end
end

function itemCountAllowed(name, count, player)
    local item = game.item_prototypes[name]
    local place_type = item.place_result and item.place_result.type
    if name == "upgrade-builder2" or name == "droid-pickup-tool" then
        -- the upgrade planner isn't allowed, it upgrades stuff for free in cheat mode
        -- the droid pickup tool from Robot Army breaks some of the immersion in this scenario and is thus banned
        player.print({"item_not_allowed"})
        return 0
    elseif name == "red-wire" or name == "green-wire" then
        -- need these for circuitry, one stack is enough
        return math.min(200, count)
    elseif name == "copper-cable" then
        -- need this for manually connecting poles, but don't want player to manually move stuff around so we'll limit it
        return math.min(20, count)
    elseif place_type == "pipe-to-ground" then
        -- allow user to carry one pipe-to-ground, makes it easier to place underground pipes at max distance
        return 1
    elseif place_type == "electric-pole" then
        -- allow user to carry one of each power pole, makes it easier to place poles at max distance
        return 1
    elseif item.type == "blueprint" or item.type == "deconstruction-item" or item.type == "blueprint-book" or item.type == "selection-tool" or name == "artillery-targeting-remote" then
        -- these only place ghosts or are utility items
        return count
    elseif place_type == "locomotive" or place_type == "cargo-wagon" or place_type == "fluid-wagon" or place_type == "artillery-wagon" then
        -- locomotives and wagons must be placed manually
        return count
    elseif name == "rail" then
        -- rail stuff can't be (correctly) built directly with blueprints, allow 10 rails for the short range rail planner
        return 10
    elseif name == "train-stop" or name == "rail-signal" or name == "rail-chain-signal" then
        -- rail stuff can't be (correctly) built directly with blueprints, allow one that we'll later replace with a ghost
        return 1
    elseif place_type == "car" then
        -- let users put down cars & tanks
        return count
    elseif name == "landfill" or name == "cliff-explosives" then
        -- let users fill in water and remove cliffs
        return count
    elseif item.place_as_equipment_result then
        -- let user carry equipment
        return count
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
            direction = direction or defines.direction.north
            if direction % 4 == 2 then
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

function setupForce(force, surface, x, y, seablock_enabled)
    if not global.forces then
        global.forces = {}
    end
    if global.forces[force.name] then
        -- force already exist
        return
    end
    global.forces[force.name] = {
        rewires = {}
    }

    -- setup event listeners for creative mode
    if remote.interfaces["creative-mode"] then
        script.on_event(remote.call("creative-mode", "on_enabled"), function(event)
            global.creative = true
        end)
        script.on_event(remote.call("creative-mode", "on_disabled"), function(event)
            global.creative = false
        end)
    end

    -- give player the possibility to build robots & logistic chests from the start
    force.technologies["construction-robotics"].researched = true
    force.technologies["logistic-robotics"].researched = true
    force.technologies["logistic-system"].researched = true

    -- research some techs that require manual labour
    if seablock_enabled then
        force.technologies["sb-startup1"].researched = true
        force.technologies["sb-startup2"].researched = true
        force.technologies["bio-wood-processing"].researched = true -- what happened to sb-startup3? :o
        force.technologies["sb-startup4"].researched = true
    end

    -- setup starting location
    local water_replace_tile = "sand-1"
    force.chart(surface, {{x - 192, y - 192}, {x + 192, y + 192}})
    if not seablock_enabled then
        water_replace_tile = "dirt-3"
        -- oil is rare, but mandatory to continue research. add some oil patches near spawn point
        local xx = x + math.random(16, 32) * (math.random(1, 2) == 1 and 1 or -1)
        local yy = y + math.random(16, 32) * (math.random(1, 2) == 1 and 1 or -1)
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
    end

    -- remove trees/stones/resources
    local entities = surface.find_entities_filtered{area = {{x - 16, y - 7}, {x + 15, y + 9}}, force = "neutral"}
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- place dirt beneath structures
    tiles = {}
    for xx = x - 14, x + 13 do
        for yy = y - 5, y + 7 do
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
        surface.create_entity{name = "stone-wall", position = {xx, y - 3}, force = force}
        surface.create_entity{name = "stone-wall", position = {xx, y + 5}, force = force}
    end
    for yy = y - 3, y + 5 do
        surface.create_entity{name = "stone-wall", position = {x - 3, yy}, force = force}
        surface.create_entity{name = "stone-wall", position = {x + 2, yy}, force = force}
    end
    -- roboport
    local config = global.forces[force.name]
    config.roboport = surface.create_entity{name = "roboport", position = {x, y}, force = force}
    config.roboport.minable = false
    config.roboport.energy = 100000000
    local roboport_inventory = config.roboport.get_inventory(defines.inventory.roboport_robot)
    roboport_inventory.insert{name = "construction-robot", count = 100}
    roboport_inventory.insert{name = "logistic-robot", count = 50}
    roboport_inventory = config.roboport.get_inventory(defines.inventory.roboport_material)
    roboport_inventory.insert{name = "repair-pack", count = 10}
    -- electric pole
    local electric_pole = surface.create_entity{name = "medium-electric-pole", position = {x + 1, y + 2}, force = force}
    -- radar
    surface.create_entity{name = "radar", position = {x - 1, y + 3}, force = force}
    -- storage chest
    local seablock_chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y + 3}, force = force}
    -- storage chest, contains the items the force starts with
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {x + 1, y + 4}, force = force}
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
    chest_inventory.insert{name = "roboport", count = 4}
    chest_inventory.insert{name = "logistic-chest-storage", count = 4}
    chest_inventory.insert{name = "logistic-chest-passive-provider", count = 4}
    chest_inventory.insert{name = "logistic-chest-requester", count = 4}
    chest_inventory.insert{name = "lab", count = 2}
    if seablock_enabled then
        -- need some stuff for SeaBlock so we won't get stuck (also slightly accelerate gameplay)
        chest_inventory.insert{name = "ore-crusher", count = 4}
        chest_inventory.insert{name = "angels-electrolyser", count = 1}
        chest_inventory.insert{name = "liquifier", count = 2}
        chest_inventory.insert{name = "algae-farm", count = 2}
        chest_inventory.insert{name = "hydro-plant", count = 1}
        chest_inventory.insert{name = "crystallizer", count = 1}
        chest_inventory.insert{name = "angels-flare-stack", count = 2}
        chest_inventory.insert{name = "clarifier", count = 1}
        chest_inventory.insert{name = "wood-pellets", count = 50}
        global.seablock_chest = seablock_chest
    else
        -- prevent error when looking for "rock-chest" later
        global.seablocked = true
        -- only give player this when we're not seablocking
        chest_inventory.insert{name = "electric-mining-drill", count = 4}
    end
    -- solar panels and accumulators (left side)
    surface.create_entity{name = "solar-panel", position = {x - 11, y - 2}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 11, y + 1}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 11, y + 4}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 8, y + 4}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 5, y - 2}, force = force}
    surface.create_entity{name = "solar-panel", position = {x - 5, y + 4}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x - 7, y}, force = force}
    surface.create_entity{name = "small-lamp", position = {x - 6, y}, force = force}
    local accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y - 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 8, y + 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 6, y + 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x - 4, y + 2}, force = force}
    accumulator.energy = 5000000
    -- solar panels and accumulators (right side)
    surface.create_entity{name = "solar-panel", position = {x + 4, y - 2}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 4, y + 4}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 7, y + 4}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y - 2}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y + 1}, force = force}
    surface.create_entity{name = "solar-panel", position = {x + 10, y + 4}, force = force}
    surface.create_entity{name = "medium-electric-pole", position = {x + 6, y}, force = force}
    surface.create_entity{name = "small-lamp", position = {x + 5, y}, force = force}
    accumulator = surface.create_entity{name = "accumulator", position = {x + 4, y + 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 6, y + 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y - 2}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y}, force = force}
    accumulator.energy = 5000000
    accumulator = surface.create_entity{name = "accumulator", position = {x + 8, y + 2}, force = force}
    accumulator.energy = 5000000
end

function convertToGhost(entity)
    if not entity or not entity.valid then
        return
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

function preventMining(player)
    -- prevent mining (this appeared to be reset when loading a 0.16.26 save in 0.16.27)
    player.force.manual_mining_speed_modifier = -0.99999999 -- allows removing ghosts with right-click
end

script.on_event(defines.events.on_player_created, function(event)
    if not global.players then
        global.players = {}
    end
    local player = game.players[event.player_index]
    global.players[event.player_index] = {
        crafted = {},
        inventory_items = {},
        previous_position = player.position
    }

    -- create a "staging" surface that helps with the magic
    if not game.surfaces.staging then
        game.create_surface("staging", {width = 1, height = 1, seed = 42})
        global.chest = game.surfaces.staging.create_entity{name = "wooden-chest", position = {0, 0}}
        global.tmpstack = global.chest.get_inventory(defines.inventory.chest)[1]
    end

    if player.character then
        player.character.destroy()
        player.character = nil
    end
    -- disable light
    player.disable_flashlight()
    -- enable cheat mode
    player.cheat_mode = true

    -- print tip
    player.print({"startup_tip_1"})

    -- setup force
    setupForce(player.force, player.surface, 0, 0, game.active_mods["SeaBlock"])
    preventMining(player)
end)

script.on_event(defines.events.on_built_entity, function(event)
    if global.creative then
        return
    end
    local player = game.players[event.player_index]
    local entity = event.created_entity
    local last_entity = global.players[event.player_index].last_built_entity
    if last_entity then
        convertToGhost(last_entity)
        global.players[event.player_index].last_built_entity = nil
    end
    if entity.type ~= "entity-ghost" and entity.type ~= "tile-ghost" then
        -- disconnect electric poles
        if entity.type == "electric-pole" then
            entity.disconnect_neighbour()
        end
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
        local name = player.cursor_stack.label
        if name == "pipe-to-ground" or name == "underground-belt" or name == "fast-underground-belt" or name == "express-underground-belt" then
            local entities = player.cursor_stack.get_blueprint_entities()
            if entities and #entities == 1 then
                local direction = entities.direction or 0
                entities[1].direction = ((entities[1].direction or 0) + 4) % 8
                player.cursor_stack.set_blueprint_entities(entities)
            end
        end
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    if global.creative then
        return
    end
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
end)

script.on_event(defines.events.on_player_crafted_item, function(event)
    if global.creative then
        return
    end
    local crafted = global.players[event.player_index].crafted
    local item = game.item_prototypes[event.item_stack.name or ""]
    if item.type == "blueprint" or item.type == "deconstruction-item" or item.type == "blueprint-book" or item.type == "selection-tool" then
        -- let user craft these items
        return
    end
    crafted[#crafted + 1] = event.item_stack
end)

script.on_event(defines.events.on_player_pipette, function(event)
    if global.creative then
        return
    end
    local player = game.players[event.player_index]
    if not player.cursor_stack or not player.cursor_stack.valid_for_read then
        return
    end
    local name = player.cursor_stack.name
    if itemCountAllowed(name, player.cursor_stack.count, player) > 0 then
        -- some entities may be carried, but only allow pipetting if player got item in inventory (or cheat mode will make some)
        if not global.players[event.player_index].inventory_items[name] then
            player.cursor_stack.clear()
        end
    else
        if not replaceWithBlueprint(player.cursor_stack, player.selected and player.selected.direction) then
            player.cursor_stack.clear()
        end
    end
end)

script.on_event(defines.events.on_player_main_inventory_changed, inventoryChanged)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    if global.creative then
        return
    end
    local player = game.players[event.player_index]
    local cursor = player.cursor_stack
    local last_entity = global.players[event.player_index].last_built_entity
    if last_entity and (not cursor or not cursor.valid_for_read) then
        convertToGhost(last_entity)
        global.players[event.player_index].last_built_entity = nil
    end
    if cursor and cursor.valid_for_read then
        if cursor.is_deconstruction_item then
            local was_replacing = global.players[event.player_index].replace_entities and next(global.players[event.player_index].replace_entities)
            global.players[event.player_index].replace_entities = {}
            for i = 11, cursor.entity_filter_count - 10 do
                local from = cursor.get_entity_filter(i)
                local to = cursor.get_entity_filter(i + 10)
                if from and to then
                    global.players[event.player_index].replace_entities[from] = to
                    -- remove "to" filter to prevent user from removing ghosts of target entity
                    cursor.set_entity_filter(i + 10, nil)
                    player.print({"replace_entity", {"entity-name." .. from}, {"entity-name." .. to}})
                end
            end
            if was_replacing and not next(global.players[event.player_index].replace_entities) then
                player.print{"stopped_replacing"}
            end
        end
        local count_remaining = itemCountAllowed(cursor.name, cursor.count, player)
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
    if global.creative then
        return
    end
    if not event.player_index then
        return
    end
    local entity = event.entity
    local player = game.players[event.player_index]
    if player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.is_deconstruction_item then
        if global.players[event.player_index].replace_entities and global.players[event.player_index].replace_entities[entity.name] then
            -- using pcall in case someone tries to create a ghost of a fish or something
            local create_ghost = function()
                global.tmpstack.set_stack{name = "blueprint", count = 1}
                entity.cancel_deconstruction(entity.force) -- must cancel deconstruction or it won't be added to blueprint
                global.tmpstack.create_blueprint{surface = entity.surface, force = entity.force, area = {entity.position, entity.position}}
                entity.order_deconstruction(entity.force)
                local blueprint = nil
                for _, bp_entity in pairs(global.tmpstack.get_blueprint_entities()) do
                    if bp_entity.name == entity.name then
                        bp_entity.name = global.players[event.player_index].replace_entities[entity.name]
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
    if global.creative then
        return
    end
    local entity = event.entity
    -- check if roboport was destroyed
    local config = global.forces[entity.force.name]
    if config and entity == config.roboport then
        game.set_game_state{game_finished = true, player_won = false, can_continue = false}
    end
end)

script.on_event(defines.events.on_player_changed_position, function(event)
    if global.creative then
        return
    end
    local player = game.players[event.player_index]
    preventMining(player)

    local config = global.forces[player.force.name]
    local x_chunk = math.floor(player.position.x / 32)
    local y_chunk = math.floor(player.position.y / 32)
    -- prevent player from exploring, unless in a vehicle
    if not player.vehicle then
        local charted = function(x, y)
            return player.force.is_chunk_charted(player.surface, {x - 2, y - 2}) and player.force.is_chunk_charted(player.surface, {x - 2, y + 2}) and player.force.is_chunk_charted(player.surface, {x + 2, y - 2}) and player.force.is_chunk_charted(player.surface, {x + 2, y + 2})
        end
        if not charted(math.floor(player.position.x / 32), math.floor(player.position.y / 32)) then
            -- can't move here, chunk not charted
            local prev_pos = global.players[event.player_index].previous_position
            if charted(math.floor(player.position.x / 32), math.floor(prev_pos.y / 32)) then
                -- we can move here, though
                prev_pos.x = player.position.x
            elseif charted(math.floor(prev_pos.x / 32), math.floor(player.position.y / 32)) then
                -- or here
                prev_pos.y = player.position.y
            end
            -- teleport player to (possibly modified) prev_pos
            player.teleport(prev_pos)
        end
    end
    -- save new player position
    global.players[event.player_index].previous_position = player.position
end)
