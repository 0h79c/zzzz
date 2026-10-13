--!nonstrict
-- Outgoing timing and geometric checks, not a Roblox engine simulation.
-- A moving enemy needs a real player/controller and physics to estimate incoming hits.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Rules = require("../src/shared/CombatRules")
local Dodge = require("../src/shared/DodgeRules")
local Expedition = require("../src/shared/Expedition")
local Pet = require("../src/shared/PetRules")
local Progression = require("../src/shared/Progression")

local project = serde.decode("json", fs.readFile("default.project.json"))
local walkSpeed = assert(project.tree.StarterPlayer["$properties"].CharacterWalkSpeed)
assert(walkSpeed > 0 and Rules.meleeDamage > 0 and Rules.meleeCooldown > 0)
assert(Pet.attackDamage > 0 and Pet.skillDamage > 0 and Pet.skillCooldown > 0 and Dodge.cooldown > 0)

-- Capacity lower bound: every player hit lands, pets survive and never travel.
-- Pet basic/skill clocks are treated independently here; the actual service
-- serializes windups. Therefore this optimistic bound need not be achievable.
-- It does not predict survival, playtime, or the outcome with a dead pet.
local function outgoingTime(foe, contributors, withPet)
	local remaining = Rules.scaledHealth(foe.maxHealth, contributors)
	local melee, basic, skill = 0, 0, 0
	while remaining > 0 do
		local nextMelee = melee * Rules.meleeCooldown
		local nextBasic = if withPet then basic * Pet.attackCooldown + Pet.attackWindup else math.huge
		local nextSkill = if withPet then skill * Pet.skillCooldown + Pet.skillWindup else math.huge
		local at = math.min(nextMelee, nextBasic, nextSkill)
		if math.abs(nextMelee - at) < 1e-8 then
			remaining -= Rules.meleeDamage * contributors
			melee += 1
		end
		if math.abs(nextBasic - at) < 1e-8 then
			remaining -= Pet.attackDamage * contributors
			basic += 1
		end
		if math.abs(nextSkill - at) < 1e-8 then
			remaining -= Pet.skillDamage * contributors
			skill += 1
		end
		if remaining <= 0 then return at end
	end
	error("Enemy health must be positive.")
end

print("WILDBOND BALANCE AUDIT — theoretical bounds, not measured playtime")
print("AI now patrols, chases, commits directional basic attacks, recovers and returns home. Boss specials replace basic actions; they do not execute concurrently.")
print("The old static-AoE route profiles are retired. No expected incoming damage, survival, full-hunt duration or age-group reaction model is inferred here.")
print(string.format("Player %.0fHP, walk %.1f; melee %d/%.2fs in %.1f studs.",
	Rules.playerMaxHealth, walkSpeed, Rules.meleeDamage, Rules.meleeCooldown, Rules.meleeRange))
print(string.format("Pet: %dHP, defense%d; auto basic%d/%.2fs (windup%.2fs), auto skill%d/%.2fs (windup%.2fs); revive after%.0fs continuously out of owner combat.",
	Pet.maxHealth, Pet.defense, Pet.attackDamage, Pet.attackCooldown, Pet.attackWindup,
	Pet.skillDamage, Pet.skillCooldown, Pet.skillWindup, Pet.reviveDelay))
print(string.format("Nominal attack capacity %.2f player + %.2f pet basic + %.2f pet skill = %.2f damage/s before action overlap, travel or death.",
	Rules.meleeDamage / Rules.meleeCooldown, Pet.attackDamage / Pet.attackCooldown, Pet.skillDamage / Pet.skillCooldown,
	Rules.meleeDamage / Rules.meleeCooldown + Pet.attackDamage / Pet.attackCooldown + Pet.skillDamage / Pet.skillCooldown))
print("Outgoing bounds assume independent pet clocks (actual windups serialize), ready cooldowns, perfect range/LOS, living pets and synchronized contributors. These are capacity bounds, not simulated fights.")
for _, foe in Rules.foes do
	local cooldown = if foe.boss then Rules.bossMeleeCooldown else Rules.enemyMeleeCooldown
	local period = math.max(cooldown, Rules.enemyMeleeWindup + Rules.enemyMeleeRecover)
	print(string.format("  %s — %s", foe.id, if foe.bounty then "bounty target" else "ambient enemy; session coins/XP"))
	print(string.format("  %-20s %4dHP | melee %.1fs | melee + pet %.1fs | basic %d, nominal period %.2fs, contact pressure <= %.2fHP/s, %d hits to exhaust full HP.",
		foe.name, foe.maxHealth, outgoingTime(foe, 1, false), outgoingTime(foe, 1, true),
		foe.meleeDamage, period, foe.meleeDamage / period, math.ceil(Rules.playerMaxHealth / foe.meleeDamage)))
	if foe.boss then
		for count = 2, Rules.maxGroupSize do
			print(string.format("    %d contributors: %dHP, %.1fs outgoing bound with equal pet support.",
				count, Rules.scaledHealth(foe.maxHealth, count), outgoingTime(foe, count, true)))
		end
		print(string.format("    Boss specials: first eligible at engagement + %.2fs, then %.2fs after resolution; readiness can wait for an active basic/recovery.",
			Rules.firstSlamDelay, Rules.slamCooldown))
		for sequence = 1, 2 do
			local pattern = Rules.attackPattern(foe, sequence)
			-- For a targeted disk, start at its center. For the centered burst,
			-- start at the player's melee edge. Clear ground, fixed source, no body radius.
			local escape = if pattern.centered then math.max(0, pattern.radius - Rules.meleeRange) else pattern.radius
			print(string.format("    %s: %d damage, %.1f radius, %.2fs windup; walking from %s needs >%.2fs, leaving <%.2fs reaction budget.",
				if pattern.centered then "centered burst" else "targeted circle", pattern.damage, pattern.radius,
				pattern.windup, if pattern.centered then "melee edge" else "disk center", escape / walkSpeed,
				pattern.windup - escape / walkSpeed))
		end
	end
end
print("Contact pressure is an isolated always-hit basic upper bound: no specials, dodges, chase, geometry or server tick delays. Do not add it to a special-DPS figure as if actions overlap.")

print("\nMovement and dodge feasibility — flat unobstructed geometry only:")
print(string.format("  Enemy patrol %.1f, chase %.1f; player %.1f. Player melee reaches %.1f vs enemy %.1f. Ideal spacing/kiting can avoid most basics; Studio must assess whether this trivializes fights.",
	Rules.patrolSpeed, Rules.chaseSpeed, walkSpeed, Rules.meleeRange, Rules.enemyMeleeRange))
print(string.format("  Basic aim locks during %.2fs windup; walking from contact to beyond enemy reach takes >%.2fs, leaving <%.2fs to react, before latency and obstacles.",
	Rules.enemyMeleeWindup, Rules.enemyMeleeRange / walkSpeed, Rules.enemyMeleeWindup - Rules.enemyMeleeRange / walkSpeed))
print(string.format("  Shift requests dodge: up to %.1f studs over %.2fs, up to %.2fs damage immunity, %.1fs cooldown. A wall/floor check can shorten or reject the move and end immunity early.",
	Dodge.distance, Dodge.duration, Dodge.invulnerabilityDuration, Dodge.cooldown))
print("  Request latency precedes accepted dodge. Immunity covers only the opening portion, not the whole movement; do not equate distance or cooldown with guaranteed evasion.")
print("  Basic attacks resolve faster than dodge recharges. Walking outside reach/the locked front arc must remain usable between dodges; specials cannot require an available dodge every time.")
if Rules.enemyMeleeWindup <= Rules.enemyMeleeRange / walkSpeed then
	print("  WARNING: even instant walking from contact cannot leave basic reach before nominal resolution.")
end
if Rules.chaseSpeed >= walkSpeed then
	print("  WARNING: enemy chase is as fast as player walking; the starter escape/kiting assumption needs a fresh Studio check.")
end

-- Construction geometry is useful context, never a mission-time forecast.
local worldSource = fs.readFile("src/server/WorldBuilder.luau")
local trailBlock = worldSource:match("local%s+trailPoints%s*=%s*{(.-)\n%s*}")
if trailBlock then
	local vertices = {}
	for x, y, z in trailBlock:gmatch("Vector3%.new%s*%(%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*%)") do
		table.insert(vertices, { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
	end
	if #vertices >= 2 then
		local length = 0
		for index = 2, #vertices do
			length += math.sqrt(Rules.distanceSquared(vertices[index - 1], vertices[index]))
		end
		print(string.format("\nConstruction trail: %d vertices, %.1f studs; %.1fs uninterrupted walking if following that polyline. Not a quest route or duration estimate.",
			#vertices, length, length / walkSpeed))
	else
		print("\nConstruction trail is not a numeric vertex table; geometric timing omitted.")
	end
else
	print("\nConstruction trail layout changed; geometric timing omitted.")
end

print("\nShell economy read from Expedition (alpha collection loop only):")
local spend = 0
for _, pet in Expedition.pets do
	spend += pet.cost
	print(string.format("  %s: %d shells, %d hunts from zero if bought alone; %d cumulative hunts in catalog order.",
		pet.name, pet.cost, math.ceil(pet.cost / Expedition.reward), math.ceil(spend / Expedition.reward)))
end
print("\nSession XP/coins (no persistent inventory or shop):")
for _, kind in { "boar", "sprout", "reed", "ancient" } do
	local reward = Progression.rewards[kind]
	print(string.format("  %s: %d coins + %d XP per eligible kill contribution.", kind, reward.coins, reward.xp))
end
for _, level in { 1, 2, 9, 19, 29, 39 } do
	print(string.format("  Level%d ->%d needs%d XP. Levels currently change no combat stats or class access.", level, level + 1, Progression.xpToNext(level)))
end
print("Equipment rolls, passive buffs, evolution and class resources are not live. No retention, leveling-time or Robux revenue inference is supported.")
