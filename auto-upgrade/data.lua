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

-- dynamically add sprites for modules
for _, module in pairs(data.raw.module) do
    if module.icon then
        data:extend({
            {
                type = "sprite",
                name = "auto_upgrade_module_" .. module.name,
                filename = module.icon,
                priority = "extra-high-no-scale",
                width = 32,
                height = 32
            }
        })
    end
end
