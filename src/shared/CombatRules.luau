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
	meleeDamage: number,
	slamDamage: number,
	slamRadius: number,
	windup: number,
	boss: boolean,
	kind: string,
	bounty: boolean,
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
CombatRules.slamCooldown = 5
CombatRules.firstSlamDelay = 2.8
CombatRules.patrolRadius = 12
CombatRules.leashRadius = 28
CombatRules.patrolSpeed = 3.5
CombatRules.chaseSpeed = 7
CombatRules.enemyMeleeRange = 5
CombatRules.enemyMeleeWindup = 0.65
CombatRules.enemyMeleeRecover = 0.28
CombatRules.enemyMeleeCooldown = 1.2
CombatRules.bossMeleeCooldown = 1.5
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
		maxHealth = 140, meleeDamage = 8, slamDamage = 12, slamRadius = 5, windup = 0.9, boss = false, kind = "sprout", bounty = true,
	},
	{
		id = "river", name = "Reed Guardian", position = { x = 0, y = 7, z = -57 },
		maxHealth = 200, meleeDamage = 10, slamDamage = 16, slamRadius = 5, windup = 1.0, boss = false, kind = "reed", bounty = true,
	},
	{
		id = "ruins", name = "The Hollow Crown", position = { x = 65, y = 8, z = -72 },
		maxHealth = 600, meleeDamage = 12, slamDamage = 22, slamRadius = 7, windup = 1.2, boss = true, kind = "ancient", bounty = true,
	},
}
local ambient = {
	{ id = "brush01", name = "Bramble Forager", kind = "sprout", x = -62, z = 28, health = 80, damage = 6 },
	{ id = "brush02", name = "Brush Boar", kind = "boar", x = -65, z = -66, health = 75, damage = 6 },
	{ id = "brush03", name = "Brush Boar", kind = "boar", x = 38, z = -28, health = 75, damage = 6 },
	{ id = "brush04", name = "Bramble Forager", kind = "sprout", x = 70, z = 33, health = 80, damage = 6 },
	{ id = "brush05", name = "Reed Warden", kind = "reed", x = -40, z = -100, health = 100, damage = 7 },
	{ id = "brush06", name = "Reed Warden", kind = "reed", x = 50, z = -116, health = 100, damage = 7 },
	-- The outer routes add places to hunt without making the first expedition
	-- longer. These creatures use the same readable four species and attack rules.
	{ id = "forest01", name = "Bramble Forager", kind = "sprout", x = -125, z = -20, health = 80, damage = 6 },
	{ id = "forest02", name = "Brush Boar", kind = "boar", x = -192, z = -52, health = 75, damage = 6 },
	{ id = "forest03", name = "Brush Boar", kind = "boar", x = -207, z = -145, health = 75, damage = 6 },
	{ id = "forest04", name = "Bramble Forager", kind = "sprout", x = -119, z = -147, health = 80, damage = 6 },
	{ id = "marsh01", name = "Reed Warden", kind = "reed", x = -92, z = -218, health = 100, damage = 7 },
	{ id = "marsh02", name = "Reed Warden", kind = "reed", x = -12, z = -243, health = 100, damage = 7 },
	{ id = "marsh03", name = "Reed Warden", kind = "reed", x = 70, z = -229, health = 100, damage = 7 },
	{ id = "marsh04", name = "Reed Warden", kind = "reed", x = 180, z = -258, health = 100, damage = 7 },
	{ id = "outskirts01", name = "Bramble Forager", kind = "sprout", x = 154, z = -140, health = 80, damage = 6 },
	{ id = "outskirts02", name = "Brush Boar", kind = "boar", x = 220, z = -70, health = 75, damage = 6 },
	{ id = "outskirts03", name = "Bramble Forager", kind = "sprout", x = 210, z = 37, health = 80, damage = 6 },
	{ id = "meadow01", name = "Brush Boar", kind = "boar", x = 175, z = 132, health = 75, damage = 6 },
	{ id = "meadow02", name = "Bramble Forager", kind = "sprout", x = 85, z = 188, health = 80, damage = 6 },
	{ id = "meadow03", name = "Bramble Forager", kind = "sprout", x = -24, z = 187, health = 80, damage = 6 },
	{ id = "meadow04", name = "Brush Boar", kind = "boar", x = -150, z = 166, health = 75, damage = 6 },
	{ id = "forest05", name = "Brush Boar", kind = "boar", x = -219, z = 83, health = 75, damage = 6 },
}
for _, spawn in ambient do
	table.insert(foes, {
		id = spawn.id, name = spawn.name, position = { x = spawn.x, y = 7, z = spawn.z },
		kind = spawn.kind, bounty = false, boss = false, maxHealth = spawn.health, meleeDamage = spawn.damage,
		slamDamage = 0, slamRadius = 0, windup = 0.9,
	})
end
local knownIds: { [string]: FoeDefinition } = {}
for _, foe in foes do
	knownIds[foe.id] = foe
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

-- A committed swing checks a short front arc, not a radius around the enemy.
function CombatRules.inEnemyMelee(target: Point, origin: Point, facing: Point): boolean
	if not CombatRules.inRange(target, origin, CombatRules.enemyMeleeRange) then return false end
	local dx, dz = target.x - origin.x, target.z - origin.z
	local distance = math.sqrt(dx * dx + dz * dz)
	local length = math.sqrt(facing.x * facing.x + facing.z * facing.z)
	return finite(length) and length > 0 and (distance < 0.01 or (dx * facing.x + dz * facing.z) / (distance * length) >= 0.25)
end

function CombatRules.canTakeDamage(now: number, dodgeUntil: any): boolean
	return finite(now) and (typeof(dodgeUntil) ~= "number" or not finite(dodgeUntil) or now >= dodgeUntil)
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
	local definition = knownIds[foeId]
	return alive and state ~= nil and definition ~= nil
		and (not definition.bounty or (state.active == true and state.defeated[foeId] ~= true))
end

function CombatRules.canReward(
	state: HuntState?, alive: boolean, connected: boolean, contributed: boolean,
	foeId: string, playerPosition: Point, foePosition: Point
): boolean
	local definition = knownIds[foeId]
	return definition ~= nil and definition.bounty and connected and contributed and CombatRules.eligible(state, alive, foeId)
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
