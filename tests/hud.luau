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
humanoid.MoveDirection = roblox.Vector3.new(3, 0, 4)
local root = roblox.Instance.new("Part")
root.Name, root.CFrame, root.Parent = "HumanoidRootPart", roblox.CFrame.new(0, 7, 0), character
local render, input, added = signal(), signal(), signal()
local player = {
	Character = character, CharacterAdded = added,
	WaitForChild = function(_, name) assert(name == "PlayerGui"); return playerGui end,
}
local pending, commands = {}, {}
local command = { FireServer = function(_, action, id) table.insert(commands, { action, id }) end }
local boundActions, focus = {}, nil
local services = {
	Players = { LocalPlayer = player }, RunService = { RenderStepped = render },
	UserInputService = { TouchEnabled = true, InputBegan = input, GetFocusedTextBox = function() return focus end },
	ContextActionService = {
		BindActionAtPriority = function(_, name, callback, touch, priority, key)
			check(touch == false and priority > roblox.Enum.ContextActionPriority.High.Value and key == roblox.Enum.KeyCode.Space, "Double Space intercepts only Space above Roblox's jump action")
			boundActions[name] = callback
		end,
		UnbindAction = function(_, name) boundActions[name] = nil end,
	},
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
local dodgeButton = textItem("DODGE")
local hotbar = assert(canvas:FindFirstChild("SkillHotbar"))
for index = 1, 8 do
	local slot = assert(hotbar:FindFirstChild("SkillSlot" .. tostring(index)))
	check(slot:IsA(if index == 1 then "TextButton" else "TextLabel"), "Only learned slot 1 is interactive; slot " .. tostring(index))
end
local scale = canvas:FindFirstChildOfClass("UIScale").Scale
check(-strikeButton.Position.Y.Offset * scale >= 194, "Mobile strike preserves at least the 194-pixel native-jump gap despite HUD scaling")
check(strikeButton.Position.Y == bondButton.Position.Y and bondButton.Position.X.Offset < strikeButton.Position.X.Offset, "Mobile attack controls sit side by side above native jump")
check(math.abs(hotbar.Position.Y.Offset * scale + 145) < 0.5, "Hotbar keeps a physical gap above native mobile controls")
local function actionRowsClear()
	local strikeBottom = (-strikeButton.Position.Y.Offset - strikeButton.Size.Y.Offset) * scale
	local hotbarTop = (-hotbar.Position.Y.Offset + hotbar.Size.Y.Offset) * scale
	local dodgeBottom = (-dodgeButton.Position.Y.Offset - dodgeButton.Size.Y.Offset) * scale
	local strikeTop = -strikeButton.Position.Y.Offset * scale
	return strikeBottom >= hotbarTop + 11 and dodgeBottom >= strikeTop + 19
end
check(actionRowsClear(), "Action buttons, dodge and the eight-slot hotbar do not overlap on a narrow landscape screen")
activated[strikeButton]:Fire()
now = 0.5
activated[strikeButton]:Fire()
check(#commands == 1, "HUD does not send a melee swing before the shared 0.6s cooldown")
now = 0.6
activated[strikeButton]:Fire()
check(#commands == 2 and commands[2][1] == "attack", "Melee becomes available at the rules cooldown")
check(strikeButton.Text == "STRIKE", "A raw click never starts the visible melee cooldown")
hud:meleeAccepted()
check(strikeButton.Text == "STRIKE 0.6", "Accepted server melee starts the cooldown display")

activated[bondButton]:Fire()
now = 0.7
activated[bondButton]:Fire()
check(#commands == 3 and commands[3][1] == "bond", "Immediate repeated bond request is locally throttled")
now = 0.81
input:Fire({ KeyCode = roblox.Enum.KeyCode.One }, false)
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
input:Fire({ KeyCode = roblox.Enum.KeyCode.One }, true)
check(#commands == 5, "Processed chat/UI inputs do not trigger combat")
input:Fire({ KeyCode = roblox.Enum.KeyCode.Q }, false)
input:Fire({ KeyCode = roblox.Enum.KeyCode.F }, false)
for _, key in { "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" } do input:Fire({ KeyCode = roblox.Enum.KeyCode[key] }, false) end
check(#commands == 5, "Removed F/Q bindings and unlearned slots send no fake actions")
focus = {}
input:Fire({ KeyCode = roblox.Enum.KeyCode.ButtonR2 }, false)
input:Fire({ KeyCode = roblox.Enum.KeyCode.ButtonB }, false)
check(#commands == 5, "Focused text input blocks attacks and dodge")
focus = nil

local space = assert(boundActions.WildbondDoubleSpaceDodge)
check(space("", roblox.Enum.UserInputState.Begin) == roblox.Enum.ContextActionResult.Pass, "First Space retains normal Roblox jump")
input:Fire({ KeyCode = roblox.Enum.KeyCode.Space }, true)
now += 0.2
check(space("", roblox.Enum.UserInputState.Begin) == roblox.Enum.ContextActionResult.Sink, "A processed default-jump event cannot erase CAS history; second Space is consumed")
check(#commands == 6 and commands[6][1] == "dodge" and (commands[6][2] - roblox.Vector3.new(0.6, 0, 0.8)).Magnitude < 0.001, "Double Space sends a normalized horizontal move direction")
check(dodgeButton.Text == "DODGE", "Unanswered dodge does not start a displayed cooldown")
hud:dodgeAccepted()
check(dodgeButton.Text == "DODGE 4.0", "Accepted server dodge displays the shared cooldown")
now += 1
input:Fire({ KeyCode = roblox.Enum.KeyCode.ButtonB }, false)
activated[dodgeButton]:Fire()
check(#commands == 6, "Touch and gamepad dodge respect the accepted cooldown")
now += 3.1
humanoid.MoveDirection = roblox.Vector3.zero
input:Fire({ KeyCode = roblox.Enum.KeyCode.ButtonB }, false)
check(#commands == 7 and commands[7][2] == roblox.Vector3.new(0, 0, -1), "Stationary controller dodge uses the character's forward direction")
now += 0.3
space("", roblox.Enum.UserInputState.Begin)
now += 0.29
check(space("", roblox.Enum.UserInputState.Begin) == roblox.Enum.ContextActionResult.Pass and #commands == 7, "Two Space taps outside 0.28s remain normal jumps")
focus = {}
space("", roblox.Enum.UserInputState.Begin)
focus = nil
now += 0.1
check(space("", roblox.Enum.UserInputState.Begin) == roblox.Enum.ContextActionResult.Pass and #commands == 7, "Chat-focused Space cannot seed a later dodge")
input:Fire({ KeyCode = roblox.Enum.KeyCode.Space }, true)
now += 0.1
check(space("", roblox.Enum.UserInputState.Begin) == roblox.Enum.ContextActionResult.Sink and #commands == 8, "Only CAS owns Space history across processed UIS jump events")
input:Fire({ KeyCode = roblox.Enum.KeyCode.Space }, true)
now += 0.1
check(space("", roblox.Enum.UserInputState.Begin) == roblox.Enum.ContextActionResult.Pass and #commands == 8, "A second Sink's processed event cannot corrupt the next normal first tap")

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
check(-strikeButton.Position.Y.Offset * scale >= 194 and actionRowsClear(), "Portrait resize preserves touch-control gaps without overlapping the hotbar")
hud:destroy()
hud:destroy()
check(#playerGui:GetChildren() == 0 and scene:FindFirstChild("LocalHuntWaypoint") == nil, "HUD cleanup removes owned GUI and local waypoint")
check(render.Active() == 0 and input.Active() == 0 and added.Active() == 0 and healthEvents[humanoid].Active() == 0, "HUD cleanup disconnects frame, input, character and health signals")
input:Fire({ KeyCode = roblox.Enum.KeyCode.One }, false)
for _, callback in pending do callback() end
hud:render(state)
hud:bondAccepted()
hud:dodgeAccepted()
hud:meleeAccepted()
check(#commands == 8 and boundActions.WildbondDoubleSpaceDodge == nil, "Removed HUD cannot issue input commands and releases its Space action")
check(#playerGui:GetChildren() == 0, "Delayed notifications and late updates cannot revive a destroyed HUD")
print("HUD: " .. checks .. " reflected GUI, input, timing and cleanup checks passed; native controls/rendering require Studio")
