script.on_event(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    local player_inv = player.get_inventory(defines.inventory.player_main)
    player_inv.insert{name="blueprint-book", count=1}
    player_inv.insert{name="deconstruction-planner", count=1}
    for i=1, #player_inv do
        local item = player_inv[i]
        if not item.valid then
            break
        end
        if item.name == "blueprint-book" then
            player_inv[i].get_inventory(defines.inventory.item_main).insert{name="blueprint", count=10}
            break
        end
    end

    -- If Killkrog's Blueprint Manager is installed, show GUI
    if remote.interfaces.KBlueprints and remote.interfaces.KBlueprints["Always Show GUI"] then
        remote.call("KBlueprints", "Always Show GUI", player)
    end
end)
