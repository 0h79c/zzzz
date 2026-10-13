--!nonstrict
-- Native procedural animation supports legacy Motor6D and upgraded R15
-- AnimationConstraint joints. Restore our layer before Animator evaluates, then
-- apply it at PreSimulation after Animator; no attachment/C0 mutation or asset
-- upload is needed. Server effects authorize strikes and root movement.
-- https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint
local RunService = game:GetService("RunService")
local View = {}
local punchDuration = 0.42
local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < math.huge and math.abs(value.Y) < math.huge and math.abs(value.Z) < math.huge
end
local function sameFrame(a, b)
	return (a.Position - b.Position).Magnitude < 0.0001
		and (a.LookVector - b.LookVector).Magnitude < 0.0001 and (a.UpVector - b.UpVector).Magnitude < 0.0001
end

function View.start(player, dodgeRules)
	local dodgeDuration = (dodgeRules and dodgeRules.duration) or 0.3
	local stopped, character = false, player.Character
	local arms, legs, torso, rootJoint, states = {}, {}, nil, nil, {}
	local punch, dash, impact, nextLeft, scanAt = nil, nil, nil, false, 0
	local effects = Instance.new("Folder")
	effects.Name = "LocalPlayerCombatEffects"
	effects:SetAttribute("CosmeticOnly", true)
	effects.Parent = workspace
	local function piece(name, size)
		local part = Instance.new("Part")
		part.Name, part.Size = name, size
		part.Anchored, part.CastShadow = true, false
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Material, part.Color = Enum.Material.Neon, Color3.fromRGB(232, 241, 207)
		part.Transparency, part.Parent = 1, effects
		return part
	end
	local trail, sparks, wake = {}, {}, {}
	for index = 1, 2 do wake[index] = piece("DodgeWake" .. index, Vector3.new(0.06, 0.06, 3)) end
	for index = 1, 4 do
		trail[index] = piece("FistTrail" .. index, Vector3.new(0.08, 0.08, 0.3))
		sparks[index] = piece("HitSpark" .. index, Vector3.new(0.1, 0.1, 0.45))
	end
	local impactAnchor = piece("ImpactOrigin", Vector3.new(0.08, 0.08, 0.08))
	local popup = Instance.new("BillboardGui")
	popup.Name, popup.Size, popup.AlwaysOnTop = "HitDamage", UDim2.fromOffset(100, 36), false
	popup.MaxDistance, popup.Enabled, popup.Parent = 70, false, impactAnchor
	local damageText = Instance.new("TextLabel")
	damageText.Size, damageText.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	damageText.Font, damageText.TextSize = Enum.Font.GothamBold, 18
	damageText.TextColor3, damageText.TextStrokeTransparency = Color3.fromRGB(243, 229, 178), 0.5
	damageText.Text, damageText.Parent = "", popup
	local function hideTrail() for _, part in trail do part.Transparency = 1 end end
	local function hideWake() for _, part in wake do part.Transparency = 1 end end
	local function hideImpact()
		for _, part in sparks do part.Transparency = 1 end
		popup.Enabled = false
	end
	local function restorePose()
		for joint, state in states do
			if joint.Parent and sameFrame(joint.Transform, state.applied) then joint.Transform = state.base end
		end
		table.clear(states)
	end
	local function jointFrames(joint)
		if joint:IsA("AnimationConstraint") then
			local a, b = joint.Attachment0, joint.Attachment1
			if a and b and a.Parent and b.Parent and a.Parent:IsA("BasePart") and b.Parent:IsA("BasePart") then
				return a.Parent, b.Parent, a.CFrame, b.CFrame
			end
		elseif joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			return joint.Part0, joint.Part1, joint.C0, joint.C1
		end
		return nil
	end
	local function discoverJoints()
		arms, legs, torso, rootJoint = { right = {}, left = {} }, { right = {}, left = {} }, nil, nil
		if not character then return end
		local count, upgraded = 0, 0
		for _, item in character:GetDescendants() do
			if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
				local _, child = jointFrames(item)
				if not child then continue end
				count += 1
				if item:IsA("AnimationConstraint") then upgraded += 1 end
				-- Match connected limb names as well as joint names: upgraded
				-- constraints and custom rig exports can rename the joint itself.
				if child.Name == "LowerTorso" or child.Name == "Torso" or item.Name == "Root" or item.Name == "RootJoint" then rootJoint = item end
				if child.Name == "UpperTorso" or item.Name == "Waist" then torso = item end
				for _, side in { "right", "left" } do
					local prefix = if side == "right" then "Right" else "Left"
					if child.Name == prefix .. "UpperArm" or child.Name == prefix .. " Arm" or item.Name == prefix .. "Shoulder" or item.Name == prefix .. " Shoulder" then arms[side].shoulder = item end
					if child.Name == prefix .. "LowerArm" or item.Name == prefix .. "Elbow" then arms[side].elbow = item end
					if child.Name == prefix .. "Hand" or item.Name == prefix .. "Wrist" then arms[side].wrist = item end
					if child.Name == prefix .. "UpperLeg" or child.Name == prefix .. " Leg" or item.Name == prefix .. "Hip" or item.Name == prefix .. " Hip" then legs[side].hip = item end
					if child.Name == prefix .. "LowerLeg" or item.Name == prefix .. "Knee" then legs[side].knee = item end
					if child.Name == prefix .. "Foot" or item.Name == prefix .. "Ankle" then legs[side].ankle = item end
				end
			end
		end
		torso = torso or rootJoint
		character:SetAttribute("WildbondCombatJointCount", count)
		character:SetAttribute("WildbondCombatRig", if upgraded > 0 then "AnimationConstraint" elseif count > 0 then "Motor6D" else "Waiting for rig")
		character:SetAttribute("WildbondCombatReady", arms.right.shoulder ~= nil and arms.left.shoulder ~= nil and rootJoint ~= nil and legs.right.hip ~= nil and legs.left.hip ~= nil)
		scanAt = os.clock() + 0.5
	end
	local function setCharacter(nextCharacter)
		restorePose(); hideTrail(); hideImpact(); hideWake()
		punch, dash, impact, character, nextLeft = nil, nil, nil, nextCharacter, false
		discoverJoints()
	end
	discoverJoints()
	local added = player.CharacterAdded:Connect(setCharacter)
	local removed = player.CharacterRemoving:Connect(function(old) if character == old then setCharacter(nil) end end)
	local function rootPart()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return nil end
		return root
	end
	local function compose(joint, rotation)
		if not joint or not joint.Parent then return end
		local _, _, c0 = jointFrames(joint)
		if not c0 then return end
		local base = joint.Transform
		local previous = states[joint]
		if previous and sameFrame(base, previous.applied) then base = previous.base end
		-- Convert Part0-space rotations into the attachment's local axes.
		-- R6 shoulder/hip attachments have different axes from R15.
		joint.Transform = c0.Rotation:Inverse() * rotation * c0.Rotation * base
		states[joint] = { base = base, applied = joint.Transform }
	end
	local function fistPosition(arm)
		local joint = arm.shoulder
		if not joint then return nil end
		local parent, part, c0, c1 = jointFrames(joint)
		if not parent then return nil end
		local frame = parent.CFrame * c0 * joint.Transform * c1:Inverse()
		for _, nextJoint in { arm.elbow, arm.wrist } do
			if nextJoint then
				local nextParent, nextPart, nextC0, nextC1 = jointFrames(nextJoint)
				if nextParent == part then
					frame = frame * nextC0 * nextJoint.Transform * nextC1:Inverse()
					part = nextPart
				end
			end
		end
		return frame:PointToWorldSpace(Vector3.new(0, -part.Size.Y * 0.45, 0))
	end
	local function update()
		if stopped then return end
		local root, now = rootPart(), os.clock()
		if not root then
			restorePose(); hideTrail(); hideImpact(); hideWake()
			punch, dash, impact = nil, nil, nil
			return
		end
		local function incomplete(limb, primary, second, third, r15Part)
			local joint = limb and limb[primary]
			if not joint or not joint.Parent then return true end
			local _, child = jointFrames(joint)
			return child and string.find(child.Name, r15Part, 1, true) ~= nil
				and (not limb[second] or not limb[second].Parent or not limb[third] or not limb[third].Parent)
		end
		local missing = punch and incomplete(arms[punch.side], "shoulder", "elbow", "wrist", "UpperArm")
		if dash then
			missing = missing or not rootJoint or not rootJoint.Parent
			for _, side in { "right", "left" } do
				missing = missing or incomplete(arms[side], "shoulder", "elbow", "wrist", "UpperArm")
					or incomplete(legs[side], "hip", "knee", "ankle", "UpperLeg")
			end
		end
		if now >= scanAt or missing then discoverJoints() end
		if punch and now - punch.started >= punchDuration then punch = nil; hideTrail() end
		if dash and now - dash.started >= dodgeDuration then dash = nil; hideWake() end
		restorePose()
		local torsoPose = CFrame.identity
		if punch then
			local age, arm = now - punch.started, arms[punch.side]
			local isR15 = arm.elbow ~= nil
			local draw = if isR15 then 25 else -22
			local shoulderAngle, elbowAngle, envelope
			if age < 0.11 then
				local alpha = math.clamp(age / 0.11, 0, 1)
				shoulderAngle, elbowAngle, envelope = draw * alpha, 105 * alpha, alpha
			elseif age < 0.2 then
				local alpha = (age - 0.11) / 0.09
				shoulderAngle, elbowAngle, envelope = draw + (95 - draw) * alpha, 105 * (1 - alpha), 1
			elseif age < 0.25 then shoulderAngle, elbowAngle, envelope = 95, 0, 1
			else
				local alpha = math.clamp((age - 0.25) / 0.17, 0, 1)
				shoulderAngle, elbowAngle, envelope = 95 * (1 - alpha), 0, 1 - alpha
			end
			local side = if punch.side == "right" then 1 else -1
			compose(arm.shoulder, CFrame.Angles(math.rad(shoulderAngle), 0, math.rad(side * 4) * envelope))
			compose(arm.elbow, CFrame.Angles(math.rad(elbowAngle), 0, 0))
			compose(arm.wrist, CFrame.Angles(math.rad(-8) * envelope, 0, 0))
			torsoPose = CFrame.Angles(0, math.rad(side * 8) * envelope, 0)
			local fist = fistPosition(arm)
			if fist and age >= 0.11 and age <= 0.27 then
				table.insert(punch.history, 1, fist)
				if #punch.history > 5 then table.remove(punch.history) end
				for index, part in trail do
					local a, b = punch.history[index], punch.history[index + 1]
					if a and b and (a - b).Magnitude > 0.015 then
						part.Size = Vector3.new(0.08, 0.08, math.min((a - b).Magnitude, 2))
						part.CFrame, part.Transparency = CFrame.lookAt((a + b) / 2, a), 0.5 + index * 0.1
					else part.Transparency = 1 end
				end
			else hideTrail() end
			if punch.hit and not punch.impacted and age >= 0.18 then
				punch.impacted = true
				impact = { started = now, position = punch.target + Vector3.new(0, 0.7, 0) }
				damageText.Text, popup.Enabled = "-" .. tostring(punch.damage), true
			end
		end
		if dash then
			local strength = math.sin(math.clamp((now - dash.started) / dodgeDuration, 0, 1) * math.pi)
			local direction = root.CFrame:VectorToObjectSpace(dash.direction)
			local across = Vector3.new(-dash.direction.Z, 0, dash.direction.X)
			for index, part in wake do
				local position = root.Position - dash.direction * 1.6 + across * (if index == 1 then -1.15 else 1.15)
				part.CFrame = CFrame.lookAt(position, position + dash.direction)
				part.Size = Vector3.new(0.06, 0.06, 1 + strength * 4)
				part.Transparency = 0.9 - strength * 0.35
			end
			local lean = CFrame.new(0, -0.35 * strength, 0) * CFrame.Angles(direction.Z * math.rad(32) * strength, 0, -direction.X * math.rad(30) * strength)
			if rootJoint == torso then torsoPose = lean * torsoPose else compose(rootJoint, lean) end
			for _, side in { "right", "left" } do
				local sign = if side == "right" then 1 else -1
				local stride = math.sin((now - dash.started) / dodgeDuration * math.pi * 2) * sign * 24
				local leg, arm = legs[side], arms[side]
				compose(leg.hip, CFrame.Angles(math.rad(30 + stride) * strength, 0, 0))
				compose(leg.knee, CFrame.Angles(math.rad(-65) * strength, 0, 0))
				compose(leg.ankle, CFrame.Angles(math.rad(25) * strength, 0, 0))
				if not punch or punch.side ~= side then
					compose(arm.shoulder, CFrame.Angles(math.rad(-30) * strength, 0, math.rad(sign * 10) * strength))
					compose(arm.elbow, CFrame.Angles(math.rad(85) * strength, 0, 0))
				end
			end
		end
		if punch or dash then compose(torso, torsoPose) end
		if impact then
			local age = now - impact.started
			impactAnchor.CFrame = CFrame.new(impact.position + Vector3.new(0, age * 1.8, 0))
			damageText.TextTransparency = math.clamp((age - 0.35) / 0.25, 0, 1)
			for index, part in sparks do
				local angle = index * math.pi / 2
				part.CFrame = CFrame.new(impact.position + Vector3.new(math.cos(angle), math.sin(angle), 0) * (0.15 + age * 3)) * CFrame.Angles(0, 0, angle)
				part.Transparency = math.clamp(0.3 + age * 3, 0, 1)
			end
			if age >= 0.6 then impact = nil; hideImpact() end
		end
	end
	-- PreAnimation restores the previous cosmetic layer before Animator runs.
	-- PreSimulation then applies the fresh pose to BOTH supported joint types.
	local beforeAnimation = RunService.PreAnimation:Connect(restorePose)
	local poseConnection = RunService.PreSimulation:Connect(update)
	local function attackFx(target, hit, damage)
		if stopped or not rootPart() then return end
		hideTrail()
		punch = { started = os.clock(), side = if nextLeft then "left" else "right", history = {},
			hit = hit == true and finiteVector(target) and typeof(damage) == "number" and damage > 0 and damage < math.huge,
			target = target, damage = damage }
		nextLeft = not nextLeft
	end
	local function dodgeFx(direction)
		if stopped or not rootPart() or not finiteVector(direction) then return end
		local flat = direction * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.01 then dash = { started = os.clock(), direction = flat.Unit } end
	end
	local function cleanup()
		if stopped then return end
		stopped = true
		poseConnection:Disconnect(); beforeAnimation:Disconnect(); added:Disconnect(); removed:Disconnect()
		restorePose(); effects:Destroy()
		character = nil
	end
	return cleanup, attackFx, dodgeFx
end
return View
