--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes)
require(script.Parent.Services.MapService)
require(script.Parent.Services.RoleService)

local RoundService = require(script.Parent.Services.RoundService)

print("Server started")

RoundService.start()
