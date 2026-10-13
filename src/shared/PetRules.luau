--!strict
-- Owned companions share combat strength; shells buy a different appearance.
local PetRules = {}
PetRules.maxHealth = 60
PetRules.attackDamage = 4
PetRules.skillDamage = 12
PetRules.defense = 1
PetRules.moveSpeed = 22
PetRules.attackRange = 5.5
PetRules.attackCooldown = 1.2
PetRules.attackWindup = 0.3
PetRules.skillRange = 18
PetRules.skillCooldown = 6
PetRules.skillWindup = 0.35
PetRules.ownerLeash = 24
PetRules.reviveDelay = 10

function PetRules.known(id: any): boolean
	return id == "mosswolf" or id == "emberfox" or id == "tidecub"
end

function PetRules.damageTaken(amount: number): number
	if amount ~= amount or amount == math.huge or amount <= 0 then return 0 end
	return math.max(1, amount - PetRules.defense)
end

return table.freeze(PetRules)
