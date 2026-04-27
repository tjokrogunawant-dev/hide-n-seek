--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"RoundStateChanged",
	"RoleAssigned",
	"PlayerFrozen",
	"PlayerUnfrozen",
	"TimerUpdate",
	"RoundResults",
	"UnfreezeStarted",
	"UnfreezeCancelled",
}

local remotes: { [string]: RemoteEvent } = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	for _, name in REMOTE_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		remotes[name] = event
	end
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in REMOTE_NAMES do
		remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return remotes
