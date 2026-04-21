-- relm_core: world content + progression.
--
-- Groups the fundamental nodes, ores, and hand tools the rewards
-- economy can meaningfully score. Kept intentionally small — this is
-- the MVP loop, not a finished game. The ore tier is where real
-- reward pressure happens: deeper / rarer → more RELM per dig (the
-- server curve in server/src/lib/scoring.ts mirrors this table).

local MOD = "relm_core"

-- ───────── basic terrain nodes ─────────

core.register_node(MOD .. ":stone", {
    description = "Relm Stone",
    tiles = { "default_stone.png" },
    groups = { cracky = 3, stone = 1 },
    drop = MOD .. ":stone",
    sounds = {
        footstep = { name = "default_hard_footstep", gain = 0.3 },
        dug      = { name = "default_hard_footstep", gain = 0.6 },
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

core.register_node(MOD .. ":sand", {
    description = "Relm Sand",
    tiles = { "default_sand.png" },
    groups = { crumbly = 3, falling_node = 1 },
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

-- ───────── trees & wood ─────────

core.register_node(MOD .. ":tree", {
    description = "Relm Tree",
    tiles = {
        "default_tree_top.png",
        "default_tree_top.png",
        "default_tree.png",
    },
    groups = { choppy = 2, tree = 1 },
    drop = MOD .. ":tree",
})

core.register_node(MOD .. ":leaves", {
    description = "Relm Leaves",
    drawtype = "allfaces_optional",
    tiles = { "default_leaves.png" },
    paramtype = "light",
    groups = { snappy = 3, leafdecay = 3, leaves = 1 },
    drop = {
        max_items = 1,
        items = {
            { items = { MOD .. ":sapling" }, rarity = 20 },
            { items = { MOD .. ":leaves" } },
        },
    },
})

core.register_node(MOD .. ":sapling", {
    description = "Relm Sapling",
    drawtype = "plantlike",
    tiles = { "default_sapling.png" },
    inventory_image = "default_sapling.png",
    wield_image     = "default_sapling.png",
    paramtype = "light",
    walkable = false,
    groups = { snappy = 3, sapling = 1 },
})

core.register_node(MOD .. ":wood", {
    description = "Relm Wood Planks",
    tiles = { "default_wood.png" },
    groups = { choppy = 3, wood = 1 },
})

-- ───────── ores (the reward engine) ─────────

local function ore_node(id, desc, tile, hardness)
    core.register_node(MOD .. ":" .. id, {
        description = desc,
        tiles = { "default_stone.png^" .. tile },
        groups = { cracky = hardness, ore = 1 },
        drop = MOD .. ":" .. id .. "_lump",
    })
    core.register_craftitem(MOD .. ":" .. id .. "_lump", {
        description = desc .. " Lump",
        inventory_image = tile,
    })
end

ore_node("coal_ore",  "Relm Coal Ore",  "default_mineral_coal.png",  3)
ore_node("iron_ore",  "Relm Iron Ore",  "default_mineral_iron.png",  2)
ore_node("gold_ore",  "Relm Gold Ore",  "default_mineral_gold.png",  2)
-- Ink ore — thematic rare drop. Deep, hard, high bps in the scorer.
ore_node("ink_ore",   "Relm Ink Ore",   "default_mineral_diamond.png", 1)

-- Mapgen: sprinkle ores through stone layers, each at its own depth band.
core.register_ore({ ore_type = "scatter", ore = MOD .. ":coal_ore",
    wherein = MOD .. ":stone", clust_scarcity = 8 * 8 * 8, clust_num_ores = 8,
    clust_size = 3, y_max = 0, y_min = -128 })
core.register_ore({ ore_type = "scatter", ore = MOD .. ":iron_ore",
    wherein = MOD .. ":stone", clust_scarcity = 12 * 12 * 12, clust_num_ores = 5,
    clust_size = 3, y_max = -12, y_min = -256 })
core.register_ore({ ore_type = "scatter", ore = MOD .. ":gold_ore",
    wherein = MOD .. ":stone", clust_scarcity = 18 * 18 * 18, clust_num_ores = 3,
    clust_size = 2, y_max = -48, y_min = -512 })
core.register_ore({ ore_type = "scatter", ore = MOD .. ":ink_ore",
    wherein = MOD .. ":stone", clust_scarcity = 24 * 24 * 24, clust_num_ores = 2,
    clust_size = 2, y_max = -96, y_min = -768 })

-- ───────── tools ─────────

core.register_tool(MOD .. ":pick_wood", {
    description = "Wooden Pickaxe",
    inventory_image = "default_tool_woodpick.png",
    tool_capabilities = {
        full_punch_interval = 1.2,
        max_drop_level = 0,
        groupcaps = { cracky = { times = { [3] = 1.6 }, uses = 10, maxlevel = 1 } },
        damage_groups = { fleshy = 2 },
    },
})

core.register_tool(MOD .. ":pick_iron", {
    description = "Iron Pickaxe",
    inventory_image = "default_tool_steelpick.png",
    tool_capabilities = {
        full_punch_interval = 1.0,
        max_drop_level = 1,
        groupcaps = { cracky = { times = { [1] = 4.0, [2] = 1.6, [3] = 0.8 }, uses = 40, maxlevel = 2 } },
        damage_groups = { fleshy = 4 },
    },
})

core.register_tool(MOD .. ":axe_wood", {
    description = "Wooden Axe",
    inventory_image = "default_tool_woodaxe.png",
    tool_capabilities = {
        full_punch_interval = 1.2,
        max_drop_level = 0,
        groupcaps = { choppy = { times = { [2] = 1.6, [3] = 1.0 }, uses = 10, maxlevel = 1 } },
        damage_groups = { fleshy = 2 },
    },
})

-- ───────── crafting ─────────

core.register_craft({ output = MOD .. ":wood 4", recipe = {{ MOD .. ":tree" }} })

core.register_craft({
    output = MOD .. ":pick_wood",
    recipe = {
        { MOD .. ":wood", MOD .. ":wood", MOD .. ":wood" },
        { "",             MOD .. ":wood", ""             },
        { "",             MOD .. ":wood", ""             },
    },
})

core.register_craft({
    output = MOD .. ":axe_wood",
    recipe = {
        { MOD .. ":wood", MOD .. ":wood" },
        { MOD .. ":wood", MOD .. ":wood" },
        { "",             MOD .. ":wood" },
    },
})

core.register_craft({
    output = MOD .. ":pick_iron",
    recipe = {
        { MOD .. ":iron_ore_lump", MOD .. ":iron_ore_lump", MOD .. ":iron_ore_lump" },
        { "",                       MOD .. ":wood",          ""                       },
        { "",                       MOD .. ":wood",          ""                       },
    },
})

-- ───────── mapgen aliases ─────────

core.register_alias("mapgen_stone",              MOD .. ":stone")
core.register_alias("mapgen_dirt",               MOD .. ":dirt")
core.register_alias("mapgen_dirt_with_grass",    MOD .. ":grass")
core.register_alias("mapgen_water_source",       MOD .. ":water_source")
core.register_alias("mapgen_river_water_source", MOD .. ":water_source")
core.register_alias("mapgen_sand",               MOD .. ":sand")
core.register_alias("mapgen_tree",               MOD .. ":tree")
core.register_alias("mapgen_leaves",             MOD .. ":leaves")

-- ───────── sapling growth ─────────
-- Plant a sapling → it grows into a 5-block trunk with a 3x3 leaf cap
-- after a short delay. Keeps the world renewable without shipping a
-- full schematic.

core.register_abm({
    label = "Grow sapling",
    nodenames = { MOD .. ":sapling" },
    interval = 30,
    chance = 5,
    action = function(pos)
        for dy = 0, 4 do
            core.set_node({ x = pos.x, y = pos.y + dy, z = pos.z }, { name = MOD .. ":tree" })
        end
        for dx = -1, 1 do
            for dz = -1, 1 do
                for dy = 4, 5 do
                    local p = { x = pos.x + dx, y = pos.y + dy, z = pos.z + dz }
                    if core.get_node(p).name == "air" then
                        core.set_node(p, { name = MOD .. ":leaves" })
                    end
                end
            end
        end
    end,
})

-- ───────── starter inventory ─────────

core.register_on_newplayer(function(player)
    local inv = player:get_inventory()
    inv:add_item("main", MOD .. ":wood 4")
    inv:add_item("main", MOD .. ":pick_wood")
    inv:add_item("main", MOD .. ":axe_wood")
    inv:add_item("main", MOD .. ":sapling 2")
end)

core.log("action", "[relm_core] loaded (content pack)")
