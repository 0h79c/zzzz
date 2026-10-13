-- Executes actual PetService and CombatService together with reflected Instances.
-- Deterministic rays/clock/signals stub engine boundaries; Studio is still required.
local fs, luau, roblox = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local CombatRules, PetRules = require("../src/shared/CombatRules"), require("../src/shared/PetRules")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local checks, active = 0, nil
local function check(value, message) assert(value, message); checks += 1 end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { active = true, callback = callback }
			function connection:Disconnect() self.active = false end
			table.insert(listeners, connection)
			return connection
		end,
		Fire = function(_, ...) for _, listener in listeners do if listener.active then listener.callback(...) end end end,
		Count = function() local n = 0; for _, listener in listeners do if listener.active then n += 1 end end; return n end,
	}
end
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return active.now end)
roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction, parameters)
	if direction.Y < -1 then
		local excludedFoes = false
		for _, instance in parameters.FilterDescendantsInstances do
			if instance.Name == "WildbondGuardians" then excludedFoes = true end
		end
		if active.monsterFloor and not excludedFoes then
			return { Position = Vector3.new(origin.X, 9, origin.Z), Normal = Vector3.yAxis, Instance = active.models.moss.PrimaryPart }
		end
		return if active.noGround then nil else { Position = Vector3.new(origin.X, 4.1, origin.Z), Normal = Vector3.yAxis, Instance = active.floor }
	end
	return if active.blocked then { Instance = active.floor } else nil
end)
roblox.implementMethod("Humanoid", "TakeDamage", function(value, amount) value.Health = math.max(0, value.Health - amount) end)
local function harness(position)
	local h = { now = 0, states = {}, kills = {}, credits = {}, effects = {}, jobs = {}, blocked = false }
	active = h
	local data = Instance.new("DataModel")
	h.workspace = data:GetService("Workspace")
	h.floor = Instance.new("Part"); h.floor.Parent = h.workspace
	h.heartbeat, h.removing = signal(), signal()
	h.players = { list = {}, PlayerRemoving = h.removing }
	function h.players:GetPlayers() return self.list end
	function h:character(position)
		local model = Instance.new("Model"); model.Parent = self.workspace
		local root = Instance.new("Part"); root.Name, root.Parent = "HumanoidRootPart", model
		root.CFrame, root.Position = CFrame.new(position), position
		local humanoid = Instance.new("Humanoid"); humanoid.Parent, humanoid.Health = model, 100
		return model, root, humanoid
	end
	function h:addPlayer(position)
		local model, root, humanoid = self:character(position)
		local player = { Character = model, Parent = self.players, UserId = #self.players.list + 1, attributes = {} }
		function player:SetAttribute(key, value) self.attributes[key] = value end
		function player:GetAttribute(key) return self.attributes[key] end
		table.insert(self.players.list, player)
		self.states[player] = { active = true, defeated = {}, owned = { mosswolf = true, emberfox = true, tidecub = true }, equipped = "mosswolf", equipRevision = 0 }
		return player, root, humanoid
	end
	local tokens = { CombatRules = {}, PetRules = {} }
	local services = { Workspace = h.workspace, Players = h.players, RunService = { Heartbeat = h.heartbeat },
		ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, name) return assert(tokens[name], name) end } end } }
	local environment = { game = { GetService = function(_, name) return assert(services[name], name) end },
		RaycastParams = { new = function() return {} end },
		require = function(token) return if token == tokens.CombatRules then CombatRules else PetRules end,
		task = { delay = function(delay, callback) table.insert(h.jobs, { at = h.now + delay, callback = callback }) end } }
	for _, name in { "Instance", "Vector3", "CFrame", "Color3", "UDim2", "UDim", "Enum" } do environment[name] = roblox[name] end
	local Combat = luau.load(fs.readFile("src/server/CombatService.luau"), { environment = environment })()
	local Pets = luau.load(fs.readFile("src/server/PetService.luau"), { environment = environment })()
	h.combat = Combat.start(function(player) return h.states[player] end, function(player, id) table.insert(h.credits, { player, id }) end,
		function(player, target) table.insert(h.effects, { player, target }) end,
		function(player, definition) table.insert(h.kills, { player, definition.id }) end)
	h.pets = Pets.start(function(player) return h.states[player] end, h.combat,
		function(player, target) table.insert(h.effects, { player, target }) end)
	h.models = {}
	for _, model in h.workspace:FindFirstChild("WildbondGuardians"):GetChildren() do
		h.models[model:GetAttribute("EnemyId")] = model
		model.PrimaryPart.Position = model.PrimaryPart.CFrame.Position
	end
	function h:tick(at)
		self.now = at
		self.heartbeat:Fire(0.1)
	end
	function h:step(seconds)
		local count = math.ceil(seconds / 0.1)
		for _ = 1, count do self:tick(self.now + 0.1) end
	end
	function h:destroy() self.pets.destroy(); self.combat.destroy() end
	return h
end

local h = harness()
local player, root, humanoid = h:addPlayer(Vector3.new(1000, 7, 1000))
h:tick(0)
local model = h.workspace:FindFirstChild("WildbondCompanions"):GetChildren()[1]
check(model:GetAttribute("OwnerUserId") == player.UserId and model:GetAttribute("PetId") == "mosswolf", "Server exposes owner and equipped pet identity")
check(model.PrimaryPart.Anchored and not model.PrimaryPart.CanCollide and not model.PrimaryPart.CanQuery, "Companion server root is authoritative and cannot block players or aim rays")
check(player:GetAttribute("PetHealth") == 60 and player:GetAttribute("PetMaxHealth") == 60 and humanoid.Health == 100, "Pet has independent health")
check(player:GetAttribute("PetAttackDamage") == 4 and player:GetAttribute("PetSkillDamage") == 12 and player:GetAttribute("PetDefense") == 1, "Separate pet stats are replicated by server")
h.monsterFloor = true
h:step(2)
check(#h.effects == 0 and player:GetAttribute("PetState") == "Follow" and not player:GetAttribute("InCombat"), "Pet never autonomously provokes an idle creature")
check(math.abs(model.PrimaryPart.Position.Y - 5.45) < 0.01, "Pet floor probes exclude collidable enemy bodies and follow actual ground")
local source = h.pets.actor(player)
h.pets.damage(source, 7, h.now)
check(player:GetAttribute("PetHealth") == 54 and humanoid.Health == 100, "Defense reduces incoming pet damage without touching owner health")
h.states[player].equipped, h.states[player].equipRevision = "emberfox", 1
h:tick(2.2)
check(model:GetAttribute("PetId") == "emberfox" and player:GetAttribute("PetHealth") == 54, "Equip preserves health rather than buying a free heal")
h.pets.damage(source, 100, h.now)
check(player:GetAttribute("PetHealth") == 54, "Old pet actor snapshots are invalidated by equip lifetime")
h.pets.damage(h.pets.actor(player), 100, h.now)
check(player:GetAttribute("PetHealth") == 0 and player:GetAttribute("PetState") == "Dead" and not h.pets.actor(player), "Lethal damage kills companion actor and cancels combat")
h:tick(2.3)
local deadline = player:GetAttribute("PetRespawnAt")
check(math.abs(deadline - 12.3) < 0.001, "Out-of-combat death starts a ten-second countdown")
h.states[player].equipped, h.states[player].equipRevision = "tidecub", 2
h:tick(3)
check(player:GetAttribute("PetHealth") == 0 and player:GetAttribute("PetRespawnAt") == deadline, "Equip while dead preserves death and countdown")
local oldCharacter = player.Character
local replacement, replacementRoot, replacementHealth = h:character(Vector3.new(1000, 7, 1000))
player.Character = replacement
h:tick(4)
check(player:GetAttribute("PetHealth") == 0 and player:GetAttribute("PetRespawnAt") == deadline, "Owner respawn does not revive a dead companion")
h:tick(deadline - 0.01)
check(player:GetAttribute("PetHealth") == 0, "Companion remains dead before exact revive deadline")
h:tick(deadline)
check(player:GetAttribute("PetHealth") == 60 and player:GetAttribute("PetState") == "Follow" and player:GetAttribute("PetRespawnAt") == 0, "Ten continuous seconds out of combat revives companion at full health")
check(h.pets.cooldown(player) >= PetRules.skillCooldown - 0.001, "Revival cannot bypass skill cooldown")
humanoid.Health = 0
h:destroy()
check(h.heartbeat:Count() == 0 and h.removing:Count() == 0 and not h.workspace:FindFirstChild("WildbondCompanions"), "Shutdown removes callbacks and pet actor folder")

-- Actual enemy chase/basic attacks choose the pet when it is the closest actor.
h = harness()
player, root, humanoid = h:addPlayer(Vector3.new(65, 8, -65))
h:tick(0)
model = h.workspace:FindFirstChild("WildbondCompanions"):GetChildren()[1]
check(player:GetAttribute("InCombat") and h.combat.inCombat(player), "Real enemy pursuit marks owner combat state")
h:step(0.5)
check(#h.effects >= 1 and h.models.ruins:GetAttribute("Health") == 588, "Provoked companion automatically commits and resolves its independent skill")
local readyAt = player:GetAttribute("PetSkillReadyAt")
check(not h.combat.bond(player) and readyAt > h.now, "Manual companion skill shares automatic cooldown")
-- Place its real authoritative actor beside the boss while leaving owner outside melee.
model.PrimaryPart.Position = h.models.ruins.PrimaryPart.Position + Vector3.new(0, -2.55, 3)
model.PrimaryPart.CFrame = CFrame.new(model.PrimaryPart.Position)
root.Position = Vector3.new(65, 8, -61); root.CFrame = CFrame.new(root.Position)
h:step(2)
check(player:GetAttribute("PetHealth") < 60 and humanoid.Health == 100, "Enemy basic attacks damage closest companion with separate health and defense")
check(h.models.ruins:GetAttribute("Health") < 588, "Companion uses normal attacks separately from skill")
local remainingCooldown = player:GetAttribute("PetSkillReadyAt")
h.states[player].equipped, h.states[player].equipRevision = "emberfox", 1
h:tick(h.now + 0.1)
check(player:GetAttribute("PetSkillReadyAt") == remainingCooldown and not h.combat.bond(player), "Equip cannot reset the shared automatic/manual skill cooldown")
h.pets.damage(h.pets.actor(player), 1000, h.now)
h:tick(h.now + 0.1)
check(player:GetAttribute("PetHealth") == 0 and player:GetAttribute("PetRespawnAt") == 0, "Dead pet stays dead while owner is engaged")
humanoid.MaxHealth, humanoid.Health = 1000, 1000 -- Keep the owner alive while testing the ten-second combat boundary.
h:step(11)
check(player:GetAttribute("PetHealth") == 0 and player:GetAttribute("PetRespawnAt") == 0, "Ten seconds in combat never revives pet")
root.Position, root.CFrame = Vector3.new(1000, 7, 1000), CFrame.new(1000, 7, 1000)
h:step(1.3)
deadline = player:GetAttribute("PetRespawnAt")
check(deadline > h.now and not player:GetAttribute("InCombat"), "Leaving real enemy aggro starts an out-of-combat countdown")
-- Returning before the deadline cancels progress; escaping must start a fresh interval.
root.Position, root.CFrame = Vector3.new(65, 8, -65), CFrame.new(65, 8, -65)
h:tick(h.now + 2)
check(player:GetAttribute("InCombat") and player:GetAttribute("PetRespawnAt") == 0, "Reengaging an enemy resets revival countdown")
root.Position, root.CFrame = Vector3.new(1000, 7, 1000), CFrame.new(1000, 7, 1000)
h:step(1.3)
local newDeadline = player:GetAttribute("PetRespawnAt")
check(newDeadline > deadline, "Fresh escape requires a new full ten-second interval")
humanoid.Health = 0
h:tick(h.now + 0.1)
check(player:GetAttribute("PetRespawnAt") == 0, "Dead owner cannot accumulate a pet revival countdown")
humanoid.Health = 100
h:tick(h.now + 0.1)
newDeadline = player:GetAttribute("PetRespawnAt")
h:tick(newDeadline - 0.01)
check(player:GetAttribute("PetHealth") == 0, "Revival waits for full living-owner out-of-combat interval")
h:tick(newDeadline)
check(player:GetAttribute("PetHealth") == 60, "Pet revives after resumed living-owner out-of-combat interval")
h.removing:Fire(player); player.Parent = nil
check(not h.pets.actor(player) and #h.workspace:FindFirstChild("WildbondCompanions"):GetChildren() == 0, "Leaving destroys pet state and root")
h:destroy()

-- Delayed companion skills are bound to owner/pet/equipment lifetimes and actual LOS.
for _, reason in { "respawn", "equip", "wall", "range", "death" } do
	h = harness()
	player, root, humanoid = h:addPlayer(Vector3.new(1000, 7, 1000))
	h:tick(0)
	model = h.workspace:FindFirstChild("WildbondCompanions"):GetChildren()[1]
	root.Position, root.CFrame = Vector3.new(-65, 7, -60), CFrame.new(-65, 7, -60)
	model.PrimaryPart.Position, model.PrimaryPart.CFrame = Vector3.new(-65, 5.45, -61), CFrame.new(-65, 5.45, -61)
	check(h.combat.bond(player), "Manual skill commits an authoritative eligible target")
	local originalReadyAt = player:GetAttribute("PetSkillReadyAt")
	if reason == "respawn" then
		local nextCharacter = h:character(root.Position)
		player.Character = nextCharacter
	elseif reason == "equip" then h.states[player].equipped, h.states[player].equipRevision = "emberfox", 1
	elseif reason == "wall" then h.blocked = true
	elseif reason == "range" then model.PrimaryPart.Position, model.PrimaryPart.CFrame = Vector3.new(1000, 5.45, 1000), CFrame.new(1000, 5.45, 1000)
	elseif reason == "death" then h.pets.damage(h.pets.actor(player), 1000, h.now) end
	h:tick(PetRules.skillWindup + 0.01)
	check(h.models.brush02:GetAttribute("Health") == 75, reason .. " cancels delayed skill damage")
	check(player:GetAttribute("PetSkillReadyAt") == originalReadyAt, reason .. " cannot refund committed skill cooldown")
	h:destroy()
end

-- Both player and companion are affected by the boss ground skill, independently.
h = harness()
player, root, humanoid = h:addPlayer(Vector3.new(65, 8, -65))
h:tick(0)
model = h.workspace:FindFirstChild("WildbondCompanions"):GetChildren()[1]
h:tick(0.1)
h:tick(0.5)
-- Move the pet nearby but outside basic reach. Avoid unrelated normal hit schedules.
root.Position, root.CFrame = Vector3.new(65, 8, -61), CFrame.new(65, 8, -61)
model.PrimaryPart.Position, model.PrimaryPart.CFrame = Vector3.new(66, 5.45, -61), CFrame.new(66, 5.45, -61)
h:tick(CombatRules.firstSlamDelay)
local boss = h.models.ruins
check(boss:GetAttribute("State") == "SkillWindup", "Boss commits real skill against engaged owner or companion")
local petBefore, ownerBefore = player:GetAttribute("PetHealth"), humanoid.Health
local target = boss:GetAttribute("AttackTarget")
root.Position, root.CFrame = Vector3.new(target.X, 8, target.Z), CFrame.new(target.X, 8, target.Z)
model.PrimaryPart.Position, model.PrimaryPart.CFrame = Vector3.new(target.X + 1, 5.45, target.Z), CFrame.new(target.X + 1, 5.45, target.Z)
h:tick(CombatRules.firstSlamDelay + 1.2)
check(humanoid.Health == ownerBefore - 22 and player:GetAttribute("PetHealth") == math.max(0, petBefore - 21), "Boss AoE applies independent owner damage and defended companion damage")
h:destroy()

-- Pet kill contributions preserve bounty rewards and add one universal kill callback.
h = harness()
player, root, humanoid = h:addPlayer(Vector3.new(-65, 7, -60))
h.states[player].active = false
h:tick(0)
model = h.workspace:FindFirstChild("WildbondCompanions"):GetChildren()[1]
check(h.combat.attack(player), "Owner can provoke ambient fauna without a bounty")
h:step(8)
while h.models.brush02:GetAttribute("Health") > 0 do
	h.now += 0.61
	check(h.combat.attack(player), "Owner and companion can finish ambient encounter")
end
check(#h.kills == 1 and h.kills[1][1] == player and h.kills[1][2] == "brush02" and #h.credits == 0, "Ambient kill pays universal reward once and never calls bounty defeat callback")
h:tick(h.now + 0.1)
check(#h.kills == 1, "Dead enemy life cannot produce duplicate kill reward")
h:destroy()
print("PetService: " .. checks .. " authoritative companion/enemy integration and lifecycle checks passed; native rendering/physics still need Studio")
