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

-- Four-legged geometry matches the server's brush boar rather than a golem
-- with an attribute changed. Duplicate limb names are resolved by rest offset.
local boar = roblox.Instance.new("Model")
boar.Name, boar.Parent = "Brush Boar", folder
boar:SetAttribute("EnemyKind", "boar")
boar:SetAttribute("State", "Patrol")
boar:SetAttribute("Health", 75)
local boarOrigin = roblox.CFrame.new(40, 7, 10)
local boarParts, boarRest = {}, {}
local function boarPiece(name, size, offset)
	local part = roblox.Instance.new("Part")
	part.Name, part.Size, part.CFrame, part.Position = name, size, boarOrigin * offset, (boarOrigin * offset).Position
	part.Parent, part.LocalTransparencyModifier = boar, 0.35
	table.insert(boarParts, part)
	return part
end
local boarRoot = boarPiece("BarkCore", roblox.Vector3.new(3.1, 2.3, 4.4), roblox.CFrame.Angles(0, 0, math.rad(-3)))
boar.PrimaryPart = boarRoot
local boarHead = boarPiece("Head", roblox.Vector3.new(2.5, 1.9, 2.2), roblox.CFrame.new(0, -0.2, 2.1))
local boarSnout = boarPiece("Snout", roblox.Vector3.new(1.6, 1, 0.9), roblox.CFrame.new(0, -0.55, 3.52))
for _, side in { -1, 1 } do
	for _, z in { -1.3, 1.1 } do
		boarPiece("RootLeg", roblox.Vector3.new(0.75, 1.75, 0.85), roblox.CFrame.new(side * 1.12, -1.95, z))
		boarPiece("RootFoot", roblox.Vector3.new(0.9, 0.45, 1.1), roblox.CFrame.new(side * 1.12, -2.72, z + 0.12))
	end
	boarPiece("Tusk", roblox.Vector3.new(0.28, 1.15, 0.3), roblox.CFrame.new(side * 0.9, -0.2, 3.4))
	boarPiece("Ear", roblox.Vector3.new(0.65, 1, 0.5), roblox.CFrame.new(side * 0.95, 1.05, 2.15))
	boarPiece("Eye", roblox.Vector3.new(0.22, 0.25, 0.22), roblox.CFrame.new(side * 1.23, 0.2, 2.75))
end
for _, part in boarParts do boarRest[part] = boarRoot.CFrame:ToObjectSpace(part.CFrame) end
folder.ChildAdded:Fire(boar)
step(1, 1 / 60)
local boarVisual = assert(container:FindFirstChild("Brush Boar"))
local boarBody = assert(boarVisual:FindFirstChild("BarkCore"))
check(boarVisual:FindFirstChild("BranchArm") == nil and #boarVisual:GetChildren() == #boarParts, "Boar contains real quadruped geometry without guardian arms")
local nextFrame = roblox.CFrame.new(46, 7, 10) * roblox.CFrame.Angles(0, 0, math.rad(-3))
for _, part in boarParts do part.CFrame = nextFrame * boarRest[part]; part.Position = part.CFrame.Position end
step(1, 1 / 60)
local function legAngles()
	local angles = {}
	for _, part in boarVisual:GetChildren() do
		if part.Name == "RootLeg" then
			local relative = boarBody.CFrame:ToObjectSpace(part.CFrame)
			local key = (if relative.X < 0 then "L" else "R") .. (if relative.Z < 0 then "Back" else "Front")
			for _, source in boarParts do
				local rest = boarRest[source]
				if source.Name == "RootLeg" and (rest.X < 0) == (relative.X < 0) and (rest.Z < 0) == (relative.Z < 0) then
					angles[key] = (relative.Rotation * rest.Rotation:Inverse()):ToEulerAnglesXYZ()
				end
			end
		end
	end
	return angles
end
local gaitAngles = legAngles()
check(math.abs(gaitAngles.LFront) > 0.01 and math.abs(gaitAngles.RFront) > 0.01, "All four boar legs articulate during movement")
check(math.abs(gaitAngles.LFront - gaitAngles.RBack) < 0.001 and math.abs(gaitAngles.RFront - gaitAngles.LBack) < 0.001,
	"Diagonal quadruped legs share their stride phase")
check(math.abs(gaitAngles.LFront + gaitAngles.RFront) < 0.001, "Opposing diagonal pairs alternate their steps")
step(90, 1 / 60)
local sourceFrames = {}
for _, part in boarParts do sourceFrames[part] = part.CFrame end
local function boarAction(state, duration)
	boar:SetAttribute("State", state)
	boar:SetAttribute("ActionStartedAt", now)
	boar:SetAttribute("ActionDuration", duration)
end
boarAction("MeleeWindup", 0.65)
step(36, 1 / 60)
local pulledHead = boarBody.CFrame:ToObjectSpace(boarVisual.Head.CFrame)
local pulledSnout = boarBody.CFrame:ToObjectSpace(boarVisual.Snout.CFrame)
local bracedLegs = legAngles()
check(pulledHead.Z < boarRest[boarHead].Z - 0.15 and pulledSnout.Z < boarRest[boarSnout].Z - 0.1,
	"Boar visibly draws its head and snout back during the bite telegraph")
boarAction("MeleeRecover", 0.28)
step(1, 1 / 60)
local bitingHead = boarBody.CFrame:ToObjectSpace(boarVisual.Head.CFrame)
local bitingSnout = boarBody.CFrame:ToObjectSpace(boarVisual.Snout.CFrame)
check(bitingHead.Z > boarRest[boarHead].Z + 0.25 and bitingSnout.Z > boarRest[boarSnout].Z + 0.12,
	"Bite impact moves the head and snout forward rather than attempting an absent arm swing")
check(boarRoot.CFrame:ToObjectSpace(boarBody.CFrame).Z > 0.3, "Boar body visibly lunges toward the target for the impact")
local strikingLegs = legAngles()
check(strikingLegs.LFront < bracedLegs.LFront - 0.4 and math.abs(strikingLegs.LBack) < 0.001,
	"Bite braces then strikes with front legs while rear legs hold their ground")
local restHeadToSnout = (boarRest[boarHead].Position - boarRest[boarSnout].Position).Magnitude
check(math.abs((boarVisual.Head.CFrame.Position - boarVisual.Snout.CFrame.Position).Magnitude - restHeadToSnout) < 0.001,
	"Head, snout and facial pieces move as one connected neck group")
for _, part in boarParts do check(part.CFrame == sourceFrames[part], "Quadruped animation never moves the authoritative hitbox or source limbs") end
step(30, 1 / 60)
check(math.abs(boarBody.CFrame:ToObjectSpace(boarVisual.Head.CFrame).Z - boarRest[boarHead].Z) < 0.001,
	"Bite recovery restores the authored head pose")
cleanup()
cleanup()
check(scene:FindFirstChild("LocalGuardianVisuals") == nil and model.Parent == folder and secondModel.Parent == secondFolder, "Idempotent cleanup destroys local instances and preserves authoritative models")
check(math.abs(root.LocalTransparencyModifier - 0.2) < 0.001 and secondRoot.LocalTransparencyModifier == 0, "Cleanup restores each source's original transparency modifier")
check(boar.Parent == folder and math.abs(boarRoot.LocalTransparencyModifier - 0.35) < 0.001, "Quadruped cleanup restores original visibility and preserves its server model")
check(render.Count() == 0, "Cleanup disconnects rendering")
for _, itemEvents in events do
	for _, connection in itemEvents do check(connection.Count() == 0, "Cleanup disconnects every workspace, folder and streaming subscription") end
end
scene.ChildAdded:Fire(folder)
render:Fire(1 / 60)
check(scene:FindFirstChild("LocalGuardianVisuals") == nil, "Late events cannot revive a stopped view")
print("EnemyView: " .. checks .. " articulation, streamed geometry, clock and cleanup checks passed; native rendering requires Studio")
