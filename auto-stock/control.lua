function onTick()
    if game.tick % 128 ~= 0 then
        return
    end
    for _, player in pairs(game.players) do
        if player.connected and player.character and player.force.technologies["auto-character-logistic-trash-slots"].researched then
            local atf = player.auto_trash_filters
            if atf then
                local slots = player.character.request_slot_count
                local slot = 1
                for item, count in pairs(atf) do
                    if slot <= slots and player.get_item_count(item) < count then
                        player.character.set_request_slot({name = item, count = count}, slot)
                        slot = slot + 1
                    end
                end
                -- clear other slots
                for slot = slot, slots do
                    player.character.clear_request_slot(slot)
                end
            end
        end
    end
end

script.on_event(defines.events.on_tick, onTick)
