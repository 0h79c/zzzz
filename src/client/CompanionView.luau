--!strict
-- Pet positions, health and actions come from the server. These anchored parts
-- articulate the replicated actor and never select or damage foes.
local RunService = game:GetService("RunService")
local CompanionView = {}

type Piece = { part: BasePart, offset: CFrame, phase: number?, role: string }
type Pet = {
	actor: Model, visual: Model, pieces: { Piece }, petId: string?, frame: CFrame?, phase: number,
	state: string, changedAt: number, label: TextLabel?, fill: Frame?, billboard: BillboardGui?,
}
type FolderWatch = { active: boolean, connections: { RBXScriptConnection } }
local names: { [string]: string } = { mosswolf = "Moss Wolf", emberfox = "Ember Fox", tidecub = "Tide Cub" }

local function disconnect(connections: { RBXScriptConnection })
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function piece(pet: Pet, name: string, size: Vector3, offset: CFrame, color: Color3, role: string?, phase: number?, wedge: boolean?): BasePart
	local part = (if wedge then Instance.new("WedgePart") else Instance.new("Part")) :: BasePart
	part.Name, part.Size, part.Color, part.Material = name, size, color, Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Parent = pet.visual
	table.insert(pet.pieces, { part = part, offset = offset, phase = phase, role = role or "body" })
	return part
end

local function build(pet: Pet, petId: string, localOwner: boolean)
	pet.visual:ClearAllChildren()
	table.clear(pet.pieces)
	pet.petId = petId
	pet.visual:SetAttribute("PetId", petId)
	pet.visual:SetAttribute("OwnerUserId", pet.actor:GetAttribute("OwnerUserId"))
	local fox, cub = petId == "emberfox", petId == "tidecub"
	local fur = if fox then Color3.fromRGB(196, 115, 67) elseif cub then Color3.fromRGB(129, 180, 197) else Color3.fromRGB(222, 230, 220)
	local shadow = if fox then Color3.fromRGB(89, 70, 65) elseif cub then Color3.fromRGB(104, 146, 169) else Color3.fromRGB(176, 192, 189)
	local cream = if fox then Color3.fromRGB(238, 219, 177) else shadow
	local accent = if fox then Color3.fromRGB(239, 205, 133) elseif cub then Color3.fromRGB(178, 210, 221) else Color3.fromRGB(139, 174, 116)
	local body = piece(pet, "Body", if cub then Vector3.new(1.5, 1.1, 1.6) else Vector3.new(1.25, 0.95, 2), CFrame.identity, fur)
	pet.visual.PrimaryPart = body
	piece(pet, "ChestRuff", if cub then Vector3.new(1.4, 1.05, 0.7) else Vector3.new(1.4, 1.12, 0.8), CFrame.new(0, 0.1, -0.7) * CFrame.Angles(math.rad(-8), 0, 0), if fox then cream else fur)
	piece(pet, "Head", if cub then Vector3.new(1.2, 0.95, 0.9) else Vector3.new(0.95, 0.85, 0.95), CFrame.new(0, 0.45, -1.25), fur, "head")
	piece(pet, "Muzzle", if cub then Vector3.new(0.72, 0.32, 0.4) else Vector3.new(0.65, 0.32, 0.65), CFrame.new(0, 0.28, if cub then -1.78 else -1.92), cream, "head")
	piece(pet, "Jaw", if cub then Vector3.new(0.63, 0.18, 0.45) else Vector3.new(0.56, 0.18, 0.7), CFrame.new(0, 0.06, if cub then -1.77 else -1.91), shadow, "jaw")
	piece(pet, "Nose", Vector3.new(0.25, 0.2, 0.16), CFrame.new(0, 0.32, if cub then -2.02 else -2.29), Color3.fromRGB(43, 54, 57), "head")
	for _, side in { -1, 1 } do
		local ear = piece(pet, "Ear", if fox then Vector3.new(0.45, 0.95, 0.42) elseif cub then Vector3.new(0.46, 0.46, 0.4) else Vector3.new(0.32, 0.68, 0.4), CFrame.new(side * (if cub then 0.5 else 0.34), if fox then 1.15 else 1.05, -1.15) * CFrame.Angles(0, 0, math.rad(-side * 12)), shadow, "head", nil, not cub)
		if cub and ear:IsA("Part") then ear.Shape = Enum.PartType.Ball end
		piece(pet, "Eye", Vector3.new(0.08, 0.13, 0.17), CFrame.new(side * (if cub then 0.61 else 0.48), 0.53, -1.56), Color3.fromRGB(47, 72, 83), "head")
		for _, z in { -0.63, 0.7 } do
			local phase = if (side == -1 and z < 0) or (side == 1 and z > 0) then 0 else math.pi
			piece(pet, "Leg", if cub then Vector3.new(0.43, 0.77, 0.45) else Vector3.new(0.32, 0.92, 0.38), CFrame.new(side * (if cub then 0.53 else 0.46), if cub then -0.96 else -0.84, z), shadow, if z < 0 then "frontLeg" else "backLeg", phase)
		end
	end
	piece(pet, "Tail", if fox then Vector3.new(0.68, 0.65, 1.6) elseif cub then Vector3.new(0.48, 0.45, 0.5) else Vector3.new(0.4, 0.42, 1.22), CFrame.new(0, 0.15, if cub then 1 else 1.37) * CFrame.Angles(math.rad(-23), 0, 0), fur, "tail")
	if fox then piece(pet, "FoxTailTip", Vector3.new(0.7, 0.67, 0.5), CFrame.new(0, 0.45, 2.08) * CFrame.Angles(math.rad(-23), 0, 0), cream, "tail") end
	piece(pet, "TrailScarf", Vector3.new(1.43, 0.26, 0.33), CFrame.new(0, 0.3, -0.9), accent)
	piece(pet, "ScarfKnot", Vector3.new(0.25, 0.6, 0.25), CFrame.new(0.64, 0.02, -0.97) * CFrame.Angles(0, 0, math.rad(-15)), accent)
	for index = 1, 6 do
		local spark = piece(pet, "SkillSpark", Vector3.new(0.16, 0.42, 0.16), CFrame.identity, accent, "spark", index * math.pi / 3)
		spark.Material, spark.Transparency = Enum.Material.Neon, 1
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name, billboard.Adornee = "PetHealth", body
	billboard.Size, billboard.StudsOffset = UDim2.fromOffset(170, 42), Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop, billboard.MaxDistance, billboard.Parent = true, if localOwner then 85 else 55, pet.visual
	local label = Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "HealthLabel", UDim2.new(1, 0, 0, 25), 1
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.GothamMedium, 12, Color3.fromRGB(244, 247, 237)
	label.TextStrokeColor3, label.TextStrokeTransparency, label.Parent = Color3.fromRGB(30, 44, 38), 0.35, billboard
	local bar = Instance.new("Frame")
	bar.Name, bar.Position, bar.Size = "HealthBar", UDim2.new(0.12, 0, 0, 28), UDim2.new(0.76, 0, 0, 5)
	bar.BackgroundColor3, bar.BorderSizePixel, bar.Parent = Color3.fromRGB(38, 48, 45), 0, billboard
	local fill = Instance.new("Frame")
	fill.Name, fill.Size, fill.BorderSizePixel = "Fill", UDim2.fromScale(1, 1), 0
	fill.BackgroundColor3, fill.Parent = if localOwner then Color3.fromRGB(140, 220, 159) else Color3.fromRGB(149, 195, 218), bar
	pet.billboard, pet.label, pet.fill = billboard, label, fill
end

local function animate(pet: Pet, dt: number, now: number, container: Folder, player: Player)
	local root, petId = pet.actor.PrimaryPart, pet.actor:GetAttribute("PetId")
	local owner = pet.actor:GetAttribute("OwnerUserId")
	local health, maxHealth = pet.actor:GetAttribute("Health"), pet.actor:GetAttribute("MaxHealth")
	if not root or not root:IsDescendantOf(pet.actor) or typeof(petId) ~= "string" or not names[petId]
		or typeof(owner) ~= "number" or typeof(health) ~= "number" or typeof(maxHealth) ~= "number" or maxHealth <= 0 then
		pet.visual.Parent, pet.frame = nil, nil
		return
	end
	if pet.petId ~= petId or pet.visual:GetAttribute("OwnerUserId") ~= owner then build(pet, petId, owner == player.UserId) end
	pet.visual.Parent = container
	local previous = pet.frame or root.CFrame
	local frame = if (previous.Position - root.CFrame.Position).Magnitude > 40 then root.CFrame
		else previous:Lerp(root.CFrame, 1 - math.exp(-math.min(dt, 0.1) * 16))
	local speed = ((frame.Position - previous.Position) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 0.001)
	pet.frame = frame
	local serverState = pet.actor:GetAttribute("State")
	local state = if health == 0 then "Dead" elseif typeof(serverState) == "string" then serverState else "Follow"
	if state ~= pet.state then pet.state, pet.changedAt = state, now end
	local started, duration = pet.actor:GetAttribute("ActionStartedAt"), pet.actor:GetAttribute("ActionDuration")
	-- State and HP can arrive in separate replication updates. A premature
	-- Follow timestamp must not restart the death fade while HP is still zero.
	local actionStart = if state == "Dead" and serverState ~= "Dead" then pet.changedAt
		elseif typeof(started) == "number" then started else pet.changedAt
	local elapsed = now - actionStart
	local progress = math.clamp(elapsed / (if typeof(duration) == "number" and duration > 0 then duration else 0.5), 0, 1)
	local dead = if state == "Dead" then math.clamp(elapsed / 0.45, 0, 1) else 0
	local skill, attack = state == "Skill", state == "Attack"
	local windup = if attack or skill then math.clamp(progress / 0.3, 0, 1) * (1 - math.clamp((progress - 0.3) / 0.16, 0, 1)) else 0
	local strike = if attack or skill then math.sin(math.clamp((progress - 0.3) / 0.7, 0, 1) * math.pi) else 0
	local target = pet.actor:GetAttribute("AttackTarget")
	if (attack or skill) and typeof(target) == "Vector3" then
		local direction = (target - frame.Position) * Vector3.new(1, 0, 1)
		if direction.Magnitude > 0.01 then frame = CFrame.lookAt(frame.Position, frame.Position + direction.Unit) end
	end
	local gait = if state == "Follow" then math.clamp(speed / 16, 0, 1) else 0
	pet.phase += math.min(dt, 0.1) * (5 + math.min(speed, 22))
	local bob = math.sin(pet.phase * 2) * 0.045 * gait
	local lift = if skill then strike * 0.85 elseif attack then strike * 0.22 else 0
	local pose = frame * CFrame.new(0, bob + lift - dead * 0.9, windup * 0.18 - strike * (if skill then 1.1 else 0.5))
		* CFrame.Angles(windup * 0.08 - strike * 0.1, 0, dead * 1.1)
	for _, item in pet.pieces do
		local offset = item.offset
		if item.role == "spark" then
			local angle = (item.phase or 0) + progress * math.pi * 2
			offset = CFrame.new(math.cos(angle) * (1.2 + strike * 0.5), 0.2 + strike * 0.7, math.sin(angle) * 1.7)
				* CFrame.Angles(0.4, angle, -0.6)
			item.part.Transparency = if skill and progress > 0 and progress < 1 then 0.15 + 0.85 * (1 - strike) else 1
		elseif item.phase then
			local swing = math.sin(pet.phase + item.phase) * 0.35 * gait
			if item.role == "frontLeg" then swing += windup * 0.18 - strike * (if skill then 0.7 else 0.25)
			else swing += strike * 0.28 end
			local hip = Vector3.new(offset.X, -0.38, offset.Z)
			offset = CFrame.new(hip) * CFrame.Angles(swing, 0, 0) * CFrame.new(-hip) * offset
		elseif item.role == "head" or item.role == "jaw" then
			local neck = Vector3.new(0, 0.3, -0.85)
			offset = CFrame.new(neck) * CFrame.Angles(-windup * 0.16 + strike * 0.2, 0, 0) * CFrame.new(-neck) * offset
			if item.role == "jaw" then
				local hinge = Vector3.new(0, 0.13, -1.55)
				offset = CFrame.new(hinge) * CFrame.Angles(-(windup * 0.42 + strike * 0.16), 0, 0) * CFrame.new(-hinge) * offset
			end
		elseif item.role == "tail" then
			offset *= CFrame.Angles(0, math.sin(pet.phase * 0.55) * 0.09 * (1 - strike), windup * 0.14)
		end
		if item.role ~= "spark" then item.part.Transparency = dead end
		item.part.CFrame = pose * offset
	end
	local billboard, label, fill = pet.billboard, pet.label, pet.fill
	if billboard and label and fill then
		billboard.Enabled = state ~= "Dead" and typeof(health) == "number" and typeof(maxHealth) == "number" and maxHealth > 0
		if typeof(health) == "number" and typeof(maxHealth) == "number" and maxHealth > 0 then
			label.Text = string.format("%s  %d / %d", names[petId], math.ceil(math.max(0, health)), math.ceil(maxHealth))
			fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
		end
	end
end

function CompanionView.start(player: Player): (() -> (), (Vector3) -> ())
	local container = Instance.new("Folder")
	container.Name, container.Parent = "LocalCompanionVisuals", workspace
	container:SetAttribute("CosmeticOnly", true)
	local pets: { [Model]: Pet } = {}
	local folders: { [Instance]: FolderWatch } = {}
	local stopped = false
	local function removePet(item: Instance)
		if not item:IsA("Model") then return end
		local pet = pets[item]
		if not pet then return end
		pet.visual:Destroy()
		pets[item] = nil
	end
	local function addPet(item: Instance)
		if stopped or not item:IsA("Model") or pets[item] then return end
		local visual = Instance.new("Model")
		visual.Name, visual.Parent = item.Name, container
		visual:SetAttribute("CosmeticOnly", true)
		pets[item] = { actor = item, visual = visual, pieces = {}, petId = nil, frame = nil, phase = 0, state = "", changedAt = 0,
			label = nil, fill = nil, billboard = nil }
	end
	local function detach(folder: Instance, watch: FolderWatch)
		for _, child in folder:GetChildren() do removePet(child) end
		for model in pets do if model.Parent == folder then removePet(model) end end
		for index = #watch.connections, 2, -1 do watch.connections[index]:Disconnect(); table.remove(watch.connections, index) end
		watch.active = false
	end
	local function refreshFolder(folder: Instance, watch: FolderWatch)
		local active = not stopped and folder.Parent == workspace and folder.Name == "WildbondCompanions"
		if watch.active and not active then detach(folder, watch) end
		if active and not watch.active then
			watch.active = true
			table.insert(watch.connections, folder.ChildAdded:Connect(addPet))
			table.insert(watch.connections, folder.ChildRemoved:Connect(removePet))
			for _, child in folder:GetChildren() do addPet(child) end
		end
	end
	local function watchFolder(folder: Instance)
		if stopped or folder == container or not folder:IsA("Folder") or folders[folder] then return end
		local watch: FolderWatch = { active = false, connections = {} }
		folders[folder] = watch
		table.insert(watch.connections, folder:GetPropertyChangedSignal("Name"):Connect(function() refreshFolder(folder, watch) end))
		refreshFolder(folder, watch)
	end
	local function removeFolder(folder: Instance)
		local watch = folders[folder]
		if not watch then return end
		if watch.active then detach(folder, watch) end
		disconnect(watch.connections)
		folders[folder] = nil
	end
	for _, folder in workspace:GetChildren() do watchFolder(folder) end
	local added, removed = workspace.ChildAdded:Connect(watchFolder), workspace.ChildRemoved:Connect(removeFolder)
	local render = RunService.RenderStepped:Connect(function(dt: number)
		local now = workspace:GetServerTimeNow()
		for model, pet in pets do
			local parent = model.Parent
			if parent and folders[parent] and folders[parent].active then animate(pet, dt, now, container, player)
			else removePet(model) end
		end
	end)
	local function cleanup()
		if stopped then return end
		stopped = true
		render:Disconnect(); added:Disconnect(); removed:Disconnect()
		for folder in folders do removeFolder(folder) end
		for model in pets do removePet(model) end
		container:Destroy()
	end
	-- The old manual Bond effect still calls this API. Replicated action timestamps
	-- drive its animation now, so the callback must not start a second pounce.
	local function strikeAt(_targetPosition: Vector3) end
	return cleanup, strikeAt
end

return CompanionView
