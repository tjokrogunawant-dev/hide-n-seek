# Freeze Tag — Roblox Game Development Plan

A staged build plan for an AI coding agent (Claude Code). Each stage is independently testable, builds on the previous one, and includes a copy-paste prompt.

---

## Game Concept

**Freeze Tag Hide & Seek** — A round-based game where seekers chase hiders. Tagged hiders become **frozen** in place. Other hiders can **unfreeze** teammates by touching them. Round ends when all hiders are frozen (seekers win) or the timer runs out (hiders win).

**Player flow:**
1. Players spawn in lobby
2. Round starts → roles assigned (1–2 seekers, rest hiders)
3. Hiding phase (15s): seekers blinded/held, hiders run
4. Seeking phase (90s): seekers chase, freeze hiders, hiders unfreeze each other
5. Round ends → winners announced → back to lobby

---

## Tech Stack

- Luau with `--!strict`
- Rojo for filesystem sync
- Wally (optional) for packages
- Selene + StyLua for linting/formatting

---

## Project Structure

```
src/
  client/
    Controllers/      → UI, input, camera handling
    init.client.luau  → Client entry point
  server/
    Services/         → Round, Roles, Tagging, Maps, Data
    init.server.luau  → Server entry point
  shared/
    Constants.luau    → Tunable game values
    Remotes.luau      → RemoteEvent definitions
    Types.luau        → Shared Luau types
    Util/             → Pure helper functions
default.project.json
```

---

# PHASE 1 — MINIMAL PROTOTYPE (v1)

Target: one map, working freeze tag round loop, no persistence, no shop.

---

## Stage 1: Foundation

**Goal:** Empty but valid Rojo project that syncs to Studio. Folder structure in place. No gameplay yet.

**Files to create:**
- `default.project.json` (Rojo config mapping `src/` to Roblox services)
- `src/server/init.server.luau` (prints "Server started")
- `src/client/init.client.luau` (prints "Client started")
- `src/shared/Constants.luau` (empty module returning a table)
- `src/shared/Remotes.luau` (creates Remotes folder in ReplicatedStorage)
- `src/shared/Types.luau` (empty types module)
- `.gitignore`, `selene.toml`, `stylua.toml`

**Acceptance criteria:**
- [ ] `rojo serve` runs without errors
- [ ] In Studio, after connecting, both prints appear in the output
- [ ] `ReplicatedStorage.Remotes` folder exists

**Prompt for agent:**
> Read CLAUDE.md, then set up Stage 1 of the freeze tag game. Create a Rojo project structure with src/client, src/server, src/shared folders. Add init scripts for client and server that just print startup messages. Create empty Constants.luau, Types.luau, and a Remotes.luau module that creates a Remotes folder in ReplicatedStorage. Use `--!strict` on every file. Don't add gameplay yet — just the scaffold.

---

## Stage 2: Constants & Remotes

**Goal:** All tunable values centralized. All remote events declared upfront so later stages just reference them.

**Files to create/modify:**
- `src/shared/Constants.luau` — round timings, player limits, freeze duration, seeker count
- `src/shared/Remotes.luau` — declare all RemoteEvents and RemoteFunctions
- `src/shared/Types.luau` — `Role`, `RoundState`, `PlayerState` types

**Constants to include:**
```luau
return {
    MIN_PLAYERS = 2,
    HIDING_DURATION = 15,
    SEEKING_DURATION = 90,
    INTERMISSION_DURATION = 10,
    SEEKER_RATIO = 0.25,        -- 25% of players are seekers
    UNFREEZE_TOUCH_DURATION = 2, -- seconds to hold touch to unfreeze
    SEEKER_WALKSPEED = 18,
    HIDER_WALKSPEED = 16,
    FROZEN_WALKSPEED = 0,
}
```

**Remotes to declare:**
- `RoundStateChanged` (server → client)
- `RoleAssigned` (server → client)
- `PlayerFrozen` (server → client)
- `PlayerUnfrozen` (server → client)
- `TimerUpdate` (server → client)
- `RoundResults` (server → client)

**Acceptance criteria:**
- [ ] Constants module returns a frozen table of values
- [ ] `ReplicatedStorage.Remotes` contains all listed RemoteEvents
- [ ] Types module exports `Role = "Seeker" | "Hider" | "Frozen" | "Spectator"`

**Prompt for agent:**
> Stage 2: Add all constants and remote events. Open Constants.luau and add the values listed in the plan. Open Remotes.luau and create every RemoteEvent listed under "Remotes to declare", parented to ReplicatedStorage.Remotes. Define Role, RoundState, and PlayerState types in Types.luau. Don't write any gameplay logic — this stage just declares the contracts later stages will use.

---

## Stage 3: Map & Lobby

**Goal:** A playable map with spawn points and a separate lobby area. Players spawn in the lobby on join.

**Files/instances to create:**
- `src/server/Services/MapService.luau` — manages map references, returns spawn points
- A map model placed manually in Studio at `Workspace.Maps.Map1` (large floor + obstacles)
- `Workspace.Lobby` — a small floor area with `SpawnLocation`s
- `Workspace.Maps.Map1.HiderSpawns` — folder of `Part`s marking hider spawn positions
- `Workspace.Maps.Map1.SeekerSpawns` — folder of `Part`s for seekers

**Note:** Building the actual map geometry should be done in Studio by hand or by giving the agent explicit dimensions. For prototype, a simple flat map with 5–10 box obstacles is enough.

**MapService responsibilities:**
- `getCurrentMap(): Model`
- `getHiderSpawns(): { Vector3 }`
- `getSeekerSpawns(): { Vector3 }`
- `teleportPlayerTo(player: Player, position: Vector3)`

**Acceptance criteria:**
- [ ] Joining the game spawns you in the Lobby, not the map
- [ ] `MapService.getHiderSpawns()` returns at least 8 positions
- [ ] `MapService.teleportPlayerTo(player, somewhere)` actually moves the character

**Prompt for agent:**
> Stage 3: Create MapService at src/server/Services/MapService.luau. It should expose getCurrentMap, getHiderSpawns, getSeekerSpawns, and teleportPlayerTo. Read spawn positions from Workspace.Maps.Map1.HiderSpawns and SeekerSpawns folders (Parts inside). Generate a simple test map programmatically: a 200x200 floor at Workspace.Maps.Map1.Floor, plus 8 box obstacles scattered around, plus 8 hider spawn Parts and 2 seeker spawn Parts. Also generate a small Lobby area at Workspace.Lobby with one SpawnLocation. Make sure the lobby SpawnLocation has Neutral=true so players spawn there by default.

---

## Stage 4: Round State Machine

**Goal:** Server-side state machine that transitions: `Lobby → Hiding → Seeking → Results → Lobby`. No role logic yet — just the timer-driven transitions.

**Files to create:**
- `src/server/Services/RoundService.luau`

**State machine rules:**
- Stays in `Lobby` until `>= MIN_PLAYERS` connected
- `Lobby → Hiding`: fires `RoundStateChanged` with `"Hiding"`, starts hiding timer
- `Hiding → Seeking`: after `HIDING_DURATION` seconds
- `Seeking → Results`: after `SEEKING_DURATION` seconds OR when win condition met (stub for now)
- `Results → Lobby`: after `INTERMISSION_DURATION` seconds

**Public API:**
- `RoundService.getState(): RoundState`
- `RoundService.start()` — called from `init.server.luau`

**Acceptance criteria:**
- [ ] Joining alone keeps state at "Lobby"
- [ ] Joining with 2+ players advances through all states with correct timings
- [ ] Each state change fires `RoundStateChanged` to all clients
- [ ] `TimerUpdate` fires every second with remaining time

**Prompt for agent:**
> Stage 4: Build RoundService — a server state machine that cycles through Lobby, Hiding, Seeking, Results states. Use task.wait for transitions, but use the durations from Constants.luau. Fire RoundStateChanged and TimerUpdate remotes at appropriate times. The win-condition check in Seeking can be a TODO stub for now — just transition on timeout. Wire RoundService.start() into init.server.luau. Test: with 2 players, the state should cycle correctly with proper timings.

---

## Stage 5: Role Assignment & Teleporting

**Goal:** When `Hiding` starts, players are assigned Seeker or Hider roles, teleported to spawn points, and given correct walkspeed.

**Files to create:**
- `src/server/Services/RoleService.luau`

**Logic:**
- On `Hiding` start: pick `ceil(playerCount * SEEKER_RATIO)` random seekers, rest are hiders
- Teleport each player to a spawn from the corresponding spawn list
- Apply walkspeed: hiders run normally, **seekers are held in place during Hiding** (walkspeed = 0)
- On `Seeking` start: seekers get their walkspeed back
- On `Results` start: teleport everyone back to lobby, restore walkspeed
- Fire `RoleAssigned` remote to each player so client knows their role

**Acceptance criteria:**
- [ ] With 4 players, 1 becomes seeker and 3 become hiders (25% rounded up)
- [ ] Seekers cannot move during Hiding phase
- [ ] All players teleported to lobby on Results
- [ ] Each player receives `RoleAssigned` with their actual role

**Prompt for agent:**
> Stage 5: Build RoleService. Subscribe to RoundService state changes. On Hiding start, partition players into seekers (ceil(count * SEEKER_RATIO)) and hiders, teleport them to MapService spawn points, set walkspeeds (hiders move, seekers frozen at 0). On Seeking start, give seekers their walkspeed. On Results, teleport everyone to lobby and reset walkspeeds. Send RoleAssigned to each player. Track current roles in a server-side table keyed by Player.

---

## Stage 6: Tagging & Freezing (Core Mechanic)

**Goal:** The actual freeze tag gameplay. Seekers tag hiders by touching them → hiders freeze. Hiders unfreeze frozen teammates by touching them for 2 seconds.

**Files to create:**
- `src/server/Services/TaggingService.luau`

**Logic:**
- Listen to `Touched` events on seeker characters
- If a seeker touches a non-frozen hider → that hider's role becomes `Frozen`, walkspeed = 0, fire `PlayerFrozen` remote
- Listen to `Touched` events on hider characters
- If a hider touches a `Frozen` teammate continuously for `UNFREEZE_TOUCH_DURATION`s → unfreeze them, restore walkspeed, fire `PlayerUnfrozen`
- **Server validates everything** — never trust client claims about who touched whom
- Win condition check (now real): if all hiders are `Frozen`, transition to Results immediately

**Acceptance criteria:**
- [ ] Seeker walking into a hider freezes them (walkspeed becomes 0)
- [ ] A free hider standing next to a frozen one for 2s unfreezes them
- [ ] Frozen players visually distinct (e.g., body becomes light blue / has a freeze effect)
- [ ] When all hiders frozen → round immediately ends with seekers winning

**Prompt for agent:**
> Stage 6: Build TaggingService — the core freeze tag mechanic. Hook into character Touched events (only after Seeking starts, disconnect on Results). Seeker touches hider → freeze them: set walkspeed 0, change role to Frozen in RoleService, fire PlayerFrozen remote, apply a visual effect (color the character light blue or add a particle). Hider standing in contact with frozen teammate for UNFREEZE_TOUCH_DURATION seconds → unfreeze. Track touch duration server-side using a touch-start timestamp dict. Update the win-condition check in RoundService to end Seeking early when every hider is frozen. Validate everything on the server — never trust client.

---

## Stage 7: Client UI

**Goal:** Player sees their role, the round state, the timer, who's frozen, and the round results.

**Files to create:**
- `src/client/Controllers/UIController.luau`
- `src/client/Controllers/HUDController.luau`
- ScreenGui assets (can be created in code for prototype)

**UI elements:**
- **Top center:** current round state ("Hiding", "Seeking", "Lobby") + timer
- **Bottom center:** your role badge ("You are a SEEKER" / "HIDER" / "FROZEN")
- **Frozen overlay:** when you're frozen, show a "Wait for a teammate to unfreeze you!" message with progress bar
- **Results screen:** appears on Results state, shows winning team

**Acceptance criteria:**
- [ ] Timer counts down accurately matching server
- [ ] Role badge updates when `RoleAssigned` fires
- [ ] Frozen overlay appears on `PlayerFrozen` (only for the local player who got frozen)
- [ ] Results screen shows on round end

**Prompt for agent:**
> Stage 7: Build the UI. Create UIController and HUDController under src/client/Controllers. Build the ScreenGui in code (no asset IDs). Subscribe to RoundStateChanged, TimerUpdate, RoleAssigned, PlayerFrozen, PlayerUnfrozen, and RoundResults remotes. Show round state and timer at top, role badge at bottom, frozen overlay when local player is frozen, and a results screen on round end. Keep visuals minimal but clear — text labels with solid backgrounds is fine for prototype.

---

## ✅ End of v1 — You should have a complete playable freeze tag prototype.

Test it with 2+ players. Iterate on tuning (walkspeeds, timer durations) before moving on.

---

# PHASE 2 — META FEATURES (v1.1, v1.2, v1.3)

Add these only after v1 plays well.

---

## Stage 8: Multiple Random Maps (v1.1)

**Goal:** At each round start, pick a random map from a pool. Hide all maps and show only the active one.

**Files to modify:**
- `src/server/Services/MapService.luau` — track multiple maps, expose `pickRandomMap()`, `showMap(name)`, `hideAllMaps()`

**Workspace structure:**
```
Workspace.Maps.Map1
Workspace.Maps.Map2
Workspace.Maps.Map3
```
Each map has its own `HiderSpawns` and `SeekerSpawns` folders.

**Logic:**
- On `Lobby → Hiding`: pick random map, parent the others to ServerStorage to hide them
- On `Results → Lobby`: hide current map

**Prompt for agent:**
> Stage 8: Extend MapService to support multiple maps. Build out 2 more maps programmatically (different obstacle layouts and floor colors). Add pickRandomMap, showMap, hideAllMaps. Hook into RoundService so a random map is picked on Hiding start and hidden on Results end. Keep maps in ServerStorage when not active and reparent to Workspace.Maps when active.

---

## Stage 9: Player Stats & Persistence (v1.2)

**Goal:** Track wins, freezes, and unfreezes per player, persist across sessions using DataStoreService.

**Files to create:**
- `src/server/Services/DataService.luau`
- `src/shared/Types.luau` — extend with `PlayerProfile` type

**Profile schema:**
```luau
type PlayerProfile = {
    coins: number,
    wins: number,
    losses: number,
    freezesGiven: number,
    unfreezeAssists: number,
    cosmeticsOwned: { string },
}
```

**Logic:**
- On `PlayerAdded`: load profile from DataStore, create default if new
- On round end: increment relevant stats, award coins (e.g., 10 for win, 5 for participation, 2 per freeze)
- On `PlayerRemoving` and on autosave (every 60s): save profile back
- Use **session-locking** pattern (or just use ProfileService library) to prevent data loss
- Expose stats to client via a remote (`GetMyProfile` RemoteFunction)

**Acceptance criteria:**
- [ ] New players get a default profile
- [ ] Stats update after round end
- [ ] Stats persist across rejoining the server
- [ ] Server doesn't crash if DataStore is down (graceful fallback)

**Prompt for agent:**
> Stage 9: Add DataService for persistence. Use DataStoreService with a versioned key like "PlayerProfile_v1". Implement load on PlayerAdded, save on PlayerRemoving, and autosave every 60s. Use pcall around all DataStore calls and handle failures gracefully. Add a session-lock mechanism (or use the ProfileService open-source library if you can — recommend it to me first). Track wins, losses, freezes given, unfreeze assists, and coins. Update stats from RoundService on round end. Add a GetMyProfile RemoteFunction so the client can query its own data.

---

## Stage 10: Shop & Cosmetics (v1.3)

**Goal:** Players spend coins on cosmetic trails or character colors. Owned cosmetics persist and apply on spawn.

**Files to create:**
- `src/server/Services/ShopService.luau`
- `src/client/Controllers/ShopController.luau`
- `src/shared/Catalog.luau` — defines all available cosmetics with prices

**Catalog example:**
```luau
return {
    {id = "trail_red", name = "Red Trail", price = 100, type = "Trail", color = Color3.fromRGB(255,0,0)},
    {id = "trail_blue", name = "Blue Trail", price = 100, type = "Trail", color = Color3.fromRGB(0,0,255)},
    {id = "color_gold", name = "Gold Skin", price = 500, type = "BodyColor", color = Color3.fromRGB(255,215,0)},
}
```

**Logic:**
- Client fetches catalog on join, displays shop UI
- Player clicks Buy → fires `PurchaseRequest` remote
- Server validates: enough coins? not already owned? deduct coins, add to `cosmeticsOwned`, save profile
- Player can equip an owned cosmetic → applied to character on spawn

**Acceptance criteria:**
- [ ] Shop UI shows all catalog items with prices
- [ ] Buying deducts coins and unlocks the item
- [ ] Trying to buy without enough coins fails gracefully
- [ ] Equipped cosmetics appear on character respawn
- [ ] Persists across sessions

**Prompt for agent:**
> Stage 10: Build the shop. Define cosmetic catalog in Catalog.luau (5–10 items). Create ShopService that handles PurchaseRequest remote — validate coins on server, deduct, add to profile, save. Create EquipRequest for selecting an active cosmetic. On CharacterAdded, apply equipped cosmetic (Trail attached to motor, or BodyColors for skin tints). Build ShopController for the UI: list catalog, show owned/not-owned state, buy button, equip button. Update HUD to show coin count.

---

## Stage 11: Lobby Polish (v1.4)

**Goal:** Replace the single-spawn lobby with a social hub that has multiple game zones, a leaderboard, and a shop NPC. Players walk into a zone to queue for a game; all players in that zone launch together.

---

### 11a: Multi-Zone Matchmaking

**Concept:** The lobby has several **Game Portals** (glowing pads). Each portal is an independent queue holding up to 8 players. When ≥ 2 players are standing on a portal, a countdown starts. If the portal fills to 8, the countdown resets to a much shorter value. When the countdown hits 0, everyone on that portal is sent into a game together (their own server/round).

**Constants to add:**
```luau
MAX_PLAYERS_PER_ZONE = 8,
ZONE_MIN_PLAYERS = 2,
ZONE_COUNTDOWN_NORMAL = 30,  -- seconds when 2–7 players present
ZONE_COUNTDOWN_FULL = 5,     -- seconds when 8 players present
```

**Files to create/modify:**
- `src/server/Services/LobbyService.luau` — manages all portal zones, player queues, per-zone countdowns
- `src/server/Services/MapService.luau` — add `buildLobby()` portals (glowing circular pads, each with a proximity trigger)
- `src/shared/Remotes.luau` — add `ZoneCountdownUpdate`, `ZonePlayersChanged` remotes
- `src/client/Controllers/LobbyController.luau` — show per-zone player count and countdown above each portal

**LobbyService responsibilities:**
- Track which players are standing on which portal via `Touched` / `TouchEnded`
- Per-zone countdown loop: starts when zone reaches ZONE_MIN_PLAYERS, resets to ZONE_COUNTDOWN_FULL when zone is full
- On countdown reaching 0: call `RoundService.startRound(playersInZone)` and remove them from the zone
- Broadcast `ZonePlayersChanged` and `ZoneCountdownUpdate` to all clients so the UI stays live

**Portal layout (in lobby):**
- 3–4 circular pads arranged around the lobby floor
- Each pad labeled "Zone 1", "Zone 2", etc.
- Glowing neon color (e.g. cyan) so they're easy to spot
- Billboard GUI above each showing player count (e.g. "3 / 8") and countdown

**Acceptance criteria:**
- [ ] Walking onto a portal adds you to that zone (visible in count above pad)
- [ ] Walking off removes you
- [ ] Countdown starts when 2 players are on same portal
- [ ] Countdown jumps to 5s when portal hits 8 players
- [ ] Countdown resets if player count drops below 2
- [ ] All players on the portal teleport to the map together when countdown hits 0

**Prompt for agent:**
> Stage 11a: Build multi-zone lobby matchmaking. Add 3 circular neon portal pads to the lobby in MapService. Create LobbyService to track which players stand on each portal using Touched/TouchEnded on the pad parts. Each zone runs its own countdown coroutine: 30s normally, 5s when full (8 players), resets if count drops below 2. When countdown hits 0, fire all players in that zone into a round together. Add ZoneCountdownUpdate and ZonePlayersChanged remotes. Add a BillboardGui above each pad showing count and timer. Wire into RoundService so a zone launch starts a round for exactly those players.

---

### 11b: Leaderboard

**Goal:** A physical leaderboard board in the lobby showing top 10 players by wins.

**Files to create:**
- `src/server/Services/LeaderboardService.luau` — reads top stats from DataStore ordered datastore, updates the board every 60s
- Physical `SurfaceGui` Part placed in the lobby (created programmatically)

**Acceptance criteria:**
- [ ] Leaderboard Part visible in lobby
- [ ] Shows top 10 player names + win counts
- [ ] Refreshes every 60s

**Prompt for agent:**
> Stage 11b: Add a physical leaderboard to the lobby. Create a tall Part in the lobby with a SurfaceGui showing the top 10 players by wins. Use an OrderedDataStore keyed by UserId to fetch the leaderboard. Refresh every 60 seconds. Build LeaderboardService to own this logic.

---

### 11c: Shop NPC

**Goal:** An NPC standing in the lobby that opens the shop UI when a player walks up to it.

**Files to create/modify:**
- `src/server/Services/NPCService.luau` — spawns the shop NPC model (or a placeholder dummy) in the lobby
- `src/client/Controllers/ShopController.luau` — opens shop GUI on ProximityPrompt interact (replaces or supplements the existing shop UI trigger)

**Acceptance criteria:**
- [ ] NPC model visible in lobby
- [ ] ProximityPrompt appears when player is nearby
- [ ] Activating it opens the shop UI

**Prompt for agent:**
> Stage 11c: Add a shop NPC to the lobby. Spawn a Dummy model (using InsertService or a manually placed model) at a fixed lobby position. Attach a ProximityPrompt to it labelled "Shop". On the client, when the prompt fires, open the shop UI from ShopController. The NPC should have a nameplate ("Shop").

---

# Implementation Order Summary

| Stage | Deliverable | Approx. complexity |
|-------|-------------|-------------------|
| 1 | Project scaffold | Small |
| 2 | Constants + Remotes | Small |
| 3 | Map + Lobby | Medium |
| 4 | Round state machine | Medium |
| 5 | Role assignment | Medium |
| 6 | Freeze tag mechanic | Large |
| 7 | Client UI | Medium |
| **— v1 ships here —** | | |
| 8 | Multiple maps | Small |
| 9 | Persistence | Large |
| 10 | Shop | Large |
| 11a | Multi-zone matchmaking | Large |
| 11b | Leaderboard board | Medium |
| 11c | Shop NPC | Small |

---

# How to Use This Plan with Claude Code

For each stage:

1. Open Claude Code in your project
2. Make sure CLAUDE.md is up to date
3. Paste the **Prompt for agent** into Claude Code
4. After it finishes, run the **Acceptance criteria** as a manual checklist
5. Test in Studio
6. **Commit to git before moving to the next stage** — gives you a rollback point
7. If something's wrong, give Claude the failure and the relevant acceptance criterion as feedback
8. Only move to the next stage when ALL acceptance criteria pass

**Don't skip stages or merge them.** Each one is sized to be one Claude Code session.

---

# Tuning Notes (After v1)

Things that almost always need adjustment after the first playtest:
- Hiding duration (15s often too short on bigger maps)
- Seeker walkspeed advantage (currently 18 vs 16 — may need bigger gap)
- Unfreeze duration (2s — too easy = stalemate, too hard = no comebacks)
- Seeker ratio (25% — may need 33% for small lobbies of 4–6 players)

Edit `Constants.luau`, no other code changes needed.
