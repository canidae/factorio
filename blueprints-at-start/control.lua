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
        -- ok, so this is super annoying:
        -- this mod likely handles "on_player_created" event before KBM, which means that
        -- KBM isn't fully set up when event "on_player_created" is broadcasted.
        -- that means we can't invoke the remote call below just yet
        -- but we can invoke it on the first tick, hence the "creative" code
        script.on_event(defines.events.on_tick, function(event)
            remote.call("KBlueprints", "Always Show GUI", player)
            script.on_event(defines.events.on_tick, nil) -- remove event listener immediately
        end)
    end
end)
