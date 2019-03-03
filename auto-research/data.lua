data.raw["gui-style"].default["auto_research_header_label"] = {
    type = "label_style",
    font_color = {r = .91764705882352941176, g = .85098039215686274509, b = .67450980392156862745},
    font = "default-large-semibold",
    top_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    right_padding = 6
}

data.raw["gui-style"].default["auto_research_list_flow"] = {
    type = "vertical_flow_style",
    vertical_spacing = 0
}

data.raw["gui-style"].default["auto_research_tech_flow"] = {
    type = "horizontal_flow_style",
    horizontal_spacing = 0,
    resize_row_to_width = true
}

data.raw["gui-style"].default["auto_research_sprite_button"] = {
    type = "button_style",
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

data.raw["gui-style"].default["auto_research_sprite_button_toggle"] = {
    type = "button_style",
    parent = "auto_research_sprite_button",
    default_graphical_set = {
        type = "composition",
        filename = "__core__/graphics/gui.png",
        priority = "extra-high-no-scale",
        load_in_minimal_mode = true,
        corner_size = {3, 3},
        position = {0, 0}
    },
    hovered_graphical_set = {
        type = "composition",
        filename = "__core__/graphics/gui.png",
        priority = "extra-high-no-scale",
        load_in_minimal_mode = true,
        corner_size = {3, 3},
        position = {0, 8}
    }
}

data.raw["gui-style"].default["auto_research_sprite_button_toggle_pressed"] = {
    type = "button_style",
    parent = "auto_research_sprite_button_toggle",
    default_graphical_set = {
        type = "composition",
        filename = "__core__/graphics/gui.png",
        priority = "extra-high-no-scale",
        load_in_minimal_mode = true,
        corner_size = {3, 3},
        position = {0, 40}
    },
    hovered_graphical_set = {
        type = "composition",
        filename = "__core__/graphics/gui.png",
        priority = "extra-high-no-scale",
        load_in_minimal_mode = true,
        corner_size = {3, 3},
        position = {0, 48}
    }
}

data.raw["gui-style"].default["auto_research_tech_label"] = {
    type = "label_style",
    left_padding = 4,
    right_padding = 4
}

data.raw["gui-style"].default["auto_research_sprite"] = {
    type = "image_style",
    width = 24,
    height = 24,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0
}

data:extend({
	-- keybindings
	{
		type = "custom-input",
		name = "auto_research_toggle",
		key_sequence = "SHIFT + T"
	},

    -- sprites
    {
        type = "sprite",
        name = "auto_research_prioritize_top",
        filename = "__auto-research__/graphics/prioritize_top.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    },
    {
        type = "sprite",
        name = "auto_research_prioritize_bottom",
        filename = "__auto-research__/graphics/prioritize_bottom.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    },
    {
        type = "sprite",
        name = "auto_research_deprioritize",
        filename = "__auto-research__/graphics/deprioritize.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    },
    {
        type = "sprite",
        name = "auto_research_delete",
        filename = "__auto-research__/graphics/delete.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    },
    {
        type = "sprite",
        name = "auto_research_unknown",
        filename = "__auto-research__/graphics/questionmark.png",
        priority = "extra-high-no-scale",
        width = 32,
        height = 32
    }
})
