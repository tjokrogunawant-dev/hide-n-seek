# Roblox Game Project — Claude Code Instructions

## Project Overview
This is a Roblox game built with **Luau** and synced via **Rojo**. Source files live on disk and replicate into Roblox Studio. Always treat the filesystem as the source of truth.

---

## Tech Stack
- **Language:** Luau (Roblox's typed Lua dialect — NOT vanilla Lua)
- **Sync tool:** Rojo (`default.project.json` defines the mapping)
- **Package manager:** Wally (if `wally.toml` exists)
- **Linter:** Selene (`selene.toml`)
- **Formatter:** StyLua (`stylua.toml`)
- **Type checking:** Use `--!strict` at the top of every script

---

## Project Structure
```
src/
  client/          → StarterPlayer.StarterPlayerScripts (LocalScripts)
  server/          → ServerScriptService (Scripts)
  shared/          → ReplicatedStorage (ModuleScripts shared by both)
  assets/          → ReplicatedStorage.Assets (models, sounds, etc.)
default.project.json
wally.toml
selene.toml
stylua.toml
references/       → Read-only example projects for pattern reference
```

**Naming conventions:**
- `*.client.luau` → LocalScript (client only)
- `*.server.luau` → Script (server only)
- `*.luau` → ModuleScript (default, runs in either context)
- Folders become `Folder` instances unless an `init.luau` is present (then they become a ModuleScript)

---

## Critical Rules — DO NOT SKIP

### 1. Parts must be physically instantiated to appear in-world
A common failure: writing logic that references tiles/parts without actually creating them. **Every visible object MUST go through `Instance.new()` and be parented to `workspace` (or a descendant).**

```luau
-- CORRECT: tile actually appears
local tile = Instance.new("Part")
tile.Size = Vector3.new(4, 1, 4)
tile.Position = Vector3.new(x * 4, 0, z * 4)
tile.Anchored = true              -- REQUIRED or it falls
tile.TopSurface = Enum.SurfaceType.Smooth
tile.Material = Enum.Material.Plastic
tile.Parent = workspace.Tiles     -- REQUIRED or it never renders
```

**Checklist before finishing any "build the map/world" task:**
- [ ] Did I actually call `Instance.new()` for each visible object?
- [ ] Did I set `.Anchored = true` for static geometry?
- [ ] Did I set `.Parent` to something inside `workspace`?
- [ ] Did I set `.Size` and `.Position` (or `.CFrame`)?
- [ ] If it's a tile grid, did I LOOP through coordinates, not just write one?

### 2. Server vs Client boundaries
- **Server (`ServerScriptService`):** authoritative game state, data persistence, anti-exploit, spawning
- **Client (`StarterPlayerScripts`):** input, camera, UI, local effects
- **Shared (`ReplicatedStorage`):** types, constants, pure functions used by both
- Cross the boundary ONLY via `RemoteEvent` / `RemoteFunction` (or `BindableEvent` within same context)
- Never trust client input on the server — always validate

### 3. Use Roblox services correctly
Always fetch services with `game:GetService(...)`, never with dot notation:
```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
```

### 4. Always use `--!strict` and type annotations
```luau
--!strict

type TileData = {
    position: Vector3,
    tileType: "grass" | "stone" | "water",
    walkable: boolean,
}

local function createTile(data: TileData): Part
    -- ...
end
```

---

## Tile-Based Map Generation Pattern
When asked to build a tile map, ALWAYS follow this template:

```luau
--!strict
local TILE_SIZE = 4
local GRID_WIDTH = 20
local GRID_DEPTH = 20

-- 1. Create container folder
local tilesFolder = Instance.new("Folder")
tilesFolder.Name = "Tiles"
tilesFolder.Parent = workspace

-- 2. Loop through grid coordinates
for x = 0, GRID_WIDTH - 1 do
    for z = 0, GRID_DEPTH - 1 do
        -- 3. Instance each tile
        local tile = Instance.new("Part")
        tile.Name = `Tile_{x}_{z}`
        tile.Size = Vector3.new(TILE_SIZE, 1, TILE_SIZE)
        tile.Position = Vector3.new(x * TILE_SIZE, 0, z * TILE_SIZE)
        tile.Anchored = true
        tile.TopSurface = Enum.SurfaceType.Smooth
        tile.BottomSurface = Enum.SurfaceType.Smooth
        tile.Material = Enum.Material.Grass
        tile.Color = Color3.fromRGB(86, 142, 76)
        tile.Parent = tilesFolder    -- MUST parent or invisible
    end
end

print(`Generated {GRID_WIDTH * GRID_DEPTH} tiles`)
```

**After running, verify in Studio that the Tiles folder under Workspace contains the expected number of Parts.**

---

## Common Patterns

### RemoteEvent setup
```luau
-- shared/Remotes.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local PlaceTile = Instance.new("RemoteEvent")
PlaceTile.Name = "PlaceTile"
PlaceTile.Parent = Remotes

return Remotes
```

### Player spawn handling
```luau
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player: Player)
    player.CharacterAdded:Connect(function(character: Model)
        -- handle character setup
    end)
end)
```

### Heartbeat/RenderStepped loops
```luau
local RunService = game:GetService("RunService")

-- Server-side game loop
RunService.Heartbeat:Connect(function(deltaTime: number)
    -- update game state
end)

-- Client-side rendering (camera, UI)
RunService.RenderStepped:Connect(function(deltaTime: number)
    -- update camera or visual effects
end)
```

---

## Verification Workflow
After every code-generation task, before declaring done:

1. **List what was created:** "I created X tiles at positions Y to Z, parented under workspace.Tiles"
2. **Check parenting:** Every visible Instance has a valid `.Parent`
3. **Check anchoring:** Static geometry has `.Anchored = true`
4. **Check the Rojo project file:** New script paths are reachable via `default.project.json`
5. **Run linter mentally:** No undefined globals, no missing `local`, no shadowed variables

If asked to build a world/map and Studio shows nothing after sync, the most likely causes are (in order):
1. Parts created but never `.Parent` assigned
2. Parts created but `.Anchored = false` and they fell through the floor
3. Code written in a ModuleScript that nothing requires
4. Server-only code that runs but a client-only test was performed

---

## Forbidden / Avoid
- ❌ `wait()` — use `task.wait()` instead
- ❌ `spawn()` — use `task.spawn()` instead
- ❌ `delay()` — use `task.delay()` instead
- ❌ Storing player data only in memory — use `DataStoreService` or a wrapper like ProfileService
- ❌ `while true do ... wait() end` without a `task.wait()` and exit condition
- ❌ Using `_G` or `shared` for cross-script communication — use ModuleScripts
- ❌ FilteringEnabled is always on (it's not a setting anymore) — design accordingly
- ❌ Trusting client-sent values on the server without validation

---

## Reference Projects
When unsure about a pattern, look in `references/` for working examples:
- Folder structure
- How Parts are created and parented
- How client/server/shared code is organized
- How RemoteEvents are wired up

Read before writing — don't reinvent patterns that already exist in references.

---

## Game-Specific Configuration
> **Edit this section to describe YOUR specific game:**

- **Genre:** [e.g. tile-based dungeon crawler, obby, simulator, tycoon]
- **Core loop:** [e.g. player explores procedural tiles, collects loot, fights enemies]
- **Key systems:** [e.g. inventory, combat, economy, leaderstats]
- **Data persistence:** [e.g. ProfileService with auto-save every 60s]
- **Target player count:** [e.g. up to 12 per server]

---

## When in Doubt
1. Check `references/` for an existing pattern
2. Check the [Roblox Creator Docs](https://create.roblox.com/docs)
3. Ask the user before inventing a new architecture
4. Prefer explicit, verbose code over clever code — Luau strict mode catches more that way
