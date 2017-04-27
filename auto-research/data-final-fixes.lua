-- dynamically add sprites for tools (to display research ingredients)
for _, tool in pairs(data.raw.tool) do
    if tool.icon then
        data:extend({
            {
                type = "sprite",
                name = "auto_research_tool_" .. tool.name,
                filename = tool.icon,
                priority = "extra-high-no-scale",
                width = 32,
                height = 32
            }
        })
    end
end
