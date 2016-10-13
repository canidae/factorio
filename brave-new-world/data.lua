data:extend({
    -- entities
    {
        type = "lab",
        name = "player-habitat",
        icon = "__base__/graphics/icons/lab.png",
        flags = {"player-creation", "not-blueprintable"},
        max_health = 150,
        corpse = "big-remnants",
        dying_explosion = "medium-explosion",
        collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
        selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
        light = {intensity = 0.75, size = 8},
        on_animation = {
            filename = "__base__/graphics/entity/lab/lab.png",
            width = 113,
            height = 91,
            frame_count = 33,
            line_length = 11,
            animation_speed = 1 / 3,
            shift = {0.2, 0.15}
        },
        off_animation = {
            filename = "__base__/graphics/entity/lab/lab.png",
            width = 113,
            height = 91,
            frame_count = 1,
            shift = {0.2, 0.15}
        },
        working_sound = {
            sound = {
                filename = "__base__/sound/lab.ogg",
                volume = 0.7
            },
            apparent_volume = 1
        },
        energy_source = {
            type = "electric",
            usage_priority = "secondary-input"
        },
        energy_usage = "10kW",
        researching_speed = 1,
        inputs = {}
    }
})
