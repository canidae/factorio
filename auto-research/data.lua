data:extend({
	-- keybindings
	{
		type = "custom-input",
		name = "auto-research_toggle",
		key_sequence = "SHIFT + t"
	},
	{
		type = "custom-input",
		name = "auto-research_toggle_fewest_ingredients",
		key_sequence = "CONTROL + t"
	},
	{
		type = "custom-input",
		name = "auto-research_toggle_extended",
		key_sequence = "ALT + t"
	},

	-- entities
	{
		type = "constant-combinator",
		name = "research-center",
		icon = "__auto-research__/graphics/icons/research-center.png",
		flags = {"placeable-neutral", "player-creation"},
		minable = {hardness = 0.2, mining_time = 0.5, result = "research-center"},
		max_health = 150,
		corpse = "big-remnants",
		dying_explosion = "big-explosion",
		collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
		selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
		item_slot_count = 30,
		sprites = {
			north = {
				filename = "__auto-research__/graphics/entity/research-center.png",
				width = 113,
				height = 91,
				frame_count = 1,
				shift = {0.2, 0.15},
			},
			east = {
				filename = "__auto-research__/graphics/entity/research-center.png",
				width = 113,
				height = 91,
				frame_count = 1,
				shift = {0.2, 0.15},
			},
			south = {
				filename = "__auto-research__/graphics/entity/research-center.png",
				width = 113,
				height = 91,
				frame_count = 1,
				shift = {0.2, 0.15},
			},
			west = {
				filename = "__auto-research__/graphics/entity/research-center.png",
				width = 113,
				height = 91,
				frame_count = 1,
				shift = {0.2, 0.15},
			}
		},
		activity_led_sprites = {
			north = {
				filename = "__base__/graphics/entity/combinator/activity-leds/combinator-led-constant-north.png",
				width = 11,
				height = 10,
				frame_count = 1,
				shift = {0.296875, -0.40625},
			},
			east = {
				filename = "__base__/graphics/entity/combinator/activity-leds/combinator-led-constant-east.png",
				width = 14,
				height = 12,
				frame_count = 1,
				shift = {0.25, -0.03125},
			},
			south = {
				filename = "__base__/graphics/entity/combinator/activity-leds/combinator-led-constant-south.png",
				width = 11,
				height = 11,
				frame_count = 1,
				shift = {-0.296875, -0.078125},
			},
			west = {
				filename = "__base__/graphics/entity/combinator/activity-leds/combinator-led-constant-west.png",
				width = 12,
				height = 12,
				frame_count = 1,
				shift = {-0.21875, -0.46875},
			}
		},

		activity_led_light =
		{
			intensity = 0.8,
			size = 1,
		},

		activity_led_light_offsets = {
			{0.296875, -0.40625},
			{0.25, -0.03125},
			{-0.296875, -0.078125},
			{-0.21875, -0.46875}
		},
		circuit_wire_connection_points = {
			{
				shadow = {
					red = {0.15625, -0.28125},
					green = {0.65625, -0.25}
				},
				wire = {
					red = {-0.28125, -0.5625},
					green = {0.21875, -0.5625},
				}
			},
			{
				shadow = {
					red = {0.75, -0.15625},
					green = {0.75, 0.25},
				},
				wire = {
					red = {0.46875, -0.5},
					green = {0.46875, -0.09375},
				}
			},
			{
				shadow = {
					red = {0.75, 0.5625},
					green = {0.21875, 0.5625}
				},
				wire = {
					red = {0.28125, 0.15625},
					green = {-0.21875, 0.15625}
				}
			},
			{
				shadow = {
					red = {-0.03125, 0.28125},
					green = {-0.03125, -0.125},
				},
				wire = {
					red = {-0.46875, 0},
					green = {-0.46875, -0.40625},
				}
			}
		},
		circuit_wire_max_distance = 10
	},

	-- items
	{
		type = "item",
		name = "research-center",
		icon = "__auto-research__/graphics/icons/research-center.png",
		flags = {"goes-to-quickbar"},
		subgroup = "production-machine",
		order = "g[research-center]",
		place_result = "research-center",
		stack_size = 1
	},

	-- recipes
	{
		type = "recipe",
		name = "research-center",
		enabled = "true",
		energy_required = 3,
		ingredients = {
			{"electronic-circuit", 4},
			{"iron-gear-wheel", 4},
			{"copper-cable", 8}
		},
		result = "research-center"
	},

    -- subgroup for signals
    {
        type = "item-subgroup",
        name = "virtual-signal-auto-research",
        group = "signals",
        order = "g"
    },

    -- signals
    {
        type = "virtual-signal",
        name = "grenade-damage",
        icon = "__auto-research__/graphics/icons/signal/grenade-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "research-speed",
        icon = "__auto-research__/graphics/icons/signal/research-speed.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "toolbelt",
        icon = "__auto-research__/graphics/icons/signal/toolbelt.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "worker-robots-speed",
        icon = "__auto-research__/graphics/icons/signal/worker-robots-speed.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "worker-robots-storage",
        icon = "__auto-research__/graphics/icons/signal/worker-robots-storage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "character-logistic-slots",
        icon = "__auto-research__/graphics/icons/signal/character-logistic-slots.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "character-logistic-trash-slots",
        icon = "__auto-research__/graphics/icons/signal/character-logistic-trash-slots.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "auto-character-logistic-trash-slots",
        icon = "__auto-research__/graphics/icons/signal/auto-character-logistic-trash-slots.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "shotgun-shell-damage",
        icon = "__auto-research__/graphics/icons/signal/shotgun-shell-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "shotgun-shell-speed",
        icon = "__auto-research__/graphics/icons/signal/shotgun-shell-speed.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "laser-turret-damage",
        icon = "__auto-research__/graphics/icons/signal/laser-turret-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "laser-turret-speed",
        icon = "__auto-research__/graphics/icons/signal/laser-turret-speed.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "gun-turret-damage",
        icon = "__auto-research__/graphics/icons/signal/gun-turret-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "flamethrower-damage",
        icon = "__auto-research__/graphics/icons/signal/flamethrower-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "bullet-damage",
        icon = "__auto-research__/graphics/icons/signal/bullet-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "bullet-speed",
        icon = "__auto-research__/graphics/icons/signal/bullet-speed.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "combat-robot-damage",
        icon = "__auto-research__/graphics/icons/signal/combat-robot-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "rocket-damage",
        icon = "__auto-research__/graphics/icons/signal/rocket-damage.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "rocket-speed",
        icon = "__auto-research__/graphics/icons/signal/rocket-speed.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "follower-robot-count",
        icon = "__auto-research__/graphics/icons/signal/follower-robot-count.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    },
    {
        type = "virtual-signal",
        name = "inserter-capacity-bonus",
        icon = "__auto-research__/graphics/icons/signal/inserter-capacity-bonus.png",
        subgroup = "virtual-signal-auto-research",
        order = "g[auto-research]"
    }
})
