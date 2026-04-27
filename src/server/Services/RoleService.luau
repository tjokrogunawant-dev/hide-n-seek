--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local MapService = require(script.Parent.MapService)
local RoundService = require(script.Parent.RoundService)

type Role = Types.Role

local RoleService = {}

local playerRoles: { [Player]: Role } = {}

local function setWalkSpeed(player: Player, speed: number)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = speed
end

local function assignRoles()
	task.wait(0.1) -- let characters finish loading before teleporting
	local allPlayers = Players:GetPlayers()
	local count = #allPlayers
	print(`[RoleService] assignRoles called, {count} players`)

	local seekerCount = math.ceil(count * Constants.SEEKER_RATIO)

	-- Fisher-Yates shuffle
	local shuffled = table.clone(allPlayers)
	for i = count, 2, -1 do
		local j = math.random(i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	local hiderSpawns = MapService.getHiderSpawns()
	local seekerSpawns = MapService.getSeekerSpawns()
	print(`[RoleService] hiderSpawns={#hiderSpawns} seekerSpawns={#seekerSpawns}`)

	for i, player in shuffled do
		local role: Role = if i <= seekerCount then "Seeker" else "Hider"
		local spawns = if role == "Seeker" then seekerSpawns else hiderSpawns
		local speed = if role == "Seeker"
			then Constants.FROZEN_WALKSPEED
			else Constants.HIDER_WALKSPEED

		playerRoles[player] = role

		local spawnPos = spawns[((i - 1) % #spawns) + 1]
		print(
			`[RoleService] {player.Name} → {role}, teleporting to {spawnPos}, char={player.Character ~= nil}`
		)
		MapService.teleportPlayerTo(player, spawnPos)
		setWalkSpeed(player, speed)
		Remotes.RoleAssigned:FireClient(player, role)
	end
end

local function releaseSeekers()
	for player, role in playerRoles do
		if role == "Seeker" then
			setWalkSpeed(player, Constants.SEEKER_WALKSPEED)
		end
	end
end

local function returnToLobby()
	local lobbySpawn = MapService.getLobbySpawn()
	for player in playerRoles do
		setWalkSpeed(player, Constants.HIDER_WALKSPEED)
		MapService.teleportPlayerTo(player, lobbySpawn)
	end
	table.clear(playerRoles)
end

function RoleService.getRole(player: Player): Role?
	return playerRoles[player]
end

function RoleService.setRole(player: Player, role: Role)
	playerRoles[player] = role
end

function RoleService.getAllRoles(): { [Player]: Role }
	return playerRoles
end

RoundService.StateChanged:Connect(function(newState: string)
	if newState == "Hiding" then
		assignRoles()
	elseif newState == "Seeking" then
		releaseSeekers()
	elseif newState == "Results" then
		returnToLobby()
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerRoles[player] = nil
end)

return RoleService
