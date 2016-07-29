script.on_event(defines.events.on_player_created, function(event)
    game.players[event.player_index].insert{name="blueprint-book", count=1}
    game.players[event.player_index].insert{name="blueprint", count=10}
    game.players[event.player_index].insert{name="deconstruction-planner", count=1}
end)
