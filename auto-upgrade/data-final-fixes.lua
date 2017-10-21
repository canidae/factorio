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
