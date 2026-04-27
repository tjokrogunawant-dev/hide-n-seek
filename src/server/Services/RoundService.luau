--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type RoundState = Types.RoundState

local RoundService = {}

local state: RoundState = "Lobby"
local pendingWinner: string = "Hiders"

local stateChangedEvent = Instance.new("BindableEvent")
RoundService.StateChanged = stateChangedEvent.Event

local function setState(newState: RoundState)
	state = newState
	Remotes.RoundStateChanged:FireAllClients(newState)
	stateChangedEvent:Fire(newState)
	print(`[RoundService] State → {newState}`)
end

local function broadcastTimer(seconds: number)
	Remotes.TimerUpdate:FireAllClients(seconds)
end

local function waitForPlayers()
	-- Wait until minimum players are present
	while #Players:GetPlayers() < Constants.MIN_PLAYERS do
		task.wait(1)
	end
	-- Countdown to give more players time to join
	print(`[RoundService] {Constants.MIN_PLAYERS} players reached, starting lobby countdown`)
	for remaining = Constants.LOBBY_WAIT_DURATION, 1, -1 do
		-- Reset countdown if player count drops below minimum
		if #Players:GetPlayers() < Constants.MIN_PLAYERS then
			print("[RoundService] Player left during countdown, resetting")
			waitForPlayers()
			return
		end
		broadcastTimer(remaining)
		task.wait(1)
	end
	broadcastTimer(0)
end

local function runRound()
	-- Hiding phase
	setState("Hiding")
	for remaining = Constants.HIDING_DURATION, 1, -1 do
		broadcastTimer(remaining)
		task.wait(1)
	end
	broadcastTimer(0)

	-- Seeking phase — exits early if forceEndSeeking() is called
	setState("Seeking")
	for remaining = Constants.SEEKING_DURATION, 1, -1 do
		if state ~= "Seeking" then
			break
		end
		broadcastTimer(remaining)
		task.wait(1)
	end
	broadcastTimer(0)

	-- Results phase
	setState("Results")
	Remotes.RoundResults:FireAllClients(pendingWinner)
	pendingWinner = "Hiders" -- reset for next round
	for remaining = Constants.INTERMISSION_DURATION, 1, -1 do
		broadcastTimer(remaining)
		task.wait(1)
	end
	broadcastTimer(0)
end

function RoundService.getState(): RoundState
	return state
end

function RoundService.forceEndSeeking(winner: string?)
	pendingWinner = winner or "Hiders"
	state = "Results" -- seeking countdown detects this and breaks
end

function RoundService.start()
	task.spawn(function()
		while true do
			setState("Lobby")
			waitForPlayers()
			runRound()
		end
	end)
end

return RoundService
