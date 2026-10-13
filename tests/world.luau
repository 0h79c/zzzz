-- Headless geometry/property checks, not a substitute for Studio rendering or physics.
-- Lune provides real Roblox instance reflection and datatypes. Its library has no
-- Random datatype, so scenery is sampled by a bounded deterministic test PRNG;
-- the exact Roblox Random sequence is deliberately not asserted.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/CombatRules")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Instance = roblox.Instance
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end

local function close(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 0.001)
end

local Random = {}
function Random.new(seed)
	local value = seed
	return {
		NextNumber = function(_, minimum, maximum)
			value = (value * 48271) % 2147483647
			return minimum + (maximum - minimum) * value / 2147483647
		end,
	}
end

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
-- Shared definitions are the real module; only Roblox's Instance require and
-- asynchronous WaitForChild lookup are adapted for the headless loader.
local rulesToken = {}
local shared = { WaitForChild = function(_, name) assert(name == "CombatRules"); return rulesToken end }
local replicated = { WaitForChild = function(_, name) assert(name == "Wildbond"); return shared end }
local environment = {
	game = { GetService = function(_, name)
		return if name == "ReplicatedStorage" then replicated else game:GetService(name)
	end },
	workspace = workspace,
	Random = Random,
	require = function(token) assert(token == rulesToken); return Rules end,
}
for _, name in { "Instance", "Vector3", "CFrame", "Color3", "UDim2", "Enum" } do
	environment[name] = roblox[name]
end
local WorldBuilder = luau.load(fs.readFile("src/server/WorldBuilder.luau"), {
	environment = environment,
	debugName = "WorldBuilder",
})()

-- Lune stores Position and CFrame independently. Read the actual property the
-- builder authored, instead of inventing a Studio transform synchronization.
local function frame(object)
	if object:IsA("SpawnLocation") then
		return CFrame.new(object.Position)
	end
	return object.CFrame
end

local function bounds(object)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local half = object.Size / 2
	local transform = frame(object)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local point = transform:PointToWorldSpace(Vector3.new(x * half.X, y * half.Y, z * half.Z))
				minimum = Vector3.new(math.min(minimum.X, point.X), math.min(minimum.Y, point.Y), math.min(minimum.Z, point.Z))
				maximum = Vector3.new(math.max(maximum.X, point.X), math.max(maximum.Y, point.Y), math.max(maximum.Z, point.Z))
			end
		end
	end
	return { part = object, minimum = minimum, maximum = maximum }
end

local function overlapsCylinder(box, position, radius, bottom, top)
	if box.maximum.Y <= bottom or box.minimum.Y >= top then
		return false
	end
	local nearestX = math.clamp(position.X, box.minimum.X, box.maximum.X)
	local nearestZ = math.clamp(position.Z, box.minimum.Z, box.maximum.Z)
	return (position.X - nearestX) ^ 2 + (position.Z - nearestZ) ^ 2 < radius ^ 2
end

local function validateWorld(result)
	local island = workspace:FindFirstChild("FirstTrailIsland")
	check(island ~= nil and island:IsA("Model"), "Builder must create the compatible region Model")
	local allParts, trails, allPrompts, walkingRoutes = {}, {}, {}, {}
	local colliders = {}
	for _, object in island:GetDescendants() do
		if object:IsA("BasePart") then
			table.insert(allParts, object)
			check(object.Anchored, "World part is not anchored: " .. object.Name)
			check(object.Size.X > 0 and object.Size.Y > 0 and object.Size.Z > 0, "World part has invalid size: " .. object.Name)
			if object.Name == "Trail" then
				table.insert(trails, object)
			end
			if object.Name == "Trail" or object.Name == "CarriageApproach" or object.Name == "SideTrail" then
				table.insert(walkingRoutes, object)
			end
			if object.CanCollide then
				table.insert(colliders, bounds(object))
			end
		elseif object:IsA("ProximityPrompt") then
			table.insert(allPrompts, object)
		end
	end
	check(#allParts > 100 and #allParts < 650, "Region exceeds the prototype geometry budget")
	check(island:GetAttribute("GeneratedPartCount") == #allParts, "Generated part count must include every BasePart")
	check(island:GetAttribute("PrototypeGeometry") == true, "Prototype geometry must be identified")
	check(island:GetAttribute("RegionName") == "Greywater Reach", "Visible region needs its mainland identity")
	check(island:GetAttribute("TravelImplemented") == false, "Future travel must not claim to work")
	check(island:FindFirstChild("Sea") == nil and island:FindFirstChild("SouthBeach") == nil and island:FindFirstChild("EasternShore") == nil, "Starting region must not be an ocean-surrounded island")
	local landscape = island:FindFirstChild("WoodlandLandscape")
	check(landscape ~= nil and landscape:IsA("BasePart") and landscape.CanCollide and landscape.Size.X > 1000 and landscape.Size.Z > 1000, "Mainland must continue beneath the surrounding ridges")
	check(#trails == 9, "Village and expedition routes must all be present")
	check(#walkingRoutes == 13, "Carriage stop and roaming clearings need supported branch routes")
	check(#allPrompts == 5, "Exactly five map interactions are required")
	local expected = { start = true, ["return"] = true, moss = true, river = true, ruins = true }
	local count = 0
	for id, prompt in result.prompts do
		count += 1
		check(expected[id] == true, "Unexpected interaction id: " .. id)
		check(prompt:IsA("ProximityPrompt") and prompt:IsDescendantOf(island), "Returned prompt must belong to this island")
		check(prompt.Parent ~= nil and prompt.Parent:IsA("BasePart"), "Prompt must have a BasePart host")
		check(prompt.Parent:GetAttribute("InteractionId") == id, "Prompt host and id must agree")
		check(prompt.Parent:GetAttribute("InteractionRadius") == prompt.MaxActivationDistance, "Server and prompt interaction distances must agree")
		check(prompt.MaxActivationDistance >= 10 and prompt.MaxActivationDistance <= 14, "Interaction must be reachable without excessive range")
		check(prompt.KeyboardKeyCode == roblox.Enum.KeyCode.E and prompt.GamepadKeyCode == roblox.Enum.KeyCode.ButtonX, "Keyboard and controller inputs must be configured")
		expected[id] = nil
	end
	check(count == 5 and next(expected) == nil, "A required prompt is missing")

	local ground = island:FindFirstChild("IslandMeadow")
	check(ground ~= nil and ground:IsA("BasePart") and ground.CanCollide, "Playable ground must be solid")
	check(close(ground.CFrame.UpVector.Y, 1), "Playable meadow must be level")
	check(ground.Size.X >= 220 and ground.Size.Z >= 260, "Valley needs a larger connected playable meadow")
	local groundTop = ground.CFrame.Position.Y + ground.Size.Y / 2
	check(close(groundTop, 4), "Combat and world ground height must agree")
	local function supported(point)
		local localPoint = ground.CFrame:PointToObjectSpace(point)
		return math.abs(localPoint.X) <= ground.Size.X / 2 and math.abs(localPoint.Z) <= ground.Size.Z / 2
	end
	local function clear(position, radius, bottom, top, ignoreApproaches)
		if ignoreApproaches then
			for _, prompt in result.prompts do
				local offset = frame(prompt.Parent).Position - position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= prompt.MaxActivationDistance then
					return true
				end
			end
		end
		for _, box in colliders do
			if overlapsCylinder(box, position, radius, bottom, top) then
				return false, box.part.Name
			end
		end
		return true
	end

	for _, trail in walkingRoutes do
		check(close(trail.CFrame.UpVector.Y, 1) and close(trail.Size.Y, 0.12), "All player trails must be flat")
		local samples = math.ceil(trail.Size.Z / 2)
		for index = 0, samples do
			local localZ = -trail.Size.Z / 2 + trail.Size.Z * index / samples
			for _, localX in { -trail.Size.X / 2, 0, trail.Size.X / 2 } do
				local point = trail.CFrame:PointToWorldSpace(Vector3.new(localX, -trail.Size.Y / 2, localZ))
				check(supported(point) and point.Y >= groundTop and point.Y - groundTop < 0.15, "Trail width must remain supported by level solid ground")
			end
			local center = trail.CFrame:PointToWorldSpace(Vector3.new(0, 0, localZ))
			local isClear, obstacle = clear(center, 1.25, groundTop + 0.3, groundTop + 5.7, true)
			check(isClear, "An obstacle blocks a route away from interaction approaches: " .. tostring(obstacle) .. " at route sample " .. tostring(center) .. " (trail center " .. tostring(trail.CFrame.Position) .. ")")
		end
	end

	local spawn = island:FindFirstChild("VillageSpawn")
	check(spawn ~= nil and spawn:IsA("SpawnLocation"), "Village needs a real SpawnLocation")
	check(spawn.Neutral and spawn.Duration == 0 and spawn.Anchored, "Spawn must work for all players without a forcefield timer")
	check(supported(spawn.Position), "Spawn must be on supported ground")
	check(close(spawn.Position.Y - spawn.Size.Y / 2, groundTop), "Spawn must sit on the meadow")
	local spawnClear, spawnObstacle = clear(spawn.Position, 1.75, groundTop + 0.3, groundTop + 6, false)
	check(spawnClear, "Spawn is obstructed by " .. tostring(spawnObstacle))
	check(supported(result.companionSpawn), "Starter companion must appear above the region")

	local carriageSign = island:FindFirstChild("CarriageStopSign")
	check(carriageSign ~= nil and carriageSign:IsA("BasePart"), "Region needs a visible carriage stop")
	local signGui = carriageSign:FindFirstChild("LandmarkLabel")
	local signText = if signGui then signGui:FindFirstChildOfClass("TextLabel") else nil
	check(signText ~= nil and signText.Text == "Other regions — future update", "Carriage stop must clearly mark future travel")
	check(carriageSign:FindFirstChildOfClass("ProximityPrompt") == nil, "Carriage stop must not offer fake teleport interaction")
	for z = 55, 69, 2 do
		local point = Vector3.new(-45, groundTop, z)
		local accessible, obstacle = clear(point, 1.25, groundTop + 0.3, groundTop + 5.7, false)
		check(supported(point) and accessible, "Players must reach the carriage stop without obstruction: " .. tostring(obstacle))
	end
	for _, name in { "DraftHorseBody", "CarriageBed", "WaygateLintel", "ValleySideRidge", "SouthernRidge", "NorthernCliff", "DistantWoodlandRidge" } do
		check(island:FindFirstChild(name) ~= nil, "Woodland region landmark is missing: " .. name)
	end

	local bountyCount = 0
	for _, foe in Rules.foes do
		local position = Vector3.new(foe.position.x, foe.position.y, foe.position.z)
		check(supported(position), "Enemy must stand above supported ground: " .. foe.id)
		local isClear, obstacle = clear(position, 4, groundTop + 0.3, groundTop + 8, false)
		check(isClear, "Enemy collision clearance is blocked: " .. foe.id .. " / " .. tostring(obstacle))
		if foe.bounty ~= false then
			bountyCount += 1
			check(result.prompts[foe.id] ~= nil, "Bounty enemy needs its expedition landmark: " .. foe.id)
			local beacon = frame(result.prompts[foe.id].Parent).Position
			check(close(beacon.X, position.X) and close(beacon.Z + 8, position.Z), "Enemy and bounty landmark must be aligned")
		else
			check(result.prompts[foe.id] == nil, "Roaming enemy must not create an expedition interaction: " .. foe.id)
		end
		local dodgeRadius = math.max(foe.slamRadius, if foe.boss then Rules.bossBurstRadius else 0) + 2
		for _, radius in { dodgeRadius, Rules.patrolRadius } do
			local openSamples = 0
			for index = 1, 24 do
				local angle = index * math.pi * 2 / 24
				local escape = position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				check(supported(escape), "Enemy dodge/patrol ring crosses an unsupported edge: " .. foe.id)
				if clear(escape, 1.25, groundTop + 0.3, groundTop + 5.7, false) then
					openSamples += 1
				end
			end
			check(openSamples >= 18, "Enemy needs clear dodge/patrol space on at least three quarters of its arena: " .. foe.id .. " / radius " .. tostring(radius))
		end
	end
	check(bountyCount == 3, "Only three enemies participate in the expedition bounty sequence")

	check(lighting.GlobalShadows and lighting.ClockTime > 10 and lighting.ClockTime < 17, "Region lighting must use readable daylight")
	for _, name in { "FirstTrailAtmosphere", "FirstTrailColor", "FirstTrailBloom" } do
		check(lighting:FindFirstChild(name) ~= nil, "A required lighting effect is missing: " .. name)
	end
	return island, #allParts
end

local firstResult = WorldBuilder.build()
local firstIsland, partCount = validateWorld(firstResult)
local unrelated = Instance.new("Model")
unrelated.Name = "UserOwnedModel"
unrelated.Parent = workspace
local unrelatedPart = Instance.new("Part")
unrelatedPart.Name = "KeepThis"
unrelatedPart.Parent = unrelated
local unrelatedEffect = Instance.new("ColorCorrectionEffect")
unrelatedEffect.Name = "UserOwnedEffect"
unrelatedEffect.Parent = lighting

local secondResult = WorldBuilder.build()
local secondIsland, secondPartCount = validateWorld(secondResult)
check(secondIsland ~= firstIsland, "Rebuild must replace the previous generated model")
check(secondPartCount == partCount, "Repeated seeded headless builds must be stable")
check(unrelated.Parent == workspace and unrelatedPart.Parent == unrelated, "Rebuild must preserve unrelated workspace models and their children")
check(unrelatedEffect.Parent == lighting, "Rebuild must preserve unrelated lighting effects")
local islandCount = 0
for _, child in workspace:GetChildren() do
	if child.Name == "FirstTrailIsland" then
		islandCount += 1
	end
end
check(islandCount == 1, "Repeated builds must leave exactly one generated region")
local effectCount = 0
for _, child in lighting:GetChildren() do
	if child.Name == "FirstTrailAtmosphere" or child.Name == "FirstTrailColor" or child.Name == "FirstTrailBloom" then
		effectCount += 1
	end
end
check(effectCount == 3, "Repeated builds must not accumulate generated lighting effects")

print("World: " .. checks .. " headless geometry checks passed; " .. partCount .. " BaseParts; Studio physics/rendering and Roblox Random sequence still require playtesting")
