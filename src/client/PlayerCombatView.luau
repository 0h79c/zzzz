--!nonstrict
-- Original, local combat poses. No uploaded animations or physical root movement.
-- Accepted server effects are the only callers of attackFx and dodgeFx.
local RunService = game:GetService("RunService")
local PlayerCombatView = {}
local swingDuration, dodgeDuration = 0.24, 0.22

local function finiteVector(value)
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < math.huge and math.abs(value.Y) < math.huge and math.abs(value.Z) < math.huge
end

local function sameFrame(a, b)
	return (a.Position - b.Position).Magnitude < 0.0001
		and (a.LookVector - b.LookVector).Magnitude < 0.0001 and (a.UpVector - b.UpVector).Magnitude < 0.0001
end

function PlayerCombatView.start(player)
	local stopped = false
	local character = player.Character
	local shoulder, torso
	local attackStarted, dodgeStarted, dodgeDirection, swingDirection
	local states = {}
	local effects = Instance.new("Folder")
	effects.Name = "LocalPlayerCombatEffects"
	effects:SetAttribute("CosmeticOnly", true)
	effects.Parent = workspace
	local arc = {}
	for index = 1, 7 do
		local shard = Instance.new("WedgePart")
		shard.Name = "SwingArc" .. tostring(index)
		shard.Anchored = true
		shard.CanCollide, shard.CanTouch, shard.CanQuery = false, false, false
		shard.CastShadow = false
		shard.Size = Vector3.new(0.1, 0.14, 0.8)
		shard.Material = Enum.Material.Neon
		shard.Color = Color3.fromRGB(230, 241, 212)
		shard.Transparency = 1
		shard.Parent = effects
		arc[index] = shard
	end
	local function hideArc()
		for _, shard in arc do shard.Transparency = 1 end
	end
	local function restorePose()
		for joint, state in states do
			-- Animate may have produced a new base pose since our last frame.
			if joint.Parent and state.applied and sameFrame(joint.Transform, state.applied) then
				joint.Transform = state.base
			end
		end
		table.clear(states)
	end
	local function discoverJoints()
		shoulder, torso = nil, nil
		if not character then return end
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("Motor6D") then
				if descendant.Name == "RightShoulder" or descendant.Name == "Right Shoulder" then shoulder = descendant end
				if descendant.Name == "Root" or descendant.Name == "RootJoint" then torso = descendant end
			end
		end
	end
	local function resetCharacter(nextCharacter)
		restorePose()
		hideArc()
		attackStarted, dodgeStarted, dodgeDirection, swingDirection = nil, nil, nil, nil
		character = nextCharacter
		discoverJoints()
	end
	discoverJoints()
	local added = player.CharacterAdded:Connect(resetCharacter)
	local removed = player.CharacterRemoving:Connect(function(oldCharacter)
		if character == oldCharacter then resetCharacter(nil) end
	end)

	local function compose(joint, offset)
		if not joint or not joint.Parent then return end
		local current = joint.Transform
		local previous = states[joint]
		-- Unanimated/custom rigs retain Transform, while Animate refreshes it.
		-- Remove our previous contribution only when it is still present.
		if previous and sameFrame(current, previous.applied) then current = previous.base end
		joint.Transform = current * offset
		states[joint] = { base = current, applied = joint.Transform }
	end
	local function rootPart()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return nil end
		return root
	end
	local function updatePose()
		if stopped then return end
		local root = rootPart()
		if not root then
			restorePose()
			hideArc()
			attackStarted, dodgeStarted = nil, nil
			return
		end
		if not shoulder or not shoulder.Parent or not torso or not torso.Parent then discoverJoints() end
		local now = os.clock()
		local attackProgress = if attackStarted then (now - attackStarted) / swingDuration else 1
		local dodgeProgress = if dodgeStarted then (now - dodgeStarted) / dodgeDuration else 1
		if attackProgress >= 1 then attackStarted = nil end
		if dodgeProgress >= 1 then dodgeStarted = nil end
		if not attackStarted and not dodgeStarted then
			restorePose()
			hideArc()
			return
		end
		local shoulderPose, torsoPose = CFrame.identity, CFrame.identity
		if attackStarted then
			local strength = math.sin(math.clamp(attackProgress, 0, 1) * math.pi)
			-- A short shoulder wind-up, cross-body swing and return to Animate.
			local sweep = math.rad(105) * (1 - 2 * attackProgress)
			shoulderPose = CFrame.Angles(-math.rad(35) * strength, sweep * strength, math.rad(32) * strength)
			torsoPose = CFrame.Angles(0, -math.rad(15) * strength, 0)
			local direction = swingDirection or root.CFrame.LookVector
			local flat = direction * Vector3.new(1, 0, 1)
			if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
			local frame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
			for index, shard in arc do
				local trailProgress = math.clamp(attackProgress - (index - 1) * 0.035, 0, 1)
				local angle = math.rad(-68 + trailProgress * 136)
				shard.CFrame = frame * CFrame.new(math.sin(angle) * 3, 0.8, -math.cos(angle) * 3) * CFrame.Angles(0, -angle, math.rad(14))
				shard.Transparency = if attackProgress >= 0.12 and attackProgress <= 0.82 then 0.35 + (index - 1) * 0.075 else 1
			end
		else
			hideArc()
		end
		if dodgeStarted then
			local strength = math.sin(math.clamp(dodgeProgress, 0, 1) * math.pi)
			local localDirection = root.CFrame:VectorToObjectSpace(dodgeDirection or root.CFrame.LookVector)
			torsoPose *= CFrame.Angles(-localDirection.Z * math.rad(24) * strength, 0, -localDirection.X * math.rad(28) * strength)
			shoulderPose *= CFrame.Angles(-math.rad(30) * strength, 0, math.rad(15) * strength)
		end
		compose(shoulder, shoulderPose)
		compose(torso, torsoPose)
	end
	-- Animator evaluates before PreSimulation, so the additive pose survives it.
	local poseConnection = (RunService.PreSimulation or RunService.RenderStepped):Connect(updatePose)
	local function attackFx(targetPosition)
		if stopped then return end
		local root = rootPart()
		if not root then return end
		swingDirection = root.CFrame.LookVector
		if finiteVector(targetPosition) then
			local delta = (targetPosition - root.Position) * Vector3.new(1, 0, 1)
			if delta.Magnitude > 0.01 and delta.Magnitude < 40 then swingDirection = delta.Unit end
		end
		attackStarted = os.clock()
	end
	local function dodgeFx(direction)
		if stopped or not rootPart() or not finiteVector(direction) then return end
		local flat = direction * Vector3.new(1, 0, 1)
		if flat.Magnitude < 0.01 then return end
		dodgeDirection = flat.Unit
		dodgeStarted = os.clock()
	end
	local function cleanup()
		if stopped then return end
		stopped = true
		poseConnection:Disconnect()
		added:Disconnect()
		removed:Disconnect()
		restorePose()
		effects:Destroy()
		character = nil
	end
	return cleanup, attackFx, dodgeFx
end

return PlayerCombatView
