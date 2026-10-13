--!strict
-- Guardians and combat decisions live on the server. The attack remote supplies no target.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Rules = require(ReplicatedStorage:WaitForChild("Wildbond"):WaitForChild("CombatRules"))

type HuntState = Rules.HuntState
type Definition = Rules.FoeDefinition
type Actor = { player: Player, character: Model, humanoid: Humanoid, root: BasePart }
type Slam = { center: Vector3, radius: number, resolveAt: number, disc: Part }
type Foe = {
	definition: Definition,
	model: Model,
	root: Part,
	health: number,
	maxHealth: number,
	alive: boolean,
	contributors: { [Player]: Model },
	participants: { [Player]: boolean },
	participantCount: number,
	life: number,
	engaged: boolean,
	lastNearby: number,
	pattern: number,
	nextSlam: number,
	respawnAt: number?,
	slam: Slam?,
	transparencies: { [BasePart]: number },
	label: BillboardGui,
	healthText: TextLabel,
	healthFill: Frame,
	highlight: Highlight,
	flashUntil: number,
	home: Vector3,
	facing: Vector3,
	frames: { [BasePart]: CFrame },
	state: string,
	patrol: number,
	nextMelee: number,
	recoverUntil: number,
	melee: { target: Actor, resolveAt: number }?,
}

local CombatService = {}

local function point(position: Vector3): Rules.Point
	return { x = position.X, y = position.Y, z = position.Z }
end

local function actor(player: Player): Actor?
	if player.Parent ~= Players then
		return nil
	end
	local character = player.Character
	if not character or character.Parent == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return { player = player, character = character, humanoid = humanoid, root = root }
end

local function setState(foe: Foe, state: string, at: number, duration: number?)
	if foe.state == state then return end
	foe.state = state
	foe.model:SetAttribute("State", state)
	foe.model:SetAttribute("ActionStartedAt", at)
	foe.model:SetAttribute("ActionDuration", duration or 0)
end

local function place(foe: Foe, position: Vector3, direction: Vector3)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 0.01 then foe.facing = flat.Unit end
	local frame = CFrame.new(position) * CFrame.Angles(0, math.atan2(foe.facing.X, foe.facing.Z), 0)
	for object, offset in foe.frames do
		object.CFrame = frame * offset
		object.Position = object.CFrame.Position -- Also keeps reflected/headless Instances consistent.
	end
	foe.model:SetAttribute("FacingDirection", foe.facing)
end

local function takeDamage(source: Actor, amount: number, at: number)
	if Rules.canTakeDamage(at, source.character:GetAttribute("DodgeUntil")) then source.humanoid:TakeDamage(amount) end
end

local function part(
	parent: Instance, name: string, size: Vector3, position: CFrame, color: Color3,
	shape: Enum.PartType?
): Part
	local object = Instance.new("Part")
	object.Name = name
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.Size = size
	object.CFrame = position
	object.Color = color
	object.Material = Enum.Material.SmoothPlastic
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		object.Shape = shape
	end
	object.Parent = parent
	return object
end

local function buildFoe(parent: Instance, definition: Definition, now: number): Foe
	local model = Instance.new("Model")
	model.Name = definition.name
	model:SetAttribute("EnemyId", definition.id)
	model:SetAttribute("EnemyKind", definition.kind)
	model:SetAttribute("BountyTarget", definition.bounty)
	model:SetAttribute("Health", definition.maxHealth)
	model:SetAttribute("MaxHealth", definition.maxHealth)
	model:SetAttribute("Status", "Ready")
	model:SetAttribute("PartySize", 1)
	model.Parent = parent
	local spawn = definition.position
	local center = Vector3.new(spawn.x, spawn.y, spawn.z)
	model:SetAttribute("HomePosition", center)
	model:SetAttribute("State", "Patrol")
	model:SetAttribute("ActionStartedAt", now)
	model:SetAttribute("ActionDuration", 0)
	model:SetAttribute("FacingDirection", Vector3.new(0, 0, 1))
	local scale = if definition.boss then 1.4 else 1
	local bark = if definition.kind == "reed" then Color3.fromRGB(80, 115, 117) else Color3.fromRGB(108, 86, 63)
	local stone = if definition.boss then Color3.fromRGB(114, 119, 94) else Color3.fromRGB(143, 139, 112)
	local leaves = if definition.kind == "reed" then Color3.fromRGB(74, 181, 156) else Color3.fromRGB(120, 166, 76)
	local glow = if definition.boss then Color3.fromRGB(255, 174, 72) else Color3.fromRGB(171, 248, 164)
	local function shaped(name: string, size: Vector3, offset: Vector3, color: Color3, angles: Vector3?): Part
		local rotation = angles or Vector3.zero
		return part(model, name, size * scale, CFrame.new(center + offset * scale)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)), color)
	end
	local boar = definition.kind == "boar"
	local reed = definition.kind == "reed"
	local body = shaped("BarkCore", if boar then Vector3.new(3.1, 2.3, 4.4)
		elseif reed then Vector3.new(2.4, 3.5, 2.1) else Vector3.new(3.1, 3.35, 2.5),
		Vector3.zero, bark, Vector3.new(0, 0, -3))
	body.CanCollide = true
	model.PrimaryPart = body
	if boar then
		local fur, snout = Color3.fromRGB(131, 89, 57), Color3.fromRGB(91, 61, 47)
		body.Color = fur
		shaped("Head", Vector3.new(2.5, 1.9, 2.2), Vector3.new(0, -0.2, 2.1), fur)
		shaped("Snout", Vector3.new(1.6, 1, 0.9), Vector3.new(0, -0.55, 3.52), snout)
		shaped("Ridge", Vector3.new(1.2, 0.6, 3.5), Vector3.new(0, 1.25, -0.3), snout)
		shaped("MossBack", Vector3.new(1.2, 0.3, 1.8), Vector3.new(-0.85, 1.15, -0.7), leaves)
		shaped("Tail", Vector3.new(0.3, 0.35, 1.4), Vector3.new(0, 0.05, -2.75), snout, Vector3.new(20, 0, 0))
		for _, side in { -1, 1 } do
			for _, endZ in { -1.3, 1.1 } do
				shaped("RootLeg", Vector3.new(0.75, 1.75, 0.85), Vector3.new(side * 1.12, -1.95, endZ), fur)
				shaped("RootFoot", Vector3.new(0.9, 0.45, 1.1), Vector3.new(side * 1.12, -2.72, endZ + 0.12), snout)
			end
			shaped("Ear", Vector3.new(0.65, 1, 0.5), Vector3.new(side * 0.95, 1.05, 2.15), fur, Vector3.new(0, 0, -side * 20))
			shaped("Eye", Vector3.new(0.22, 0.25, 0.22), Vector3.new(side * 1.23, 0.2, 2.75), Color3.fromRGB(248, 202, 94))
			shaped("Tusk", Vector3.new(0.28, 1.15, 0.3), Vector3.new(side * 0.9, -0.2, 3.4), Color3.fromRGB(236, 221, 180),
				Vector3.new(-20, 0, -side * 18))
		end
	else
		shaped("StoneApron", Vector3.new(2.7, 1.5, 0.6), Vector3.new(0, -0.65, 1.35), stone, Vector3.new(0, 0, 6))
		shaped("ChestRune", Vector3.new(0.45, 1.15, 0.14), Vector3.new(0, -0.25, 1.69), glow).Material = Enum.Material.Neon
		shaped("Head", Vector3.new(2.7, 1.9, 2.3), Vector3.new(0, 2.15, 0), stone, Vector3.new(0, 5, 2))
		for _, direction in { -1, 1 } do
			shaped("RootLeg", Vector3.new(1.15, 1.85, 1.3), Vector3.new(direction * 0.92, -2.05, 0), bark,
				Vector3.new(0, direction * 10, direction * 3))
			shaped("RootFoot", Vector3.new(1.5, 0.5, 1.85), Vector3.new(direction * 1.02, -2.77, 0.3), stone)
			shaped("BranchArm", Vector3.new(0.95, 2.6, 1.1), Vector3.new(direction * 2.02, -0.4, 0), bark,
				Vector3.new(0, 0, direction * 17))
			shaped("KnottedFist", Vector3.new(1.4, 1.15, 1.4), Vector3.new(direction * 2.4, -1.62, 0.15), stone,
				Vector3.new(0, direction * 14, direction * 8))
			shaped("Eye", Vector3.new(0.36, 0.32, 0.15), Vector3.new(direction * 0.64, 2.35, 1.2), glow).Material = Enum.Material.Neon
			shaped("TwigCrown", Vector3.new(0.33, 2.05, 0.4), Vector3.new(direction * 0.85, 3.48, -0.35), bark,
				Vector3.new(12, 0, -direction * 22))
			shaped("LeafCrown", if reed then Vector3.new(0.55, 2.6, 0.4) else Vector3.new(1.25, 0.62, 1.1),
				Vector3.new(direction * 1.3, 4.07, -0.4), leaves,
				Vector3.new(5, direction * 20, -direction * 12))
		end
		shaped("Brow", Vector3.new(2.35, 0.27, 0.33), Vector3.new(0, 2.64, 1.14), bark, Vector3.new(0, 0, 3))
		shaped("MossShoulder", Vector3.new(1.85, 0.65, 1.75), Vector3.new(-1.27, 1.68, -0.1), leaves,
			Vector3.new(0, -12, 9))
		if definition.boss then
			shaped("AncientCrest", Vector3.new(0.9, 1.3, 0.55), Vector3.new(0, 3.47, 0.2), glow,
				Vector3.new(0, 0, 45)).Material = Enum.Material.Neon
		end
	end

	local label = Instance.new("BillboardGui")
	label.Name = "GuardianHealth"
	label.Adornee = body
	label.Size = UDim2.fromOffset(220, 68)
	label.StudsOffsetWorldSpace = Vector3.new(0, (if boar then 3.5 else 6) * scale, 0)
	label.MaxDistance = 90
	label.AlwaysOnTop = true
	label.Parent = model
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextSize = if definition.boss then 19 else 17
	title.TextColor3 = Color3.fromRGB(255, 245, 219)
	title.TextStrokeTransparency = 0.35
	title.Text = definition.name
	title.Parent = label
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(15, 32)
	track.Size = UDim2.new(1, -30, 0, 10)
	track.BackgroundColor3 = Color3.fromRGB(30, 38, 35)
	track.BorderSizePixel = 0
	track.Parent = label
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if definition.boss then Color3.fromRGB(240, 171, 70) else Color3.fromRGB(142, 203, 105)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local healthText = Instance.new("TextLabel")
	healthText.BackgroundTransparency = 1
	healthText.Position = UDim2.fromOffset(0, 46)
	healthText.Size = UDim2.new(1, 0, 0, 18)
	healthText.Font = Enum.Font.GothamMedium
	healthText.TextSize = 13
	healthText.TextColor3 = Color3.fromRGB(239, 242, 225)
	healthText.TextStrokeTransparency = 0.4
	healthText.Text = tostring(definition.maxHealth) .. " / " .. tostring(definition.maxHealth)
	healthText.Parent = label
	local highlight = Instance.new("Highlight")
	highlight.Name = "CombatSignal"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.2
	highlight.Enabled = false
	highlight.Parent = model
	local transparencies: { [BasePart]: number } = {}
	local frames: { [BasePart]: CFrame } = {}
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			transparencies[object] = object.Transparency
			frames[object] = CFrame.new(center):ToObjectSpace(object.CFrame)
		end
	end
	return {
		definition = definition, model = model, root = body, health = definition.maxHealth,
		maxHealth = definition.maxHealth, alive = true, contributors = {}, participants = {}, participantCount = 0, life = 1,
		engaged = false, lastNearby = now, pattern = 0, nextSlam = math.huge,
		respawnAt = nil, slam = nil, transparencies = transparencies,
		label = label, healthText = healthText, healthFill = fill, highlight = highlight, flashUntil = 0,
		home = center, facing = Vector3.new(0, 0, 1), frames = frames, state = "Patrol", patrol = 0,
		nextMelee = now, recoverUntil = now, melee = nil,
	}
end

local function healthDisplay(foe: Foe)
	foe.model:SetAttribute("Health", foe.health)
	foe.model:SetAttribute("MaxHealth", foe.maxHealth)
	foe.healthText.Text = tostring(foe.health) .. " / " .. tostring(foe.maxHealth)
	foe.healthFill.Size = UDim2.fromScale(foe.health / foe.maxHealth, 1)
end

local function clearSlam(foe: Foe)
	if foe.slam then
		foe.slam.disc:Destroy()
		foe.slam = nil
	end
end

local function visible(foe: Foe, enabled: boolean)
	for object, original in foe.transparencies do
		object.Transparency = if enabled then original else 1
		object.CanQuery = enabled
		object.CanCollide = enabled and object == foe.root
	end
	foe.label.Enabled = enabled
	foe.highlight.Enabled = false
end

local function lineOfSight(source: Actor, foe: Foe): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { source.character }
	parameters.RespectCanCollide = true
	local from = source.root.Position
	local result = Workspace:Raycast(from, foe.root.Position - from, parameters)
	return result == nil or result.Instance:IsDescendantOf(foe.model)
end

function CombatService.start(
	getState: (Player) -> HuntState?, onDefeat: (Player, string) -> (),
	onBondFx: ((Player, Vector3) -> ())?
)
	local destroyed = false
	local folder = Instance.new("Folder")
	folder.Name = "WildbondGuardians"
	folder.Parent = Workspace
	local foes: { Foe } = {}
	local lastAttack: { [Player]: number } = {}
	local lastBond: { [Player]: number } = {}
	local now = Workspace:GetServerTimeNow()
	for _, definition in Rules.foes do
		table.insert(foes, buildFoe(folder, definition, now))
	end

	local function defeat(foe: Foe, at: number)
		foe.alive = false
		foe.life += 1
		foe.respawnAt = at + Rules.respawnDelay
		clearSlam(foe) -- A killing blow during windup always cancels that slam.
		foe.melee = nil
		setState(foe, "Dead", at, 0.7)
		foe.model:SetAttribute("Status", "Returning")
		visible(foe, false)
		for player, character in foe.contributors do
			local source = actor(player)
			if source and source.character == character and Rules.canReward(getState(player), true, player.Parent == Players, true,
				foe.definition.id, point(source.root.Position), point(foe.root.Position)) then
				onDefeat(player, foe.definition.id)
			end
		end
		foe.contributors = {}
		foe.participants = {}
	end

	local function nearestPlayer(foe: Foe): Actor?
		local nearest: Actor? = nil
		local best = Rules.aggroRange * Rules.aggroRange
		for _, player in Players:GetPlayers() do
			local source = actor(player)
			if source and Rules.eligible(getState(player), true, foe.definition.id)
				and Rules.inRange(point(source.root.Position), point(foe.home), Rules.leashRadius) then
				local distance = Rules.distanceSquared(point(source.root.Position), point(foe.root.Position))
				if distance <= Rules.aggroRange * Rules.aggroRange and lineOfSight(source, foe) then
					if distance <= best then nearest, best = source, distance end
				end
			end
		end
		return nearest
	end

	local function engage(foe: Foe, at: number)
		if foe.engaged then return end
		foe.engaged, foe.lastNearby = true, at
		foe.nextSlam = if foe.definition.boss then at + Rules.firstSlamDelay else math.huge
	end

	local function reset(foe: Foe, at: number)
		foe.life += 1
		foe.alive, foe.engaged = true, false
		foe.health, foe.maxHealth = foe.definition.maxHealth, foe.definition.maxHealth
		foe.contributors, foe.respawnAt, foe.flashUntil, foe.pattern = {}, nil, 0, 0
		foe.participants, foe.participantCount = {}, 0
		foe.lastNearby, foe.nextSlam = at, math.huge
		foe.melee, foe.nextMelee, foe.recoverUntil = nil, at, at
		place(foe, foe.home, Vector3.new(0, 0, 1))
		setState(foe, "Patrol", at)
		foe.model:SetAttribute("PartySize", 1)
		clearSlam(foe)
		foe.model:SetAttribute("Status", "Ready")
		healthDisplay(foe)
		visible(foe, true)
	end

	local function damage(foe: Foe, player: Player, source: Actor, amount: number, at: number)
		engage(foe, at)
		if not foe.participants[player] then
			foe.participants[player] = true
			foe.participantCount = math.min(foe.participantCount + 1, Rules.maxGroupSize)
			local maximum = Rules.scaledHealth(foe.definition.maxHealth, foe.participantCount)
			foe.health += maximum - foe.maxHealth
			foe.maxHealth = maximum
			foe.model:SetAttribute("PartySize", foe.participantCount)
		end
		foe.contributors[player] = source.character
		foe.health = math.max(0, foe.health - amount)
		foe.flashUntil = at + 0.15
		healthDisplay(foe)
		if foe.health <= 0 then defeat(foe, at) end
	end

	local function selectFoe(source: Actor, state: HuntState, radius: number): Foe?
		local selected: Foe? = nil
		local best = radius * radius
		for _, foe in foes do
			if foe.alive and foe.state ~= "Return" and Rules.eligible(state, true, foe.definition.id) then
				local distance = Rules.distanceSquared(point(source.root.Position), point(foe.root.Position))
				if distance <= best and lineOfSight(source, foe) then
					selected, best = foe, distance
				end
			end
		end
		return selected
	end

	local function beginSlam(foe: Foe, target: Actor, at: number)
		foe.pattern += 1
		local pattern = Rules.attackPattern(foe.definition, foe.pattern)
		local burst = pattern.centered
		local position = if burst then foe.root.Position else target.root.Position
		local center = Vector3.new(position.X, Rules.groundHeight, position.Z)
		local radius = pattern.radius
		local disc = part(folder, "SlamWarning", Vector3.new(0.12, radius * 2, radius * 2),
			CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 80, 70), Enum.PartType.Cylinder)
		disc.Material = Enum.Material.Neon
		disc.Transparency = 0.45
		disc.CanQuery = false
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromOffset(125, 26)
		sign.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
		sign.AlwaysOnTop = true
		sign.MaxDistance = 65
		sign.Parent = disc
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = 16
		text.TextColor3 = Color3.fromRGB(255, 239, 224)
		text.TextStrokeTransparency = 0.2
		text.Text = if burst then "RETREAT!" else "MOVE!"
		text.Parent = sign
		foe.slam = { center = center, radius = radius, resolveAt = at + pattern.windup, disc = disc }
		foe.model:SetAttribute("AttackTarget", target.root.Position)
		setState(foe, "SkillWindup", at, pattern.windup)
		foe.model:SetAttribute("Status", "Windup")
	end

	-- Short steering probes fit these flat clearings. Every candidate needs floor
	-- and a clear body-width corridor; walls and cliff edges stop movement.
	local function move(foe: Foe, goal: Vector3, speed: number, delta: number, players: { Player })
		local offset = Vector3.new(goal.X - foe.root.Position.X, 0, goal.Z - foe.root.Position.Z)
		if offset.Magnitude < 0.1 then return end
		local step = math.min(speed * delta, offset.Magnitude)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		local excluded: { Instance } = { folder }
		for _, player in players do if player.Character then table.insert(excluded, player.Character) end end
		parameters.FilterDescendantsInstances = excluded
		parameters.RespectCanCollide = true
		local width = if foe.definition.boss then 2.5 elseif foe.definition.kind == "boar" then 2.7 else 1.8
		for _, angle in { 0, 45, -45, 90, -90, 135, -135, 180 } do
			local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(offset.Unit)
			local position = foe.root.Position + direction * step
			local radius = if foe.state == "Patrol" then Rules.patrolRadius else Rules.leashRadius
			if not Rules.inRange(point(position), point(foe.home), radius) then continue end
			local side = Vector3.new(-direction.Z, 0, direction.X) * width
			local clear = true
			for _, sideOffset in { Vector3.zero, side, -side } do
				local from = foe.root.Position + sideOffset
				if Workspace:Raycast(from, direction * (step + width), parameters) then clear = false; break end
				local floor = Workspace:Raycast(position + sideOffset + Vector3.new(0, 2, 0), Vector3.new(0, -9, 0), parameters)
				if not floor or math.abs(floor.Position.Y - Rules.groundHeight) > 1.25 then clear = false; break end
			end
			if clear then place(foe, position, direction); return end
		end
	end

	local function beginMelee(foe: Foe, target: Actor, at: number)
		place(foe, foe.root.Position, target.root.Position - foe.root.Position)
		foe.melee = { target = target, resolveAt = at + Rules.enemyMeleeWindup }
		foe.nextMelee = at + (if foe.definition.boss then Rules.bossMeleeCooldown else Rules.enemyMeleeCooldown)
		foe.model:SetAttribute("AttackTarget", target.root.Position)
		setState(foe, "MeleeWindup", at, Rules.enemyMeleeWindup)
		foe.model:SetAttribute("Status", "Windup")
	end

	local function update(at: number, delta: number)
		if destroyed then
			return
		end
		local players = Players:GetPlayers()
		for _, foe in foes do
			if not foe.alive then
				if foe.respawnAt and at >= foe.respawnAt then
					reset(foe, at)
				end
				continue
			end
			if foe.state == "Return" then
				if (foe.root.Position - foe.home).Magnitude <= 0.8 then reset(foe, at)
				else move(foe, foe.home, Rules.chaseSpeed, delta, players) end
				continue
			end
			local nearest = nearestPlayer(foe)
			if nearest then
				engage(foe, at)
				foe.lastNearby = at
			elseif foe.engaged and at >= foe.lastNearby + Rules.encounterResetDelay then
				clearSlam(foe)
				foe.melee = nil
				setState(foe, "Return", at)
				foe.model:SetAttribute("Status", "Returning")
				continue
			end
			local slam = foe.slam
			if slam and at >= slam.resolveAt then
				for _, player in players do
					local source = actor(player)
					if source and Rules.eligible(getState(player), true, foe.definition.id)
						and Rules.inSlam(point(source.root.Position), point(slam.center), slam.radius) and lineOfSight(source, foe) then
						takeDamage(source, foe.definition.slamDamage, at)
					end
				end
				clearSlam(foe)
				foe.nextSlam = at + Rules.slamCooldown
				foe.recoverUntil = at + Rules.enemyMeleeRecover
				setState(foe, "MeleeRecover", at, Rules.enemyMeleeRecover)
				foe.model:SetAttribute("Status", "Ready")
			end
			local melee = foe.melee
			if melee and at >= melee.resolveAt then
				local target = actor(melee.target.player)
				if target and target.character == melee.target.character and Rules.eligible(getState(target.player), true, foe.definition.id)
					and Rules.inEnemyMelee(point(target.root.Position), point(foe.root.Position), point(foe.facing))
					and lineOfSight(target, foe) then takeDamage(target, foe.definition.meleeDamage, at) end
				foe.melee = nil
				foe.recoverUntil = at + Rules.enemyMeleeRecover
				setState(foe, "MeleeRecover", at, Rules.enemyMeleeRecover)
				foe.model:SetAttribute("Status", "Ready")
			end
			if not foe.slam and not foe.melee and at >= foe.recoverUntil then
				if nearest then
					if at >= foe.nextSlam then beginSlam(foe, nearest, at)
					elseif Rules.inRange(point(nearest.root.Position), point(foe.root.Position), Rules.enemyMeleeRange) then
						if at >= foe.nextMelee then beginMelee(foe, nearest, at) end
					else
						setState(foe, "Chase", at)
						move(foe, nearest.root.Position, Rules.chaseSpeed, delta, players)
					end
				else
					setState(foe, "Patrol", at)
					local phase = foe.patrol * 2.4 + foe.home.X
					local goal = foe.home + Vector3.new(math.sin(phase), 0, math.cos(phase)) * Rules.patrolRadius * 0.75
					if (foe.root.Position - goal).Magnitude < 0.6 then foe.patrol += 1 end
					move(foe, goal, Rules.patrolSpeed, delta, players)
				end
			end
			local flashing = at < foe.flashUntil
			foe.highlight.Enabled = flashing or foe.slam ~= nil or foe.melee ~= nil
			if flashing then
				foe.highlight.FillColor = Color3.fromRGB(255, 246, 221)
				foe.highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			elseif foe.slam or foe.melee then
				foe.highlight.FillColor = Color3.fromRGB(255, 99, 55)
				foe.highlight.OutlineColor = Color3.fromRGB(255, 170, 75)
			end
		end
	end

	local accumulated = 0
	local heartbeat = RunService.Heartbeat:Connect(function(delta: number)
		accumulated += delta
		if accumulated >= 0.1 then
			local elapsed = math.min(accumulated, 0.2)
			accumulated = 0
			update(Workspace:GetServerTimeNow(), elapsed)
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player: Player)
		lastAttack[player] = nil
		lastBond[player] = nil
		for _, foe in foes do
			foe.contributors[player] = nil
		end
	end)

	local service = {}
	function service.attack(player: Player): (boolean, string, Vector3?, boolean?)
		if destroyed then
			return false, "Combat is unavailable.", nil, nil
		end
		local source = actor(player)
		if not source then
			return false, "Wait until your character is ready.", nil, nil
		end
		local state = getState(player)
		local at = Workspace:GetServerTimeNow()
		if not Rules.cooldownReady(at, lastAttack[player], Rules.meleeCooldown) then
			return false, "Your next swing is not ready yet.", nil, nil
		end
		lastAttack[player] = at
		local ahead = source.root.Position + source.root.CFrame.LookVector * 6
		if not state then return true, "Practice swing.", ahead, false end
		local selected = selectFoe(source, state, Rules.meleeRange)
		if not selected then
			return true, if state.active then "Swing." else "Practice swing.", ahead, false
		end
		damage(selected, player, source, Rules.meleeDamage, at)
		if selected.health <= 0 then
			return true, selected.definition.name .. " defeated!", selected.root.Position, true
		end
		return true, selected.definition.name .. ": " .. tostring(selected.health) .. " HP", selected.root.Position, true
	end

	function service.cooldown(player: Player): number
		local previous = lastBond[player]
		return if previous then math.max(0, previous + Rules.petCooldown - Workspace:GetServerTimeNow()) else 0
	end

	function service.bond(player: Player): (boolean, string)
		if destroyed then return false, "Combat is unavailable." end
		local source, state = actor(player), getState(player)
		if not source then return false, "Wait until your character is ready." end
		if not state then return false, "Wait until your companion is ready." end
		if not Rules.canBond(state) then return false, "Equip a companion you own first." end
		local at = Workspace:GetServerTimeNow()
		if not Rules.cooldownReady(at, lastBond[player], Rules.petCooldown) then
			return false, "Your companion is catching its breath."
		end
		local selected = selectFoe(source, state, Rules.petRange)
		if not selected then return false, if state.active then "Move within 18 studs of an eligible creature."
			else "Move near a wild creature, or begin a hunt for bounty guardians." end
		lastBond[player] = at
		engage(selected, at)
		local life, character, equipped, defeated = selected.life, source.character, state.equipped, state.defeated
		local equipRevision = state.equipRevision
		task.delay(Rules.petWindup, function()
			if destroyed or not selected.alive or selected.life ~= life or selected.state == "Return" then return end
			local current, currentState = actor(player), getState(player)
			if not current or current.character ~= character or currentState ~= state
				or currentState.defeated ~= defeated or currentState.equipped ~= equipped or currentState.equipRevision ~= equipRevision
				or not Rules.canBond(currentState) or not Rules.eligible(currentState, true, selected.definition.id)
				or not Rules.inRange(point(current.root.Position), point(selected.root.Position), Rules.petRange)
				or not lineOfSight(current, selected) then return end
			damage(selected, player, current, Rules.petDamage, Workspace:GetServerTimeNow())
		end)
		if onBondFx then onBondFx(player, selected.root.Position) end
		return true, "Companion strike!"
	end

	function service.destroy()
		if destroyed then
			return
		end
		destroyed = true
		heartbeat:Disconnect()
		leaving:Disconnect()
		for _, foe in foes do
			clearSlam(foe)
			foe.contributors = {}
			foe.participants = {}
		end
		lastAttack = {}
		lastBond = {}
		folder:Destroy()
	end

	return service
end

return CombatService
