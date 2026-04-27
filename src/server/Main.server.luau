--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes)
require(script.Parent.Services.MapService)

local RoundService = require(script.Parent.Services.RoundService)

print("Server started")

RoundService.start()
