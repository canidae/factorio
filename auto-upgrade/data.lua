data.raw["gui-style"].default["auto_upgrade_header_label"] = {
    type = "label_style",
    parent = "label_style",
    font_color = {r = .91764705882352941176, g = .85098039215686274509, b = .67450980392156862745},
    font = "default-semibold"
}

data.raw["gui-style"].default["auto_upgrade_list_flow"] = {
    type = "flow_style",
    parent = "flow_style",
    vertical_spacing = 0
}

data.raw["gui-style"].default["auto_upgrade_sprite_button"] = {
    type = "button_style",
    parent = "button_style",
    width = 32,
    height = 32,
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

data.raw["gui-style"].default["auto_upgrade_checkbox"] = {
    type = "checkbox_style",
    parent = "checkbox_style"
}

data.raw["gui-style"].default["auto_upgrade_label"] = {
    type = "label_style",
    parent = "label_style",
    top_padding = 6
}

data:extend({
	-- keybindings
	{
		type = "custom-input",
		name = "auto_upgrade_toggle",
		key_sequence = "SHIFT + u"
	},

	-- sprites
	{
		type = "sprite",
		name = "auto_upgrade_add",
		filename = "__auto-upgrade__/graphics/add-icon.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
	{
		type = "sprite",
		name = "auto_upgrade_delete",
		filename = "__auto-upgrade__/graphics/delete.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
	{
		type = "sprite",
		name = "auto_upgrade_add_module",
		filename = "__auto-upgrade__/graphics/add-module.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
	{
		type = "sprite",
		name = "auto_upgrade_target",
		filename = "__auto-upgrade__/graphics/goto-icon.png",
		priority = "extra-high-no-scale",
		width = 32,
		height = 32
	},
    {
        type = "sprite",
        name = "auto_upgrade_unknown",
        filename = "__auto-upgrade__/graphics/questionmark.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    }
})
