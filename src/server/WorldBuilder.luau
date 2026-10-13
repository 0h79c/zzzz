--!strict
-- The first playable island uses only original, locally generated geometry.
local Lighting = game:GetService("Lighting")

local WorldBuilder = {}

export type World = {
	prompts: { [string]: ProximityPrompt },
	companionSpawn: Vector3,
}

function WorldBuilder.build(): World
	local previous = workspace:FindFirstChild("FirstTrailIsland")
	if previous then
		previous:Destroy()
	end

	local world = Instance.new("Model")
	world.Name = "FirstTrailIsland"
	world.Parent = workspace
	local partCount = 0
	local prompts: { [string]: ProximityPrompt } = {}
	local palette = {
		grass = Color3.fromRGB(108, 157, 101),
		grassLight = Color3.fromRGB(133, 173, 112),
		earth = Color3.fromRGB(112, 91, 76),
		stone = Color3.fromRGB(124, 139, 135),
		stoneLight = Color3.fromRGB(160, 171, 158),
		path = Color3.fromRGB(196, 173, 125),
		wood = Color3.fromRGB(110, 77, 57),
		woodLight = Color3.fromRGB(163, 120, 77),
		cream = Color3.fromRGB(231, 217, 174),
		water = Color3.fromRGB(96, 190, 195),
		leaves = Color3.fromRGB(86, 132, 102),
		leavesLight = Color3.fromRGB(132, 168, 117),
		roof = Color3.fromRGB(66, 101, 111),
	}

	local function part(name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Size = size
		result.CFrame = frame
		result.Color = color
		result.Material = material or Enum.Material.SmoothPlastic
		result.Anchored = true
		result.TopSurface = Enum.SurfaceType.Smooth
		result.BottomSurface = Enum.SurfaceType.Smooth
		result.Parent = world
		partCount += 1
		return result
	end

	local function label(adornee: BasePart, text: string, color: Color3?)
		local gui = Instance.new("BillboardGui")
		gui.Name = "LandmarkLabel"
		gui.Size = UDim2.fromOffset(210, 44)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.MaxDistance = 65
		gui.AlwaysOnTop = false
		gui.Parent = adornee
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.GothamMedium
		textLabel.TextSize = 19
		textLabel.TextColor3 = color or palette.cream
		textLabel.TextStrokeColor3 = Color3.fromRGB(44, 57, 52)
		textLabel.TextStrokeTransparency = 0.25
		textLabel.Text = text
		textLabel.Parent = gui
	end

	local function interaction(id: string, landmark: BasePart, action: string, object: string)
		landmark:SetAttribute("InteractionId", id)
		landmark:SetAttribute("InteractionRadius", 14)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = id .. "Prompt"
		prompt.ActionText = action
		prompt.ObjectText = object
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
		prompt.Parent = landmark
		prompts[id] = prompt
	end

	local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
		local line = b - a
		local along = math.clamp((point - a):Dot(line) / line:Dot(line), 0, 1)
		return (point - (a + line * along)).Magnitude
	end

	local function path(a: Vector3, b: Vector3, width: number)
		local delta = b - a
		local middle = (a + b) / 2
		part("Trail", Vector3.new(width, 0.12, delta.Magnitude + 1), CFrame.lookAt(middle, b), palette.path, Enum.Material.Sand)
	end

	-- All expedition routes share a flat surface; cliffs are scenery.
	local sea = part("Sea", Vector3.new(1600, 2, 1600), CFrame.new(0, -7, 0), Color3.fromRGB(75, 145, 173))
	sea.Material = Enum.Material.SmoothPlastic
	sea.CanCollide = false
	part("IslandEarth", Vector3.new(166, 12, 204), CFrame.new(8, -4, -29), palette.earth, Enum.Material.Rock)
	part("IslandMeadow", Vector3.new(166, 4, 204), CFrame.new(8, 2, -29), palette.grass, Enum.Material.Grass)
	part("WestCoast", Vector3.new(27, 4, 113), CFrame.new(-79, 2, -33) * CFrame.Angles(0, math.rad(8), 0), palette.grass, Enum.Material.Grass)
	part("SouthBeach", Vector3.new(128, 4, 19), CFrame.new(9, 1.5, 79), palette.path, Enum.Material.Sand)
	part("EasternShore", Vector3.new(18, 4, 159), CFrame.new(96, 1.6, -24) * CFrame.Angles(0, math.rad(-5), 0), palette.path, Enum.Material.Sand)

	local trailPoints = {
		Vector3.new(0, 4.07, 35),
		Vector3.new(0, 4.07, 15),
		Vector3.new(-45, 4.07, -25),
		Vector3.new(0, 4.07, -65),
		Vector3.new(65, 4.07, -80),
		Vector3.new(63, 4.07, -18),
		Vector3.new(35, 4.07, 35),
		Vector3.new(0, 4.07, 35),
	}
	for index = 1, #trailPoints - 1 do
		path(trailPoints[index], trailPoints[index + 1], 10)
	end
	path(Vector3.new(-23, 4.07, 27), Vector3.new(0, 4.07, 15), 7)
	path(Vector3.new(12, 4.07, 15), Vector3.new(0, 4.07, 15), 7)

	-- The tavern has an actual doorway, a warm interior, and a readable silhouette.
	local tavernX, tavernZ = -24, 38
	part("TavernFloor", Vector3.new(21, 0.3, 19), CFrame.new(tavernX, 4.2, tavernZ), palette.woodLight, Enum.Material.WoodPlanks)
	part("TavernBackWall", Vector3.new(21, 8, 0.8), CFrame.new(tavernX, 8.4, tavernZ + 9), palette.cream)
	for _, side in { -1, 1 } do
		part("TavernSideWall", Vector3.new(0.8, 8, 18), CFrame.new(tavernX + side * 10, 8.4, tavernZ), palette.cream)
		part("DoorwayWall", Vector3.new(7.5, 8, 0.8), CFrame.new(tavernX + side * 6.4, 8.4, tavernZ - 9), palette.cream)
		part("RoofSlope", Vector3.new(12.2, 0.65, 22), CFrame.new(tavernX + side * 5.4, 14.2, tavernZ) * CFrame.Angles(0, 0, math.rad(-side * 23)), palette.roof)
		for _, endZ in { -9, 9 } do
			part("TavernPost", Vector3.new(1.1, 8.6, 1.1), CFrame.new(tavernX + side * 10, 8.4, tavernZ + endZ), palette.wood, Enum.Material.Wood)
		end
		part("WindowFrame", Vector3.new(4.1, 3.5, 0.25), CFrame.new(tavernX + side * 6.4, 9, tavernZ - 9.5), palette.wood)
		local window = part("WarmWindow", Vector3.new(3.2, 2.6, 0.15), CFrame.new(tavernX + side * 6.4, 9, tavernZ - 9.67), Color3.fromRGB(248, 202, 129), Enum.Material.Neon)
		window.CanCollide = false
		part("WindowCrossbar", Vector3.new(0.18, 2.7, 0.17), CFrame.new(tavernX + side * 6.4, 9, tavernZ - 9.8), palette.wood)
	end
	part("TavernDoorLintel", Vector3.new(5.5, 2.3, 1), CFrame.new(tavernX, 11.3, tavernZ - 9), palette.wood)
	part("TavernRoofRidge", Vector3.new(0.9, 0.9, 22.8), CFrame.new(tavernX, 16.6, tavernZ), palette.wood)
	part("Chimney", Vector3.new(2.6, 8.5, 2.5), CFrame.new(tavernX - 6, 14, tavernZ + 3), palette.stone, Enum.Material.Slate)
	part("TavernFrontBeam", Vector3.new(21, 0.6, 0.9), CFrame.new(tavernX, 12, tavernZ - 9.15), palette.wood)
	for _, side in { -1, 1 } do
		part("TavernFootBeam", Vector3.new(7.5, 0.6, 0.9), CFrame.new(tavernX + side * 6.4, 5, tavernZ - 9.15), palette.wood)
	end
	part("TavernTable", Vector3.new(5, 0.5, 3), CFrame.new(tavernX, 6.5, tavernZ + 2), palette.woodLight, Enum.Material.Wood)
	part("TablePedestal", Vector3.new(1, 2, 1), CFrame.new(tavernX, 5.3, tavernZ + 2), palette.wood)
	for _, side in { -1, 1 } do
		part("TavernBench", Vector3.new(5, 0.6, 1), CFrame.new(tavernX, 5.2, tavernZ + 2 + side * 2.3), palette.woodLight)
	end
	local tavernSign = part("TavernSign", Vector3.new(5.5, 1.7, 0.4), CFrame.new(tavernX, 10.8, tavernZ - 9.8), palette.wood)
	label(tavernSign, "THE WAYFARER", palette.cream)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "VillageSpawn"
	spawn.Size = Vector3.new(7, 1, 7)
	spawn.Position = Vector3.new(0, 4.5, 35)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = world
	partCount += 1

	for _, side in { -1, 1 } do
		part("HuntBoardPost", Vector3.new(0.6, 5, 0.6), CFrame.new(side * 2.9, 6.5, 15.4), palette.wood)
	end
	local board = part("HuntBoard", Vector3.new(6.7, 3.3, 0.55), CFrame.new(0, 7.2, 15), palette.woodLight, Enum.Material.Wood)
	part("BoardParchment", Vector3.new(5.5, 2.3, 0.1), CFrame.new(0, 7.2, 15.32), palette.cream)
	label(board, "EXPEDITION BOARD")
	interaction("start", board, "Begin hunt", "Expedition board")
	local rewardChest = part("HuntRewardChest", Vector3.new(3.5, 2.1, 2.4), CFrame.new(12, 5.1, 15), palette.woodLight, Enum.Material.Wood)
	part("ChestLid", Vector3.new(3.7, 0.5, 2.6), CFrame.new(12, 6.35, 15), palette.wood)
	for _, side in { -1, 1 } do
		part("ChestBand", Vector3.new(0.24, 2.6, 2.7), CFrame.new(12 + side * 1, 5.4, 15), palette.cream, Enum.Material.Metal)
	end
	label(rewardChest, "HUNT REWARDS")
	interaction("return", rewardChest, "Claim reward", "Village reward chest")

	-- Camp details establish a handmade scale without purchased assets.
	part("CampAwning", Vector3.new(11, 0.4, 8), CFrame.new(23, 10, 29) * CFrame.Angles(0, 0, math.rad(-6)), Color3.fromRGB(175, 110, 92), Enum.Material.Fabric)
	for _, x in { 18, 28 } do
		for _, z in { 25.5, 32.5 } do
			part("CampPole", Vector3.new(0.35, 6, 0.35), CFrame.new(x, 7, z), palette.wood)
		end
	end
	part("ApothecaryTable", Vector3.new(8, 0.5, 2.6), CFrame.new(23, 6.3, 30), palette.woodLight)
	for _, x in { 20, 26 } do
		part("CampTableLeg", Vector3.new(0.5, 2.2, 0.5), CFrame.new(x, 5.15, 30), palette.wood)
	end
	for index, color in { Color3.fromRGB(113, 205, 198), Color3.fromRGB(190, 153, 211), Color3.fromRGB(234, 181, 99) } do
		local bottle = part("PotionBottle", Vector3.new(0.75, 1.2, 0.75), CFrame.new(19.9 + index * 1.3, 7.15, 30), color, Enum.Material.Glass)
		bottle.Transparency = 0.2
		part("PotionStopper", Vector3.new(0.4, 0.3, 0.4), CFrame.new(19.9 + index * 1.3, 7.85, 30), palette.path)
	end
	part("CampCrate", Vector3.new(2.4, 2.4, 2.4), CFrame.new(31, 5.2, 30), palette.woodLight, Enum.Material.WoodPlanks)
	for _, x in { -7, 10, 34 } do
		part("VillageLanternPost", Vector3.new(0.45, 6, 0.45), CFrame.new(x, 7, 39), palette.wood)
		local lantern = part("VillageLantern", Vector3.new(0.9, 1.3, 0.9), CFrame.new(x, 10.25, 39), Color3.fromRGB(248, 206, 134), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = lantern.Color
		light.Brightness = 0.65
		light.Range = 13
		light.Parent = lantern
	end

	-- Broad clearings accommodate the three server-controlled encounters.
	local stops = {
		{ id = "moss", name = "MossdenBounty", title = "MOSSDEN", position = Vector3.new(-45, 5.7, -25), color = Color3.fromRGB(155, 205, 124) },
		{ id = "river", name = "RiverwatchBounty", title = "RIVERWATCH", position = Vector3.new(0, 5.7, -65), color = Color3.fromRGB(125, 212, 218) },
		{ id = "ruins", name = "RuinheartBounty", title = "RUINHEART", position = Vector3.new(65, 5.7, -80), color = Color3.fromRGB(187, 166, 225) },
	}
	for _, stop in stops do
		part("BountyPlinth", Vector3.new(4.5, 0.6, 4.5), CFrame.new(stop.position.X, 4.3, stop.position.Z), palette.stone)
		local landmark = part(stop.name, Vector3.new(1.8, 2.7, 1.8), CFrame.new(stop.position), palette.stoneLight, Enum.Material.Slate)
		local gem = part("BountyBeacon", Vector3.new(0.95, 0.95, 0.95), CFrame.new(stop.position + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, math.rad(45), math.rad(25)), stop.color, Enum.Material.Neon)
		gem.CanCollide = false
		label(landmark, stop.title, stop.color)
		interaction(stop.id, landmark, "Collect bounty", stop.title)
	end

	-- Terraced silhouettes stay behind the playable ground.
	for index, cliffZ in { 40, 4, -35, -78, -113 } do
		local height = 14 + index * 2
		part("WesternCliff", Vector3.new(23, height, 31), CFrame.new(-88, 4 + height / 2, cliffZ), palette.earth, Enum.Material.Rock)
		part("CliffMeadow", Vector3.new(24, 1.4, 32), CFrame.new(-88, 4 + height + 0.4, cliffZ), palette.grassLight, Enum.Material.Grass)
	end
	for index = 1, 5 do
		local cliffX = -54 + (index - 1) * 33
		local height = if index == 3 then 24 else 15 + index % 3 * 3
		part("NorthernCliff", Vector3.new(31, height, 17), CFrame.new(cliffX, 4 + height / 2, -125), palette.earth, Enum.Material.Rock)
		part("NorthernGrass", Vector3.new(32, 1, 18), CFrame.new(cliffX, 4 + height + 0.3, -125), palette.grassLight, Enum.Material.Grass)
	end
	part("WaterfallShelf", Vector3.new(23, 20, 10), CFrame.new(-9, 14, -109), palette.stone, Enum.Material.Rock)
	part("WaterfallShelfGrass", Vector3.new(24, 1, 11), CFrame.new(-9, 24.3, -109), palette.grassLight)
	local waterfall = part("Waterfall", Vector3.new(11, 20, 0.65), CFrame.new(-9, 14.2, -103.6), palette.water, Enum.Material.Glass)
	waterfall.Transparency = 0.22
	waterfall.CanCollide = false
	for _, x in { -12, -8, -5 } do
		local foam = part("WaterfallFoam", Vector3.new(0.4, 19, 0.1), CFrame.new(x, 14.3, -103.2), Color3.fromRGB(198, 238, 224), Enum.Material.Neon)
		foam.Transparency = 0.5
		foam.CanCollide = false
	end
	local pool = part("ShallowRiverPool", Vector3.new(36, 0.16, 17), CFrame.new(-9, 4.12, -94), palette.water, Enum.Material.Glass)
	pool.Transparency = 0.22
	pool.CanCollide = false
	part("RiversideFootbridge", Vector3.new(22, 0.4, 4), CFrame.new(-9, 4.5, -88), palette.woodLight, Enum.Material.WoodPlanks)
	for _, z in { -90, -86 } do
		part("BridgeHandrail", Vector3.new(22, 0.35, 0.35), CFrame.new(-9, 6.5, z), palette.wood)
		for _, x in { -19, -9, 1 } do
			part("BridgePost", Vector3.new(0.4, 2.2, 0.4), CFrame.new(x, 5.55, z), palette.wood)
		end
	end

	-- The broken ring leaves a western approach and a broad southern exit.
	for index = 0, 9 do
		local angle = math.rad(index * 30 + 15)
		local radius = 25
		local x = 65 + math.cos(angle) * radius
		local z = -80 + math.sin(angle) * radius
		local approachDistance = distanceToSegment(Vector3.new(x, 4.07, z), trailPoints[4], trailPoints[5])
		if z < -65 and approachDistance > 8 then
			local height = 5 + index % 3 * 2
			part("RuinColumn", Vector3.new(2.3, height, 2.3), CFrame.new(x, 4 + height / 2, z) * CFrame.Angles(0, angle, 0), palette.stoneLight, Enum.Material.Slate)
			part("RuinColumnCapital", Vector3.new(3.2, 0.75, 3.2), CFrame.new(x, 4 + height, z) * CFrame.Angles(0, angle, 0), palette.stone)
		end
	end
	for index = 1, 7 do
		local angle = math.rad(index * 40)
		part("RuinBorderStone", Vector3.new(4, 0.3, 2.5), CFrame.new(65 + math.cos(angle) * 23, 4.12, -80 + math.sin(angle) * 23) * CFrame.Angles(0, -angle, 0), palette.stoneLight)
	end

	local function tree(x: number, z: number, scale: number, pine: boolean)
		local trunkHeight = 4.8 * scale
		part("TreeTrunk", Vector3.new(1.1 * scale, trunkHeight, 1.1 * scale), CFrame.new(x, 4 + trunkHeight / 2, z), palette.wood, Enum.Material.Wood)
		if pine then
			for tier = 0, 2 do
				local size = (6.7 - tier * 1.5) * scale
				part("PineCrown", Vector3.new(size, 2.7 * scale, size), CFrame.new(x, 7.5 * scale + 2 + tier * 1.7 * scale, z) * CFrame.Angles(0, math.rad(45), 0), if tier % 2 == 0 then palette.leaves else palette.leavesLight)
			end
		else
			part("TreeCrown", Vector3.new(7.5 * scale, 6 * scale, 7.2 * scale), CFrame.new(x, 4 + trunkHeight + 1.7 * scale, z) * CFrame.Angles(math.rad(8), math.rad(35), math.rad(7)), palette.leaves)
			part("TreeCrownLight", Vector3.new(5.7 * scale, 4.5 * scale, 5.9 * scale), CFrame.new(x - scale, 4 + trunkHeight + 3 * scale, z - scale) * CFrame.Angles(0, math.rad(-15), math.rad(-12)), palette.leavesLight)
		end
	end

	local function clearForScenery(x: number, z: number): boolean
		local point = Vector3.new(x, 4.07, z)
		if (point - Vector3.new(-24, 4.07, 38)).Magnitude < 22 or (point - Vector3.new(20, 4.07, 27)).Magnitude < 20 then
			return false
		end
		for _, stop in stops do
			local encounter = Vector3.new(stop.position.X, 4.07, stop.position.Z + 8)
			if (point - encounter).Magnitude < (if stop.id == "ruins" then 28 else 23) then
				return false
			end
		end
		if x > -32 and x < 13 and z < -84 then
			return false
		end
		for index = 1, #trailPoints - 1 do
			if distanceToSegment(point, trailPoints[index], trailPoints[index + 1]) < 9 then
				return false
			end
		end
		return true
	end

	local random = Random.new(52719)
	local trees = 0
	for _ = 1, 150 do
		if trees >= 30 then
			break
		end
		local x, z = random:NextNumber(-68, 82), random:NextNumber(-113, 62)
		if clearForScenery(x, z) then
			tree(x, z, random:NextNumber(0.7, 1.1), z < -45)
			trees += 1
		end
	end
	for index = 1, 26 do
		local x, z = random:NextNumber(-68, 86), random:NextNumber(-113, 62)
		if clearForScenery(x, z) then
			local rockSize = random:NextNumber(1.2, 2.8)
			part("MeadowRock", Vector3.new(rockSize * 1.3, rockSize, rockSize), CFrame.new(x, 4 + rockSize * 0.35, z) * CFrame.Angles(math.rad(15), random:NextNumber(0, math.pi), math.rad(20)), palette.stone)
			if index % 2 == 0 then
				part("RockMoss", Vector3.new(rockSize, 0.4, rockSize * 0.8), CFrame.new(x, 4 + rockSize * 0.7, z), palette.grassLight)
			end
		end
	end
	for _ = 1, 22 do
		local x, z = random:NextNumber(-60, 78), random:NextNumber(-105, 58)
		if clearForScenery(x, z) then
			for flowerIndex = 1, 3 do
				local offset = Vector3.new((flowerIndex - 2) * 0.5, 0, flowerIndex % 2 * 0.6)
				part("MeadowFlower", Vector3.new(0.55, 0.3, 0.55), CFrame.new(Vector3.new(x, 4.3, z) + offset) * CFrame.Angles(0, math.rad(45), 0), if flowerIndex == 2 then Color3.fromRGB(237, 205, 141) else Color3.fromRGB(218, 183, 195))
			end
		end
	end

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(113, 132, 143)
	Lighting.OutdoorAmbient = Color3.fromRGB(141, 159, 168)
	Lighting.EnvironmentDiffuseScale = 0.65
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.FogStart = 200
	Lighting.FogEnd = 950
	Lighting.FogColor = Color3.fromRGB(185, 214, 221)
	for _, effectName in { "FirstTrailAtmosphere", "FirstTrailColor", "FirstTrailBloom" } do
		local oldEffect = Lighting:FindFirstChild(effectName)
		if oldEffect then
			oldEffect:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "FirstTrailAtmosphere"
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(201, 225, 233)
	atmosphere.Decay = Color3.fromRGB(122, 148, 159)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.9
	atmosphere.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "FirstTrailColor"
	color.Contrast = 0.035
	color.Saturation = 0.045
	color.TintColor = Color3.fromRGB(255, 248, 236)
	color.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "FirstTrailBloom"
	bloom.Intensity = 0.12
	bloom.Size = 20
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	world:SetAttribute("GeneratedPartCount", partCount)
	world:SetAttribute("PrototypeGeometry", true)

	return {
		prompts = prompts,
		companionSpawn = Vector3.new(3, 5.1, 38),
	}
end

return WorldBuilder
