-- relm_rewards: forwards significant gameplay events to the closed-source
-- backend. The backend batches them, applies whatever RTP / curve logic
-- we want to keep private, and mints/transfers RELM tokens on Soneium.
--
-- No on-chain calls happen in Lua. That's deliberate:
--   - Keeps the secret economy logic off-client (players can read these mods)
--   - Batches transactions so we don't pay gas per dug block
--   - Lets us iterate on reward curves without re-distributing the mod

local MOD = "relm_rewards"

local http = core.request_http_api()
if not http then
    core.log("error", "[" .. MOD .. "] HTTP API unavailable — add to secure.http_mods")
    return
end

local BACKEND_URL = core.settings:get("relm.backend_url") or "http://localhost:3000"
local BACKEND_SECRET = core.settings:get("relm.backend_secret") or ""

-- Emit-on-dig is noisy, so we batch locally and flush every few seconds.
local batch = {}
local FLUSH_INTERVAL = 5.0

local function push_event(player_name, kind, payload)
    local addr = relm_wallet and relm_wallet.get_address(player_name)
    if not addr then
        return -- unlinked player → no rewards, silently drop
    end
    table.insert(batch, {
        player = player_name,
        address = addr,
        kind = kind,
        payload = payload,
        t = os.time(),
    })
end

local function flush()
    if #batch == 0 then return end
    local events = batch
    batch = {}
    http.fetch({
        url = BACKEND_URL .. "/api/rewards/ingest",
        method = "POST",
        timeout = 15,
        extra_headers = {
            "Content-Type: application/json",
            "X-Relm-Secret: " .. BACKEND_SECRET,
        },
        data = core.write_json({ events = events }),
    }, function(res)
        if res.code ~= 200 then
            core.log("warning", "[" .. MOD .. "] backend ingest failed (" .. tostring(res.code) .. "), dropping " .. #events .. " events")
        end
    end)
end

local timer = 0
core.register_globalstep(function(dt)
    timer = timer + dt
    if timer >= FLUSH_INTERVAL then
        timer = 0
        flush()
    end
end)

-- Gameplay hooks — every signal the backend will use to score activity.

core.register_on_dignode(function(pos, oldnode, digger)
    if not digger or not digger:is_player() then return end
    push_event(digger:get_player_name(), "dignode", { node = oldnode.name })
end)

core.register_on_placenode(function(pos, newnode, placer)
    if not placer or not placer:is_player() then return end
    push_event(placer:get_player_name(), "placenode", { node = newnode.name })
end)

core.register_on_player_hpchange(function(player, hp_change, reason)
    if reason.type == "node_damage" or reason.type == "punch" then
        push_event(player:get_player_name(), "hp_change", { delta = hp_change, reason = reason.type })
    end
    return hp_change
end, false)

core.register_on_dieplayer(function(player, reason)
    push_event(player:get_player_name(), "death", { reason = reason.type or "unknown" })
end)

core.register_on_shutdown(flush)

core.log("action", "[" .. MOD .. "] loaded, backend = " .. BACKEND_URL)
