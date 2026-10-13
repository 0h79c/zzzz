local Expedition = require("../src/shared/Expedition")
local state = Expedition.new()
assert(state.equipRevision == 0)
assert(Expedition.equip(state, "mosswolf") and state.equipRevision == 0, "Repeated same pet does not invalidate a strike")
assert(not Expedition.equip(state, "emberfox") and state.equipRevision == 0, "Rejected equips leave the pending pet alone")
state.shells = 120
assert(Expedition.unlock(state, "emberfox") and state.equipRevision == 0)
assert(Expedition.equip(state, "emberfox") and state.equipRevision == 1)
assert(Expedition.equip(state, "mosswolf") and state.equipRevision == 2, "Switching back cannot revive an old strike")
local copy = Expedition.snapshot(state)
assert(copy.equipRevision == 2)
copy.equipRevision = 99
assert(state.equipRevision == 2)
print("Equipment revision: 8 checks passed")
