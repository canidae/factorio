-- Technology ID can be found in factorio/data/base/locale/en/base.cfg
-- Format in file is <technology ID>=<technology name>
-- Search for the technology you wish to research as soon as possible and add <technology ID> to the list below
-- Note that you'll have to add "-1", "-2", etc. for research of sequential technologies (such as "research-speed-1", "gun-turret-damage-1", etc)
auto_research_first = {
    "automation",
    "logistics",
    "steel-processing",
    "oil-processing",
    "fluid-handling",
    "advanced-material-processing",
    "research-speed-1",
    "research-speed-2",
    "research-speed-3",
    "research-speed-4"
}

-- Technologies listed here will not be researched before there's no other technologies available for research
-- If a technology is listed both in "auto_research_first" and "auto_research_last" then "auto_research_last" takes precedence
auto_research_last = {
}
