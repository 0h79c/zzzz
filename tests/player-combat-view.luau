-- Actual procedural animation on reflected legacy and upgraded avatar joints.
-- PreAnimation/Animator/PreSimulation order is explicit; native rendering
-- and physical animation evaluation still need Roblox Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local R = require("@lune/roblox")
local checks, now = 0, 0
local function check(value, message) assert(value, message); checks += 1 end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local item = { callback = callback, connected = true }; table.insert(listeners, item)
			return { Disconnect = function() item.connected = false end }
		end,
		Fire = function(_, ...) for _, item in listeners do if item.connected then item.callback(...) end end end,
		Active = function() local count = 0; for _, item in listeners do if item.connected then count += 1 end end; return count end,
	}
end
local function close(a, b)
	return (a.Position - b.Position).Magnitude < 0.001 and (a.LookVector - b.LookVector).Magnitude < 0.001 and (a.UpVector - b.UpVector).Magnitude < 0.001
end
local function jointFrames(m)
	if m:IsA("AnimationConstraint") then return m.Attachment0.Parent, m.Attachment1.Parent, m.Attachment0.CFrame, m.Attachment1.CFrame end
	return m.Part0, m.Part1, m.C0, m.C1
end
local function rig(r15, upgraded)
	local model = R.Instance.new("Model")
	local humanoid = R.Instance.new("Humanoid"); humanoid.Health, humanoid.Parent = 100, model
	local function part(name, size, cf)
		local p = R.Instance.new("Part"); p.Name, p.Size, p.CFrame, p.Position, p.Parent = name, size, cf, cf.Position, model
		return p
	end
	local function joint(name, parentPart, childPart, c0, c1)
		local m = R.Instance.new(if upgraded then "AnimationConstraint" else "Motor6D")
		m.Name, m.Transform, m.Parent = if upgraded then "Constraint_" .. name else name, R.CFrame.identity, parentPart
		if upgraded then
			local a, b = R.Instance.new("Attachment"), R.Instance.new("Attachment")
			a.CFrame, a.Parent, b.CFrame, b.Parent = c0, parentPart, c1, childPart
			m.Attachment0, m.Attachment1 = a, b
		else m.Part0, m.Part1, m.C0, m.C1 = parentPart, childPart, c0, c1 end
		childPart.CFrame = parentPart.CFrame * c0 * c1:Inverse()
		return m
	end
	local root = part("HumanoidRootPart", R.Vector3.new(2, 2, 1), R.CFrame.new(5, 7, 2))
	local lower = part(if r15 then "LowerTorso" else "Torso", R.Vector3.new(2, 2, 1), root.CFrame)
	local rootBase = if r15 then R.CFrame.identity else R.CFrame.Angles(-math.pi / 2, 0, math.pi)
	local rootJoint = joint(if r15 then "Root" else "RootJoint", root, lower, rootBase, rootBase)
	local torso, waist = lower, nil
	if r15 then
		torso = part("UpperTorso", R.Vector3.new(2, 1.6, 1), lower.CFrame)
		waist = joint("Waist", lower, torso, R.CFrame.new(0, 0.5, 0), R.CFrame.new(0, -0.5, 0))
	end
	local arms, legs, saved = {}, {}, {}
	for _, side in { "right", "left" } do
		local sign, prefix = if side == "right" then 1 else -1, if side == "right" then "Right" else "Left"
		local arm = {}; arms[side] = arm
		local upper = part(if r15 then prefix .. "UpperArm" else prefix .. " Arm", R.Vector3.new(1, if r15 then 1.2 else 2, 1), torso.CFrame)
		local c0 = R.CFrame.new(sign, 0.5, 0) * (if r15 then R.CFrame.identity else R.CFrame.Angles(0, sign * math.pi / 2, 0))
		local c1 = (if r15 then R.CFrame.new(-sign * 0.3, 0.6, 0) else R.CFrame.new(-sign * 0.5, 0.5, 0) * R.CFrame.Angles(0, sign * math.pi / 2, 0))
		arm.shoulder = joint(if r15 then prefix .. "Shoulder" else prefix .. " Shoulder", torso, upper, c0, c1)
		if r15 then
			local forearm = part(prefix .. "LowerArm", R.Vector3.new(0.8, 1, 0.8), upper.CFrame)
			arm.elbow = joint(prefix .. "Elbow", upper, forearm, R.CFrame.new(0, -0.6, 0), R.CFrame.new(0, 0.5, 0))
			local hand = part(prefix .. "Hand", R.Vector3.new(0.8, 0.5, 0.8), forearm.CFrame)
			arm.wrist = joint(prefix .. "Wrist", forearm, hand, R.CFrame.new(0, -0.5, 0), R.CFrame.new(0, 0.25, 0))
		end
	end
	for _, side in { "right", "left" } do
		local sign, prefix = if side == "right" then 1 else -1, if side == "right" then "Right" else "Left"
		local leg = {}; legs[side] = leg
		local upper = part(if r15 then prefix .. "UpperLeg" else prefix .. " Leg", R.Vector3.new(1, if r15 then 1 else 2, 1), lower.CFrame)
		leg.hip = joint(if r15 then prefix .. "Hip" else prefix .. " Hip", lower, upper, R.CFrame.new(sign * 0.5, -1, 0), R.CFrame.new(0, 0.5, 0))
		if r15 then
			local calf = part(prefix .. "LowerLeg", R.Vector3.new(0.8, 1, 0.8), upper.CFrame)
			leg.knee = joint(prefix .. "Knee", upper, calf, R.CFrame.new(0, -0.5, 0), R.CFrame.new(0, 0.5, 0))
			local foot = part(prefix .. "Foot", R.Vector3.new(0.8, 0.5, 1), calf.CFrame)
			leg.ankle = joint(prefix .. "Ankle", calf, foot, R.CFrame.new(0, -0.5, 0), R.CFrame.new(0, 0.25, 0))
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
			local _, _, c0, c1 = jointFrames(item)
			saved[item] = { transform = item.Transform, c0 = c0, c1 = c1 }
		end
	end
	return { model = model, humanoid = humanoid, root = root, torso = torso, rootJoint = rootJoint, waist = waist, arms = arms, legs = legs, saved = saved }
end
local function fist(arm)
	local shoulder = arm.shoulder
	local parent, part, c0, c1 = jointFrames(shoulder)
	local frame = parent.CFrame * c0 * shoulder.Transform * c1:Inverse()
	for _, m in { arm.elbow, arm.wrist } do
		if m then
			local _, child, nextC0, nextC1 = jointFrames(m)
			frame = frame * nextC0 * m.Transform * nextC1:Inverse(); part = child
		end
	end
	return frame:PointToWorldSpace(R.Vector3.new(0, -part.Size.Y * 0.45, 0))
end
local function restored(rigState)
	for m, original in rigState.saved do
		local _, _, c0, c1 = jointFrames(m)
		if not close(m.Transform, original.transform) or c0 ~= original.c0 or c1 ~= original.c1 then return false end
	end
	return true
end
local scene = R.Instance.new("Workspace")
local frames, beforeAnimation, added, removed = signal(), signal(), signal(), signal()
local current = rig(false); current.model.Parent = scene
local player = { Character = current.model, CharacterAdded = added, CharacterRemoving = removed }
local environment = {
	game = { GetService = function(_, name) assert(name == "RunService"); return { PreSimulation = frames, PreAnimation = beforeAnimation } end },
	workspace = scene, os = { clock = function() return now end },
}
for _, name in { "Instance", "Vector3", "CFrame", "Color3", "Enum", "UDim2" } do environment[name] = R[name] end
local View = luau.load(fs.readFile("src/client/PlayerCombatView.luau"), { environment = environment, debugName = "PlayerCombatView" })()
local cleanup, attackFx, dodgeFx = View.start(player, { duration = 0.3 })
local effects = assert(scene:FindFirstChild("LocalPlayerCombatEffects"))
local popup = assert(effects:FindFirstChild("ImpactOrigin"):FindFirstChild("HitDamage"))
local damage = assert(popup:FindFirstChildOfClass("TextLabel"))
check(effects:GetAttribute("CosmeticOnly") == true and #effects:GetChildren() == 11, "Combat owns bounded fist trail, dash wake, impact sparks and popup anchor")
for _, part in effects:GetChildren() do check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery, "Cosmetic part does not affect physics or target queries") end
frames:Fire()
check(restored(current) and not popup.Enabled, "No pose or damage appears without an accepted effect")
local rootBefore, neutral = current.root.CFrame, fist(current.arms.right)
attackFx(R.Vector3.new(5, 7, -3), false, nil)
now = 0.1; frames:Fire()
local draw = fist(current.arms.right)
now = 0.16; frames:Fire()
now = 0.2; frames:Fire()
local extended = fist(current.arms.right)
check((extended - draw):Dot(current.torso.CFrame.LookVector) > 1.7, "R6 attachment forward kinematics prove the fist advances over 1.7 studs from draw-back")
check((extended - neutral):Dot(current.torso.CFrame.LookVector) > 1.25, "R6 fist visibly extends forward rather than rotating only the shoulder matrix")
check(current.root.CFrame == rootBefore and current.arms.right.shoulder.C0 == current.saved[current.arms.right.shoulder].c0 and current.arms.right.shoulder.Transform ~= R.CFrame.identity, "Punch changes native Transform while physical root and rig rest attachment remain untouched")
check(effects:FindFirstChild("FistTrail1").Transparency < 1 and not popup.Enabled, "A miss shows hand-following trail without fabricated damage")
local pose = current.arms.right.shoulder.Transform
frames:Fire()
check(close(current.arms.right.shoulder.Transform, pose), "Repeated frames cannot accumulate Transform offsets")
now = 0.43; frames:Fire()
check(restored(current), "R6 punch recovers all original joint Transform values exactly")

-- Left punch follows the next accepted click rather than a fixed slash animation.
now = 0.6; local leftBefore = fist(current.arms.left)
attackFx(R.Vector3.new(5, 7, -3), true, 10)
now = 0.8; frames:Fire()
check((fist(current.arms.left) - leftBefore):Dot(current.torso.CFrame.LookVector) > 1.25 and current.arms.right.shoulder.Transform == current.saved[current.arms.right.shoulder].transform, "Second click jabs with the left arm while the right recovers")
check(popup.Enabled and damage.Text == "-10" and effects:FindFirstChild("HitSpark1").Transparency < 1, "Server-confirmed hit shows its actual damage and a brief impact burst")
now = 1.03; frames:Fire()
check(restored(current), "Alternating punch also restores the original avatar")
now = 1.41; frames:Fire()
check(not popup.Enabled and effects:FindFirstChild("HitSpark1").Transparency == 1, "Floating damage and impact sparks expire without retained effects")

now = 1.5; attackFx(R.Vector3.new(5, 7, -3), false)
now = 1.6; frames:Fire()
removed:Fire(current.model)
check(restored(current) and not popup.Enabled, "Respawn cancels the old avatar pose and hit feedback")
current = rig(true); current.model.Parent = scene; player.Character = current.model; added:Fire(current.model)
now = 2
local r15Neutral = fist(current.arms.right)
attackFx(R.Vector3.new(5, 8, -3), true, 10)
now = 2.1; frames:Fire(); local r15Draw = fist(current.arms.right)
-- Simulate Animator replacing Transform after draw-back: the C0 pose must survive.
current.arms.right.shoulder.Transform = R.CFrame.identity
current.arms.right.elbow.Transform = R.CFrame.identity
now = 2.16; frames:Fire()
now = 2.2; frames:Fire()
local r15Extended = fist(current.arms.right)
check((r15Extended - r15Draw):Dot(current.torso.CFrame.LookVector) > 0.8, "R15 FK proves shoulder, elbow and wrist deliver a forward punch after Animator overwrites Transform")
check((r15Extended - r15Neutral):Dot(current.torso.CFrame.LookVector) > 1.8, "R15 fist reaches well in front of the resting arm")
check(current.arms.right.elbow.Transform ~= current.saved[current.arms.right.elbow].transform or current.arms.right.wrist.Transform ~= current.saved[current.arms.right.wrist].transform, "R15 presentation includes wrist and elbow joints")
now = 2.43; frames:Fire()
check(restored(current), "R15 attack restores shoulder, elbow, wrist and waist Transforms exactly")

local streamedShoulder, leftNeutral = current.arms.left.shoulder, fist(current.arms.left)
streamedShoulder.Parent = nil
now = 2.45; attackFx(R.Vector3.new(5, 8, -3), false); frames:Fire()
streamedShoulder.Parent = current.torso
now = 2.65; frames:Fire()
check(streamedShoulder.Transform ~= current.saved[streamedShoulder].transform and (fist(current.arms.left) - leftNeutral):Dot(current.torso.CFrame.LookVector) > 1.8, "A shoulder that streams in during the punch is rediscovered before the periodic scan")
now = 2.89; frames:Fire()
check(restored(current), "Late-stream arm completes and restores its original Transform")

local beforeDash = current.root.CFrame
now = 3; dodgeFx(R.Vector3.new(1, 0, 0))
now = 3.24; frames:Fire()
check(current.rootJoint.Transform ~= current.saved[current.rootJoint].transform, "Dodge lean uses provided 0.3-second duration rather than the old 0.22-second duration")
check(current.root.CFrame == beforeDash, "Client dodge animation never moves the physical root")
check(effects:FindFirstChild("DodgeWake1").Transparency < 1, "Accepted dash includes a short cosmetic motion wake")
now = 3.31; frames:Fire()
check(restored(current) and effects:FindFirstChild("DodgeWake1").Transparency == 1, "Dodge restores joints and removes its motion wake")
now = 3.4; dodgeFx(R.Vector3.new(0 / 0, 0, 0)); frames:Fire()
check(restored(current), "Invalid cosmetic direction cannot change the rig")
-- New experiences now use AnimationConstraint; Motor6D-only scans find none.
removed:Fire(current.model)
current = rig(true, true); current.model.Parent = scene; player.Character = current.model; added:Fire(current.model)
check(current.model:GetAttribute("WildbondCombatRig") == "AnimationConstraint" and current.model:GetAttribute("WildbondCombatJointCount") == 14, "Upgraded R15 constraints are discovered by connected limb names rather than assuming Motor6D or joint names")
now = 3.5; local upgradedNeutral = fist(current.arms.right)
attackFx(R.Vector3.new(5, 8, -3), true, 10)
now = 3.6; beforeAnimation:Fire(); frames:Fire()
local nativeDraw = fist(current.arms.right)
beforeAnimation:Fire()
check(restored(current), "Before Animator evaluates, our prior layer is removed from constraints without changing rest attachments")
local animatorPose = R.CFrame.Angles(0, 0.08, 0)
current.arms.right.shoulder.Transform = animatorPose
current.saved[current.arms.right.shoulder].transform = animatorPose
now = 3.7; frames:Fire()
check((fist(current.arms.right) - nativeDraw):Dot(current.torso.CFrame.LookVector) > 0.7 and (fist(current.arms.right) - upgradedNeutral):Dot(current.torso.CFrame.LookVector) > 1.7, "Upgraded native joint transforms move the R15 fist forward after Animator writes its walking pose")
check(current.arms.right.shoulder.Attachment0.CFrame == current.saved[current.arms.right.shoulder].c0 and current.arms.right.shoulder.Attachment1.CFrame == current.saved[current.arms.right.shoulder].c1, "Procedural animation leaves retargeting attachments untouched")
now = 3.93; beforeAnimation:Fire(); frames:Fire()
check(restored(current), "Upgraded avatar returns to Animator's prior pose when the punch finishes")
now = 4.0; dodgeFx(R.Vector3.new(0, 0, -1))
now = 4.15; beforeAnimation:Fire(); frames:Fire()
check(current.legs.right.hip.Transform ~= R.CFrame.identity and current.legs.left.knee.Transform ~= R.CFrame.identity and current.arms.left.elbow.Transform ~= R.CFrame.identity, "Dash has a full crouched stride and bent arms rather than a root-only lean")
check(current.root.CFrame == beforeDash, "Upgraded dash pose also leaves server movement authoritative")
now = 4.31; beforeAnimation:Fire(); frames:Fire()
check(restored(current), "Full-body dash releases all constraint transforms")
local lateHip = current.legs.left.hip
lateHip.Parent = nil
now = 4.4; dodgeFx(R.Vector3.new(1, 0, 0)); beforeAnimation:Fire(); frames:Fire()
lateHip.Parent = current.rootJoint.Attachment1.Parent
now = 4.5; beforeAnimation:Fire(); frames:Fire()
check(lateHip.Transform ~= R.CFrame.identity, "A late dash hip is rediscovered immediately within the 0.3s dash instead of waiting for the 0.5s periodic scan")
now = 4.71; beforeAnimation:Fire(); frames:Fire()
check(restored(current), "Late-stream dash joint is also restored after recovery")
current.humanoid.Health = 0
attackFx(R.Vector3.new(5, 8, -3), true, 10); frames:Fire()
check(restored(current) and not popup.Enabled, "Dead avatar cannot start a new attack or damage popup")
current.humanoid.Health = 100
now = 5; attackFx(R.Vector3.new(5, 8, -3), true, 10)
now = 5.1; frames:Fire()
local customized = R.CFrame.Angles(0, 0.12, 0)
current.arms.right.shoulder.Transform = customized
current.saved[current.arms.right.shoulder].transform = customized
now = 5.12; frames:Fire(); cleanup(); cleanup()
check(restored(current), "Cleanup restores the unfinished native Transform pose exactly")
check(close(current.arms.right.shoulder.Transform, customized), "An external Animator update becomes the restored base rather than being overwritten")
check(frames.Active() == 0 and beforeAnimation.Active() == 0 and added.Active() == 0 and removed.Active() == 0 and scene:FindFirstChild("LocalPlayerCombatEffects") == nil, "Cleanup disconnects lifecycle signals and deletes owned effects")
attackFx(R.Vector3.new(5, 7, -3), true, 10); dodgeFx(R.Vector3.new(0, 0, -1)); frames:Fire()
check(restored(current), "Late effects cannot revive a destroyed view")
print("Player combat view: " .. checks .. " actual-module legacy/upgraded R6/R15 FK, Animator ordering, hit, full-body dodge and cleanup checks passed; native rendering requires Studio")
