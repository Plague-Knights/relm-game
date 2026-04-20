-- relm_wallet: binds a Luanti player to their Soneium wallet.
--
-- Flow (stub for now):
--   1. Player runs /wallet-link  → server POSTs to backend with username
--   2. Backend returns a one-time URL with a challenge (SIWE nonce)
--   3. Player opens URL in browser, connects wallet, signs challenge
--   4. Backend pushes back via webhook OR we poll — that's the closed-source
--      side and lives on the web, not here
--
-- This file just wires the HTTP request and caches the linked address in
-- a player meta field so other mods (relm_rewards, etc.) can read it.

local MOD = "relm_wallet"

-- Must be called ONCE, synchronously, during mod load. Returns nil if
-- the mod isn't listed in secure.http_mods.
local http = core.request_http_api()
if not http then
    core.log("error", "[" .. MOD .. "] HTTP API unavailable — add this mod to secure.http_mods")
    return
end

local BACKEND_URL = core.settings:get("relm.backend_url") or "http://localhost:3000"
local BACKEND_TIMEOUT = 10 -- seconds

local function get_linked_address(player)
    local meta = player:get_meta()
    local addr = meta:get_string("relm_wallet_address")
    return addr ~= "" and addr or nil
end

local function set_linked_address(player, addr)
    player:get_meta():set_string("relm_wallet_address", addr)
end

-- Public API other mods consume.
relm_wallet = {
    get_address = function(name)
        local p = core.get_player_by_name(name)
        if not p then return nil end
        return get_linked_address(p)
    end,
}

core.register_chatcommand("wallet-link", {
    description = "Generate a one-time URL to link your Soneium wallet to this account.",
    func = function(name)
        http.fetch({
            url = BACKEND_URL .. "/api/wallet/challenge",
            method = "POST",
            timeout = BACKEND_TIMEOUT,
            extra_headers = { "Content-Type: application/json" },
            data = core.write_json({ player = name }),
        }, function(res)
            if res.code ~= 200 then
                core.chat_send_player(name, "[Relm] backend error (" .. tostring(res.code) .. ")")
                return
            end
            local body = core.parse_json(res.data)
            if not body or not body.url then
                core.chat_send_player(name, "[Relm] malformed challenge response")
                return
            end
            core.chat_send_player(name, "[Relm] Open this URL within 10 minutes to finish linking:")
            core.chat_send_player(name, body.url)
        end)
        return true, "Generating wallet-link URL …"
    end,
})

core.register_chatcommand("wallet", {
    description = "Show the Soneium wallet currently linked to your account.",
    func = function(name)
        local addr = relm_wallet.get_address(name)
        if not addr then
            return true, "No wallet linked. Run /wallet-link to bind one."
        end
        return true, "Linked wallet: " .. addr
    end,
})

-- Backend can PUT back the signed-off address after the player finishes
-- the browser flow. For the MVP the player runs /wallet-set manually with
-- the address the backend gave them — keeps the mod stateless without a
-- poller. Secure handshake stays a backend concern.
core.register_chatcommand("wallet-set", {
    params = "<0xAddress> <signature-token>",
    description = "Finalize wallet linking (token comes from the browser flow).",
    func = function(name, param)
        local addr, token = param:match("^(0x[%x]+)%s+(%S+)$")
        if not addr or not token then
            return false, "Usage: /wallet-set 0x<address> <token-from-browser>"
        end
        http.fetch({
            url = BACKEND_URL .. "/api/wallet/confirm",
            method = "POST",
            timeout = BACKEND_TIMEOUT,
            extra_headers = { "Content-Type: application/json" },
            data = core.write_json({ player = name, address = addr, token = token }),
        }, function(res)
            if res.code ~= 200 then
                core.chat_send_player(name, "[Relm] backend rejected token (" .. tostring(res.code) .. ")")
                return
            end
            local p = core.get_player_by_name(name)
            if p then set_linked_address(p, addr) end
            core.chat_send_player(name, "[Relm] Wallet linked: " .. addr)
        end)
        return true, "Confirming with backend …"
    end,
})

core.log("action", "[" .. MOD .. "] loaded, backend = " .. BACKEND_URL)
