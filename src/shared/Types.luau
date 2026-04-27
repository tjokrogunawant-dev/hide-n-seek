--!strict

export type Role = "Seeker" | "Hider" | "Frozen" | "Spectator"
export type RoundState = "Lobby" | "Hiding" | "Seeking" | "Results"

export type PlayerState = {
	role: Role,
	isFrozen: boolean,
}

return {}
