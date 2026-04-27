--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RoleService = require(script.Parent.RoleService)
local RoundService = require(script.Parent.RoundService)

type Role = Types.Role

local TaggingService = {}

local connections: { RBXScriptConnection } = {}
local activeTouches: { [Player]: { [Player]: boolean } } = {}
local freezeDebounce: { [Player]: boolean } = {}

local UNFREEZE_DISTANCE = 8

local function getPlayerFromPart(part: BasePart): Player?
	local character = part.Parent
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

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

local function applyFreezeEffect(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "FreezeHighlight"
	highlight.FillColor = Color3.fromRGB(100, 200, 255)
	highlight.OutlineColor = Color3.fromRGB(0, 150, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Parent = character
end

local function removeFreezeEffect(character: Model)
	local highlight = character:FindFirstChild("FreezeHighlight")
	if highlight then
		highlight:Destroy()
	end
end

local function checkWinCondition()
	for _, role in RoleService.getAllRoles() do
		if role == "Hider" then
			return -- at least one free hider remains
		end
	end
	-- All hiders are frozen — seekers win
	RoundService.forceEndSeeking("Seekers")
end

local function unfreezePlayer(frozen: Player)
	if RoleService.getRole(frozen) ~= "Frozen" then
		return
	end

	RoleService.setRole(frozen, "Hider")
	setWalkSpeed(frozen, Constants.HIDER_WALKSPEED)
	freezeDebounce[frozen] = nil

	local character = frozen.Character
	if character then
		removeFreezeEffect(character)
	end

	Remotes.PlayerUnfrozen:FireAllClients(frozen)
	print(`[TaggingService] {frozen.Name} unfrozen`)
end

local function freezePlayer(hider: Player)
	if freezeDebounce[hider] then
		return
	end
	if RoleService.getRole(hider) ~= "Hider" then
		return
	end

	freezeDebounce[hider] = true
	RoleService.setRole(hider, "Frozen")
	setWalkSpeed(hider, Constants.FROZEN_WALKSPEED)

	local character = hider.Character
	if character then
		applyFreezeEffect(character)
	end

	Remotes.PlayerFrozen:FireAllClients(hider)
	print(`[TaggingService] {hider.Name} frozen`)

	checkWinCondition()
end

local function onSeekerPartTouched(seeker: Player, hit: BasePart)
	if RoundService.getState() ~= "Seeking" then
		return
	end
	local hitPlayer = getPlayerFromPart(hit)
	if not hitPlayer or hitPlayer == seeker then
		return
	end
	freezePlayer(hitPlayer)
end

local function onHiderPartTouched(hider: Player, hit: BasePart)
	if RoundService.getState() ~= "Seeking" then
		return
	end
	local hitPlayer = getPlayerFromPart(hit)
	if not hitPlayer or hitPlayer == hider then
		return
	end
	if RoleService.getRole(hitPlayer) ~= "Frozen" then
		return
	end

	-- Track this unfreeze attempt (deduplicated per pair)
	if not activeTouches[hitPlayer] then
		activeTouches[hitPlayer] = {}
	end
	if activeTouches[hitPlayer][hider] then
		return
	end
	activeTouches[hitPlayer][hider] = true

	task.delay(Constants.UNFREEZE_TOUCH_DURATION, function()
		if not activeTouches[hitPlayer] or not activeTouches[hitPlayer][hider] then
			return
		end
		activeTouches[hitPlayer][hider] = nil

		-- Proximity check: still close enough after the delay?
		local hiderChar = hider.Character
		local frozenChar = hitPlayer.Character
		if not hiderChar or not frozenChar then
			return
		end
		local hiderRoot = hiderChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local frozenRoot = frozenChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hiderRoot or not frozenRoot then
			return
		end
		if (hiderRoot.Position - frozenRoot.Position).Magnitude <= UNFREEZE_DISTANCE then
			unfreezePlayer(hitPlayer)
		end
	end)
end

local function onHiderPartTouchEnded(hider: Player, hit: BasePart)
	local hitPlayer = getPlayerFromPart(hit)
	if not hitPlayer then
		return
	end
	if activeTouches[hitPlayer] then
		activeTouches[hitPlayer][hider] = nil
	end
end

local function connectPlayerTouches(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local role = RoleService.getRole(player)

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if role == "Seeker" then
				local conn = part.Touched:Connect(function(hit: BasePart)
					onSeekerPartTouched(player, hit)
				end)
				table.insert(connections, conn)
			elseif role == "Hider" then
				local conn = part.Touched:Connect(function(hit: BasePart)
					onHiderPartTouched(player, hit)
				end)
				table.insert(connections, conn)
				local conn2 = part.TouchEnded:Connect(function(hit: BasePart)
					onHiderPartTouchEnded(player, hit)
				end)
				table.insert(connections, conn2)
			end
		end
	end
end

local function disconnectAll()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	table.clear(activeTouches)
	table.clear(freezeDebounce)
end

RoundService.StateChanged:Connect(function(newState: string)
	if newState == "Seeking" then
		for _, player in Players:GetPlayers() do
			connectPlayerTouches(player)
		end
	elseif newState == "Results" then
		disconnectAll()
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	freezeDebounce[player] = nil
	activeTouches[player] = nil
end)

return TaggingService
