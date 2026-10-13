local Metrics = require("../src/shared/HuntMetrics")
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end

local stats = Metrics.new()
Metrics.death(stats)
check(stats.deaths == 0, "Camp deaths must not affect the next hunt")
check(not Metrics.finish(stats, 50), "No completion without starting")
for _, invalid in { -1, math.huge, 0 / 0 } do
	check(not Metrics.start(stats, invalid), "Reject invalid server clock")
end
check(Metrics.start(stats, 10), "Start a measured hunt")
check(not Metrics.start(stats, 11), "Repeated start must not erase elapsed time")
Metrics.death(stats)
Metrics.death(stats)
local midway = Metrics.snapshot(stats, 100)
check(midway.elapsed == 90 and midway.deaths == 2, "Elapsed includes deaths and recovery")
midway.deaths = 900
check(stats.deaths == 2, "Snapshot must not mutate measurements")
check(not Metrics.finish(stats, 9), "Backwards time must not complete")
check(not Metrics.finish(stats, math.huge), "Infinite time must not complete")
check(not Metrics.finish(stats, 0 / 0), "NaN time must not complete")
check(Metrics.finish(stats, 130), "Finish confirmed completion")
check(stats.lastDuration == 120 and stats.bestDuration == 120 and stats.lastDeaths == 2, "Store actual first result")
check(Metrics.snapshot(stats, 500).elapsed == nil, "Inactive timer must stop")
check(not Metrics.finish(stats, 600) and stats.lastDuration == 120, "Duplicate completion cannot corrupt result")
Metrics.death(stats)
check(stats.lastDeaths == 2 and stats.deaths == 2, "Deaths after claim must not alter result")
check(Metrics.start(stats, 600) and stats.deaths == 0, "Repeat hunt resets only current falls")
check(Metrics.finish(stats, 750) and stats.bestDuration == 120 and stats.lastDuration == 150, "Slower hunt keeps best")
check(Metrics.start(stats, 800), "Start third hunt")
check(Metrics.finish(stats, 890) and stats.bestDuration == 90, "Faster hunt updates best")
check(Metrics.start(stats, 0), "Zero is a valid clock start")
check(Metrics.snapshot(stats, 0).elapsed == 0, "Zero elapsed is not missing")
check(Metrics.snapshot(stats, -1).elapsed == nil, "Reject invalid snapshot clock")
print("HuntMetrics: " .. tostring(checks) .. " checks passed")
