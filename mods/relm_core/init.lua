-- relm_core: minimum-viable world bootstrap.
--
-- Registers a handful of nodes so the mapgen has something to place,
-- plus a starter inventory for new joiners. The real content layer
-- (biomes, crafting, progression) sits on top of this once the core
-- economy loop is wired up.

local MOD = "relm_core"

core.register_node(MOD .. ":stone", {
    description = "Relm Stone",
    tiles = { "default_stone.png" },
    groups = { cracky = 3, stone = 1 },
    drop = MOD .. ":stone",
    sounds = {
        footstep  = { name = "default_hard_footstep", gain = 0.3 },
        dug       = { name = "default_hard_footstep", gain = 0.6 },
    },
})

core.register_node(MOD .. ":dirt", {
    description = "Relm Dirt",
    tiles = { "default_dirt.png" },
    groups = { crumbly = 3, soil = 1 },
    drop = MOD .. ":dirt",
})

core.register_node(MOD .. ":grass", {
    description = "Relm Grass",
    tiles = {
        "default_grass.png",
        "default_dirt.png",
        { name = "default_dirt.png^default_grass_side.png", tileable_vertical = false },
    },
    groups = { crumbly = 3, soil = 1 },
    drop = MOD .. ":dirt",
})

core.register_node(MOD .. ":water_source", {
    description = "Relm Water",
    drawtype = "liquid",
    tiles = { "default_water.png" },
    paramtype = "light",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    liquidtype = "source",
    liquid_alternative_flowing = MOD .. ":water_flowing",
    liquid_alternative_source  = MOD .. ":water_source",
    liquid_viscosity = 1,
    post_effect_color = { a = 103, r = 30, g = 60, b = 90 },
    groups = { water = 3, liquid = 3 },
})

core.register_node(MOD .. ":water_flowing", {
    description = "Relm Water (flowing)",
    drawtype = "flowingliquid",
    tiles = { "default_water.png" },
    paramtype = "light",
    paramtype2 = "flowingliquid",
    walkable = false,
    pointable = false,
    diggable = false,
    buildable_to = true,
    liquidtype = "flowing",
    liquid_alternative_flowing = MOD .. ":water_flowing",
    liquid_alternative_source  = MOD .. ":water_source",
    liquid_viscosity = 1,
    post_effect_color = { a = 103, r = 30, g = 60, b = 90 },
    groups = { water = 3, liquid = 3, not_in_creative_inventory = 1 },
})

-- Mapgen alias table — tells the v7 generator which of our nodes to
-- place where it would normally use "mapgen_stone" / "mapgen_dirt".
core.register_alias("mapgen_stone",          MOD .. ":stone")
core.register_alias("mapgen_dirt",           MOD .. ":dirt")
core.register_alias("mapgen_dirt_with_grass", MOD .. ":grass")
core.register_alias("mapgen_water_source",   MOD .. ":water_source")

core.register_on_newplayer(function(player)
    local inv = player:get_inventory()
    inv:add_item("main", MOD .. ":dirt 20")
    inv:add_item("main", MOD .. ":stone 20")
end)

core.log("action", "[relm_core] loaded")
