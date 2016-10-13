script.on_event(defines.events.on_player_created, function(event)
    if not global.brave_new_world then
        global.brave_new_world = {}
    end
    local player = game.players[event.player_index]
    if not global.brave_new_world[player.name] then
        global.brave_new_world[player.name] = {}
    end
    local character = player.character
    player.character = nil
    if character then
        character.destroy()
    end
    player.force.manual_mining_speed_modifier = -1
    player.force.manual_crafting_speed_modifier = -1
    player.insert{name = "deconstruction-planner", count = 1}

    -- build initial structures
    local surface = player.surface
    -- place dirt beneath structures
    local tiles = {}
    for x = -11, 7 do
        for y = -9, 3 do
            table.insert(tiles, {name = "grass-dry", position = {x, y}})
        end
    end
    surface.set_tiles(tiles)
    -- remove trees/stones
    local entities = surface.find_entities_filtered{area = {{-13, -11}, {9, 5}}, force = "neutral"}
    for _, entity in pairs(entities) do
        entity.destroy()
    end
    -- place walls
    for x = -9, -4 do
        surface.create_entity{name = "stone-wall", position = {x, -7}, force = player.force}
        surface.create_entity{name = "stone-wall", position = {x, 1}, force = player.force}
    end
    for y = -7, 1 do
        surface.create_entity{name = "stone-wall", position = {-9, y}, force = player.force}
        surface.create_entity{name = "stone-wall", position = {-4, y}, force = player.force}
    end
    -- roboport
    local roboport = surface.create_entity{name = "roboport", position = {-6, -4}, force = player.force}
    roboport.minable = false
    local roboport_inventory = roboport.get_inventory(defines.inventory.roboport_robot)
    roboport_inventory.insert{name = "construction-robot", count = 10}
    roboport_inventory.insert{name = "logistic-robot", count = 10}
    roboport_inventory = roboport.get_inventory(defines.inventory.roboport_material)
    roboport_inventory.insert{name = "repair-pack", count = 10}
    -- habitat
    local habitat = surface.create_entity{name = "player-habitat", position = {-7, -1}, force = player.force}
    habitat.operable = false
    -- electric pole
    local electric_pole = surface.create_entity{name = "medium-electric-pole", position = {-5, -2}, force = player.force}
    electric_pole.minable = false
    -- chests
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {-5, -1}, force = player.force}
    chest.minable = false
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    chest_inventory.insert{name = "iron-plate", count = 1000}
    chest_inventory.insert{name = "copper-plate", count = 1000}
    chest_inventory.insert{name = "coal", count = 200}
    chest_inventory.insert{name = "stone", count = 50}
    chest_inventory.insert{name = "transport-belt", count = 250}
    chest_inventory.insert{name = "pipe", count = 50}
    chest_inventory.insert{name = "medium-electric-pole", count = 50}
    chest_inventory.insert{name = "inserter", count = 20}
    chest_inventory.insert{name = "steam-engine", count = 1}
    chest_inventory.insert{name = "assembling-machine-1", count = 4}
    chest_inventory.insert{name = "electric-mining-drill", count = 4}
    chest_inventory.insert{name = "stone-furnace", count = 4}
    chest_inventory.insert{name = "roboport", count = 4}
    chest_inventory.insert{name = "logistic-chest-storage", count = 5}
    chest_inventory.insert{name = "logistic-chest-active-provider", count = 5}
    chest_inventory.insert{name = "logistic-chest-passive-provider", count = 5}
    chest_inventory.insert{name = "logistic-chest-requester", count = 5}
    chest_inventory.insert{name = "lab", count = 1}
    chest = surface.create_entity{name = "logistic-chest-storage", position = {-5, 0}, force = player.force}
    chest.minable = false
    -- solar panels and accumulators
    surface.create_entity{name = "solar-panel", position = {-2, -6}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {-2, 0}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {1, 0}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {4, -6}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {4, -3}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {4, 0}, force = player.force}
    surface.create_entity{name = "medium-electric-pole", position = {0, -4}, force = player.force}
    surface.create_entity{name = "accumulator", position = {-2, -2}, force = player.force}
    surface.create_entity{name = "accumulator", position = {0, -2}, force = player.force}
    surface.create_entity{name = "accumulator", position = {2, -6}, force = player.force}
    surface.create_entity{name = "accumulator", position = {2, -4}, force = player.force}
    surface.create_entity{name = "accumulator", position = {2, -2}, force = player.force}

    -- TODO: insert some stuff in player inventory too (inserters, belts, lab, steam engine, ...)
end)

script.on_event(defines.events.on_put_item, function(event)
    local position = event.position
    local player = game.players[event.player_index]
    local surface = player.surface
    local entityname = player.cursor_stack.name
    local entity = surface.find_entity("entity-ghost", position)
    if entity and entity.valid then
        global.brave_new_world[player.name].cursor_stack = entity.ghost_name
        player.cursor_stack.clear()
    end
end)

script.on_event(defines.events.on_built_entity, function(event)
    local entity = event.created_entity
    local entityname = entity.name
    if entityname == "entity-ghost" then
        return
    end
    local player = game.players[event.player_index]
    local surface = entity.surface
    local force = entity.force
    local position = entity.position
    local area = {{position.x - 0.5, position.y - 0.5}, {position.x + 0.5, position.y + 0.5}}
    player.cursor_stack.set_stack{name = "blueprint", count = 1}
    player.cursor_stack.create_blueprint{surface = entity.surface, force = force, area = area}
    entity.destroy()
    player.cursor_stack.build_blueprint{surface = surface, force = force, position = position}
    player.cursor_stack.set_stack{name = entityname, count = 1}
end)

script.on_event(defines.events.on_tick, function(event)
    -- TODO: can we prevent exploration by setting player.position? - game.players[1].teleport{x, y}
    for playername, player in pairs(global.brave_new_world) do
        if player.cursor_stack then
            game.players[playername].cursor_stack.set_stack{name = player.cursor_stack, count = 1}
            player.cursor_stack = nil
        end
    end
end)
