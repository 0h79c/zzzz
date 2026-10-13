-- Runs the actual client articulation with reflected geometry and explicit
-- streaming/event/clock doubles; Roblox rendering still needs Studio.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local checks, now = 0, 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { active = true }
			function connection:Disconnect() self.active = false end
			listeners[connection] = callback
			return connection
		end,
		Fire = function(_, ...)
			for connection, callback in listeners do if connection.active then callback(...) end end
		end,
		Count = function()
			local count = 0
			for connection in listeners do if connection.active then count += 1 end end
			return count
		end,
	}
end
local events, transparencies = {}, {}
local function event(item, name)
	events[item] = events[item] or {}
	events[item][name] = events[item][name] or signal()
	return events[item][name]
end
for _, name in { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving" } do
	roblox.implementProperty("Instance", name, function(item) return event(item, name) end)
end
roblox.implementProperty("BasePart", "LocalTransparencyModifier", function(item)
	return transparencies[item] or 0
end, function(item, value) transparencies[item] = value end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(item, name) return event(item, name) end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return now end)
local scene, render = roblox.Instance.new("Workspace"), signal()
local environment = {
	game = { GetService = function(_, name) assert(name == "RunService"); return { RenderStepped = render } end },
	workspace = scene,
}
for _, name in { "Instance", "CFrame", "Vector3" } do environment[name] = roblox[name] end
local EnemyView = luau.load(fs.readFile("src/client/EnemyView.luau"), { environment = environment, debugName = "EnemyView" })()
local cleanup = EnemyView.start()
local container = assert(scene:FindFirstChild("LocalGuardianVisuals"))
local function step(frames, dt)
	for _ = 1, frames do now += dt; render:Fire(dt) end
end
step(1, 1 / 60)
check(#container:GetChildren() == 0, "View can start before the server guardian folder exists")

local folder = roblox.Instance.new("Folder")
folder.Name, folder.Parent = "WildbondGuardians", scene
scene.ChildAdded:Fire(folder)
local model = roblox.Instance.new("Model")
model.Name, model.Parent = "TestGuardian", folder
model:SetAttribute("State", "Patrol")
model:SetAttribute("Health", 100)
folder.ChildAdded:Fire(model)
local visual = assert(container:FindFirstChild(model.Name))
step(1, 1 / 60)
check(visual.Parent == nil, "Missing streamed PrimaryPart hides a pending visual without blocking the render loop")

local origin = roblox.CFrame.new(0, 7, 0)
local sources, offsets = {}, {}
local function piece(name, offset, className)
	local part = roblox.Instance.new(className or "Part")
	part.Name, part.Size = name, roblox.Vector3.new(1, 2, 1)
	part.Color, part.Material = roblox.Color3.fromRGB(112, 85, 64), roblox.Enum.Material.Wood
	part.CFrame, part.Position, part.Parent = origin * offset, (origin * offset).Position, model
	part.LocalTransparencyModifier = 0.2
	offsets[part] = offset
	table.insert(sources, part)
	model.DescendantAdded:Fire(part)
	return part
end
local root = piece("BarkCore", roblox.CFrame.identity)
root.Size, root.CanCollide = roblox.Vector3.new(3.1, 3.35, 2.5), true
model.PrimaryPart = root
local leg = piece("RootLeg", roblox.CFrame.new(-0.9, -2, 0))
piece("RootFoot", roblox.CFrame.new(-1, -2.7, 0.3))
local arm = piece("BranchArm", roblox.CFrame.new(2, -0.4, 0))
piece("KnottedFist", roblox.CFrame.new(2.4, -1.62, 0.15))
piece("BranchArm", roblox.CFrame.new(-2, -0.4, 0))
piece("KnottedFist", roblox.CFrame.new(-2.4, -1.62, 0.15))
piece("Head", roblox.CFrame.new(0, 2.15, 0), "WedgePart")
local crown = piece("LeafCrown", roblox.CFrame.new(1.3, 4.07, -0.4))
local mesh = roblox.Instance.new("SpecialMesh")
mesh.MeshType, mesh.Scale, mesh.Parent = roblox.Enum.MeshType.Sphere, roblox.Vector3.new(1, 0.7, 1), crown
local billboard = roblox.Instance.new("BillboardGui")
billboard.Name, billboard.Adornee, billboard.Parent = "GuardianHealth", root, model
local nestedBillboard = roblox.Instance.new("BillboardGui")
nestedBillboard.Parent = root
local highlight = roblox.Instance.new("Highlight")
highlight.Parent = model
step(1, 1 / 60)
local body, animatedLeg = assert(visual:FindFirstChild("BarkCore")), assert(visual:FindFirstChild("RootLeg"))
check(visual.Parent == container and visual:GetAttribute("CosmeticOnly") == true, "Root arrival builds a local cosmetic model")
check(#visual:GetChildren() == #sources, "Clones exactly the authored BaseParts")
check(visual.Head:IsA("WedgePart") and visual.LeafCrown:FindFirstChildOfClass("SpecialMesh") ~= nil, "Authored wedge and custom mesh geometry survive cloning")
check(visual.Head.Color == model.Head.Color and visual.Head.Material == model.Head.Material, "Authored surface colors and materials survive cloning")
check(billboard.Parent == model and billboard.Adornee == root and highlight.Parent == model, "The authoritative health billboard and highlight remain intact")
for _, part in visual:GetChildren() do
	check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch, "Animation geometry cannot participate in combat queries or physics")
	check(part.LocalTransparencyModifier == 0, "Clone is visible despite the hidden source")
	check(part:FindFirstChildOfClass("BillboardGui") == nil, "Nested health GUIs are never duplicated")
end
for _, source in sources do check(source.LocalTransparencyModifier == 1, "Original geometry is hidden only for this client") end
check(root.CanCollide, "Original server collider remains enabled")

local function moveTo(frame)
	for _, source in sources do source.CFrame = frame * offsets[source]; source.Position = source.CFrame.Position end
end
local before = body.CFrame.Position
moveTo(roblox.CFrame.new(6, 7, 0))
local authoritativeRoot, authoritativeArm = root.CFrame, arm.CFrame
step(1, 1 / 60)
check(body.CFrame.Position.X > before.X and body.CFrame.Position.X < 6, "Replicated movement is smoothly interpolated")
check(root.CFrame == authoritativeRoot and arm.CFrame == authoritativeArm, "Visual animation never writes authoritative source poses")
local relativeLeg = body.CFrame:ToObjectSpace(animatedLeg.CFrame)
check(relativeLeg ~= offsets[leg], "Walking articulates the leg around its hip instead of sliding the whole static model")
step(90, 1 / 60)
check(math.abs(body.CFrame.Position.X - 6) < 0.01, "Walk smoothing converges to the server location")

local function action(state, duration)
	model:SetAttribute("State", state)
	model:SetAttribute("ActionStartedAt", now)
	model:SetAttribute("ActionDuration", duration)
end
local function rightArm()
	for _, part in visual:GetChildren() do
		if part.Name == "BranchArm" and body.CFrame:ToObjectSpace(part.CFrame).X > 0 then return part end
	end
	error("Missing positive-X arm")
end
action("MeleeWindup", 0.45)
step(20, 1 / 60)
local windupArm = body.CFrame:ToObjectSpace(rightArm().CFrame)
check(windupArm.Z < -0.5, "Melee telegraph visibly draws the striking arm back")
action("MeleeRecover", 0.28)
step(1, 1 / 60)
local recoverArm = body.CFrame:ToObjectSpace(rightArm().CFrame)
check(recoverArm.Z > 1, "Regular strike swings the fist forward during the impact/recovery phase")
action("SkillWindup", 1)
step(60, 1 / 60)
check(body.CFrame:ToObjectSpace(rightArm().CFrame).Y > 1, "Boss skill raises its arms overhead rather than displaying only an AoE disk")

action("Dead", 0.7)
for _, source in sources do source.Transparency = 1 end
step(14, 1 / 60)
check(body.Transparency > 0.2 and body.Transparency < 0.6 and body.Size.X < root.Size.X, "Defeat animates a gentle shrink/fade even after the server hides the hitbox")
step(30, 1 / 60)
check(body.Transparency == 1, "Finished defeat animation fully hides the local visual")
for _, source in sources do source.Transparency = 0 end
action("Patrol", 0)
step(1, 1 / 60)
check(body.Transparency == 0 and body.Size == root.Size, "Respawn restores authored size and visibility")
model:SetAttribute("State", nil)
model:SetAttribute("Status", "Windup")
model:SetAttribute("ActionStartedAt", now)
step(60, 1 / 60)
check(body.CFrame:ToObjectSpace(rightArm().CFrame).Y > 1, "Legacy Status windup works while new attributes await replication")

local extra = piece("ExtraTwig", roblox.CFrame.new(0, 3, -1))
step(1, 1 / 60)
check(visual:FindFirstChild("ExtraTwig") ~= nil and extra.LocalTransparencyModifier == 1, "Parts arriving through streaming are added after the first snapshot")
model.DescendantRemoving:Fire(extra)
extra.Parent = nil
check(visual:FindFirstChild("ExtraTwig") == nil and math.abs(extra.LocalTransparencyModifier - 0.2) < 0.001, "Streamed-out parts discard their clone and recover their prior transparency")
model.DescendantRemoving:Fire(root)
root.Parent = nil
step(1, 1 / 60)
check(visual.Parent == nil, "Losing a streamed root hides its detached local geometry")
root.Parent = model
model.DescendantAdded:Fire(root)
step(1, 1 / 60)
check(visual.Parent == container, "Returning streamed root resumes the visual")

folder.Name = "RetiredGuardians"
event(folder, "Name"):Fire()
check(visual.Parent == nil and math.abs(root.LocalTransparencyModifier - 0.2) < 0.001, "Folder rename destroys only local geometry and restores the original visibility")
check(model.Parent == folder and billboard.Parent == model, "Folder detachment preserves server models and labels")
folder.Name = "WildbondGuardians"
event(folder, "Name"):Fire()
step(1, 1 / 60)
check(container:FindFirstChild(model.Name) ~= nil, "A matching folder can be reattached after rename")
local secondFolder = roblox.Instance.new("Folder")
secondFolder.Name, secondFolder.Parent = "WildbondGuardians", scene
local secondModel = roblox.Instance.new("Model")
secondModel.Name, secondModel.Parent = "SecondGuardian", secondFolder
local secondRoot = roblox.Instance.new("Part")
secondRoot.Name, secondRoot.CFrame, secondRoot.Position, secondRoot.Parent = "BarkCore", roblox.CFrame.new(10, 7, 0), roblox.Vector3.new(10, 7, 0), secondModel
secondRoot.LocalTransparencyModifier = 0
secondModel.PrimaryPart = secondRoot
scene.ChildAdded:Fire(secondFolder)
step(1, 1 / 60)
check(#container:GetChildren() == 2 and secondRoot.LocalTransparencyModifier == 1, "Distinct folders with the same server name are tracked independently")
secondFolder.Parent = nil
scene.ChildRemoved:Fire(secondFolder)
check(#container:GetChildren() == 1 and secondRoot.LocalTransparencyModifier == 0, "Removing one matching folder cleans only its own visuals")
secondFolder.Parent = scene
scene.ChildAdded:Fire(secondFolder)
step(1, 1 / 60)
check(#container:GetChildren() == 2, "A streamed folder can be added again safely")
cleanup()
cleanup()
check(scene:FindFirstChild("LocalGuardianVisuals") == nil and model.Parent == folder and secondModel.Parent == secondFolder, "Idempotent cleanup destroys local instances and preserves authoritative models")
check(math.abs(root.LocalTransparencyModifier - 0.2) < 0.001 and secondRoot.LocalTransparencyModifier == 0, "Cleanup restores each source's original transparency modifier")
check(render.Count() == 0, "Cleanup disconnects rendering")
for _, itemEvents in events do
	for _, connection in itemEvents do check(connection.Count() == 0, "Cleanup disconnects every workspace, folder and streaming subscription") end
end
scene.ChildAdded:Fire(folder)
render:Fire(1 / 60)
check(scene:FindFirstChild("LocalGuardianVisuals") == nil, "Late events cannot revive a stopped view")
print("EnemyView: " .. checks .. " articulation, streamed geometry, clock and cleanup checks passed; native rendering requires Studio")
