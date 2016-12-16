-- Make research significantly more expensive (and drop alien science pack, it's practically pointless)
for _, tech in pairs(data.raw["technology"]) do
    tech.unit.count = math.floor(tech.unit.count * (tech.unit.time * (1 + tech.unit.time / 5)) / 2)
    tech.unit.time = 2
    for index, ingredient in pairs(tech.unit.ingredients) do
        if ingredient[1] == "alien-science-pack" then
            tech.unit.ingredients[index] = nil
        end
    end
end
--log(serpent.block(data.raw["technology"], {comment = false, numformat = '%1.8g'}))
