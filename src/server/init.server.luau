--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Wildbond")
shared:SetAttribute("BuildVersion", "0.4.0")
local Expedition = require(shared:WaitForChild("Expedition"))
local CombatRules = require(shared:WaitForChild("CombatRules"))
local HuntMetrics = require(shared:WaitForChild("HuntMetrics"))
local Progression = require(shared:WaitForChild("Progression"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local CombatService = require(script:WaitForChild("CombatService"))
local DodgeService = require(script:WaitForChild("DodgeService"))
local PetService = require(script:WaitForChild("PetService"))
local world = WorldBuilder.build()

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = shared
local command = Instance.new("RemoteEvent")
command.Name = "Command"
command.Parent = remotes
local update = Instance.new("RemoteEvent")
update.Name = "Update"
update.Parent = remotes
local effect = Instance.new("RemoteEvent")
effect.Name = "Effect"
effect.Parent = remotes

-- This alpha deliberately keeps session data in memory. No Robux purchases exist.
local sessions = {}
local measurements = {}
local profiles = {}
local lastCommand = {}
local lastPrompt = {}
local actionIntervals = { sync = 1, attack = 0.1, bond = 0.1, dodge = 0.1, unlock = 0.25, equip = 0.25 }

local function send(player, message, success)
	local state = sessions[player]
	if not state or player.Parent ~= Players then
		return
	end
	player:SetAttribute("CompanionId", state.equipped)
	local snapshot = Expedition.snapshot(state)
	snapshot.timing = HuntMetrics.snapshot(measurements[player], os.clock())
	snapshot.progression = Progression.snapshot(profiles[player])
	update:FireClient(player, snapshot, message, success)
end

local combat = CombatService.start(function(player)
	return sessions[player]
end, function(player, id)
	local state = sessions[player]
	if state then
		local success, message = Expedition.defeat(state, id)
		send(player, message, success)
	end
end, function(player, targetPosition)
	effect:FireClient(player, "bond", targetPosition)
end, function(player, definition)
	local profile = profiles[player]
	if not profile or player.Parent ~= Players then return end
	local gained = Progression.award(profile, definition)
	if gained == nil then return end
	local reward = Progression.rewards[definition.kind]
	local message = string.format("+%d coins · +%d XP", reward.coins, reward.xp)
	if gained > 0 then message ..= string.format(" · Level %d!", profile.level) end
	send(player, message, true)
end)
local companions = PetService.start(function(player)
	return sessions[player]
end, combat, function(player, targetPosition)
	effect:FireClient(player, "bond", targetPosition)
end)
local dodging = DodgeService.start()

local function addPlayer(player)
	if sessions[player] then
		return
	end
	sessions[player] = Expedition.new()
	measurements[player] = HuntMetrics.new()
	profiles[player] = Progression.new()
	player:SetAttribute("CompanionId", "mosswolf")
	local function characterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.MaxHealth = CombatRules.playerMaxHealth
			humanoid.Health = humanoid.MaxHealth
			humanoid.Died:Once(function()
				if measurements[player] then
					HuntMetrics.death(measurements[player])
				end
				send(player, "Take a breath. Your hunt progress stays when you respawn.", false)
			end)
		end
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	measurements[player] = nil
	profiles[player] = nil
	lastCommand[player] = nil
	lastPrompt[player] = nil
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

-- ProximityPrompt events still need server distance and alive checks.
for id, prompt in world.prompts do
	prompt.Triggered:Connect(function(player)
		local state = sessions[player]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local landmark = prompt.Parent
		if not state or not root or not humanoid or humanoid.Health <= 0 or not landmark:IsA("BasePart") then
			return
		end
		if (root.Position - landmark.Position).Magnitude > 14 then
			return
		end
		local now = os.clock()
		if now - (lastPrompt[player] or -math.huge) < 0.25 then
			return
		end
		lastPrompt[player] = now
		local success, message
		if id == "start" then
			success, message = Expedition.start(state)
			if success then
				HuntMetrics.start(measurements[player], now)
				humanoid.Health = humanoid.MaxHealth
			end
		elseif id == "return" then
			success, message = Expedition.claim(state)
			if success then
				HuntMetrics.finish(measurements[player], now)
				humanoid.Health = humanoid.MaxHealth
				local duration = measurements[player].lastDuration or 0
				message = string.format("Hunt complete! +60 shells · %d:%02d · %d falls", math.floor(duration / 60), math.floor(duration % 60), measurements[player].lastDeaths or 0)
			end
		else
			success, message = Expedition.collect(state, id)
		end
		send(player, message, success)
	end)
end

command.OnServerEvent:Connect(function(player, action, payload)
	if typeof(action) ~= "string" or #action > 20 then
		return
	end
	local interval = actionIntervals[action]
	if not interval then return end
	local state = sessions[player]
	if not state then
		return
	end
	local now = os.clock()
	local history = lastCommand[player]
	if not history then
		history = {}
		lastCommand[player] = history
	end
	if now - (history[action] or -math.huge) < interval then
		return
	end
	history[action] = now
	if action == "sync" then
		send(player)
	elseif action == "attack" then
		local success, message, targetPosition, hit = combat.attack(player)
		if success and typeof(targetPosition) == "Vector3" then
			effect:FireClient(player, "melee", targetPosition, hit == true)
		end
		-- Quiet successful swings; keep mission text visible during combat.
		if not success and message ~= "Your next swing is not ready yet." then
			send(player, message, false)
		end
	elseif action == "bond" then
		local success, message = combat.bond(player)
		if not success then send(player, message, false) end
	elseif action == "dodge" then
		local success, message, direction = dodging.dodge(player, payload)
		if success then effect:FireClient(player, "dodge", direction)
		else send(player, message, false) end
	elseif action == "unlock" or action == "equip" then
		local petId = payload
		if typeof(petId) ~= "string" or #petId > 32 then
			return
		end
		local success, message = Expedition[action](state, petId)
		send(player, message, success)
	end
end)

game:BindToClose(function()
	companions.destroy()
	combat.destroy()
	dodging.destroy()
end)

print("Wildbond 0.4.0 ready: roaming foes, companion HP and automatic combat; purchases disabled.")
