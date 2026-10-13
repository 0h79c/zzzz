-- Runs actual C0 presentation with realistic R6/R15 joint orientation and
-- forward kinematics. Native rendering and feel still need Roblox Studio.
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
local function rig(r15)
	local model = R.Instance.new("Model")
	local humanoid = R.Instance.new("Humanoid"); humanoid.Health, humanoid.Parent = 100, model
	local function part(name, size, cf)
		local p = R.Instance.new("Part"); p.Name, p.Size, p.CFrame, p.Position, p.Parent = name, size, cf, cf.Position, model
		return p
	end
	local function joint(name, parentPart, childPart, c0, c1)
		local m = R.Instance.new("Motor6D")
		m.Name, m.Part0, m.Part1, m.C0, m.C1, m.Transform, m.Parent = name, parentPart, childPart, c0, c1, R.CFrame.identity, parentPart
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
	local arms, saved = {}, {}
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
	for _, item in model:GetDescendants() do if item:IsA("Motor6D") then saved[item] = item.C0 end end
	return { model = model, humanoid = humanoid, root = root, torso = torso, rootJoint = rootJoint, waist = waist, arms = arms, saved = saved }
end
local function fist(arm)
	local shoulder = arm.shoulder
	local frame = shoulder.Part0.CFrame * shoulder.C0 * shoulder.Transform * shoulder.C1:Inverse()
	local part = shoulder.Part1
	for _, m in { arm.elbow, arm.wrist } do
		if m then frame = frame * m.C0 * m.Transform * m.C1:Inverse(); part = m.Part1 end
	end
	return frame:PointToWorldSpace(R.Vector3.new(0, -part.Size.Y * 0.45, 0))
end
local function restored(rigState)
	for m, original in rigState.saved do if m.C0 ~= original then return false end end
	return true
end
local scene = R.Instance.new("Workspace")
local frames, added, removed = signal(), signal(), signal()
local current = rig(false); current.model.Parent = scene
local player = { Character = current.model, CharacterAdded = added, CharacterRemoving = removed }
local environment = {
	game = { GetService = function(_, name) assert(name == "RunService"); return { PreSimulation = frames } end },
	workspace = scene, os = { clock = function() return now end },
}
for _, name in { "Instance", "Vector3", "CFrame", "Color3", "Enum", "UDim2" } do environment[name] = R[name] end
local View = luau.load(fs.readFile("src/client/PlayerCombatView.luau"), { environment = environment, debugName = "PlayerCombatView" })()
local cleanup, attackFx, dodgeFx = View.start(player, { duration = 0.3 })
local effects = assert(scene:FindFirstChild("LocalPlayerCombatEffects"))
local popup = assert(effects:FindFirstChild("ImpactOrigin"):FindFirstChild("HitDamage"))
local damage = assert(popup:FindFirstChildOfClass("TextLabel"))
check(effects:GetAttribute("CosmeticOnly") == true and #effects:GetChildren() == 9, "Punch owns a small original fist trail, impact sparks and popup anchor")
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
check((extended - draw):Dot(current.torso.CFrame.LookVector) > 1.7, "R6 C0/C1 forward kinematics prove the fist advances over 1.7 studs from draw-back")
check((extended - neutral):Dot(current.torso.CFrame.LookVector) > 1.25, "R6 fist visibly extends forward rather than rotating only the shoulder matrix")
check(current.root.CFrame == rootBefore and current.arms.right.shoulder.Transform == R.CFrame.identity, "Punch changes C0 while physical root and Animator Transform remain untouched")
check(effects:FindFirstChild("FistTrail1").Transparency < 1 and not popup.Enabled, "A miss shows hand-following trail without fabricated damage")
local pose = current.arms.right.shoulder.C0
frames:Fire()
check(close(current.arms.right.shoulder.C0, pose), "Repeated frames cannot accumulate C0 offsets")
now = 0.43; frames:Fire()
check(restored(current), "R6 punch recovers all original joint C0 values exactly")

-- Left punch follows the next accepted click rather than a fixed slash animation.
now = 0.6; local leftBefore = fist(current.arms.left)
attackFx(R.Vector3.new(5, 7, -3), true, 10)
now = 0.8; frames:Fire()
check((fist(current.arms.left) - leftBefore):Dot(current.torso.CFrame.LookVector) > 1.25 and current.arms.right.shoulder.C0 == current.saved[current.arms.right.shoulder], "Second click jabs with the left arm while the right recovers")
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
check(current.arms.right.elbow.C0 ~= current.saved[current.arms.right.elbow] or current.arms.right.wrist.C0 ~= current.saved[current.arms.right.wrist], "R15 presentation includes wrist and elbow joints")
now = 2.43; frames:Fire()
check(restored(current), "R15 attack restores shoulder, elbow, wrist and waist exactly")

local streamedShoulder, leftNeutral = current.arms.left.shoulder, fist(current.arms.left)
streamedShoulder.Parent = nil
now = 2.45; attackFx(R.Vector3.new(5, 8, -3), false); frames:Fire()
streamedShoulder.Parent = current.torso
now = 2.65; frames:Fire()
check(streamedShoulder.C0 ~= current.saved[streamedShoulder] and (fist(current.arms.left) - leftNeutral):Dot(current.torso.CFrame.LookVector) > 1.8, "A shoulder that streams in during the punch is rediscovered before the periodic scan")
now = 2.89; frames:Fire()
check(restored(current), "Late-stream arm completes and restores its original C0")

local beforeDash = current.root.CFrame
now = 3; dodgeFx(R.Vector3.new(1, 0, 0))
now = 3.24; frames:Fire()
check(current.rootJoint.C0 ~= current.saved[current.rootJoint], "Dodge lean uses provided 0.3-second duration rather than the old 0.22-second duration")
check(current.root.CFrame == beforeDash, "Client dodge animation never moves the physical root")
now = 3.31; frames:Fire()
check(restored(current), "Dodge restores both the root and waist C0 values")
now = 3.4; dodgeFx(R.Vector3.new(0 / 0, 0, 0)); frames:Fire()
check(restored(current), "Invalid cosmetic direction cannot change the rig")
current.humanoid.Health = 0
attackFx(R.Vector3.new(5, 8, -3), true, 10); frames:Fire()
check(restored(current) and not popup.Enabled, "Dead avatar cannot start a new attack or damage popup")
current.humanoid.Health = 100
now = 4; attackFx(R.Vector3.new(5, 8, -3), true, 10)
now = 4.1; frames:Fire()
local customized = current.saved[current.arms.right.shoulder] * R.CFrame.Angles(0, 0.05, 0)
current.arms.right.shoulder.C0 = customized
current.saved[current.arms.right.shoulder] = current.arms.right.shoulder.C0
now = 4.12; frames:Fire(); cleanup(); cleanup()
check(restored(current), "Cleanup restores the unfinished native C0 pose exactly")
check(current.arms.right.shoulder.C0 == current.saved[current.arms.right.shoulder], "An external C0 customization becomes the restored base rather than being overwritten")
check(frames.Active() == 0 and added.Active() == 0 and removed.Active() == 0 and scene:FindFirstChild("LocalPlayerCombatEffects") == nil, "Cleanup disconnects lifecycle signals and deletes owned effects")
attackFx(R.Vector3.new(5, 7, -3), true, 10); dodgeFx(R.Vector3.new(0, 0, -1)); frames:Fire()
check(restored(current), "Late effects cannot revive a destroyed view")
print("Player combat view: " .. checks .. " actual-module R6/R15 fist FK, C0, hit, dodge and cleanup checks passed; native rendering requires Studio")
