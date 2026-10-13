--!nonstrict
-- Deterministic outgoing/dodge model, not a Roblox engine or player telemetry test.
-- All combat/economy stats are read from the real shared modules.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Rules = require("../src/shared/CombatRules")
local Expedition = require("../src/shared/Expedition")

local worldSource = fs.readFile("src/server/WorldBuilder.luau")
local project = serde.decode("json", fs.readFile("default.project.json"))
local trailBlock = assert(worldSource:match("local trailPoints = {(.-)\n\t}"), "Trail geometry changed; review the route model.")
local vertices = {}
for x, y, z in trailBlock:gmatch("Vector3%.new%(([%d%.%-]+),%s*([%d%.%-]+),%s*([%d%.%-]+)%)") do
	table.insert(vertices, { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
end
assert(#vertices >= 2, "The model needs the real trail points.")
local trailLength = 0
for index = 2, #vertices do
	trailLength += math.sqrt(Rules.distanceSquared(vertices[index - 1], vertices[index]))
end

local walkSpeed = assert(project.tree.StarterPlayer["$properties"].CharacterWalkSpeed)
local avatarHealth = assert(Rules.playerMaxHealth)
local hold = assert(tonumber(worldSource:match("prompt%.HoldDuration%s*=%s*([%d%.]+)")), "Read the real prompt hold duration.")
local promptTime = hold * (#Expedition.targetIds + 2) -- start, crystals, reward

local profiles = {
	{ name = "outgoing lower bound", ignoreIncoming = true, reaction = 0, recovery = 0, petDelay = 0, missEvery = 0, dodgeMissEvery = 0 },
	{ name = "careful movement", ignoreIncoming = false, reaction = 0.25, recovery = 0.25, petDelay = 0, missEvery = 0, dodgeMissEvery = 0 },
	{ name = "learner", ignoreIncoming = false, reaction = 0.45, recovery = 0.35, petDelay = 1.3, missEvery = 4, dodgeMissEvery = 4 },
	{ name = "risky learner", ignoreIncoming = false, reaction = 0.45, recovery = 0.35, petDelay = 1.3, missEvery = 4, dodgeMissEvery = 3 },
	{ name = "stands in every warning", ignoreIncoming = false, reaction = 0, recovery = 0, petDelay = 0, missEvery = 0, dodgeMissEvery = 1 },
}

local function simulate(foe, profile, count, health, withPet)
	local foeHealth = Rules.scaledHealth(foe.maxHealth, count)
	local nextMelee, nextPet = 0, 0
	local nextWarning = Rules.firstSlamDelay
	local warning, pendingPet
	local swings, warnings, hitsTaken, lostHealth = 0, 0, 0, 0
	local step = 0.01
	for tick = 0, 12000 do
		local at = tick * step
		if warning and not warning.resolved and at + step / 2 >= warning.resolveAt then
			if not profile.ignoreIncoming and not warning.dodged then
				health -= warning.damage
				lostHealth += warning.damage
				hitsTaken += 1
				if health <= 0 then
					return { seconds = at, health = 0, cleared = false, warnings = warnings, hits = hitsTaken, lost = lostHealth }
				end
			end
			nextWarning = at + Rules.slamCooldown
			-- Keep the melee pause through repositioning even after the slam resolves.
			warning.resolved = true
		end
		if warning and warning.resolved and at >= warning.pauseUntil then
			warning = nil
		end
		if not warning and at + step / 2 >= nextWarning then
			warnings += 1
			local pattern = Rules.attackPattern(foe, warnings)
			-- A targeted circle must be crossed from its center. A burst only needs
			-- the difference between the melee edge and the boss-centered radius.
			local escapeDistance = if pattern.centered then math.max(0, pattern.radius - Rules.meleeRange) else pattern.radius
			local dodged = profile.dodgeMissEvery ~= 1
				and (profile.dodgeMissEvery == 0 or warnings % profile.dodgeMissEvery ~= 0)
				and profile.reaction + escapeDistance / walkSpeed < pattern.windup
			warning = {
				resolveAt = at + pattern.windup,
				pauseAt = at + profile.reaction,
				pauseUntil = at + pattern.windup + profile.recovery,
				damage = pattern.damage,
				dodged = dodged,
				resolved = false,
			}
		end
		if pendingPet and at + step / 2 >= pendingPet then
			foeHealth -= Rules.petDamage * count
			pendingPet = nil
		end
		local moving = not profile.ignoreIncoming and warning and warning.dodged
			and at >= warning.pauseAt and at < warning.pauseUntil
		if at + step / 2 >= nextMelee and not moving then
			swings += 1
			if profile.missEvery == 0 or swings % profile.missEvery ~= 0 then
				foeHealth -= Rules.meleeDamage * count
			end
			nextMelee = at + Rules.meleeCooldown
		end
		if foeHealth <= 0 then
			return { seconds = at, health = health, cleared = true, warnings = warnings, hits = hitsTaken, lost = lostHealth }
		end
		if withPet and not pendingPet and at + step / 2 >= nextPet then
			-- Assumes an owned pet, line of sight, and the owner stays inside petRange.
			-- Pet damage arrives after the real server windup; melee and pet have separate cooldowns.
			pendingPet = at + Rules.petWindup
			nextPet = at + Rules.petCooldown + profile.petDelay
		end
	end
	error("Scenario exceeded 120 seconds. Review the combat model or new stats.")
end

print("WILDBOND BALANCE MODEL — estimates, not measured playtime")
print(string.format("Full trail geometry %.1f studs / %.1f speed = %.1fs; prompt holds %.2fs.", trailLength, walkSpeed, trailLength / walkSpeed, promptTime))
print("Route subtotal = three combat models + full trail + five holds. It omits discovery, detours, cooldown carry, crystals approach, latency and deaths/respawn.")
print("Warnings repeat at actual windup + slamCooldown. Movement pauses melee after a profile reaction until resolve + recovery; pet commands remain available in petRange.")
print("No healing between or during modeled fights; the same avatar HP carries across the three fights. Each new fight starts with cooldowns ready, unlike a perfect speedrun.")
print(string.format("Melee %d / %.2fs; pet %d / %.2fs, landing after %.2fs; initial avatar %.0fHP.", Rules.meleeDamage, Rules.meleeCooldown, Rules.petDamage, Rules.petCooldown, Rules.petWindup, avatarHealth))
print("Profiles: careful reaction/recovery .25/.25s; learner .45/.35s + one in four melee swings misses + 1.3s pet input delay + every fourth dodge fails; risky learner every third dodge fails; standstill fails all dodges.")

for _, profile in profiles do
	local total, health = 0, avatarHealth
	local finished = true
	print("\n" .. profile.name)
	for _, foe in Rules.foes do
		local result = simulate(foe, profile, 1, health, true)
		total += result.seconds
		health = result.health
		print(string.format("  %-18s %.1fs, %d warnings, %d hits taken, %.0fHP left, %s",
			foe.id, result.seconds, result.warnings, result.hits, health, if result.cleared then "clear" else "DIED"))
		if not result.cleared then
			finished = false
			break
		end
	end
	if finished then
		print(string.format("  Combat %.1fs; route subtotal %.1fs (not a promised mission duration).", total, total + trailLength / walkSpeed + promptTime))
	else
		print(string.format("  No full-hunt clear in this assumption; %.1fs combat before death. Retry time is not modeled.", total))
	end
	if profile.name == "careful movement" then
		assert(finished, "A careful solo player with the starter pet must be able to clear in this model.")
	elseif profile.name == "stands in every warning" then
		assert(not finished, "Ignoring every warning should have a meaningful cost in this model.")
	end
end

print("\nBoss outgoing-only group lower bounds: all members contribute at the start, synchronize attacks and use equal starter pets.")
for count = 1, Rules.maxGroupSize do
	local boss = Rules.foes[#Rules.foes]
	local result = simulate(boss, profiles[1], count, avatarHealth, true)
	print(string.format("  %d contributors: %dHP, %.1fs lower bound (no incoming damage or movement).", count, Rules.scaledHealth(boss.maxHealth, count), result.seconds))
end
local withoutPet = simulate(Rules.foes[#Rules.foes], profiles[1], 1, avatarHealth, false)
print(string.format("Boss melee-only outgoing lower bound %.1fs; collection does not change pet damage.", withoutPet.seconds))

print("\nShell economy read from Expedition:")
local spend = 0
for _, pet in Expedition.pets do
	spend += pet.cost
	print(string.format("  %s: %d shells, %d hunts from zero if bought alone; %d cumulative hunts in catalog order.",
		pet.name, pet.cost, math.ceil(pet.cost / Expedition.reward), math.ceil(spend / Expedition.reward)))
end
print("No retention or Robux revenue inference is supported by this report.")
