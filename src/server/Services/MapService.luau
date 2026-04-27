--!strict

local Workspace = game:GetService("Workspace")

-- Map is offset far from lobby so they don't overlap
local MAP_ORIGIN = Vector3.new(300, 0, 0)
local LOBBY_ORIGIN = Vector3.new(0, 0, 0)

local MapService = {}

local currentMap: Model
local hiderSpawnPositions: { Vector3 } = {}
local seekerSpawnPositions: { Vector3 } = {}

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function buildLobby()
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = Workspace

	makePart(
		lobby,
		"Floor",
		Vector3.new(40, 1, 40),
		LOBBY_ORIGIN + Vector3.new(0, -0.5, 0),
		Color3.fromRGB(106, 127, 63),
		Enum.Material.Grass
	)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SpawnLocation"
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.CFrame = CFrame.new(LOBBY_ORIGIN + Vector3.new(0, 0.5, 0))
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Color = Color3.fromRGB(255, 215, 0)
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.BottomSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = lobby
end

local function buildMap1(): Model
	local mapsFolder = Instance.new("Folder")
	mapsFolder.Name = "Maps"
	mapsFolder.Parent = Workspace

	local map = Instance.new("Model")
	map.Name = "Map1"
	map.Parent = mapsFolder

	makePart(
		map,
		"Floor",
		Vector3.new(200, 2, 200),
		MAP_ORIGIN + Vector3.new(0, -1, 0),
		Color3.fromRGB(106, 127, 63),
		Enum.Material.Grass
	)

	local obstaclesFolder = Instance.new("Folder")
	obstaclesFolder.Name = "Obstacles"
	obstaclesFolder.Parent = map

	local obstacleOffsets = {
		Vector3.new(-60, 0, -60),
		Vector3.new(-60, 0, 60),
		Vector3.new(60, 0, -60),
		Vector3.new(60, 0, 60),
		Vector3.new(0, 0, -80),
		Vector3.new(0, 0, 80),
		Vector3.new(-80, 0, 0),
		Vector3.new(80, 0, 0),
	}

	for i, offset in obstacleOffsets do
		makePart(
			obstaclesFolder,
			`Obstacle_{i}`,
			Vector3.new(8, 10, 8),
			MAP_ORIGIN + offset + Vector3.new(0, 5, 0),
			Color3.fromRGB(163, 162, 165),
			Enum.Material.SmoothPlastic
		)
	end

	local hiderSpawnsFolder = Instance.new("Folder")
	hiderSpawnsFolder.Name = "HiderSpawns"
	hiderSpawnsFolder.Parent = map

	local hiderOffsets = {
		Vector3.new(-70, 0, -70),
		Vector3.new(-70, 0, 70),
		Vector3.new(70, 0, -70),
		Vector3.new(70, 0, 70),
		Vector3.new(-40, 0, -40),
		Vector3.new(-40, 0, 40),
		Vector3.new(40, 0, -40),
		Vector3.new(40, 0, 40),
	}

	for i, offset in hiderOffsets do
		local pos = MAP_ORIGIN + offset + Vector3.new(0, 2, 0)
		local part = makePart(
			hiderSpawnsFolder,
			`HiderSpawn_{i}`,
			Vector3.new(2, 0.5, 2),
			pos,
			Color3.fromRGB(0, 200, 0),
			Enum.Material.Neon
		)
		part.CanCollide = false
		part.Transparency = 0.8
		table.insert(hiderSpawnPositions, pos)
	end

	local seekerSpawnsFolder = Instance.new("Folder")
	seekerSpawnsFolder.Name = "SeekerSpawns"
	seekerSpawnsFolder.Parent = map

	local seekerOffsets = {
		Vector3.new(-10, 0, 0),
		Vector3.new(10, 0, 0),
	}

	for i, offset in seekerOffsets do
		local pos = MAP_ORIGIN + offset + Vector3.new(0, 2, 0)
		local part = makePart(
			seekerSpawnsFolder,
			`SeekerSpawn_{i}`,
			Vector3.new(2, 0.5, 2),
			pos,
			Color3.fromRGB(200, 0, 0),
			Enum.Material.Neon
		)
		part.CanCollide = false
		part.Transparency = 0.8
		table.insert(seekerSpawnPositions, pos)
	end

	return map
end

-- Remove the default Baseplate and SpawnLocation Roblox puts in every new place
for _, child in Workspace:GetChildren() do
	if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

buildLobby()
currentMap = buildMap1()

function MapService.getLobbySpawn(): Vector3
	return LOBBY_ORIGIN + Vector3.new(0, 3, 0)
end

function MapService.getCurrentMap(): Model
	return currentMap
end

function MapService.getHiderSpawns(): { Vector3 }
	return hiderSpawnPositions
end

function MapService.getSeekerSpawns(): { Vector3 }
	return seekerSpawnPositions
end

function MapService.teleportPlayerTo(player: Player, position: Vector3)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(CFrame.new(position))
end

return MapService
