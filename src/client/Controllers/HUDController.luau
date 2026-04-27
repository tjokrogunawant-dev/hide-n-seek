--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Constants = require(ReplicatedStorage.Shared.Constants)

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function frame(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2,
	bg: Color3,
	alpha: number
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = bg
	f.BackgroundTransparency = alpha
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(
	parent: Instance,
	text: string,
	color: Color3,
	size: UDim2,
	pos: UDim2,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.BorderSizePixel = 0
	l.Parent = parent
	return l
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function formatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

-- ── Root ScreenGui ────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "GameHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- ── 1. Timer bar (top center) ─────────────────────────────────────────────────

local timerBar = frame(
	gui,
	"TimerBar",
	UDim2.new(0, 260, 0, 64),
	UDim2.new(0.5, -130, 0, 12),
	Color3.fromRGB(0, 0, 0),
	0.45
)
corner(timerBar, 10)

local stateLabel = label(
	timerBar,
	"LOBBY",
	Color3.fromRGB(255, 215, 60),
	UDim2.new(1, -16, 0.42, 0),
	UDim2.new(0, 8, 0, 0),
	true
)

local timerLabel = label(
	timerBar,
	"",
	Color3.fromRGB(255, 255, 255),
	UDim2.new(1, -16, 0.52, 0),
	UDim2.new(0, 8, 0.44, 0),
	false
)

-- ── 2. Role badge (bottom center) ────────────────────────────────────────────

local roleBadge = frame(
	gui,
	"RoleBadge",
	UDim2.new(0, 300, 0, 52),
	UDim2.new(0.5, -150, 1, -72),
	Color3.fromRGB(0, 0, 0),
	0.45
)
corner(roleBadge, 10)
roleBadge.Visible = false

local roleLabel = label(
	roleBadge,
	"",
	Color3.fromRGB(255, 255, 255),
	UDim2.new(1, -16, 1, -8),
	UDim2.new(0, 8, 0, 4),
	true
)

-- ── 3. Notification flash (center) ───────────────────────────────────────────

local notifLabel = label(
	gui,
	"",
	Color3.fromRGB(255, 255, 255),
	UDim2.new(0.6, 0, 0.1, 0),
	UDim2.new(0.2, 0, 0.38, 0),
	true
)
notifLabel.Name = "NotifLabel"
notifLabel.TextStrokeTransparency = 0.4
notifLabel.Visible = false

local notifThread: thread? = nil

local function showNotif(text: string, color: Color3, duration: number?)
	duration = duration or 2.5
	if notifThread then
		task.cancel(notifThread)
	end
	notifLabel.Text = text
	notifLabel.TextColor3 = color
	notifLabel.TextTransparency = 0
	notifLabel.Visible = true
	notifThread = task.delay(duration, function()
		TweenService:Create(notifLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		notifLabel.Visible = false
	end)
end

-- ── 4. Frozen overlay ─────────────────────────────────────────────────────────

local frozenOverlay = frame(
	gui,
	"FrozenOverlay",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(20, 60, 140),
	0.6
)
frozenOverlay.Visible = false

label(
	frozenOverlay,
	"YOU ARE FROZEN",
	Color3.fromRGB(180, 230, 255),
	UDim2.new(0.8, 0, 0.14, 0),
	UDim2.new(0.1, 0, 0.28, 0),
	true
)

label(
	frozenOverlay,
	"Stand next to a teammate to be unfrozen",
	Color3.fromRGB(160, 210, 255),
	UDim2.new(0.7, 0, 0.07, 0),
	UDim2.new(0.15, 0, 0.44, 0),
	false
)

-- Unfreeze progress bar
local unfreezeBarBg = frame(
	frozenOverlay,
	"UnfreezeBarBg",
	UDim2.new(0.44, 0, 0.035, 0),
	UDim2.new(0.28, 0, 0.54, 0),
	Color3.fromRGB(20, 30, 80),
	0.3
)
corner(unfreezeBarBg, 6)
unfreezeBarBg.Visible = false

local unfreezeBar = frame(
	unfreezeBarBg,
	"Fill",
	UDim2.new(0, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(80, 200, 255),
	0
)
corner(unfreezeBar, 6)

local unfreezeText = label(
	frozenOverlay,
	"UNFREEZING...",
	Color3.fromRGB(120, 220, 255),
	UDim2.new(0.44, 0, 0.05, 0),
	UDim2.new(0.28, 0, 0.59, 0),
	true
)
unfreezeText.Visible = false

local unfreezeTween: Tween? = nil

local function startUnfreezeProgress()
	unfreezeBarBg.Visible = true
	unfreezeText.Visible = true
	unfreezeBar.Size = UDim2.new(0, 0, 1, 0)
	if unfreezeTween then
		unfreezeTween:Cancel()
	end
	unfreezeTween = TweenService:Create(
		unfreezeBar,
		TweenInfo.new(Constants.UNFREEZE_TOUCH_DURATION, Enum.EasingStyle.Linear),
		{ Size = UDim2.new(1, 0, 1, 0) }
	)
	unfreezeTween:Play()
end

local function cancelUnfreezeProgress()
	if unfreezeTween then
		unfreezeTween:Cancel()
		unfreezeTween = nil
	end
	unfreezeBarBg.Visible = false
	unfreezeText.Visible = false
	unfreezeBar.Size = UDim2.new(0, 0, 1, 0)
end

-- ── 5. Results screen ─────────────────────────────────────────────────────────

local resultsScreen = frame(
	gui,
	"ResultsScreen",
	UDim2.new(1, 0, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(0, 0, 0),
	0.65
)
resultsScreen.Visible = false

local resultsTitle = label(
	resultsScreen,
	"",
	Color3.fromRGB(255, 215, 50),
	UDim2.new(0.8, 0, 0.18, 0),
	UDim2.new(0.1, 0, 0.32, 0),
	true
)

label(
	resultsScreen,
	"New round starting soon...",
	Color3.fromRGB(180, 180, 180),
	UDim2.new(0.6, 0, 0.07, 0),
	UDim2.new(0.2, 0, 0.54, 0),
	false
)

-- ── Role helpers ──────────────────────────────────────────────────────────────

local ROLE_COLORS = {
	Seeker = Color3.fromRGB(220, 60, 60),
	Hider = Color3.fromRGB(60, 180, 60),
	Frozen = Color3.fromRGB(60, 150, 220),
	Spectator = Color3.fromRGB(140, 140, 140),
}

local function setRoleBadge(role: string)
	roleBadge.Visible = true
	roleBadge.BackgroundColor3 = ROLE_COLORS[role] or Color3.fromRGB(100, 100, 100)
	roleBadge.BackgroundTransparency = 0.25
	roleLabel.Text = "YOU ARE A " .. role:upper()
end

-- ── Remote listeners ──────────────────────────────────────────────────────────

Remotes.RoundStateChanged.OnClientEvent:Connect(function(newState: string)
	-- Update state label
	local stateText = {
		Lobby = "WAITING FOR PLAYERS",
		Hiding = "HIDING PHASE",
		Seeking = "SEEKING PHASE",
		Results = "ROUND OVER",
	}
	stateLabel.Text = stateText[newState] or newState:upper()

	if newState == "Lobby" then
		timerLabel.Text = ""
		roleBadge.Visible = false
		frozenOverlay.Visible = false
		resultsScreen.Visible = false
		cancelUnfreezeProgress()
	elseif newState == "Results" then
		frozenOverlay.Visible = false
		cancelUnfreezeProgress()
	elseif newState == "Hiding" then
		resultsScreen.Visible = false
	end
end)

Remotes.TimerUpdate.OnClientEvent:Connect(function(seconds: number)
	timerLabel.Text = formatTime(seconds)
end)

Remotes.RoleAssigned.OnClientEvent:Connect(function(role: string)
	setRoleBadge(role)
end)

Remotes.PlayerFrozen.OnClientEvent:Connect(function(frozenPlayer: Player)
	if frozenPlayer == LocalPlayer then
		frozenOverlay.Visible = true
		showNotif("YOU HAVE BEEN FROZEN!", Color3.fromRGB(100, 200, 255))
		setRoleBadge("Frozen")
	else
		showNotif(frozenPlayer.Name .. " was frozen!", Color3.fromRGB(180, 220, 255), 2)
	end
end)

Remotes.PlayerUnfrozen.OnClientEvent:Connect(function(unfrozenPlayer: Player)
	if unfrozenPlayer == LocalPlayer then
		frozenOverlay.Visible = false
		cancelUnfreezeProgress()
		showNotif("YOU ARE FREE!", Color3.fromRGB(100, 255, 150))
		setRoleBadge("Hider")
	else
		showNotif(unfrozenPlayer.Name .. " was unfrozen!", Color3.fromRGB(100, 255, 150), 2)
	end
end)

Remotes.UnfreezeStarted.OnClientEvent:Connect(function()
	startUnfreezeProgress()
end)

Remotes.UnfreezeCancelled.OnClientEvent:Connect(function()
	cancelUnfreezeProgress()
end)

Remotes.RoundResults.OnClientEvent:Connect(function(winner: string)
	if winner == "Seekers" then
		resultsTitle.Text = "SEEKERS WIN!"
		resultsTitle.TextColor3 = Color3.fromRGB(220, 80, 80)
	else
		resultsTitle.Text = "HIDERS WIN!"
		resultsTitle.TextColor3 = Color3.fromRGB(80, 220, 100)
	end
	resultsScreen.Visible = true
end)
