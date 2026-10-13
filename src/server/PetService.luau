--!nonstrict
-- Pet actors, health, movement, attacks and revival are authoritative server state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Rules = require(ReplicatedStorage:WaitForChild("Wildbond"):WaitForChild("PetRules"))

local PetService = {}

local function ownerActor(player)
	if player.Parent ~= Players then return nil end
	local character = player.Character
	if not character or not character.Parent then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return nil end
	return { character = character, root = root }
end

function PetService.start(getState, combat, onSkillFx)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "WildbondCompanions", Workspace
	local pets, destroyed = {}, false
	local function validPet(player)
		local state = getState(player)
		return state and state.owned and Rules.known(state.equipped) and state.owned[state.equipped] == true
	end
	local function setState(pet, state, at, duration)
		pet.state = state
		pet.model:SetAttribute("State", state)
		pet.model:SetAttribute("ActionStartedAt", at)
		pet.model:SetAttribute("ActionDuration", duration or 0)
		pet.player:SetAttribute("PetState", state)
	end
	local function publish(pet)
		pet.model:SetAttribute("Health", pet.health)
		pet.model:SetAttribute("MaxHealth", Rules.maxHealth)
		pet.model:SetAttribute("PetRespawnAt", pet.respawnAt or 0)
		pet.model:SetAttribute("PetSkillReadyAt", pet.nextSkill)
		pet.player:SetAttribute("PetHealth", pet.health)
		pet.player:SetAttribute("PetMaxHealth", Rules.maxHealth)
		pet.player:SetAttribute("PetRespawnAt", pet.respawnAt or 0)
		pet.player:SetAttribute("PetSkillReadyAt", pet.nextSkill)
	end
	local function create(player, owner, at)
		local model = Instance.new("Model")
		model.Name, model.Parent = "Companion_" .. tostring(player.UserId), folder
		model:SetAttribute("OwnerUserId", player.UserId)
		model:SetAttribute("PetId", getState(player).equipped)
		local root = Instance.new("Part")
		root.Name, root.Size = "Root", Vector3.new(1.7, 1.5, 2.7)
		root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
		root.Transparency, root.Parent = 1, model
		root.CFrame = owner.root.CFrame * CFrame.new(3.2, -1.5, 3.6)
		root.Position = root.CFrame.Position
		model.PrimaryPart = root
		local pet = { player = player, model = model, root = root, health = Rules.maxHealth,
			state = "Follow", life = 1, nextAttack = at, nextSkill = at, respawnAt = nil, pending = nil,
			equipped = getState(player).equipped, revision = getState(player).equipRevision }
		pets[player] = pet
		for key, value in { AttackDamage = Rules.attackDamage, SkillDamage = Rules.skillDamage,
			Defense = Rules.defense, MoveSpeed = Rules.moveSpeed } do
			model:SetAttribute(key, value)
			player:SetAttribute("Pet" .. key, value)
		end
		setState(pet, "Follow", at)
		publish(pet)
		return pet
	end
	local function groundPosition(pet, owner, position)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		local excluded = { folder, owner.character }
		local guardians = Workspace:FindFirstChild("WildbondGuardians")
		if guardians then table.insert(excluded, guardians) end
		for _, player in Players:GetPlayers() do
			if player.Character and player.Character ~= owner.character then table.insert(excluded, player.Character) end
		end
		parameters.FilterDescendantsInstances = excluded
		parameters.RespectCanCollide = true
		local floor = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -28, 0), parameters)
		if not floor or floor.Normal and floor.Normal.Y < 0.55 then return nil end
		return Vector3.new(position.X, floor.Position.Y + 1.35, position.Z)
	end
	local function move(pet, owner, goal, delta, follow)
		local from = pet.root.Position
		local offset = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
		if offset.Magnitude < 0.1 then
			local settled = groundPosition(pet, owner, from)
			if settled then
				pet.root.CFrame = CFrame.new(settled) * pet.root.CFrame.Rotation
				pet.root.Position = settled
			end
			return
		end
		local distance = math.min(offset.Magnitude, Rules.moveSpeed * math.min(delta, 0.2))
		-- Catch up after a real owner teleport/respawn without touching health or cooldown.
		if follow and offset.Magnitude > 40 then distance = offset.Magnitude end
		local nextPosition = groundPosition(pet, owner, from + offset.Unit * distance)
		if not nextPosition then return end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { folder, owner.character, Workspace:FindFirstChild("WildbondGuardians") }
		parameters.RespectCanCollide = true
		if distance < 40 and Workspace:Raycast(from, offset.Unit * (distance + 0.8), parameters) then return end
		pet.root.CFrame = CFrame.lookAt(nextPosition, nextPosition + offset.Unit)
		pet.root.Position = nextPosition
	end
	local function begin(pet, owner, target, skill, at)
		if pet.pending or pet.health <= 0 then return false end
		if skill and at < pet.nextSkill or not skill and at < pet.nextAttack then return false end
		local duration = if skill then Rules.skillWindup else Rules.attackWindup
		if skill then pet.nextSkill = at + Rules.skillCooldown else pet.nextAttack = at + Rules.attackCooldown end
		pet.pending = { target = target, resolveAt = at + duration, skill = skill,
			character = owner.character, life = pet.life, revision = getState(pet.player).equipRevision,
			equipped = getState(pet.player).equipped }
		pet.model:SetAttribute("AttackTarget", target.position)
		setState(pet, if skill then "Skill" else "Attack", at, duration)
		combat.engageCompanionTarget(pet.player, target)
		if skill and onSkillFx then onSkillFx(pet.player, target.position) end
		publish(pet)
		return true
	end
	local service = { ownerLeash = Rules.ownerLeash }
	function service.actor(player)
		local pet = pets[player]
		if destroyed or not pet or pet.health <= 0 or not ownerActor(player) or not validPet(player) then return nil end
		return { player = player, character = pet.model, root = pet.root, pet = true, life = pet.life }
	end
	function service.damage(source, amount, at)
		local pet = pets[source.player]
		if destroyed or not pet or pet.model ~= source.character or pet.life ~= source.life or pet.health <= 0 then return end
		pet.health = math.max(0, pet.health - Rules.damageTaken(amount))
		if pet.health <= 0 then
			pet.life += 1
			pet.pending, pet.respawnAt = nil, nil
			setState(pet, "Dead", at, 0.65)
		end
		publish(pet)
	end
	function service.cooldown(player)
		local pet = pets[player]
		return if pet then math.max(0, pet.nextSkill - Workspace:GetServerTimeNow()) else 0
	end
	function service.skill(player)
		local owner, pet = ownerActor(player), pets[player]
		if destroyed or not owner or not validPet(player) then return false, "Wait until your companion is ready." end
		if not pet or pet.health <= 0 then return false, "Your companion will return after ten seconds out of combat." end
		local at = Workspace:GetServerTimeNow()
		if pet.pending or at < pet.nextSkill then return false, "Your companion is catching its breath." end
		local target = combat.selectCompanionTarget(player, pet.root, Rules.skillRange, false)
		if not target then return false, "Move your companion closer to an eligible creature." end
		begin(pet, owner, target, true, at)
		return true, "Companion skill!"
	end
	combat.attachCompanions(service)
	local function update(at, delta)
		for _, player in Players:GetPlayers() do
			local owner = ownerActor(player)
			local inCombat = combat.inCombat(player)
			player:SetAttribute("InCombat", inCombat)
			local pet = pets[player]
			if not pet and owner and validPet(player) then pet = create(player, owner, at) end
			if not pet then continue end
			local state = getState(player)
			if state and (state.equipped ~= pet.equipped or state.equipRevision ~= pet.revision) then
				pet.equipped, pet.revision, pet.pending = state.equipped, state.equipRevision, nil
				pet.life += 1
				pet.model:SetAttribute("PetId", state.equipped)
				if pet.health > 0 then setState(pet, "Follow", at) end
			end
			if pet.health <= 0 then
				if inCombat or not owner then pet.respawnAt = nil
				elseif not pet.respawnAt then pet.respawnAt = at + Rules.reviveDelay
				elseif at >= pet.respawnAt then
					pet.health, pet.life, pet.respawnAt = Rules.maxHealth, pet.life + 1, nil
					pet.nextAttack = math.max(pet.nextAttack, at + Rules.attackCooldown)
					pet.nextSkill = math.max(pet.nextSkill, at + Rules.skillCooldown)
					local position = groundPosition(pet, owner, owner.root.Position + Vector3.new(3.2, 0, 3.6))
					if position then pet.root.CFrame = CFrame.new(position); pet.root.Position = position end
					setState(pet, "Follow", at)
				end
				publish(pet)
				continue
			end
			if not owner or not validPet(player) then
				pet.pending = nil
				if pet.state ~= "Follow" then setState(pet, "Follow", at) end
				continue
			end
			local pending = pet.pending
			if pending then
				if pending.character ~= owner.character or pending.life ~= pet.life
					or pending.revision ~= state.equipRevision or pending.equipped ~= state.equipped then
					pet.pending = nil
					setState(pet, "Follow", at)
				elseif at >= pending.resolveAt then
					combat.hitCompanionTarget(player, pet.root, pending.target,
						if pending.skill then Rules.skillDamage else Rules.attackDamage,
						if pending.skill then Rules.skillRange else Rules.attackRange)
					pet.pending = nil
					setState(pet, "Follow", at)
				end
			end
			if pet.pending then continue end
			local target = if inCombat then combat.selectCompanionTarget(player, pet.root, Rules.ownerLeash, true) else nil
			if target then
				local distance = (target.position - pet.root.Position).Magnitude
				if at >= pet.nextSkill and distance <= Rules.skillRange then begin(pet, owner, target, true, at)
				elseif distance <= Rules.attackRange then begin(pet, owner, target, false, at)
				else move(pet, owner, target.position, delta, false) end
			else
				move(pet, owner, (owner.root.CFrame * CFrame.new(3.2, 0, 3.6)).Position, delta, true)
			end
		end
	end
	local accumulated = 0
	local heartbeat = RunService.Heartbeat:Connect(function(delta)
		if destroyed then return end
		accumulated += delta
		if accumulated < 0.1 then return end
		local elapsed = accumulated
		accumulated = 0
		update(Workspace:GetServerTimeNow(), elapsed)
	end)
	local removing = Players.PlayerRemoving:Connect(function(player)
		local pet = pets[player]
		if pet then pet.model:Destroy(); pets[player] = nil end
	end)
	function service.destroy()
		if destroyed then return end
		destroyed = true
		heartbeat:Disconnect()
		removing:Disconnect()
		combat.attachCompanions(nil)
		pets = {}
		folder:Destroy()
	end
	return service
end

return PetService
