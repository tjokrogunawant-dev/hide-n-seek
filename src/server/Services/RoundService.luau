--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type RoundState = Types.RoundState

local RoundService = {}

local state: RoundState = "Lobby"

local function setState(newState: RoundState)
	state = newState
	Remotes.RoundStateChanged:FireAllClients(newState)
	print(`[RoundService] State → {newState}`)
end

local function broadcastTimer(seconds: number)
	Remotes.TimerUpdate:FireAllClients(seconds)
end

local function countdown(duration: number)
	for remaining = duration, 1, -1 do
		broadcastTimer(remaining)
		task.wait(1)
	end
	broadcastTimer(0)
end

local function waitForPlayers()
	while #Players:GetPlayers() < Constants.MIN_PLAYERS do
		task.wait(1)
	end
end

local function runRound()
	-- Hiding phase
	setState("Hiding")
	countdown(Constants.HIDING_DURATION)

	-- Seeking phase
	setState("Seeking")
	countdown(Constants.SEEKING_DURATION)

	-- Results phase
	setState("Results")
	Remotes.RoundResults:FireAllClients("Hiders") -- default winner; overridden by TaggingService later
	countdown(Constants.INTERMISSION_DURATION)
end

function RoundService.getState(): RoundState
	return state
end

function RoundService.forceEndSeeking()
	-- Called by TaggingService when all hiders are frozen
	state = "Results"
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
