--!nonstrict
-- Original local C0 poses bypass Animator's Transform writes. Server effects
-- authorize the punch, impact and dodge; this module never moves the root part.
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
	local arms, torso, rootJoint, states = {}, nil, nil, {}
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
	local trail, sparks = {}, {}
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
	local function hideImpact()
		for _, part in sparks do part.Transparency = 1 end
		popup.Enabled = false
	end
	local function restorePose()
		for joint, state in states do
			if joint.Parent and sameFrame(joint.C0, state.applied) then joint.C0 = state.base end
		end
		table.clear(states)
	end
	local function discoverJoints()
		arms, torso, rootJoint = { right = {}, left = {} }, nil, nil
		if not character then return end
		for _, item in character:GetDescendants() do
			if item:IsA("Motor6D") then
				if item.Name == "Root" or item.Name == "RootJoint" then rootJoint = item end
				if item.Name == "Waist" then torso = item end
				for _, side in { "right", "left" } do
					local prefix = if side == "right" then "Right" else "Left"
					if item.Name == prefix .. "Shoulder" or item.Name == prefix .. " Shoulder" then arms[side].shoulder = item end
					if item.Name == prefix .. "Elbow" then arms[side].elbow = item end
					if item.Name == prefix .. "Wrist" then arms[side].wrist = item end
				end
			end
		end
		torso = torso or rootJoint
		scanAt = os.clock() + 0.5
	end
	local function setCharacter(nextCharacter)
		restorePose(); hideTrail(); hideImpact()
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
		local base, previous = joint.C0, states[joint]
		if previous and sameFrame(base, previous.applied) then base = previous.base end
		-- Rotate in Part0 coordinates around the existing shoulder pivot, before
		-- C0's orientation. This makes +X raise the arm FORWARD on R6 and R15.
		joint.C0 = CFrame.new(base.Position) * rotation * base.Rotation
		states[joint] = { base = base, applied = joint.C0 }
	end
	local function fistPosition(arm)
		local joint = arm.shoulder
		if not joint or not joint.Part0 or not joint.Part1 then return nil end
		local frame = joint.Part0.CFrame * joint.C0 * joint.Transform * joint.C1:Inverse()
		local part = joint.Part1
		for _, nextJoint in { arm.elbow, arm.wrist } do
			if nextJoint and nextJoint.Part0 == part and nextJoint.Part1 then
				frame = frame * nextJoint.C0 * nextJoint.Transform * nextJoint.C1:Inverse()
				part = nextJoint.Part1
			end
		end
		return frame:PointToWorldSpace(Vector3.new(0, -part.Size.Y * 0.45, 0))
	end
	local function update()
		if stopped then return end
		local root, now = rootPart(), os.clock()
		if not root then
			restorePose(); hideTrail(); hideImpact()
			punch, dash, impact = nil, nil, nil
			return
		end
		local activeArm = punch and arms[punch.side]
		local missing = activeArm and (not activeArm.shoulder or not activeArm.shoulder.Parent
			or (activeArm.shoulder.Part1 and string.find(activeArm.shoulder.Part1.Name, "UpperArm", 1, true)
				and (not activeArm.elbow or not activeArm.wrist)))
		if now >= scanAt or missing then discoverJoints() end
		if punch and now - punch.started >= punchDuration then punch = nil; hideTrail() end
		if dash and now - dash.started >= dodgeDuration then dash = nil end
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
			local lean = CFrame.Angles(-direction.Z * math.rad(28) * strength, 0, -direction.X * math.rad(30) * strength)
			if rootJoint == torso then torsoPose *= lean else compose(rootJoint, lean) end
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
	local poseConnection = (RunService.PreSimulation or RunService.RenderStepped):Connect(update)
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
		poseConnection:Disconnect(); added:Disconnect(); removed:Disconnect()
		restorePose(); effects:Destroy()
		character = nil
	end
	return cleanup, attackFx, dodgeFx
end
return View
