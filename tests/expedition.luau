local Expedition = require("../src/shared/Expedition")

local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end

local function succeeds(action, ...)
	local ok, message = action(...)
	check(ok == true, message)
	check(type(message) == "string" and #message > 0, "Successful action needs a message")
end

local function fails(action, ...)
	local ok, message = action(...)
	check(ok == false, "Action should be rejected")
	check(type(message) == "string" and #message > 0, "Rejected action needs a message")
end

local function finishHunt(state)
	succeeds(Expedition.start, state)
	for _, id in Expedition.targetIds do
		succeeds(Expedition.defeat, state, id)
		succeeds(Expedition.collect, state, id)
	end
	succeeds(Expedition.claim, state)
end

local state = Expedition.new()
check(state.shells == 0 and state.huntsCompleted == 0 and not state.active, "Fresh progression")
check(state.owned.mosswolf and state.equipped == "mosswolf", "Starter companion")
check(Expedition.reward == 60 and #Expedition.targetIds == 3 and #Expedition.pets == 3, "Public catalog")
for _, id in Expedition.targetIds do
	check(not state.defeated[id] and not state.collected[id], "Fresh hunt flags are empty")
end
check(not pcall(function() Expedition.reward = 600 end), "Public reward cannot be changed")
check(not pcall(function() Expedition.targetIds[1] = "fake" end), "Target catalog cannot be changed")
check(not pcall(function() Expedition.pets[2].cost = 0 end), "Catalog price cannot be changed")
check(not pcall(function() Expedition.pets[2] = { id = "free", name = "Free", cost = 0 } end), "Catalog entries cannot be replaced")
fails(Expedition.claim, state)
fails(Expedition.defeat, state, "moss")
fails(Expedition.collect, state, "moss")
fails(Expedition.unlock, state, "emberfox")
fails(Expedition.equip, state, "emberfox")

succeeds(Expedition.start, state)
fails(Expedition.collect, state, "moss")
fails(Expedition.claim, state)
succeeds(Expedition.defeat, state, "moss")
fails(Expedition.defeat, state, "moss")
fails(Expedition.start, state)
check(state.defeated.moss and not state.collected.moss, "Restart cannot reset an active hunt")
succeeds(Expedition.collect, state, "moss")
fails(Expedition.collect, state, "moss")
succeeds(Expedition.defeat, state, "ruins")
succeeds(Expedition.collect, state, "ruins")
fails(Expedition.claim, state)
check(state.shells == 0 and state.huntsCompleted == 0, "Partial hunt pays nothing")
succeeds(Expedition.defeat, state, "river")
succeeds(Expedition.collect, state, "river")
succeeds(Expedition.claim, state)
check(state.shells == 60 and state.huntsCompleted == 1 and not state.active, "Full hunt reward")
check(state.collected.moss and state.collected.river and state.collected.ruins, "Completed flags remain visible")
fails(Expedition.claim, state)
check(state.shells == 60 and state.huntsCompleted == 1, "Reward cannot be claimed twice")
fails(Expedition.unlock, state, "emberfox")
fails(Expedition.unlock, state, "emberfox", -1000)
check(state.shells == 60 and not state.owned.emberfox, "Insufficient shells never charge the player")

succeeds(Expedition.start, state)
for _, id in Expedition.targetIds do
	check(not state.defeated[id] and not state.collected[id], "Next hunt resets all targets")
	succeeds(Expedition.defeat, state, id)
	succeeds(Expedition.collect, state, id)
end
succeeds(Expedition.claim, state)
check(state.shells == 120 and state.huntsCompleted == 2, "Repeat hunt earns the same reward")
succeeds(Expedition.unlock, state, "emberfox")
check(state.shells == 0 and state.owned.emberfox, "Exact price boundary unlocks companion")
fails(Expedition.unlock, state, "emberfox")
check(state.shells == 0, "Duplicate unlock does not charge")
succeeds(Expedition.equip, state, "emberfox")
check(state.equipped == "emberfox", "Equip owned companion")
succeeds(Expedition.equip, state, "mosswolf")
fails(Expedition.equip, state, "tidecub")
check(state.equipped == "mosswolf", "Unowned companion cannot replace equipped companion")

for _ = 1, 4 do
	finishHunt(state)
end
check(state.shells == 240 and state.huntsCompleted == 6, "Longer earning loop")
succeeds(Expedition.unlock, state, "tidecub")
check(state.shells == 0 and state.owned.tidecub, "Higher price unlock uses catalog cost")
succeeds(Expedition.equip, state, "tidecub")

-- A client can submit any id type; none should mint rewards or unlock a pet.
local maliciousIds = { "unknown", "MOSS", "", "mosswolf;free", 0, -1, true, {}, { id = "tidecub", cost = -1000 } }
succeeds(Expedition.start, state)
for _, id in maliciousIds do
	fails(Expedition.defeat, state, id)
	fails(Expedition.collect, state, id)
	fails(Expedition.unlock, state, id)
	fails(Expedition.equip, state, id)
end
fails(Expedition.defeat, state, nil)
fails(Expedition.collect, state, nil)
fails(Expedition.unlock, state, nil)
fails(Expedition.equip, state, nil)
check(state.shells == 0 and state.huntsCompleted == 6 and state.equipped == "tidecub", "Invalid ids leave progression unchanged")
for _, id in Expedition.targetIds do
	check(not state.defeated[id] and not state.collected[id], "Invalid ids leave mission unchanged")
end

local copy = Expedition.snapshot(state)
check(copy.shells == state.shells and copy.huntsCompleted == state.huntsCompleted and copy.active == state.active and copy.equipped == state.equipped, "Snapshot preserves scalar fields")
check(copy ~= state and copy.defeated ~= state.defeated and copy.collected ~= state.collected and copy.owned ~= state.owned, "Snapshot has no shared table references")
copy.shells = 9999
copy.defeated.moss = true
copy.collected.river = true
copy.owned.fakepet = true
check(state.shells == 0 and not state.defeated.moss and not state.collected.river and not state.owned.fakepet, "Snapshot edits cannot mutate live state")
succeeds(Expedition.defeat, state, "ruins")
check(not copy.defeated.ruins, "Live state edits cannot mutate a previous snapshot")

local independent = Expedition.new()
check(not independent.active and not independent.owned.emberfox and independent.shells == 0, "Each player gets independent state")
check(independent.defeated ~= state.defeated and independent.owned ~= state.owned, "New states do not share tables")

print("Expedition: " .. checks .. " checks passed")
