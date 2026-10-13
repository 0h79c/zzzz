local Progression = require("../src/shared/Progression")
local CombatRules = require("../src/shared/CombatRules")

local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function foe(kind, boss)
	return { kind = kind, boss = boss }
end
local function award(profile, definition, expectedLevels)
	local levels, rejection = Progression.award(profile, definition)
	check(levels == expectedLevels and rejection == nil, "Kill award should return levels gained")
end
local function reject(profile, definition)
	local before = if type(profile) == "table" then table.clone(profile) else nil
	local levels, reason = Progression.award(profile, definition)
	check(levels == nil and type(reason) == "string", "Malformed reward request must be rejected")
	if before then
		for key, value in before do
			check(profile[key] == value or (type(value) == "number" and value ~= value and profile[key] ~= profile[key]), "Rejected award must not mutate profile")
		end
	end
end

local profile = Progression.new()
check(profile.level == 1 and profile.coins == 0 and profile.xp == 0, "New profile starts at level one with no currency")
check(Progression.maxLevel == 40 and Progression.xpToNext(1) == 60 and Progression.xpToNext(2) == 85, "Starter XP thresholds")
for level = 2, 39 do
	check(Progression.xpToNext(level) > Progression.xpToNext(level - 1), "XP threshold increases each level")
end
check(Progression.xpToNext(40) == 0, "Level cap has no further XP requirement")
for _, definition in CombatRules.foes do
	local instance = Progression.new()
	award(instance, definition, 0)
	local reward = Progression.rewards[definition.kind]
	check(instance.coins == reward.coins and instance.xp == reward.xp, "Actual foe definitions receive catalog rewards")
end

-- Cross the exact level boundary and preserve overflow on the next boundary.
for _ = 1, 5 do award(profile, foe("sprout", false), 0) end
check(profile.level == 1 and profile.xp == 50 and profile.coins == 25, "Five sprouts stay below level two")
award(profile, foe("sprout", false), 1)
check(profile.level == 2 and profile.xp == 0 and profile.coins == 30, "Exact threshold advances one level")
award(profile, foe("ancient", true), 0)
award(profile, foe("ancient", true), 1)
check(profile.level == 3 and profile.xp == 5 and profile.coins == 80, "Boss XP crosses the next level with overflow preserved")

-- A real kill sequence covers several levels without accepting arbitrary XP grants.
local accumulated = Progression.new()
local totalXp, totalCoins = 0, 0
for _ = 1, 100 do
	local levels, rejection = Progression.award(accumulated, foe("ancient", true))
	check(levels ~= nil and levels >= 0 and levels <= 1 and rejection == nil, "Fixed boss reward can cross at most one level")
	totalXp += 45
	totalCoins += 25
end
local expectedLevel, expectedXp = 1, totalXp
while expectedXp >= Progression.xpToNext(expectedLevel) and expectedLevel < 40 do
	expectedXp -= Progression.xpToNext(expectedLevel)
	expectedLevel += 1
end
check(accumulated.level == expectedLevel and accumulated.level > 5 and accumulated.xp == expectedXp and accumulated.coins == totalCoins,
	"Multiple levels conserve the XP earned by server kill awards")

local almostCapped = { level = 39, xp = Progression.xpToNext(39) - 1, coins = Progression.maxCoins - 2 }
award(almostCapped, foe("boar", false), 1)
check(almostCapped.level == 40 and almostCapped.xp == 0 and almostCapped.coins == Progression.maxCoins, "Cap consumes excess XP and safely saturates coins")
for _ = 1, 100 do award(almostCapped, foe("ancient", true), 0) end
check(almostCapped.level == 40 and almostCapped.xp == 0 and almostCapped.coins == Progression.maxCoins, "Kills at cap cannot wrap XP or coins")

for _, kind in { "boar", "sprout", "reed" } do
	reject(profile, foe(kind, true))
end
reject(profile, foe("ancient", false))
for _, definition in { {}, { kind = "boar" }, { boss = false }, foe("unknown", false), foe("Boar", false), foe("", false),
	{ kind = 4, boss = false }, { kind = {}, boss = false }, { kind = "boar", boss = 0 }, { kind = "boar", boss = "false" }, 1, true, "boar" } do
	reject(profile, definition)
end
reject(profile, nil)
for _, invalid in { -1, 0 / 0, math.huge, -math.huge, 0.5, "0", {} } do
	for _, field in { "coins", "xp", "level" } do
		local bad = Progression.new()
		bad[field] = invalid
		reject(bad, foe("boar", false))
		local copy, reason = Progression.snapshot(bad)
		check(copy == nil and type(reason) == "string", "Snapshot rejects corrupted profiles")
	end
end
for _, bad in { { level = 0, coins = 0, xp = 0 }, { level = 41, coins = 0, xp = 0 },
	{ level = 1, coins = Progression.maxCoins + 1, xp = 0 }, { level = 1, coins = 0, xp = 60 },
	{ level = 40, coins = 0, xp = 1 }, {}, { level = 1, xp = 0 } } do
	reject(bad, foe("boar", false))
end
reject(nil, foe("boar", false))
reject(0, foe("boar", false))

-- Foe definitions may contain other gameplay fields, never injectable amounts.
local noInjection = Progression.new()
award(noInjection, { kind = "boar", boss = false, coins = 99999999, xp = math.huge, reward = { coins = 100 } }, 0)
check(noInjection.coins == 4 and noInjection.xp == 8, "Caller-provided reward fields cannot mint currency or XP")
local copy, reason = Progression.snapshot(profile)
check(copy ~= profile and reason == nil and copy.coins == profile.coins and copy.xp == profile.xp and copy.level == profile.level,
	"Snapshot copies the session values")
check(copy.nextLevelXp == Progression.xpToNext(profile.level) and copy.maxLevel == 40, "Snapshot includes HUD progression limits")
copy.coins = 9999
copy.level = 40
copy.xp = 9999
check(profile.coins == 80 and profile.level == 3 and profile.xp == 5, "Client snapshot changes cannot mutate the session profile")
local other = Progression.new()
other.coins = 1
check(Progression.new().coins == 0, "New sessions do not share a profile table")
check(not pcall(function() Progression.maxLevel = 999 end), "Progression settings are immutable")
check(not pcall(function() Progression.rewards.boar.xp = 9999 end), "Reward entries are immutable")
check(not pcall(function() Progression.rewards.boar = { xp = 9999, coins = 9999 } end), "Reward catalog is immutable")
for _, level in { -1, 0, 41, 1.5, 0 / 0, math.huge, "1", {} } do
	check(Progression.xpToNext(level) == nil, "Malformed levels cannot query an XP threshold")
end
check(Progression.xpToNext(nil) == nil, "Missing level is rejected")
print(`Progression: {checks} checks passed`)
