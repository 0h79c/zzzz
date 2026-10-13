--!strict
-- Session progression. Only the server awards kills; this module accepts no reward amounts.
local Progression = {}

export type Profile = { coins: number, xp: number, level: number }
export type Snapshot = { coins: number, xp: number, level: number, nextLevelXp: number, maxLevel: number }
export type Reward = { coins: number, xp: number }

Progression.maxLevel = 40
Progression.maxCoins = 2147483647

local rewards: { [string]: Reward } = {
	boar = { coins = 4, xp = 8 },
	sprout = { coins = 5, xp = 10 },
	reed = { coins = 6, xp = 12 },
	ancient = { coins = 25, xp = 45 },
}
for _, reward in rewards do table.freeze(reward) end
Progression.rewards = table.freeze(rewards)

local function integer(value: any, minimum: number, maximum: number): boolean
	return type(value) == "number" and value == value and value >= minimum and value <= maximum
		and value % 1 == 0
end

local function threshold(level: number): number
	local offset = level - 1
	return 60 + 20 * offset + 5 * offset * offset
end

function Progression.xpToNext(level: any): number?
	if not integer(level, 1, Progression.maxLevel) then return nil end
	return if level == Progression.maxLevel then 0 else threshold(level)
end

local function validProfile(profile: any): boolean
	if type(profile) ~= "table" or not integer(profile.level, 1, Progression.maxLevel)
		or not integer(profile.coins, 0, Progression.maxCoins) then return false end
	local maximumXp = if profile.level == Progression.maxLevel then 0 else threshold(profile.level) - 1
	return integer(profile.xp, 0, maximumXp)
end

function Progression.new(): Profile
	return { coins = 0, xp = 0, level = 1 }
end

-- XP is the remainder toward the next level. The level cap consumes further XP.
-- Foe health, name, and caller-supplied reward fields cannot change this catalog.
function Progression.award(profile: any, definition: any): (number?, string?)
	if not validProfile(profile) then return nil, "Invalid progression profile." end
	if type(definition) ~= "table" or type(definition.kind) ~= "string" or type(definition.boss) ~= "boolean" then
		return nil, "Invalid foe definition."
	end
	local kind: string = definition.kind
	local reward = rewards[kind]
	if reward == nil or definition.boss ~= (kind == "ancient") then return nil, "Unknown foe reward." end
	local level: number = profile.level
	local xp: number = if level == Progression.maxLevel then 0 else profile.xp + reward.xp
	local previousLevel = level
	-- The loop has a fixed bound even if this catalog later gains larger rewards.
	for _ = 1, Progression.maxLevel - 1 do
		if level == Progression.maxLevel or xp < threshold(level) then break end
		xp -= threshold(level)
		level += 1
	end
	profile.level = level
	profile.xp = if level == Progression.maxLevel then 0 else xp
	profile.coins = math.min(profile.coins + reward.coins, Progression.maxCoins)
	return level - previousLevel, nil
end

function Progression.snapshot(profile: any): (Snapshot?, string?)
	if not validProfile(profile) then return nil, "Invalid progression profile." end
	return {
		coins = profile.coins,
		xp = profile.xp,
		level = profile.level,
		nextLevelXp = if profile.level == Progression.maxLevel then 0 else threshold(profile.level),
		maxLevel = Progression.maxLevel,
	}, nil
end

return table.freeze(Progression)
