-- Actual server module with reflected Instances and deterministic time.
-- Players, rays, task scheduling, and Humanoid damage are narrow stubs;
-- Roblox physics, rendering, and network delivery still require Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/CombatRules")
local Instance, Vector3 = roblox.Instance, roblox.Vector3
local checks = 0
local activeHarness
roblox.implementMethod("Workspace", "Raycast", function()
	return if activeHarness.blocked then { Instance = activeHarness.obstacle } else nil
end)
roblox.implementMethod("Humanoid", "TakeDamage", function(humanoid, damage)
	humanoid.Health = math.max(0, humanoid.Health - damage)
end)
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { connected = true }
			function connection:Disconnect() self.connected = false end
			listeners[connection] = callback
			return connection
		end,
		Fire = function(_, ...)
			for connection, callback in listeners do if connection.connected then callback(...) end end
		end,
		Count = function()
			local count = 0
			for connection in listeners do if connection.connected then count += 1 end end
			return count
		end,
	}
end
local function harness()
	local h = { now = 0, blocked = false, states = {}, credits = {}, effects = {}, scheduled = {} }
	activeHarness = h
	local game = Instance.new("DataModel")
	h.workspace = game:GetService("Workspace")
	h.obstacle = Instance.new("Part")
	h.obstacle.Name, h.obstacle.Parent = "UnrelatedFixture", h.workspace
	h.heartbeat, h.removing = signal(), signal()
	h.players = { PlayerRemoving = h.removing, list = {} }
	function h.players:GetPlayers() return self.list end
	function h:makePlayer(name, position, active)
		local character = Instance.new("Model")
		character.Name, character.Parent = name, self.workspace
		local root = Instance.new("Part")
		root.Name, root.Parent = "HumanoidRootPart", character
		root.Position = position or Vector3.new(-45, 7, -11)
		local humanoid = Instance.new("Humanoid")
		humanoid.Health, humanoid.Parent = Rules.playerMaxHealth, character
		local player = { Parent = self.players, Character = character, Name = name }
		self.states[player] = {
			active = active ~= false, defeated = {}, equipped = "mosswolf",
			owned = { mosswolf = true, emberfox = true, tidecub = true },
		}
		table.insert(self.players.list, player)
		return player, root, humanoid
	end
	local rulesToken = {}
	local services = {
		Workspace = h.workspace, Players = h.players, RunService = { Heartbeat = h.heartbeat },
		ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function() return rulesToken end } end },
	}
	local environment = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		os = { clock = function() return h.now end },
		RaycastParams = { new = function() return {} end },
		require = function(token) assert(token == rulesToken); return Rules end,
		task = { delay = function(delay, callback) table.insert(h.scheduled, { at = h.now + delay, callback = callback }) end },
	}
	for _, name in { "Instance", "Vector3", "CFrame", "Color3", "UDim2", "UDim", "Enum" } do environment[name] = roblox[name] end
	local CombatService = luau.load(fs.readFile("src/server/CombatService.luau"), {
		environment = environment, debugName = "CombatService",
	})()
	h.service = CombatService.start(function(player) return h.states[player] end, function(player, id)
		table.insert(h.credits, { player = player, id = id })
		h.states[player].defeated[id] = true
	end, function(player, position) table.insert(h.effects, { player = player, position = position }) end)
	h.folder = h.workspace:FindFirstChild("WildbondGuardians")
	h.models = {}
	for _, model in h.folder:GetChildren() do
		h.models[model:GetAttribute("EnemyId")] = model
		-- Lune stores Position/CFrame independently; sync only the authored roots.
		model.PrimaryPart.Position = model.PrimaryPart.CFrame.Position
	end
	function h:flush(at)
		self.now = at
		for index = #self.scheduled, 1, -1 do
			if self.scheduled[index].at <= at then
				local job = table.remove(self.scheduled, index)
				job.callback()
			end
		end
	end
	function h:tick(at) self:flush(at); self.heartbeat:Fire(0.1) end
	function h:finish(player, id)
		while self.models[id]:GetAttribute("Health") > 0 do
			self.now += Rules.meleeCooldown + 0.01
			check(self.service.attack(player), "Living eligible contributor can finish the guardian")
		end
	end
	return h
end

local h = harness()
local first, firstRoot, firstHealth = h:makePlayer("First")
local second, _, secondHealth = h:makePlayer("Second")
local spectator = h:makePlayer("Spectator")
check(#h.folder:GetChildren() == 3, "Service constructs three actual guardian Models")
for _, definition in Rules.foes do
	local model = h.models[definition.id]
	check(model:IsA("Model") and model:FindFirstChild("GuardianHealth"):IsA("BillboardGui"), "Guardian has real model and health display")
	check(model:GetAttribute("Health") == definition.maxHealth and model:GetAttribute("MaxHealth") == definition.maxHealth,
		"Idle enemy begins at unscaled full health")
	check((model.PrimaryPart.Position - Vector3.new(definition.position.x, definition.position.y, definition.position.z)).Magnitude < 0.001,
		"Rendered root and authoritative spawn agree")
end
local moss = h.models.moss
h.states[first].active = false
check(not h.service.attack(first) and moss:GetAttribute("Health") == 140, "Inactive hunt cannot attack")
h.states[first].active, firstHealth.Health = true, 0
check(not h.service.attack(first), "Dead character cannot attack")
firstHealth.Health, firstRoot.Position = 100, Vector3.new(-45, 7, -3)
check(not h.service.attack(first), "Server rejects targets outside melee range")
h.now, firstRoot.Position, h.blocked = 0.61, Vector3.new(-45, 7, -11), true
check(not h.service.attack(first) and moss:GetAttribute("Health") == 140, "Ray obstruction prevents melee damage")
h.blocked, h.now = false, 1.22
check(h.service.attack(first) and moss:GetAttribute("Health") == 130, "Accepted melee applies ten damage")
check(moss:GetAttribute("MaxHealth") == 140, "Nearby active hunters do not inflate enemy health before contributing")
check(not h.service.attack(first) and moss:GetAttribute("Health") == 130, "Repeated attack in one frame is throttled")
check(h.service.attack(second) and moss:GetAttribute("MaxHealth") == 231 and moss:GetAttribute("Health") == 211,
	"Second actual contributor adds allocated health while preserving previous damage")
check(moss:GetAttribute("PartySize") == 2, "Health scaling reports actual contributing party")
h.removing:Fire(second)
second.Parent = nil
local maximum = moss:GetAttribute("MaxHealth")
h:finish(first, "moss")
check(maximum == 231 and #h.credits == 1 and h.credits[1].player == first,
	"Leaving does not shrink health or grant disconnected credit; spectator gets no credit")
check(moss.PrimaryPart.Transparency == 1, "Defeated geometry is hidden")
local diedAt = h.now
h:tick(diedAt + Rules.respawnDelay - 0.01)
check(moss:GetAttribute("Health") == 0, "Enemy stays defeated before respawn deadline")
h:tick(diedAt + Rules.respawnDelay)
check(moss:GetAttribute("Health") == 140 and moss:GetAttribute("MaxHealth") == 140 and moss.PrimaryPart.Transparency == 0,
	"Respawn restores solo baseline, geometry, and encounter lifetime")
h.service.destroy()

-- Encounter HP caps actual contributors; a departing hunter never lowers it.
h = harness()
local party = {}
for index = 1, 5 do party[index] = h:makePlayer("Party" .. tostring(index)) end
for index, player in party do
	check(h.service.attack(player), "Distinct actual contributor can join the fight")
	check(h.models.moss:GetAttribute("MaxHealth") == Rules.scaledHealth(140, index), "Service matches capped party health curve")
end
check(h.models.moss:GetAttribute("Health") == 363 and h.models.moss:GetAttribute("PartySize") == 4,
	"Five contributors deal five hits but health growth caps at four")
h.removing:Fire(party[2])
party[2].Parent = nil
local newcomer = h:makePlayer("LateJoin")
check(h.service.attack(newcomer) and h.models.moss:GetAttribute("MaxHealth") == 413 and h.models.moss:GetAttribute("Health") == 353,
	"Late hit after a departure preserves capped maximum and prior damage")
h.service.destroy()

-- Shared kills reward every living contributor, including a pet-only hunter.
h = harness()
first = h:makePlayer("Melee")
second = h:makePlayer("PetOnly")
spectator = h:makePlayer("Spectator")
check(h.service.attack(first) and h.service.bond(second), "Melee and companion attacks coexist")
h:flush(0.3)
check(h.models.moss:GetAttribute("Health") == 203 and h.models.moss:GetAttribute("MaxHealth") == 231,
	"Delayed pet damage shares scaling and preserves melee damage")
h:finish(first, "moss")
local credited = {}
for _, credit in h.credits do credited[credit.player] = true end
check(#h.credits == 2 and credited[first] and credited[second] and not credited[spectator], "Pet-only contributor earns shared defeat credit")
h.service.destroy()

-- Reviving without a fresh hit cannot reuse contribution from an old character.
h = harness()
first = h:makePlayer("Living")
second, _, secondHealth = h:makePlayer("Revived")
check(h.service.attack(first) and h.service.attack(second), "Both characters initially contribute")
secondHealth.Health = 0
local replacement = h:makePlayer("NewCharacter")
second.Character = replacement.Character
h:finish(first, "moss")
check(#h.credits == 1 and h.credits[1].player == first, "Character identity blocks old-life defeat credit after respawn")
h.service.destroy()

-- Pet acceptance emits one authoritative position; damage waits and all pets match.
h = harness()
first, firstRoot = h:makePlayer("Companion", Vector3.new(-45, 7, -3))
check(not h.service.attack(first), "Pet test begins outside melee reach")
for _, id in { "mosswolf", "emberfox", "tidecub" } do
	h.states[first].equipped = id
	local before, at = h.models.moss:GetAttribute("Health"), h.now
	check(h.service.bond(first), "Every owned known companion can command the same skill")
	check(h.models.moss:GetAttribute("Health") == before, "Companion damage is delayed until windup completes")
	check(h.effects[#h.effects].position == h.models.moss.PrimaryPart.Position, "FX target comes from the server guardian position")
	check(not h.service.bond(first), "Repeated companion request is throttled independently")
	h:flush(at + 0.299)
	check(h.models.moss:GetAttribute("Health") == before, "Companion cannot deal damage before commit time")
	h:flush(at + 0.3)
	check(h.models.moss:GetAttribute("Health") == before - 18, "Companion commits exactly eighteen damage")
	h:flush(at + 3.2)
	check(h.service.cooldown(first) == 0, "Companion cooldown clears at the exact server boundary")
end
check(#h.effects == 3, "Only accepted casts emit companion FX")
h.states[first].owned.tidecub = false
check(not h.service.bond(first), "Unowned equipped companion fails closed")
h.states[first].equipped, h.states[first].owned.invented = "invented", true
check(not h.service.bond(first) and #h.effects == 3, "Fabricated pet cannot emit FX or deal damage")
h.states[first].equipped, h.blocked = "mosswolf", true
check(not h.service.bond(first), "Companion target requires line of sight")
h.blocked, firstRoot.Position = false, Vector3.new(-45, 7, 2)
check(not h.service.bond(first) and h.service.cooldown(first) == 0, "Rejected out-of-range command does not spend cooldown")
h.service.destroy()

-- A scheduled strike must still be valid at impact, not only at request time.
for _, reason in { "dead", "distance", "obstruction", "equipped", "equipFlip", "ownership", "inactive", "finished", "hunt", "disconnected", "respawn", "destroy" } do
	h = harness()
	first, firstRoot, firstHealth = h:makePlayer("Pending")
	check(h.service.bond(first), "Cancel test starts from an accepted skill")
	local model, state = h.models.moss, h.states[first]
	if reason == "dead" then firstHealth.Health = 0
	elseif reason == "distance" then firstRoot.Position = Vector3.new(0, 7, 0)
	elseif reason == "obstruction" then h.blocked = true
	elseif reason == "equipped" then state.equipped = "emberfox"
	elseif reason == "equipFlip" then state.equipRevision = 2 -- Equip A -> B -> A during windup.
	elseif reason == "ownership" then state.owned.mosswolf = false
	elseif reason == "inactive" then state.active = false
	elseif reason == "finished" then state.defeated.moss = true
	elseif reason == "hunt" then state.defeated = {}
	elseif reason == "disconnected" then first.Parent = nil
	elseif reason == "respawn" then
		local replacement = h:makePlayer("Replacement")
		first.Character = replacement.Character
	elseif reason == "destroy" then h.service.destroy() end
	h:flush(0.3)
	if reason == "destroy" then
		check(h.workspace:FindFirstChild("WildbondGuardians") == nil and #h.credits == 0, "Destroy cancels all scheduled strike work")
	else
		check(model:GetAttribute("Health") == 140 and #h.credits == 0, "Pending skill cancels after " .. reason)
		check(h.service.cooldown(first) > 0, "Canceled accepted strike retains its cooldown")
	end
	h.service.destroy()
end

-- Delayed work from an earlier enemy life cannot affect its replacement.
h = harness()
first = h:makePlayer("Lifetime")
check(h.service.bond(first), "Lifetime check starts an accepted companion cast")
local stale = h.scheduled[1].callback
h.scheduled = {} -- Deliver this job deliberately late, like an adversarial scheduler.
h:finish(first, "moss")
stale()
check(h.models.moss:GetAttribute("Health") == 0, "Late pet strike cannot damage a dead guardian")
h:tick(h.now + Rules.respawnDelay)
h.states[first].defeated.moss = false
stale()
check(h.models.moss:GetAttribute("Health") == 140 and #h.credits == 1, "Earlier lifetime cannot damage or credit a respawned guardian")
h.service.destroy()

-- A killing blow removes an unresolved warning before its damage can land.
h = harness()
first, _, firstHealth = h:makePlayer("Interrupt")
h:tick(0.1)
h:tick(0.901)
check(h.folder:FindFirstChild("SlamWarning"), "Interrupt case begins during a real pending warning")
h:finish(first, "moss")
check(h.folder:FindFirstChild("SlamWarning") == nil, "Guardian defeat immediately destroys its pending warning")
h:tick(h.now + 0.1)
check(firstHealth.Health == 100, "Canceled warning cannot deal post-mortem damage")
h.service.destroy()

-- Warning timing, captured target positions, boss alternation, and idle reset.
h = harness()
first, firstRoot, firstHealth = h:makePlayer("Dodge")
second, _, secondHealth = h:makePlayer("Inactive", nil, false)
h:tick(0.1)
h:tick(0.899)
check(h.folder:FindFirstChild("SlamWarning") == nil, "Encounter starts with a safe first-warning delay")
h:tick(0.901)
check(h.models.moss:GetAttribute("Status") == "Windup" and h.folder:FindFirstChild("SlamWarning"), "Warning appears before damage")
firstRoot.Position = Vector3.new(-45, 7, -5)
h:tick(1.802)
check(firstHealth.Health == 100, "Moving out of captured warning avoids the slam")
firstRoot.Position = Vector3.new(-45, 7, -11)
h:tick(4.203)
h:tick(5.104)
check(firstHealth.Health == 88 and secondHealth.Health == 100, "Standing still takes configured damage; inactive observer stays safe")
check(h.service.attack(first), "Idle reset test starts from damaged enemy health")
firstRoot.Position = Vector3.new(0, 7, 40)
local before = h.models.moss:GetAttribute("Health")
h:tick(15.103)
check(h.models.moss:GetAttribute("Health") == before, "Short disengagement preserves the encounter")
h:tick(15.104)
check(h.models.moss:GetAttribute("Health") == 140 and h.models.moss:GetAttribute("Status") == "Ready",
	"Ten seconds without eligible nearby hunters resets health and pending warnings")
h.service.destroy()

h = harness()
first, firstRoot, firstHealth = h:makePlayer("Boss", Vector3.new(65, 8, -66))
h:tick(0.1)
h:tick(0.901)
local warning = h.folder:FindFirstChild("SlamWarning")
check(warning and warning.Size.Y == 14 and warning.CFrame.Position.Z == -66, "Boss first pattern captures player disk radius seven")
firstRoot.Position = Vector3.new(65, 8, -52)
h:tick(2.102)
check(firstHealth.Health == 100, "Boss targeted disk can be evaded")
h:tick(4.503)
warning = h.folder:FindFirstChild("SlamWarning")
check(warning and warning.Size.Y == 20 and (warning.CFrame.Position - Vector3.new(65, 4.1, -72)).Magnitude < 0.001,
	"Boss second pattern anchors radius-ten disk at the boss")
check(warning:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel").Text == "RETREAT!", "Boss center burst has distinct readable instruction")
firstRoot.Position = Vector3.new(65, 8, -63)
h:tick(5.704)
check(firstHealth.Health == 78, "Boss burst uses its actual ten-stud geometry for damage")
h:tick(8.105)
warning = h.folder:FindFirstChild("SlamWarning")
check(warning and warning.Size.Y == 14 and warning.CFrame.Position.Z == -63, "Boss third warning returns to the captured-player pattern")
h.service.destroy()
check(h.workspace:FindFirstChild("WildbondGuardians") == nil and h.heartbeat:Count() == 0 and h.removing:Count() == 0,
	"Destroy removes guardian/warning Instances and disconnects service signals")
check(h.obstacle.Parent == h.workspace and first.Character.Parent == h.workspace, "Cleanup preserves unrelated world and player Instances")
check(not h.service.attack(first) and not h.service.bond(first), "Destroyed service rejects all combat actions")
h.service.destroy()
print("CombatService: " .. checks .. " construction, authority, scheduling, balance, and lifecycle checks passed; Studio physics/networking remain untested")
