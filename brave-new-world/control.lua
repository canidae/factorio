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
    player.cheat_mode = true

    -- build initial structures
    -- TODO: landfill starting area
    local surface = player.surface
    surface.create_entity{name = "constant-combinator", position = {0, 6}, force = player.force} -- TODO: this will be the player habitat that may not be destroyed
    local roboport = surface.create_entity{name = "roboport", position = {0, 0}, force = player.force}
    local roboport_inventory = roboport.get_inventory(defines.inventory.roboport_robot)
    roboport_inventory.insert{name = "construction-robot", count = 10}
    roboport_inventory.insert{name = "logistic-robot", count = 10}
    roboport_inventory = roboport.get_inventory(defines.inventory.roboport_material)
    roboport_inventory.insert{name = "repair-pack", count = 10}
    surface.create_entity{name = "medium-electric-pole", position = {0, 3}, force = player.force}
    local chest = surface.create_entity{name = "logistic-chest-storage", position = {-1, 3}, force = player.force}
    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    chest_inventory.insert{name = "iron-plate", count = 1000}
    chest_inventory.insert{name = "copper-plate", count = 1000}
    chest_inventory.insert{name = "coal", count = 250}
    chest_inventory.insert{name = "stone", count = 250}
    chest_inventory.insert{name = "small-electric-pole", count = 10}
    chest_inventory.insert{name = "transport-belt", count = 50}
    chest_inventory.insert{name = "inserter", count = 10}
    chest_inventory.insert{name = "assembling-machine-1", count = 5}
    chest_inventory.insert{name = "electric-mining-drill", count = 5}
    chest_inventory.insert{name = "stone-furnace", count = 5}
    chest_inventory.insert{name = "logistic-chest-storage", count = 5}
    chest_inventory.insert{name = "logistic-chest-active-provider", count = 5}
    chest_inventory.insert{name = "logistic-chest-passive-provider", count = 5}
    chest_inventory.insert{name = "logistic-chest-requester", count = 5}
    surface.create_entity{name = "solar-panel", position = {6, 0}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {6, 6}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {9, 6}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {12, 0}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {12, 3}, force = player.force}
    surface.create_entity{name = "solar-panel", position = {12, 6}, force = player.force}
    surface.create_entity{name = "medium-electric-pole", position = {8, 2}, force = player.force}
    surface.create_entity{name = "accumulator", position = {6, 4}, force = player.force}
    surface.create_entity{name = "accumulator", position = {8, 4}, force = player.force}
    surface.create_entity{name = "accumulator", position = {10, 0}, force = player.force}
    surface.create_entity{name = "accumulator", position = {10, 2}, force = player.force}
    surface.create_entity{name = "accumulator", position = {10, 4}, force = player.force}
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
    -- TODO: what if we instead "convert" cursor item to blueprint, and back again in on_built_entity?
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
    for playername, player in pairs(global.brave_new_world) do
        if player.cursor_stack then
            game.players[playername].cursor_stack.set_stack{name = player.cursor_stack, count = 1}
            player.cursor_stack = nil
        end
    end
end)
