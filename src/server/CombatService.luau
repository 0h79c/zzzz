--!strict
-- Guardians and combat decisions live on the server. The attack remote supplies no target.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Rules = require(ReplicatedStorage:WaitForChild("Wildbond"):WaitForChild("CombatRules"))

type HuntState = Rules.HuntState
type Definition = Rules.FoeDefinition
type Actor = { character: Model, humanoid: Humanoid, root: BasePart }
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
	return { character = character, humanoid = humanoid, root = root }
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
	model:SetAttribute("Health", definition.maxHealth)
	model:SetAttribute("MaxHealth", definition.maxHealth)
	model:SetAttribute("Status", "Ready")
	model:SetAttribute("PartySize", 1)
	model.Parent = parent
	local spawn = definition.position
	local center = Vector3.new(spawn.x, spawn.y, spawn.z)
	local scale = if definition.boss then 1.4 else 1
	local bark = if definition.id == "river" then Color3.fromRGB(80, 115, 117) else Color3.fromRGB(108, 86, 63)
	local stone = if definition.boss then Color3.fromRGB(114, 119, 94) else Color3.fromRGB(143, 139, 112)
	local leaves = if definition.id == "river" then Color3.fromRGB(74, 181, 156) else Color3.fromRGB(120, 166, 76)
	local glow = if definition.boss then Color3.fromRGB(255, 174, 72) else Color3.fromRGB(171, 248, 164)
	local function shaped(name: string, size: Vector3, offset: Vector3, color: Color3, angles: Vector3?): Part
		local rotation = angles or Vector3.zero
		return part(model, name, size * scale, CFrame.new(center + offset * scale)
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)), color)
	end
	local body = shaped("BarkCore", Vector3.new(3.1, 3.35, 2.5), Vector3.zero, bark, Vector3.new(0, 0, -3))
	body.CanCollide = true
	model.PrimaryPart = body
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
		shaped("LeafCrown", Vector3.new(1.25, 0.62, 1.1), Vector3.new(direction * 1.3, 4.07, -0.4), leaves,
			Vector3.new(5, direction * 20, -direction * 12))
	end
	shaped("Brow", Vector3.new(2.35, 0.27, 0.33), Vector3.new(0, 2.64, 1.14), bark, Vector3.new(0, 0, 3))
	shaped("MossShoulder", Vector3.new(1.85, 0.65, 1.75), Vector3.new(-1.27, 1.68, -0.1), leaves,
		Vector3.new(0, -12, 9))
	if definition.boss then
		shaped("AncientCrest", Vector3.new(0.9, 1.3, 0.55), Vector3.new(0, 3.47, 0.2), glow,
			Vector3.new(0, 0, 45)).Material = Enum.Material.Neon
	end

	local label = Instance.new("BillboardGui")
	label.Name = "GuardianHealth"
	label.Adornee = body
	label.Size = UDim2.fromOffset(220, 68)
	label.StudsOffsetWorldSpace = Vector3.new(0, 6 * scale, 0)
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
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			transparencies[object] = object.Transparency
		end
	end
	return {
		definition = definition, model = model, root = body, health = definition.maxHealth,
		maxHealth = definition.maxHealth, alive = true, contributors = {}, participants = {}, participantCount = 0, life = 1,
		engaged = false, lastNearby = now, pattern = 0, nextSlam = math.huge,
		respawnAt = nil, slam = nil, transparencies = transparencies,
		label = label, healthText = healthText, healthFill = fill, highlight = highlight, flashUntil = 0,
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
	local now = os.clock()
	for _, definition in Rules.foes do
		table.insert(foes, buildFoe(folder, definition, now))
	end

	local function defeat(foe: Foe, at: number)
		foe.alive = false
		foe.life += 1
		foe.respawnAt = at + Rules.respawnDelay
		clearSlam(foe) -- A killing blow during windup always cancels that slam.
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
			if source and Rules.eligible(getState(player), true, foe.definition.id) then
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
		foe.nextSlam = at + Rules.firstSlamDelay
	end

	local function reset(foe: Foe, at: number)
		foe.life += 1
		foe.alive, foe.engaged = true, false
		foe.health, foe.maxHealth = foe.definition.maxHealth, foe.definition.maxHealth
		foe.contributors, foe.respawnAt, foe.flashUntil, foe.pattern = {}, nil, 0, 0
		foe.participants, foe.participantCount = {}, 0
		foe.lastNearby, foe.nextSlam = at, math.huge
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
			if foe.alive and Rules.eligible(state, true, foe.definition.id) then
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
		foe.model:SetAttribute("Status", "Windup")
	end

	local function update(at: number)
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
			local nearest = nearestPlayer(foe)
			if nearest then
				engage(foe, at)
				foe.lastNearby = at
			elseif foe.engaged and at >= foe.lastNearby + Rules.encounterResetDelay then
				reset(foe, at)
			end
			local slam = foe.slam
			if slam and at >= slam.resolveAt then
				for _, player in players do
					local source = actor(player)
					if source and Rules.eligible(getState(player), true, foe.definition.id)
						and Rules.inSlam(point(source.root.Position), point(slam.center), slam.radius) then
						source.humanoid:TakeDamage(foe.definition.slamDamage)
					end
				end
				clearSlam(foe)
				foe.nextSlam = at + Rules.slamCooldown
				foe.model:SetAttribute("Status", "Ready")
			elseif not slam and at >= foe.nextSlam then
				if nearest then
					beginSlam(foe, nearest, at)
				end
			end
			local flashing = at < foe.flashUntil
			foe.highlight.Enabled = flashing or foe.slam ~= nil
			if flashing then
				foe.highlight.FillColor = Color3.fromRGB(255, 246, 221)
				foe.highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			elseif foe.slam then
				foe.highlight.FillColor = Color3.fromRGB(255, 99, 55)
				foe.highlight.OutlineColor = Color3.fromRGB(255, 170, 75)
			end
		end
	end

	local accumulated = 0
	local heartbeat = RunService.Heartbeat:Connect(function(delta: number)
		accumulated += delta
		if accumulated >= 0.1 then
			accumulated = 0
			update(os.clock())
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
	function service.attack(player: Player): (boolean, string)
		if destroyed then
			return false, "Combat is unavailable."
		end
		local source = actor(player)
		if not source then
			return false, "Wait until your character is ready."
		end
		local state = getState(player)
		if not state or not state.active then
			return false, "Start an expedition at camp first."
		end
		local at = os.clock()
		if not Rules.cooldownReady(at, lastAttack[player], Rules.meleeCooldown) then
			return false, "Your next swing is not ready yet."
		end
		lastAttack[player] = at
		local selected = selectFoe(source, state, Rules.meleeRange)
		if not selected then
			return false, "Move closer to an unfinished guardian."
		end
		damage(selected, player, source, Rules.meleeDamage, at)
		if selected.health <= 0 then
			return true, selected.definition.name .. " defeated!"
		end
		return true, selected.definition.name .. ": " .. tostring(selected.health) .. " HP"
	end

	function service.cooldown(player: Player): number
		local previous = lastBond[player]
		return if previous then math.max(0, previous + Rules.petCooldown - os.clock()) else 0
	end

	function service.bond(player: Player): (boolean, string)
		if destroyed then return false, "Combat is unavailable." end
		local source, state = actor(player), getState(player)
		if not source then return false, "Wait until your character is ready." end
		if not state or not state.active then return false, "Start an expedition at camp first." end
		if not Rules.canBond(state) then return false, "Equip a companion you own first." end
		local at = os.clock()
		if not Rules.cooldownReady(at, lastBond[player], Rules.petCooldown) then
			return false, "Your companion is catching its breath."
		end
		local selected = selectFoe(source, state, Rules.petRange)
		if not selected then return false, "Move within 18 studs of an unfinished guardian." end
		lastBond[player] = at
		engage(selected, at)
		local life, character, equipped, defeated = selected.life, source.character, state.equipped, state.defeated
		local equipRevision = state.equipRevision
		task.delay(Rules.petWindup, function()
			if destroyed or not selected.alive or selected.life ~= life then return end
			local current, currentState = actor(player), getState(player)
			if not current or current.character ~= character or currentState ~= state
				or currentState.defeated ~= defeated or currentState.equipped ~= equipped or currentState.equipRevision ~= equipRevision
				or not Rules.canBond(currentState) or not Rules.eligible(currentState, true, selected.definition.id)
				or not Rules.inRange(point(current.root.Position), point(selected.root.Position), Rules.petRange)
				or not lineOfSight(current, selected) then return end
			damage(selected, player, current, Rules.petDamage, os.clock())
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
