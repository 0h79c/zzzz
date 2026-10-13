--!strict
-- Local articulation only; the original server geometry remains the hitbox.
local RunService = game:GetService("RunService")
local EnemyView = {}

type Piece = { source: BasePart, part: BasePart, offset: CFrame, size: Vector3, transparency: number, hidden: number }
type Enemy = {
	model: Model, visual: Model, pieces: { [BasePart]: Piece }, connections: { RBXScriptConnection },
	root: BasePart?, frame: CFrame?, dirty: boolean, phase: number, state: string, changedAt: number,
}
type FolderWatch = { active: boolean, connections: { RBXScriptConnection } }

local function disconnect(connections: { RBXScriptConnection })
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function removePiece(enemy: Enemy, source: BasePart)
	local piece = enemy.pieces[source]
	if not piece then return end
	source.LocalTransparencyModifier = piece.hidden
	piece.part:Destroy()
	enemy.pieces[source] = nil
end

local function addPiece(enemy: Enemy, source: BasePart, root: BasePart)
	if enemy.pieces[source] then return end
	local clone = source:Clone()
	if not clone then return end
	-- Keep authored mesh/texture geometry, but never copy scripts, GUIs or joints.
	for _, child in clone:GetChildren() do
		if not (child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance") or child:IsA("Decal")) then child:Destroy() end
	end
	clone.Anchored, clone.CanCollide, clone.CanQuery, clone.CanTouch = true, false, false, false
	clone.LocalTransparencyModifier = 0
	clone.Parent = enemy.visual
	enemy.pieces[source] = {
		source = source, part = clone, offset = root.CFrame:ToObjectSpace(source.CFrame), size = source.Size,
		transparency = source.Transparency, hidden = source.LocalTransparencyModifier,
	}
	source.LocalTransparencyModifier = 1
end

local function stateOf(model: Model): string
	local state = model:GetAttribute("State")
	if typeof(state) == "string" then return state end
	local status = model:GetAttribute("Status")
	if model:GetAttribute("Health") == 0 or status == "Defeated" or status == "Dead" then return "Dead" end
	if status == "Returning" then return "Return" end
	if status == "Windup" then return "SkillWindup" end
	return "Patrol"
end

local function animate(enemy: Enemy, dt: number, now: number, container: Folder)
	local root = enemy.model.PrimaryPart
	if not root or not root:IsDescendantOf(enemy.model) then
		enemy.visual.Parent = nil
		return
	end
	if enemy.root ~= root then
		for source in enemy.pieces do removePiece(enemy, source) end
		enemy.root, enemy.frame, enemy.dirty = root, nil, true
	end
	if enemy.dirty then
		enemy.dirty = false
		for _, item in enemy.model:GetDescendants() do
			if item:IsA("BasePart") then addPiece(enemy, item, root) end
		end
	end
	enemy.visual.Parent = container
	local previous = enemy.frame or root.CFrame
	local frame = if (previous.Position - root.Position).Magnitude > 40 then root.CFrame
		else previous:Lerp(root.CFrame, 1 - math.exp(-math.min(dt, 0.1) * 14))
	local speed = (frame.Position - previous.Position).Magnitude / math.max(dt, 0.001)
	enemy.frame = frame
	local state = stateOf(enemy.model)
	if state ~= enemy.state then enemy.state, enemy.changedAt = state, now end
	local started = enemy.model:GetAttribute("ActionStartedAt")
	local duration = enemy.model:GetAttribute("ActionDuration")
	local fallback = if state == "Dead" then 0.7 elseif state == "MeleeRecover" then 0.28 else 0.6
	local progress = math.clamp((now - (if typeof(started) == "number" then started else enemy.changedAt))
		/ (if typeof(duration) == "number" and duration > 0 then duration else fallback), 0, 1)
	local moving = state == "Patrol" or state == "Chase" or state == "Return"
	local gait = if moving then math.clamp(speed / 8, 0, 1) else 0
	enemy.phase += math.min(dt, 0.1) * (4 + math.min(speed, 16) * 0.9)
	local scale = root.Size.X / 3.1
	local boar = enemy.model:GetAttribute("EnemyKind") == "boar"
	local anticipation = progress * progress
	local rightArm, leftArm, lean, twist = 0, 0, 0, 0
	if state == "MeleeWindup" then
		rightArm, leftArm, lean, twist = anticipation * 1.2, -anticipation * 0.2, anticipation * 0.12, -anticipation * 0.3
	elseif state == "MeleeRecover" then
		rightArm, leftArm, lean, twist = -1.15 * (1 - progress), 0.2 * (1 - progress), -0.18 * (1 - progress), 0.3 * (1 - progress)
	elseif state == "SkillWindup" then
		rightArm, leftArm, lean = anticipation * 2.55, anticipation * 2.55, anticipation * 0.14
	end
	local lunge, headShift, neckPitch, foreleg = 0, 0, 0, 0
	if boar then
		-- A tusked animal braces, draws its head back, then snaps forward;
		-- it has no humanoid arm to inherit the guardian's punch animation.
		twist, lean = 0, 0
		if state == "MeleeWindup" or state == "SkillWindup" then
			lunge, headShift, neckPitch, foreleg = -0.2 * anticipation, -0.25 * anticipation, -0.12 * anticipation, 0.18 * anticipation
			lean = -0.08 * anticipation
		elseif state == "MeleeRecover" then
			local impact = 1 - progress
			lunge, headShift, neckPitch, foreleg = 0.45 * impact, 0.4 * impact, 0.2 * impact, -0.4 * impact
			lean = 0.08 * impact
		end
	end
	local dead = if state == "Dead" then progress else 0
	local shrink = math.max(0.04, 1 - dead * 0.96)
	local bob = (math.sin(enemy.phase * 2) * 0.07 * gait + math.sin(now * 2.2) * 0.025) * scale
	local body = frame * CFrame.new(0, bob - dead * 1.1 * scale, lunge * scale)
		* CFrame.Angles(lean, twist, dead * 0.65)
	for _, piece in enemy.pieces do
		local name, offset = piece.source.Name, piece.offset
		local side = if offset.X < 0 then -1 else 1
		if name == "RootLeg" or name == "RootFoot" or name == "Leg" or name == "Foot" then
			local phase = if side < 0 then 0 else math.pi
			if offset.Z < -0.4 then phase += math.pi end
			local stride = math.sin(enemy.phase + phase) * 0.35 * gait
			if boar and offset.Z > 0 then stride += foreleg end
			local hip = Vector3.new(offset.X, -1.1 * scale, offset.Z)
			offset = CFrame.new(hip) * CFrame.Angles(stride, 0, 0) * CFrame.new(-hip) * offset
		elseif name == "BranchArm" or name == "KnottedFist" then
			local swing = if side > 0 then rightArm else leftArm
			swing -= math.sin(enemy.phase + (if side > 0 then 0 else math.pi)) * 0.2 * gait
			local shoulder = Vector3.new(side * 1.7 * scale, 0.85 * scale, 0)
			offset = CFrame.new(shoulder) * CFrame.Angles(swing, 0, 0) * CFrame.new(-shoulder) * offset
		elseif boar and (name == "Head" or name == "Snout" or name == "Tusk" or name == "Eye" or name == "Ear") then
			local neck = Vector3.new(0, 0.15 * scale, 1.25 * scale)
			offset = CFrame.new(0, 0, headShift * scale) * CFrame.new(neck)
				* CFrame.Angles(neckPitch, 0, 0) * CFrame.new(-neck) * offset
		elseif name == "Head" or name == "Eye" or name == "Brow" or string.find(name, "Crown") or name == "AncientCrest" then
			local neck = Vector3.new(0, 1.3 * scale, 0)
			offset = CFrame.new(neck) * CFrame.Angles(-lean * 0.7, -twist * 0.25, 0) * CFrame.new(-neck) * offset
		end
		piece.part.Size = piece.size * shrink
		piece.part.Transparency = piece.transparency + (1 - piece.transparency) * dead
		piece.part.CFrame = body * (CFrame.new(offset.Position * shrink) * offset.Rotation)
	end
end

function EnemyView.start(): () -> ()
	local container = Instance.new("Folder")
	container.Name = "LocalGuardianVisuals"
	container:SetAttribute("CosmeticOnly", true)
	container.Parent = workspace
	local enemies: { [Model]: Enemy } = {}
	local folders: { [Instance]: FolderWatch } = {}
	local stopped = false
	local function removeEnemy(item: Instance)
		if not item:IsA("Model") then return end
		local enemy = enemies[item]
		if not enemy then return end
		disconnect(enemy.connections)
		for source in enemy.pieces do removePiece(enemy, source) end
		enemy.visual:Destroy()
		enemies[item] = nil
	end
	local function addEnemy(item: Instance)
		if stopped or not item:IsA("Model") or enemies[item] then return end
		local visual = Instance.new("Model")
		visual.Name = item.Name
		visual:SetAttribute("CosmeticOnly", true)
		visual.Parent = container
		local enemy: Enemy = { model = item, visual = visual, pieces = {}, connections = {}, root = nil,
			frame = nil, dirty = true, phase = 0, state = "", changedAt = 0 }
		enemies[item] = enemy
		table.insert(enemy.connections, item.DescendantAdded:Connect(function() enemy.dirty = true end))
		table.insert(enemy.connections, item.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("BasePart") then removePiece(enemy, descendant) end
		end))
	end
	local function detach(folder: Instance, watch: FolderWatch)
		for _, child in folder:GetChildren() do removeEnemy(child) end
		-- A folder may have been removed along with its children before this event.
		for model in enemies do if model.Parent == folder then removeEnemy(model) end end
		for index = #watch.connections, 2, -1 do watch.connections[index]:Disconnect(); table.remove(watch.connections, index) end
		watch.active = false
	end
	local function refreshFolder(folder: Instance, watch: FolderWatch)
		local active = not stopped and folder.Parent == workspace and folder.Name == "WildbondGuardians"
		if watch.active and not active then detach(folder, watch) end
		if active and not watch.active then
			watch.active = true
			table.insert(watch.connections, folder.ChildAdded:Connect(addEnemy))
			table.insert(watch.connections, folder.ChildRemoved:Connect(removeEnemy))
			for _, child in folder:GetChildren() do addEnemy(child) end
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
	local added = workspace.ChildAdded:Connect(watchFolder)
	local removed = workspace.ChildRemoved:Connect(removeFolder)
	local render = RunService.RenderStepped:Connect(function(dt: number)
		local now = workspace:GetServerTimeNow()
		for model, enemy in enemies do
			if model.Parent then animate(enemy, dt, now, container) else removeEnemy(model) end
		end
	end)
	return function()
		if stopped then return end
		stopped = true
		render:Disconnect(); added:Disconnect(); removed:Disconnect()
		for folder in folders do removeFolder(folder) end
		for model in enemies do removeEnemy(model) end
		container:Destroy()
	end
end

return EnemyView
