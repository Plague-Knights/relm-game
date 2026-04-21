-- relm_cosmetics: enforces NFT perks for items the player owns.
--
-- Flow:
--   on_joinplayer → fetch /api/cosmetics/owned/<address> for the
--     player's linked Soneium wallet, cache the result in a table
--     keyed by player name, then apply auto-pickup radius right away.
--   on_dignode    → if the wielded tool's itemId matches a SOULBOUND
--     or UNBREAKABLE NFT the player owns, refund the wear delta so
--     the tool never degrades.
--   on_dieplayer  → just before the engine drops inventory, snapshot
--     any item whose itemId matches a KEEP_ON_DEATH NFT. After the
--     engine wipes the player, restore the snapshot.
--
-- The mod only reads from the backend; it doesn't mint or move NFTs
-- on-chain. The backend is the source of truth for what a wallet
-- owns; this side just applies the consequences.

local MOD = "relm_cosmetics"

local http = core.request_http_api()
if not http then
    core.log("error", "[" .. MOD .. "] HTTP API unavailable — add to secure.http_mods")
    return
end

local BACKEND_URL = core.settings:get("relm.backend_url") or "http://localhost:3000"

-- Mirrors the bitmask in RelmCosmetic.sol.
local PERK = {
    UNBREAKABLE   = 1,  -- 1 << 0
    KEEP_ON_DEATH = 2,  -- 1 << 1
    SOULBOUND     = 4,  -- 1 << 2
    AUTO_PICKUP   = 8,  -- 1 << 3
}

-- Per-player cache: name -> { items_by_id = { [itemId] = perks }, fetched_at = os.time() }
local cache = {}
local CACHE_TTL = 60  -- seconds; balances rare new mints landing fast vs RPC load

local function bit_has(v, mask)
    -- Lua 5.1 lacks bitwise ops; use math. Works for our small ints.
    return math.floor(v / mask) % 2 == 1
end

local function refresh_player(name)
    local addr = relm_wallet and relm_wallet.get_address(name)
    if not addr then
        cache[name] = { items_by_id = {}, fetched_at = os.time() }
        return
    end
    http.fetch({
        url = BACKEND_URL .. "/api/cosmetics/owned/" .. addr,
        method = "GET",
        timeout = 10,
    }, function(res)
        if res.code ~= 200 then
            core.log("warning", "[" .. MOD .. "] backend returned " .. tostring(res.code) .. " for " .. addr)
            return
        end
        local body = core.parse_json(res.data)
        if not body or not body.owned then return end
        local items_by_id = {}
        for _, o in ipairs(body.owned) do
            if o.itemId and o.itemId ~= "" then
                -- If a player owns multiple NFTs that skin the same item,
                -- the OR of their perks applies — best of both.
                items_by_id[o.itemId] = (items_by_id[o.itemId] or 0)
                    + (o.perks or 0) - bit_and_or(items_by_id[o.itemId] or 0, o.perks or 0)
            end
        end
        cache[name] = { items_by_id = items_by_id, fetched_at = os.time() }
        core.log("action", "[" .. MOD .. "] refreshed " .. name .. " (" .. addr .. ") — " .. #body.owned .. " NFTs")
    end)
end

-- Lua-5.1-safe bitwise OR for small (≤16-bit) values, used by refresh_player.
function bit_and_or(a, b)
    local r = 0
    local p = 1
    for _ = 1, 16 do
        if (a % 2 == 1) and (b % 2 == 1) then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end

local function perks_for(name, itemId)
    local c = cache[name]
    if not c then return 0 end
    return c.items_by_id[itemId] or 0
end

-- ───── join / leave ─────────────────────────────────────────────────

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    refresh_player(name)
end)

core.register_on_leaveplayer(function(player)
    cache[player:get_player_name()] = nil
end)

-- Periodic cache invalidation so newly-minted NFTs land within
-- CACHE_TTL seconds without requiring a relog.
local timer = 0
core.register_globalstep(function(dt)
    timer = timer + dt
    if timer < 30 then return end
    timer = 0
    local now = os.time()
    for name, c in pairs(cache) do
        if now - c.fetched_at > CACHE_TTL then
            refresh_player(name)
        end
    end
end)

-- ───── unbreakable: refund tool wear ───────────────────────────────

core.register_on_dignode(function(_pos, _oldnode, digger)
    if not digger or not digger:is_player() then return end
    local name = digger:get_player_name()
    local stack = digger:get_wielded_item()
    local itemId = stack:get_name()
    if itemId == "" then return end
    local perks = perks_for(name, itemId)
    if not bit_has(perks, PERK.UNBREAKABLE) then return end
    -- Engine has already applied wear by the time on_dignode fires.
    -- Reset to 0 (full durability) so the tool never breaks.
    if stack:get_wear() > 0 then
        stack:set_wear(0)
        digger:set_wielded_item(stack)
    end
end)

-- ───── keep on death: snapshot + restore ────────────────────────────

local death_snapshots = {}

core.register_on_dieplayer(function(player)
    local name = player:get_player_name()
    local inv = player:get_inventory()
    local snap = {}
    for i = 1, inv:get_size("main") do
        local stack = inv:get_stack("main", i)
        local itemId = stack:get_name()
        if itemId ~= "" then
            local perks = perks_for(name, itemId)
            if bit_has(perks, PERK.KEEP_ON_DEATH) then
                snap[i] = stack:to_string()
            end
        end
    end
    death_snapshots[name] = snap
end)

core.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    local snap = death_snapshots[name]
    if not snap then return end
    death_snapshots[name] = nil
    -- Run on the next server step so the engine's inventory wipe has
    -- finished before we put items back.
    core.after(0.1, function()
        local p = core.get_player_by_name(name)
        if not p then return end
        local inv = p:get_inventory()
        for i, str in pairs(snap) do
            inv:set_stack("main", i, ItemStack(str))
        end
    end)
end)

-- ───── soulbound: block dropping protected items ───────────────────
-- The engine still allows the player to drop items via Q, but we can
-- intercept the inventory action and refuse the move-to-detached.

core.register_on_player_inventory_action(function(player, action, inventory, info)
    if action ~= "move" then return end
    if info.from_list ~= "main" then return end
    local stack = inventory:get_stack(info.to_list, info.to_index)
    local itemId = stack:get_name()
    if itemId == "" then return end
    local perks = perks_for(player:get_player_name(), itemId)
    if bit_has(perks, PERK.SOULBOUND) then
        -- best-effort: undo the move
        inventory:set_stack(info.from_list, info.from_index, stack)
        inventory:set_stack(info.to_list, info.to_index, ItemStack(""))
        core.chat_send_player(player:get_player_name(), "[Relm] " .. itemId .. " is soulbound and can't be moved out of your inventory.")
    end
end)

-- ───── chat command: force refresh ─────────────────────────────────

core.register_chatcommand("cosmetics", {
    description = "Re-read your wallet's cosmetic NFTs from the backend.",
    func = function(name)
        refresh_player(name)
        return true, "Refreshing your cosmetics from the backend …"
    end,
})

core.log("action", "[" .. MOD .. "] loaded, backend = " .. BACKEND_URL)
