local Rules = require("../src/shared/CombatRules")

local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end

local origin = { x = 0, y = 0, z = 0 }
local edge = { x = 0, y = 0, z = 8 }
check(Rules.meleeDamage == 10 and Rules.meleeRange == 8 and Rules.meleeCooldown == 0.6, "Melee configuration")
check(Rules.distanceSquared(origin, { x = 3, y = 4, z = 12 }) == 169, "Distance uses all three axes")
check(Rules.inRange(origin, edge, 8), "Melee boundary is reachable")
check(not Rules.inRange(origin, { x = 0, y = 0, z = 8.001 }, 8), "Beyond melee boundary is rejected")
check(not Rules.inRange(origin, { x = 0, y = 9, z = 0 }, 8), "Vertical distance is authoritative")
check(Rules.inRange(origin, origin, 0), "Zero distance is in zero range")
check(not Rules.inRange(origin, origin, -1), "Negative ranges fail closed")
check(not Rules.inRange(origin, origin, math.huge), "Infinite range fails closed")
check(not Rules.inRange(origin, { x = 0 / 0, y = 0, z = 0 }, 12), "Invalid position fails closed")

check(Rules.cooldownReady(0, nil, 0.45), "First attack has no previous cooldown")
check(not Rules.cooldownReady(0.449, 0, 0.45), "Early attack is rejected")
check(Rules.cooldownReady(0.45, 0, 0.45), "Exact cooldown boundary is accepted")
check(Rules.cooldownReady(10.45, 10, 0.45), "Cooldown boundary remains stable away from clock zero")
check(not Rules.cooldownReady(10.449, 10, 0.45), "Early nonzero-clock attack remains rejected")
check(Rules.cooldownReady(10, 0, 0.45), "Expired cooldown is accepted")
check(not Rules.cooldownReady(0, 1, 0.45), "Backward clock is rejected")
check(not Rules.cooldownReady(math.huge, 0, 0.45), "Infinite clock is rejected")
check(not Rules.cooldownReady(0 / 0, nil, 0.45), "Invalid first clock is rejected")
check(not Rules.cooldownReady(10, 0 / 0, 0.45), "Invalid previous clock is rejected")
check(not Rules.cooldownReady(10, 0, -1), "Negative cooldown is rejected")

local state = { active = true, defeated = { moss = false, river = false, ruins = false } }
check(Rules.eligible(state, true, "moss"), "Living active hunter can hit unfinished guardian")
check(not Rules.eligible(nil, true, "moss"), "Missing state is rejected")
check(not Rules.eligible(state, false, "moss"), "Dead player cannot attack or be targeted")
check(not Rules.eligible(state, true, "unknown"), "Unknown guardian is rejected")
state.active = false
check(not Rules.eligible(state, true, "moss"), "Inactive player cannot enter combat")
state.active = true
state.defeated.moss = true
check(not Rules.eligible(state, true, "moss"), "Already defeated guardian cannot target or be hit by that hunter")
check(Rules.eligible(state, true, "river"), "Defeating one guardian does not block the others")
state.defeated.moss = false

local rewardEdge = { x = 0, y = 0, z = 40 }
check(Rules.canReward(state, true, true, true, "moss", rewardEdge, origin), "Contributor earns credit at reward range boundary")
check(not Rules.canReward(state, true, true, true, "moss", { x = 0, y = 0, z = 40.01 }, origin), "Faraway contributor receives no credit")
check(not Rules.canReward(state, true, true, false, "moss", origin, origin), "Nearby spectator receives no credit")
check(not Rules.canReward(state, true, false, true, "moss", origin, origin), "Disconnected contributor receives no credit")
check(not Rules.canReward(state, false, true, true, "moss", origin, origin), "Dead contributor receives no credit")
state.defeated.moss = true
check(not Rules.canReward(state, true, true, true, "moss", origin, origin), "Repeat credit is blocked")
state.defeated.moss = false
state.active = false
check(not Rules.canReward(state, true, true, true, "moss", origin, origin), "Inactive contributor receives no credit")
state.active = true

local slamCenter = { x = 2, y = 4.1, z = -4 }
check(Rules.inSlam({ x = 5, y = 7, z = 0 }, slamCenter, 5), "Slam disk includes exact 3-4-5 boundary")
check(not Rules.inSlam({ x = 5.01, y = 7, z = 0 }, slamCenter, 5), "Moving outside telegraph evades slam")
check(Rules.inSlam({ x = 2, y = 12.1, z = -4 }, slamCenter, 5), "Height boundary is included")
check(not Rules.inSlam({ x = 2, y = 12.11, z = -4 }, slamCenter, 5), "Higher platform is outside slam")
check(not Rules.inSlam({ x = 2, y = -4.01, z = -4 }, slamCenter, 5), "Below disk height tolerance is rejected")
check(not Rules.inSlam({ x = 0 / 0, y = 7, z = -4 }, slamCenter, 5), "Invalid slam position fails closed")
check(not Rules.inSlam(slamCenter, slamCenter, -1), "Negative slam radius fails closed")

check(#Rules.foes == 25 and Rules.respawnDelay == 6 and Rules.firstSlamDelay == 2.8, "Expanded mainland has 25 respawning creatures and preserves engagement warning delay")
local health = { moss = 140, river = 200, ruins = 600, brush01 = 80, brush02 = 75, brush03 = 75, brush04 = 80, brush05 = 100, brush06 = 100 }
local seen, kinds, bountyCount, regions = {}, {}, 0, {}
for _, foe in Rules.foes do
	check(not seen[foe.id] and (health[foe.id] == nil or health[foe.id] == foe.maxHealth), "Unique creature id and preserved starter creature health")
	seen[foe.id] = true
	kinds[foe.kind] = true
	local region = string.match(foe.id, "^([a-z]+)%d+$")
	if region then regions[region] = (regions[region] or 0) + 1 end
	check(foe.windup >= 0.8 and foe.slamDamage < 100, "Slam gives a warning and is survivable at full health")
	check(Rules.eligible(state, true, foe.id), "Active hunter can fight every known creature")
	if foe.bounty then
		bountyCount += 1
		local hits = math.ceil(foe.maxHealth / Rules.meleeDamage)
		check(hits == ({ moss = 14, river = 20, ruins = 60 })[foe.id], "Bounty guardian survives expected melee hit count")
		check((hits - 1) * Rules.meleeCooldown > Rules.firstSlamDelay + foe.windup,
			"First warning resolves before uninterrupted melee can kill the bounty guardian")
	else
		state.defeated[foe.id] = true
		check(Rules.eligible(state, true, foe.id), "Ambient respawns remain fightable after an earlier defeat")
		state.active = false
		check(Rules.eligible(state, true, foe.id), "Free exploration permits ambient combat without a bounty hunt")
		check(not Rules.eligible(nil, true, foe.id) and not Rules.eligible(state, false, foe.id),
			"Ambient exploration still requires a known living player state")
		state.active = true
		check(not Rules.canReward(state, true, true, true, foe.id, origin, origin), "Ambient kill cannot grant a bounty reward")
		check(not foe.boss and foe.slamDamage == 0 and foe.maxHealth <= 100, "Ambient encounters are lighter basic-attack creatures")
		check(foe.maxHealth == ({ boar = 75, sprout = 80, reed = 100 })[foe.kind] and foe.meleeDamage <= 7,
			"Outer populations preserve the readable introductory strength of their species")
	end
end
check(bountyCount == 3 and kinds.sprout and kinds.reed and kinds.ancient and kinds.boar, "Three bounty encounters and four creature kinds")
check(regions.brush == 6 and regions.forest == 5 and regions.marsh == 4 and regions.outskirts == 3 and regions.meadow == 4,
	"Outer forest, marsh, ruins approaches and meadow all have real hunting populations")
check(Rules.foes[3].boss and Rules.foes[3].slamRadius == 7 and Rules.foes[3].slamDamage == 22, "Boss has distinct area and damage")
check(Rules.petDamage == 18 and Rules.petCooldown == 3.2 and Rules.petRange == 18 and Rules.petWindup == 0.3,
	"Companion strike has its own range, delay, damage, and pacing")
check(not Rules.canBond(nil) and not Rules.canBond(state), "Missing companion bindings fail closed")
for _, id in { "mosswolf", "emberfox", "tidecub" } do
	state.equipped, state.owned = id, { [id] = true }
	check(Rules.canBond(state), "Every known owned companion has the same combat skill")
	state.owned[id] = false
	check(not Rules.canBond(state), "Unowned companion cannot use the skill")
end
state.equipped, state.owned = "invented", { invented = true }
check(not Rules.canBond(state), "Fabricated companion id is rejected")
check(Rules.scaledHealth(140, 1) == 140 and Rules.scaledHealth(140, 2) == 231,
	"Two contributors increase health less than their combined damage")
check(Rules.scaledHealth(140, 4) == 413 and Rules.scaledHealth(140, 100) == 413,
	"Party health growth is capped at four contributors")
check(Rules.scaledHealth(140, 0) == 140, "Empty party defaults to solo health")
check(Rules.encounterResetDelay == 10, "Abandoned fight has a generous return window")
local target, burst, third = Rules.attackPattern(Rules.foes[3], 1), Rules.attackPattern(Rules.foes[3], 2), Rules.attackPattern(Rules.foes[3], 3)
check(not target.centered and target.radius == 7 and burst.centered and burst.radius == 10 and not third.centered,
	"Boss alternates captured player disk and anchored center disk")
check(target.windup == 1.2 and burst.damage == 22, "Both boss patterns preserve clear warning and equal damage")
check(not Rules.attackPattern(Rules.foes[1], 2).centered, "Small guardian remains a single introductory pattern")
check(not pcall(function() Rules.foes[1].maxHealth = 1 end), "Guardian definitions are immutable")
check(not pcall(function() Rules.foes[1].position.x = 999 end), "Guardian spawn definitions are immutable")

check(Rules.patrolRadius < Rules.leashRadius and Rules.chaseSpeed > Rules.patrolSpeed,
	"Foes roam locally and run faster when chasing")
check(Rules.enemyMeleeWindup >= 0.45 and Rules.enemyMeleeCooldown > Rules.enemyMeleeWindup + Rules.enemyMeleeRecover,
	"Melee has a readable windup, recovery, and gap before the next strike")
local forward = { x = 0, y = 0, z = 1 }
check(Rules.inEnemyMelee({ x = 0, y = 0, z = 5 }, origin, forward), "Enemy front arc includes exact melee range")
check(not Rules.inEnemyMelee({ x = 0, y = 0, z = -3 }, origin, forward), "Moving behind the captured facing avoids melee")
check(not Rules.inEnemyMelee({ x = 5, y = 0, z = 0 }, origin, forward), "Melee excludes the lateral arc")
check(not Rules.inEnemyMelee({ x = 0, y = 0, z = 5.01 }, origin, forward), "Melee rejects an out-of-range impact")
check(not Rules.inEnemyMelee(origin, origin, origin), "Invalid facing fails closed")
check(Rules.canTakeDamage(3, nil) and not Rules.canTakeDamage(3, 3.001), "Server dodge expiry gates enemy damage")
check(Rules.canTakeDamage(3, 3) and Rules.canTakeDamage(3, "invented"), "Expiry boundary damages; invalid dodge data does not grant immunity")
check(not Rules.canTakeDamage(0 / 0, 1), "Invalid damage clock fails closed")

print("CombatRules: " .. checks .. " checks passed")
