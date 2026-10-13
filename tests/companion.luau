-- Executes the actual view against Lune's Roblox instance/property reflection.
-- Engine signals, Player state, and raycast results are explicit test doubles.
local Roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local checks = 0

local function check(condition, message)
	assert(condition, message)
	checks += 1
end

local function signal()
	local subscriptions = {}
	return {
		Connect = function(_, callback)
			local subscription = { callback = callback, connected = true }
			table.insert(subscriptions, subscription)
			return {
				Disconnect = function()
					subscription.connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, subscription in subscriptions do
				if subscription.connected then
					subscription.callback(...)
				end
			end
		end,
		Active = function()
			local count = 0
			for _, subscription in subscriptions do
				if subscription.connected then
					count += 1
				end
			end
			return count
		end,
	}
end

local render, added, removed, equipped = signal(), signal(), signal(), signal()
local scene = Roblox.Instance.new("Workspace")
local raycastCount, lastRaycastParameters = 0, nil
Roblox.implementMethod("Workspace", "Raycast", function(_, _, direction, parameters)
	check(direction.Y < 0, "Ground sampling points downward")
	raycastCount += 1
	lastRaycastParameters = parameters
	return { Position = Roblox.Vector3.new(0, 4, 0) }
end)

local function characterAt(position)
	local character = Roblox.Instance.new("Model")
	local root = Roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	-- Lune stores these independently; Studio synchronizes them.
	root.CFrame = Roblox.CFrame.new(position)
	root.Position = position
	root.Parent = character
	return character, root
end

local character, root = characterAt(Roblox.Vector3.new(0, 6.5, 35))
local petId = "mosswolf"
local player = {
	Character = character,
	CharacterAdded = added,
	CharacterRemoving = removed,
	GetAttribute = function(_, attribute)
		check(attribute == "CompanionId", "Reads the equipped companion attribute")
		return petId
	end,
	GetAttributeChangedSignal = function(_, attribute)
		check(attribute == "CompanionId", "Subscribes to equipped companion changes")
		return equipped
	end,
}
local environment = setmetatable({
	game = {
		GetService = function(_, name)
			check(name == "RunService", "Client view only requests RunService")
			return { RenderStepped = render }
		end,
	},
	workspace = scene,
	Instance = Roblox.Instance,
	Color3 = Roblox.Color3,
	CFrame = Roblox.CFrame,
	Vector3 = Roblox.Vector3,
	Enum = Roblox.Enum,
	RaycastParams = { new = function() return {} end },
}, { __index = getfenv() })

local constructor = assert(loadstring(fs.readFile("src/client/CompanionView.luau"), "CompanionView"))
setfenv(constructor, environment)
local CompanionView = constructor()
local cleanup, strike = CompanionView.start(player)
check(type(strike) == "function", "View exposes a server-triggered local strike animation")

local function step(frames, dt)
	for _ = 1, frames do
		render:Fire(dt)
	end
end

local function assertCosmetic(model)
	check(model:GetAttribute("CosmeticOnly") == true, "Companion is marked cosmetic")
	for _, piece in model:GetChildren() do
		check(piece:IsA("BasePart"), "Procedural companion contains parts")
		check(piece.Anchored and not piece.CanCollide and not piece.CanQuery and not piece.CanTouch, "Cosmetic geometry cannot block physics or queries")
	end
end

step(60, 1 / 60)
local model = assert(scene:FindFirstChild("LocalTrailCompanion"))
check(model.PrimaryPart == model.Body, "Body is the model's primary part")
check(model:GetAttribute("CompanionId") == "mosswolf", "Default equipped wolf is represented")
assertCosmetic(model)
check(raycastCount > 0 and raycastCount < 20, "Ground sampling is throttled")
check(lastRaycastParameters.FilterType == Roblox.Enum.RaycastFilterType.Exclude, "Ground sampling excludes the character and companion")
check(lastRaycastParameters.FilterDescendantsInstances[1] == model and lastRaycastParameters.FilterDescendantsInstances[2] == character, "Raycast filters reference active models")
local wolfColor, wolfLength, wolfEarHeight = model.Body.Color, model.Body.Size.Z, model.Ear.Size.Y

local oldPosition = model.Body.CFrame.Position
root.CFrame = Roblox.CFrame.new(10, 6.5, 35)
root.Position = Roblox.Vector3.new(10, 6.5, 35)
step(1, 1 / 60)
local firstPosition = model.Body.CFrame.Position
check(firstPosition.X > oldPosition.X and firstPosition.X < oldPosition.X + 10, "Follower moves smoothly toward a walking character")
step(90, 1 / 60)
local target = Roblox.Vector3.new(13.2, 5.1, 38.6)
check((model.Body.CFrame.Position - target).Magnitude < 0.03, "Follower converges beside and behind the character on the sampled ground")

local playerFrame = root.CFrame
local strikeTarget = Roblox.Vector3.new(10, 7, 26)
local startDistance = (model.Body.CFrame.Position - strikeTarget).Magnitude
strike(strikeTarget)
step(6, 1 / 60)
check((model.Body.CFrame.Position - strikeTarget).Magnitude < startDistance - 3, "Bond pounce visibly approaches the server's target")
check(model.Body.CFrame.Position.Y > target.Y + 0.5, "Pounce has a short raised arc")
step(9, 1 / 60)
local impactPosition = model.Body.CFrame.Position
local impactDistance = ((impactPosition - strikeTarget) * Roblox.Vector3.new(1, 0, 1)).Magnitude
check(math.abs(impactDistance - 2.2) < 0.02, "Pet stops with its muzzle near the target instead of passing through it")
check(root.CFrame == playerFrame and root.Position == Roblox.Vector3.new(10, 6.5, 35), "Attack animation never moves the player")
assertCosmetic(model)
step(15, 1 / 60)
check((model.Body.CFrame.Position - target).Magnitude < 0.03, "Pet returns to following after the short attack clip")
local beforeInvalid = model.Body.CFrame.Position
strike(Roblox.Vector3.new(10000, 7, 26))
strike(Roblox.Vector3.new(0 / 0, 7, 26))
step(1, 1 / 60)
check((model.Body.CFrame.Position - beforeInvalid).Magnitude < 0.03, "Invalid or distant animation targets are ignored")

strike(strikeTarget)
step(6, 1 / 60)

petId = "emberfox"
equipped:Fire()
step(1, 1 / 60)
check(model:GetAttribute("CompanionId") == "emberfox", "Equipping fox updates the visual id")
check(model.Body.Color ~= wolfColor and model.Ear.Size.Y > wolfEarHeight, "Fox changes color and has taller ears")
check(model:FindFirstChild("FoxTailTip") ~= nil and model.Tail.Size.Z > 1.22, "Fox has a longer tail and pale tip")
assertCosmetic(model)
step(60, 1 / 60)
check((model.Body.CFrame.Position - target).Magnitude < 0.03, "Changing companion cancels an in-flight pounce")

petId = "tidecub"
equipped:Fire()
step(30, 1 / 60)
check(model:GetAttribute("CompanionId") == "tidecub", "Equipping cub updates the visual id")
check(model.Ear:IsA("Part") and model.Ear.Shape == Roblox.Enum.PartType.Ball, "Cub has round ears")
check(model.Body.Size.Z < wolfLength and model:FindFirstChild("FoxTailTip") == nil, "Cub is shorter and discards the fox-only geometry")
assertCosmetic(model)

petId = "unknown-companion"
equipped:Fire()
step(1, 1 / 60)
check(model:GetAttribute("CompanionId") == "mosswolf", "Unknown local selection falls back to the starter companion")

strike(strikeTarget)
step(6, 1 / 60)
removed:Fire(character)
check(model.Parent == nil, "Companion hides while the character is removed")
step(3, 1 / 60)
local newCharacter, newRoot = characterAt(Roblox.Vector3.new(60, 6.5, -30))
player.Character = newCharacter
added:Fire(newCharacter)
step(10, 1 / 60)
check(model.Parent == scene, "Companion returns after respawn")
check((model.Body.CFrame.Position - Roblox.Vector3.new(63.2, 5.1, -26.4)).Magnitude < 0.03, "Respawn resets the follower near the new character")
check(lastRaycastParameters.FilterDescendantsInstances[2] == newCharacter, "Respawn refreshes the ground filter")

newRoot.CFrame = Roblox.CFrame.new(-50, 6.5, -40)
newRoot.Position = Roblox.Vector3.new(-50, 6.5, -40)
step(1, 1 / 60)
check((model.Body.CFrame.Position - Roblox.Vector3.new(-46.8, 5.1, -36.4)).Magnitude < 0.03, "Large teleports reset without a long catch-up path")

strike(Roblox.Vector3.new(-45, 7, -45))
cleanup()
cleanup()
check(#scene:GetChildren() == 0, "Repeated cleanup leaves no companion instances")
check(render.Active() == 0 and added.Active() == 0 and removed.Active() == 0 and equipped.Active() == 0, "Cleanup disconnects every event subscription")
render:Fire(1 / 60)
equipped:Fire()
added:Fire(newCharacter)
strike(strikeTarget)
check(#scene:GetChildren() == 0, "Events cannot revive a stopped view")

-- Equal elapsed time at common display refresh rates gives the same follow lag.
local function movementAtRate(fps)
	local stop = CompanionView.start(player)
	step(1, 1 / fps)
	local pet = assert(scene:FindFirstChild("LocalTrailCompanion"))
	newRoot.CFrame = Roblox.CFrame.new(-40, 6.5, -40)
	newRoot.Position = Roblox.Vector3.new(-40, 6.5, -40)
	step(fps / 2, 1 / fps)
	local position = pet.Body.CFrame.Position
	stop()
	newRoot.CFrame = Roblox.CFrame.new(-50, 6.5, -40)
	newRoot.Position = Roblox.Vector3.new(-50, 6.5, -40)
	return position
end
check((movementAtRate(30) - movementAtRate(120)).Magnitude < 0.02, "Follower translation is stable across display frame rates")
check(#scene:GetChildren() == 0 and render.Active() == 0, "Frame rate scenarios also clean up")

print("CompanionView: " .. checks .. " checks passed (reflected Roblox instances; mocked signals/player/ground, no Studio physics or rendering)")
