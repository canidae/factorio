data.raw["gui-style"].default["auto_upgrader_list_flow"] = {
    type = "flow_style",
    parent = "flow_style",
    vertical_spacing = 0
}

data.raw["gui-style"].default["auto_upgrader_sprite_button"] = {
    type = "button_style",
    parent = "button_style",
    width = 24,
    height = 24,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    left_click_sound = {
        {
            filename = "__core__/sound/gui-click.ogg",
            volume = 1
        }
    }
}

data.raw["gui-style"].default["auto_upgrader_button"] = {
	type = "button_style",
	parent = "button_style",
    font = "default",
	left_click_sound = {
		{
			filename = "__core__/sound/gui-click.ogg",
			volume = 1
		}
	},
}


data:extend({
	-- keybindings
	{
		type = "custom-input",
		name = "auto_upgrader_toggle",
		key_sequence = "SHIFT + u"
	},

	-- sprites
	{
		type = "sprite",
		name = "auto_upgrader_add",
		filename = "__auto-upgrader__/graphics/add-icon.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
	{
		type = "sprite",
		name = "auto_upgrader_delete",
		filename = "__auto-upgrader__/graphics/delete.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
	{
		type = "sprite",
		name = "auto_upgrader_add_module",
		filename = "__auto-upgrader__/graphics/add-module.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
	{
		type = "sprite",
		name = "auto_upgrader_upgrade_target",
		filename = "__auto-upgrader__/graphics/goto-icon.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	}
})
