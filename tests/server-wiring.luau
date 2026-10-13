-- Runs the actual entrypoint and pure rules. Service boundaries, signals and time
-- are narrow stubs; this does not exercise Roblox networking or character physics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Vector3 = require("@lune/roblox").Vector3
local Expedition = require("../src/shared/Expedition")
local HuntMetrics = require("../src/shared/HuntMetrics")
local CombatRules = require("../src/shared/CombatRules")
local now, checks = 0, 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function signal()
	local listeners = {}
	local function connect(callback, once)
		local listener = { callback = callback, active = true, once = once }
		table.insert(listeners, listener)
		return { Disconnect = function() listener.active = false end }
	end
	return {
		Connect = function(_, callback) return connect(callback, false) end,
		Once = function(_, callback) return connect(callback, true) end,
		Fire = function(_, ...)
			for _, listener in listeners do
				if listener.active then
					if listener.once then listener.active = false end
					listener.callback(...)
				end
			end
		end,
	}
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), list = {} }
function players:GetPlayers() return self.list end
local function character()
	local humanoid = { Health = 35, MaxHealth = 35, Died = signal() }
	local root = { Position = Vector3.zero }
	return {
		WaitForChild = function(_, name) assert(name == "Humanoid"); return humanoid end,
		FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
		FindFirstChildOfClass = function(_, class) return if class == "Humanoid" then humanoid else nil end,
	}, root, humanoid
end
local function player(name)
	local model, root, humanoid = character()
	local value = { Name = name, Parent = players, Character = model, CharacterAdded = signal(), attributes = {} }
	function value:SetAttribute(key, item) self.attributes[key] = item end
	table.insert(players.list, value)
	return value, root, humanoid
end
local hunter, root, health = player("Hunter")
local spectator, _, spectatorHealth = player("Spectator")
local prompts = {}
for index, id in { "start", "return", "moss", "river", "ruins" } do
	prompts[id] = {
		Triggered = signal(),
		Parent = { Position = Vector3.new(index * 20, 0, 0), IsA = function(_, class) return class == "BasePart" end },
	}
end
local tokens = { Expedition = {}, HuntMetrics = {}, CombatRules = {}, DodgeRules = {}, WorldBuilder = {}, CombatService = {}, DodgeService = {} }
local shared = { WaitForChild = function(_, name) return assert(tokens[name], name) end }
local remotes = {}
local instances = { new = function(class)
	local instance = { class = class }
	if class == "RemoteEvent" then
		instance.OnServerEvent, instance.calls = signal(), {}
		function instance:FireClient(recipient, ...)
			table.insert(self.calls, { player = recipient, args = { ... } })
		end
		table.insert(remotes, instance)
	end
	return instance
end }
local getState, defeated, bondEffect, closed
local attacks, bonds, destroyed = 0, 0, 0
local dodges, dodgeDestroyed, dodgeInputs = 0, 0, {}
local swingAllowed = true
local swingHit = true
local swingTarget = Vector3.new(6, 7, 9)
local dodgeDirection = Vector3.new(1, 0, 0)
local combat = {
	attack = function(value)
		assert(getState(value))
		if not swingAllowed then return false, "Your next swing is not ready yet." end
		attacks += 1
		return true, "Swing!", swingTarget, swingHit
	end,
	bond = function(value) assert(getState(value)); bonds += 1; return true end,
	destroy = function() destroyed += 1 end,
}
local dodge = {
	dodge = function(value, payload)
		assert(getState(value))
		table.insert(dodgeInputs, { player = value, payload = payload })
		if typeof(payload) ~= "Vector3" then return false, "Invalid dodge." end
		dodges += 1
		return true, "Dodge!", dodgeDirection
	end,
	destroy = function() dodgeDestroyed += 1 end,
}
local modules = {
	[tokens.Expedition] = Expedition,
	[tokens.HuntMetrics] = HuntMetrics,
	[tokens.CombatRules] = CombatRules,
	[tokens.DodgeRules] = require("../src/shared/DodgeRules"),
	[tokens.WorldBuilder] = { build = function() return { prompts = prompts } end },
	[tokens.CombatService] = { start = function(stateCallback, defeatCallback, effectCallback)
		getState, defeated, bondEffect = stateCallback, defeatCallback, effectCallback
		return combat
	end },
	[tokens.DodgeService] = { start = function() return dodge end },
}
luau.load(fs.readFile("src/server/init.server.luau"), {
	debugName = "init.server",
	environment = {
		game = {
			GetService = function(_, name)
				if name == "Players" then return players end
				assert(name == "ReplicatedStorage", name)
				return { WaitForChild = function(_, child) assert(child == "Wildbond"); return shared end }
			end,
			BindToClose = function(_, callback) closed = callback end,
		},
		script = { WaitForChild = function(_, name) return assert(tokens[name], name) end },
		Instance = instances,
		require = function(token) return assert(modules[token], "Unknown module") end,
		os = { clock = function() return now end },
		task = { spawn = function(callback, ...) callback(...) end },
	},
})()
local function remote(name)
	for _, value in remotes do if value.Name == name then return value end end
	error("Missing remote: " .. name)
end
local command, update, effect = remote("Command"), remote("Update"), remote("Effect")
local function latest(value)
	for index = #update.calls, 1, -1 do
		if update.calls[index].player == value then return update.calls[index].args end
	end
	error("No snapshot for player")
end
local function trigger(id)
	root.Position = prompts[id].Parent.Position
	prompts[id].Triggered:Fire(hunter)
end
check(health.Health == 100 and health.MaxHealth == 100 and spectatorHealth.Health == 100, "Existing characters initialize at the configured health")
command.OnServerEvent:Fire(hunter, "sync")
local initial = latest(hunter)[1]
check(initial.shells == 0 and not initial.active and initial.timing.elapsed == nil, "Initial snapshot includes inactive timing")
initial.owned.fake, initial.defeated.moss, initial.timing.deaths = true, true, 999
now = 1
command.OnServerEvent:Fire(hunter, "sync")
command.OnServerEvent:Fire(spectator, "sync")
check(not latest(hunter)[1].owned.fake and not latest(hunter)[1].defeated.moss and latest(hunter)[1].timing.deaths == 0, "Mutating delivered snapshots cannot change server progression or metrics")
check(not latest(spectator)[1].active and latest(spectator)[1].shells == 0, "Players have independent snapshots")

now = 2
health.Health = 40
root.Position = prompts.start.Parent.Position + Vector3.new(15, 0, 0)
prompts.start.Triggered:Fire(hunter)
check(not getState(hunter).active and health.Health == 40, "Out-of-range start neither opens a hunt nor heals")
health.Health = 0
trigger("start")
check(not getState(hunter).active and health.Health == 0, "Dead characters cannot start a hunt")
health.Health = 40
trigger("start")
check(latest(hunter)[1].active and latest(hunter)[1].timing.elapsed == 0 and health.Health == 100, "Accepted start begins timing and heals")
now, health.Health = 2.3, 40
trigger("start")
check(latest(hunter)[3] == false and health.Health == 40, "Rejected active-hunt restart does not heal")

now = 3
command.OnServerEvent:Fire(hunter, "attack")
command.OnServerEvent:Fire(hunter, "bond")
command.OnServerEvent:Fire(hunter, "dodge", Vector3.new(0, 0, -1))
command.OnServerEvent:Fire(hunter, "sync")
check(attacks == 1 and bonds == 1 and latest(hunter)[1].timing.elapsed == 1, "Attack, bond and sync use independent rate limits at the same instant")
check(dodges == 1 and effect.calls[1].args[1] == "melee" and effect.calls[1].args[2] == swingTarget, "Accepted melee routes the server-selected cosmetic swing position")
check(effect.calls[1].args[3] == true, "Confirmed server hits explicitly enable impact effects")
check(effect.calls[2].player == hunter and effect.calls[2].args[1] == "dodge" and effect.calls[2].args[2] == dodgeDirection, "Dodge uses its independent command interval and server-authorized effect direction")
check(health.Health == 40 and getState(hunter).shells == 0 and not getState(hunter).defeated.moss, "Movement and cosmetic attacks cannot heal or award progression")
command.OnServerEvent:Fire(hunter, "attack")
command.OnServerEvent:Fire(hunter, "bond")
command.OnServerEvent:Fire(hunter, "dodge", Vector3.new(0, 0, -1))
check(attacks == 1 and bonds == 1, "Repeated commands remain throttled within their action")
check(dodges == 1 and #dodgeInputs == 1 and #effect.calls == 2, "Repeated dodge never reaches the movement service or creates an effect")
now = 3.11
swingHit = false
command.OnServerEvent:Fire(hunter, "attack")
check(effect.calls[#effect.calls].args[3] == false, "An accepted empty swing never claims a confirmed hit")
swingHit = true
command.OnServerEvent:Fire(hunter, "bond")
check(attacks == 2 and bonds == 2, "Each combat command resumes after its own interval")
bondEffect(hunter, Vector3.new(5, 7, 9))
local bondCall = effect.calls[#effect.calls]
check(bondCall.player == hunter and bondCall.args[1] == "bond", "Server combat effects route to the correct client")
now, swingAllowed = 3.25, false
local beforeRejected = #effect.calls
command.OnServerEvent:Fire(hunter, "attack")
check(attacks == 2 and #effect.calls == beforeRejected, "Rejected melee never plays a success effect")
local malformedDodge = { x = 1, y = 0, z = 0, freeReward = 9999 }
command.OnServerEvent:Fire(hunter, "dodge", malformedDodge)
check(#dodgeInputs == 2 and dodgeInputs[2].player == hunter and dodgeInputs[2].payload == malformedDodge, "Untyped direction payload reaches the authoritative movement validator unchanged")
check(latest(hunter)[3] == false and #effect.calls == beforeRejected and health.Health == 40 and getState(hunter).shells == 0, "Rejected dodge reports failure without an effect, healing or rewards")
now = 3.5
command.OnServerEvent:Fire(hunter, "unlock", "emberfox")
check(latest(hunter)[3] == false and not latest(hunter)[1].owned.emberfox and latest(hunter)[1].shells == 0, "Server enforces companion price without charging insufficient funds")
command.OnServerEvent:Fire(hunter, "equip", "emberfox")
check(latest(hunter)[3] == false and hunter.attributes.CompanionId == "mosswolf", "Server rejects equipping an unowned companion")
local sent = #update.calls
for _, action in { "defeat", "collect", "claim", "start", "unknown", string.rep("x", 21), 42, {} } do
	command.OnServerEvent:Fire(hunter, action, "moss")
	command.OnServerEvent:Fire(spectator, action, "moss")
end
check(#update.calls == sent and not getState(hunter).defeated.moss and not getState(spectator).active, "Spoofed remote progression cannot award hunters or spectators credit")
trigger("moss")
check(latest(hunter)[3] == false and not latest(hunter)[1].collected.moss and health.Health == 40, "Crystal collection needs a server-confirmed defeat and grants no heal")

now, health.Health = 8, 0
health.Died:Fire()
health.Died:Fire()
check(latest(hunter)[1].timing.deaths == 1 and latest(hunter)[1].active, "A death is counted once and hunt progress survives")
local staleHealth = health
hunter.Character, root, health = character()
hunter.CharacterAdded:Fire(hunter.Character)
now, health.Health = 9, 40
command.OnServerEvent:Fire(hunter, "sync")
check(latest(hunter)[1].timing.elapsed == 7 and latest(hunter)[1].timing.deaths == 1, "Respawn preserves the original server timer and death count")
for index, id in Expedition.targetIds do
	now = 29 + index
	defeated(hunter, id)
	check(latest(hunter)[1].defeated[id] and not latest(spectator)[1].defeated[id], "Server defeat callback credits only the given hunter")
	trigger(id)
	check(latest(hunter)[1].collected[id] and health.Health == 40, "Valid collection records progress without free combat healing")
end
now = 35
trigger("return")
local completed = latest(hunter)
check(completed[3] == true and completed[1].shells == 60 and completed[1].huntsCompleted == 1 and health.Health == 100, "Completed hunt grants one reward and heals")
check(completed[1].timing.lastDuration == 33 and completed[1].timing.bestDuration == 33 and completed[1].timing.lastDeaths == 1 and completed[1].timing.elapsed == nil, "Claim records server duration, best time and deaths")
check(string.find(completed[2], "0:33", 1, true) and string.find(completed[2], "1 falls", 1, true), "Completion message reports actual measured results")
now, health.Health = 35.3, 40
trigger("return")
check(latest(hunter)[3] == false and latest(hunter)[1].shells == 60 and health.Health == 40, "Duplicate claim cannot mint rewards or heal")

now = 36
trigger("start")
check(latest(hunter)[1].timing.elapsed == 0 and latest(hunter)[1].timing.deaths == 0 and latest(hunter)[1].timing.lastDuration == 33, "Repeat hunt resets current metrics and preserves history")
players.PlayerRemoving:Fire(hunter)
hunter.Parent = nil
check(getState(hunter) == nil, "Leaving clears server session data")
sent = #update.calls
staleHealth.Died:Fire()
health.Died:Fire()
defeated(hunter, "ruins")
prompts.start.Triggered:Fire(hunter)
command.OnServerEvent:Fire(hunter, "sync")
command.OnServerEvent:Fire(hunter, "attack")
command.OnServerEvent:Fire(hunter, "dodge", Vector3.new(0, 0, -1))
check(#update.calls == sent and attacks == 2, "Late death, defeat, prompt and command events safely ignore a departed player")
check(#dodgeInputs == 2 and dodges == 1, "Departed players cannot reach the dodge service")
players.PlayerAdded:Fire(hunter)
hunter.Parent = players
now = 37
command.OnServerEvent:Fire(hunter, "sync")
check(latest(hunter)[1].shells == 0 and latest(hunter)[1].timing.lastDuration == nil and latest(hunter)[1].timing.deaths == 0, "A new session has no leaked metrics or rewards")
closed()
check(destroyed == 1, "Server shutdown destroys the combat service")
check(dodgeDestroyed == 1, "Server shutdown also destroys active movement service state")
print("Server wiring: " .. checks .. " entrypoint/rules checks passed; Roblox signals, networking and physics remain untested")
