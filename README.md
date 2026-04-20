# Relm

Voxel world with on-chain token rewards, running on [Soneium](https://soneium.org/).

Built as a **game** for the [Luanti (Minetest) engine](https://github.com/luanti-org/luanti). The engine stays upstream + LGPL; this repo is the gameplay layer and can carry any license.

## Layout

```
relm-game/
├── game.conf               # game metadata shown in the engine's menu
├── minetest.conf           # per-world defaults + HTTP mod allowlist
├── menu/                   # icon + background images for the engine menu
└── mods/
    ├── relm_core/          # nodes, mapgen aliases, starter inventory
    ├── relm_wallet/        # /wallet-link etc. — binds accounts to Soneium addresses
    └── relm_rewards/       # forwards gameplay events to the backend for minting
```

The crypto economy — challenge signing, reward curves, on-chain minting — lives in a separate closed-source backend. The Lua side only emits signals and caches state.

## Running locally

1. Install the Luanti engine (we use a fork at `../relm-engine/`)
2. Drop this directory into the engine's `games/` folder (or symlink)
3. Launch the engine, pick **Relm** in the game list, create a world
4. Set `relm.backend_url` in `minetest.conf` to your running backend

## First milestone

- [x] Engine forked (`relm-engine`)
- [x] Game skeleton with core / wallet / rewards mods
- [ ] Backend: `POST /api/wallet/challenge`, `POST /api/wallet/confirm`, `POST /api/rewards/ingest`
- [ ] Soneium contract: `RelmToken.mint(to, amount)` gated on backend signer
- [ ] End-to-end: dig a block in-game → token arrives in wallet
