global.auto_stock = {}

script.on_event(defines.events.on_tick, function()
    if game.tick % 128 ~= 0 then
        return
    end
    for _, player in pairs(game.players) do
        if player.connected and player.character and player.force.technologies["auto-character-logistic-trash-slots"].researched then
            local atf = player.auto_trash_filters
            if atf then
                -- add any temporarily removed auto trash rules
                if global.auto_stock[player.name] then
                    for item, count in pairs(global.auto_stock[player.name]) do
                        atf[item] = count
                    end
                    global.auto_stock[player.name] = nil
                end
                local slots = player.character.request_slot_count
                -- create table of existing requests
                local logistics = {}
                for slot = 1, slots do
                    local item = player.character.get_request_slot(slot)
                    if item ~= nil then
                        logistics[item.name] = item.count
                    end
                end
                -- compare with auto trash settings and modify logistics table as needed
                for item, count in pairs(atf) do
                    if logistics[item] and logistics[item] > count then
                        -- requesting more than trashing, temporarily remove auto trash setting
                        if not global.auto_stock[player.name] then
                            global.auto_stock[player.name] = {}
                        end
                        global.auto_stock[player.name][item] = count
                        atf[item] = nil
                    else
                        if player.get_item_count(item) < count then
                            -- missing items in inventory, request more
                            logistics[item] = count
                        else
                            -- have enough of item in inventory, remove any request for such items
                            logistics[item] = nil
                        end
                    end
                end
                -- setup new auto trash
                player.auto_trash_filters = atf
                -- setup new requests
                local slot = 1
                for item, count in pairs(logistics) do
                    player.character.set_request_slot({name = item, count = count}, slot)
                    slot = slot + 1
                end
                -- clear remaining request slots
                for slot = slot, slots do
                    player.character.clear_request_slot(slot)
                end
            end
        end
    end
end)
