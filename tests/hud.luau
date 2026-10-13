-- Actual HUD with reflected Roblox GUI properties; signals, clock, and tweens
-- are narrow doubles. Native touch controls and rendering still need Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/CombatRules")
local Expedition = require("../src/shared/Expedition")
local checks, now = 0, 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local subscription = { callback = callback, connected = true }
			table.insert(listeners, subscription)
			return { Disconnect = function() subscription.connected = false end }
		end,
		Fire = function(_, ...)
			for _, entry in listeners do if entry.connected then entry.callback(...) end end
		end,
		Active = function()
			local count = 0
			for _, entry in listeners do if entry.connected then count += 1 end end
			return count
		end,
	}
end
local activated, healthEvents = {}, {}
roblox.implementProperty("GuiButton", "Activated", function(item)
	if not activated[item] then activated[item] = signal() end
	return activated[item]
end)
roblox.implementProperty("Humanoid", "HealthChanged", function(item)
	if not healthEvents[item] then healthEvents[item] = signal() end
	return healthEvents[item]
end)
roblox.implementMethod("Instance", "WaitForChild", function(item, name)
	return item:FindFirstChild(name)
end)
local scene = roblox.Instance.new("Workspace")
local camera = roblox.Instance.new("Camera")
local viewport = roblox.Vector2.new(568, 320)
camera.ViewportSize = viewport
camera.Parent, scene.CurrentCamera = scene, camera
local playerGui = roblox.Instance.new("Folder")
local character = roblox.Instance.new("Model")
local humanoid = roblox.Instance.new("Humanoid")
humanoid.Health, humanoid.MaxHealth, humanoid.Parent = 100, 100, character
local render, input, added = signal(), signal(), signal()
local player = {
	Character = character, CharacterAdded = added,
	WaitForChild = function(_, name) assert(name == "PlayerGui"); return playerGui end,
}
local pending, commands = {}, {}
local command = { FireServer = function(_, action, id) table.insert(commands, { action, id }) end }
local services = {
	Players = { LocalPlayer = player }, RunService = { RenderStepped = render },
	UserInputService = { TouchEnabled = true, InputBegan = input },
	TweenService = { Create = function(_, item, _, goal)
		return { Play = function() for key, value in goal do item[key] = value end end }
	end },
}
local environment = {
	game = { GetService = function(_, name) return assert(services[name]) end },
	workspace = scene, os = { clock = function() return now end },
	TweenInfo = { new = function(seconds) return { seconds } end },
	task = { spawn = function(callback, ...) callback(...) end, delay = function(_, callback) table.insert(pending, callback) end },
}
for _, name in { "Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "UDim", "Enum" } do environment[name] = roblox[name] end
local Hud = luau.load(fs.readFile("src/client/Hud.luau"), { environment = environment, debugName = "Hud" })()
local hud = Hud.start(command, Expedition.pets, Rules)
local screen = assert(playerGui:FindFirstChild("WildbondHUD"))
local canvas = assert(screen:FindFirstChild("Canvas"))
local function textItem(text)
	for _, item in screen:GetDescendants() do
		if item:IsA("TextLabel") or item:IsA("TextButton") then if item.Text == text then return item end end
	end
	error("Missing HUD text: " .. text)
end
local strikeButton, bondButton = textItem("STRIKE"), textItem("BOND")
local scale = canvas:FindFirstChildOfClass("UIScale").Scale
check(math.abs(strikeButton.Position.Y.Offset * scale + 194) < 0.5, "Mobile strike stays 194 physical pixels above the bottom despite HUD scaling")
check(strikeButton.Position.Y == bondButton.Position.Y and bondButton.Position.X.Offset < strikeButton.Position.X.Offset, "Mobile attack controls sit side by side above native jump")
activated[strikeButton]:Fire()
now = 0.5
activated[strikeButton]:Fire()
check(#commands == 1, "HUD does not send a melee swing before the shared 0.6s cooldown")
now = 0.6
activated[strikeButton]:Fire()
check(#commands == 2 and commands[2][1] == "attack", "Melee becomes available at the rules cooldown")

activated[bondButton]:Fire()
now = 0.7
activated[bondButton]:Fire()
check(#commands == 3 and commands[3][1] == "bond", "Immediate repeated bond request is locally throttled")
now = 0.81
input:Fire({ KeyCode = roblox.Enum.KeyCode.Q }, false)
check(#commands == 4, "Rejected or unanswered bond request does not start the combat cooldown")
hud:bondAccepted()
check(bondButton.Text == "BOND 3.2", "Accepted server bond starts a one-decimal cooldown display")
now = 3.0
input:Fire({ KeyCode = roblox.Enum.KeyCode.ButtonL2 }, false)
check(#commands == 4, "L2 respects the accepted server cooldown")
now = 4.02
render:Fire(1)
input:Fire({ KeyCode = roblox.Enum.KeyCode.ButtonL2 }, false)
check(#commands == 5 and bondButton.Text == "BOND", "Controller bond returns after the shared cooldown")
input:Fire({ KeyCode = roblox.Enum.KeyCode.Q }, true)
check(#commands == 5, "Processed chat/UI inputs do not trigger combat")

local state = Expedition.new()
state.active = true
state.timing = { elapsed = 25, deaths = 1 }
hud:render(state)
textItem("0:25 elapsed · 1 fall")
now += 3.1
render:Fire(1)
check(textItem("0:28 elapsed · 1 fall") ~= nil, "Elapsed HUD time advances from the snapshot without comparing server and client clocks")
local waypoint = assert(scene:FindFirstChild("LocalHuntWaypoint"))
check(waypoint.Position == roblox.Vector3.new(Rules.foes[1].position.x, Rules.foes[1].position.y + 3, Rules.foes[1].position.z), "Live foe waypoint follows shared arena coordinates")
state.defeated.moss = true
hud:render(state)
check(waypoint.Position == roblox.Vector3.new(-45, 10, -25), "Defeated foe waypoint switches to its distinct crystal landmark")
state.active = false
state.timing = { lastDuration = 126, bestDuration = 98, lastDeaths = 1 }
hud:render(state, "Hunt complete.", true)
check(textItem("Last 2:06 · best 1:38 · falls 1") ~= nil, "Finished hunt shows duration, personal best and falls")

viewport = roblox.Vector2.new(390, 844)
camera.ViewportSize = viewport
render:Fire(1)
scale = canvas:FindFirstChildOfClass("UIScale").Scale
check(math.abs(strikeButton.Position.Y.Offset * scale + 194) < 0.5, "Portrait resize preserves the physical touch-control gap")
hud:destroy()
hud:destroy()
check(#playerGui:GetChildren() == 0 and scene:FindFirstChild("LocalHuntWaypoint") == nil, "HUD cleanup removes owned GUI and local waypoint")
check(render.Active() == 0 and input.Active() == 0 and added.Active() == 0 and healthEvents[humanoid].Active() == 0, "HUD cleanup disconnects frame, input, character and health signals")
input:Fire({ KeyCode = roblox.Enum.KeyCode.Q }, false)
for _, callback in pending do callback() end
hud:render(state)
hud:bondAccepted()
check(#commands == 5, "Removed HUD cannot issue further input commands")
check(#playerGui:GetChildren() == 0, "Delayed notifications and late updates cannot revive a destroyed HUD")
print("HUD: " .. checks .. " reflected GUI, input, timing and cleanup checks passed; native controls/rendering require Studio")
