--!strict
-- Pure server-owned game rules. This module has no Roblox service dependencies.
local Expedition = {}

export type State = {
	shells: number,
	huntsCompleted: number,
	active: boolean,
	defeated: { [string]: boolean },
	collected: { [string]: boolean },
	owned: { [string]: boolean },
	equipped: string,
	equipRevision: number,
}

export type Pet = { read id: string, read name: string, read cost: number }

local targetIds = table.freeze({ "moss", "river", "ruins" })
local targetSet: { [string]: boolean } = { moss = true, river = true, ruins = true }
local pets: { Pet } = table.freeze({
	table.freeze({ id = "mosswolf", name = "Moss Wolf", cost = 0 }),
	table.freeze({ id = "emberfox", name = "Ember Fox", cost = 120 }),
	table.freeze({ id = "tidecub", name = "Tide Cub", cost = 240 }),
})
local petById: { [string]: Pet } = {}
for _, pet in pets do
	petById[pet.id] = pet
end

local reward = 60

Expedition.targetIds = targetIds
Expedition.pets = pets
Expedition.reward = reward

local function emptyTargets(): { [string]: boolean }
	return { moss = false, river = false, ruins = false }
end

local function isTarget(id: any): boolean
	return typeof(id) == "string" and targetSet[id] == true
end

function Expedition.new(): State
	return {
		shells = 0,
		huntsCompleted = 0,
		active = false,
		defeated = emptyTargets(),
		collected = emptyTargets(),
		owned = { mosswolf = true },
		equipped = "mosswolf",
		equipRevision = 0,
	}
end

function Expedition.snapshot(state: State): State
	local defeated: { [string]: boolean } = {}
	local collected: { [string]: boolean } = {}
	local owned: { [string]: boolean } = {}
	for id, value in state.defeated do
		defeated[id] = value
	end
	for id, value in state.collected do
		collected[id] = value
	end
	for id, value in state.owned do
		owned[id] = value
	end
	return {
		shells = state.shells,
		huntsCompleted = state.huntsCompleted,
		active = state.active,
		defeated = defeated,
		collected = collected,
		owned = owned,
		equipped = state.equipped,
		equipRevision = state.equipRevision,
	}
end

function Expedition.start(state: State): (boolean, string)
	if state.active then
		return false, "Finish your current expedition first."
	end
	state.defeated = emptyTargets()
	state.collected = emptyTargets()
	state.active = true
	return true, "Expedition started. Defeat the three guardians and collect their crystals."
end

function Expedition.defeat(state: State, id: any): (boolean, string)
	if not isTarget(id) then
		return false, "Unknown guardian."
	end
	if not state.active then
		return false, "Start an expedition first."
	end
	if state.defeated[id] then
		return false, "This guardian is already defeated."
	end
	state.defeated[id] = true
	return true, "Guardian defeated. Collect its crystal."
end

function Expedition.collect(state: State, id: any): (boolean, string)
	if not isTarget(id) then
		return false, "Unknown crystal."
	end
	if not state.active then
		return false, "Start an expedition first."
	end
	if not state.defeated[id] then
		return false, "Defeat this crystal's guardian first."
	end
	if state.collected[id] then
		return false, "This crystal is already collected."
	end
	state.collected[id] = true
	return true, "Crystal collected."
end

function Expedition.claim(state: State): (boolean, string)
	if not state.active then
		return false, "No expedition reward is waiting."
	end
	for _, id in targetIds do
		if not state.collected[id] then
			return false, "Collect all three crystals before returning for your reward."
		end
	end
	state.shells += reward
	state.huntsCompleted += 1
	state.active = false
	return true, "Expedition complete! You earned 60 shells."
end

function Expedition.unlock(state: State, id: any): (boolean, string)
	if typeof(id) ~= "string" or petById[id] == nil then
		return false, "Unknown companion."
	end
	local pet = petById[id]
	if state.owned[id] then
		return false, "You already own this companion."
	end
	if state.shells < pet.cost then
		return false, "You need more shells for this companion."
	end
	state.shells -= pet.cost
	state.owned[id] = true
	return true, pet.name .. " joined your collection."
end

function Expedition.equip(state: State, id: any): (boolean, string)
	if typeof(id) ~= "string" or petById[id] == nil then
		return false, "Unknown companion."
	end
	if not state.owned[id] then
		return false, "Unlock this companion first."
	end
	if state.equipped ~= id then
		state.equipRevision += 1
		state.equipped = id
	end
	return true, petById[id].name .. " is now your companion."
end

return table.freeze(Expedition)
