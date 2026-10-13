--!strict
-- Pure combat decisions shared with the test runner. Clients never choose a target.
local CombatRules = {}

export type Point = { x: number, y: number, z: number }
export type HuntState = {
	active: boolean, defeated: { [string]: boolean },
	owned: { [string]: boolean }?, equipped: string?,
	equipRevision: number?,
}
export type FoeDefinition = {
	id: string,
	name: string,
	position: Point,
	maxHealth: number,
	slamDamage: number,
	slamRadius: number,
	windup: number,
	boss: boolean,
}

CombatRules.meleeDamage = 10
CombatRules.playerMaxHealth = 100
CombatRules.meleeRange = 8
CombatRules.meleeCooldown = 0.6
CombatRules.petDamage = 18
CombatRules.petRange = 18
CombatRules.petCooldown = 3.2
CombatRules.petWindup = 0.3
CombatRules.aggroRange = 22
CombatRules.rewardRange = 40
CombatRules.slamCooldown = 2.4
CombatRules.firstSlamDelay = 0.8
CombatRules.respawnDelay = 6
CombatRules.encounterResetDelay = 10
CombatRules.maxGroupSize = 4
CombatRules.groupHealthPerPlayer = 0.65
CombatRules.bossBurstRadius = 10
CombatRules.slamHeightTolerance = 8
CombatRules.groundHeight = 4.1

local foes: { FoeDefinition } = {
	{
		id = "moss", name = "Bramble Sprout", position = { x = -45, y = 7, z = -17 },
		maxHealth = 140, slamDamage = 12, slamRadius = 5, windup = 0.9, boss = false,
	},
	{
		id = "river", name = "Reed Guardian", position = { x = 0, y = 7, z = -57 },
		maxHealth = 200, slamDamage = 16, slamRadius = 5, windup = 1.0, boss = false,
	},
	{
		id = "ruins", name = "The Hollow Crown", position = { x = 65, y = 8, z = -72 },
		maxHealth = 600, slamDamage = 22, slamRadius = 7, windup = 1.2, boss = true,
	},
}
local knownIds: { [string]: boolean } = {}
for _, foe in foes do
	knownIds[foe.id] = true
	table.freeze(foe.position)
	table.freeze(foe)
end
CombatRules.foes = table.freeze(foes)

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function CombatRules.distanceSquared(a: Point, b: Point): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return dx * dx + dy * dy + dz * dz
end

function CombatRules.inRange(a: Point, b: Point, radius: number): boolean
	local squared = CombatRules.distanceSquared(a, b)
	return finite(radius) and radius >= 0 and finite(squared) and squared <= radius * radius
end

function CombatRules.cooldownReady(now: number, previous: number?, cooldown: number): boolean
	if not finite(now) or not finite(cooldown) or cooldown < 0 then
		return false
	end
	if previous == nil then
		return true
	end
	return finite(previous) and now >= previous and now >= previous + cooldown
end

-- Companions are collection choices: spending shells never buys stronger combat.
function CombatRules.canBond(state: HuntState?): boolean
	if state == nil or state.owned == nil or state.equipped == nil then
		return false
	end
	local id = state.equipped
	return (id == "mosswolf" or id == "emberfox" or id == "tidecub") and state.owned[id] == true
end

function CombatRules.scaledHealth(base: number, participants: number): number
	local count = math.clamp(math.floor(participants), 1, CombatRules.maxGroupSize)
	return math.floor(base * (1 + CombatRules.groupHealthPerPlayer * (count - 1)) + 0.5)
end

function CombatRules.attackPattern(definition: FoeDefinition, sequence: number)
	local centered = definition.boss and sequence % 2 == 0
	return {
		centered = centered,
		radius = if centered then CombatRules.bossBurstRadius else definition.slamRadius,
		windup = definition.windup,
		damage = definition.slamDamage,
	}
end

function CombatRules.eligible(state: HuntState?, alive: boolean, foeId: string): boolean
	return alive and state ~= nil and state.active == true
		and knownIds[foeId] == true and state.defeated[foeId] ~= true
end

function CombatRules.canReward(
	state: HuntState?, alive: boolean, connected: boolean, contributed: boolean,
	foeId: string, playerPosition: Point, foePosition: Point
): boolean
	return connected and contributed and CombatRules.eligible(state, alive, foeId)
		and CombatRules.inRange(playerPosition, foePosition, CombatRules.rewardRange)
end

-- Slams hit a ground disk, with a height limit so distant platforms are safe.
function CombatRules.inSlam(playerPosition: Point, center: Point, radius: number): boolean
	local dx, dz = playerPosition.x - center.x, playerPosition.z - center.z
	local planarSquared = dx * dx + dz * dz
	local height = math.abs(playerPosition.y - center.y)
	return finite(radius) and radius >= 0 and finite(planarSquared) and finite(height)
		and planarSquared <= radius * radius and height <= CombatRules.slamHeightTolerance
end

return table.freeze(CombatRules)
