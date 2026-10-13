--!strict
-- A local visual companion; rewards and ownership are always server concerns.
local RunService = game:GetService("RunService")

local CompanionView = {}

type Piece = {
	part: BasePart,
	offset: CFrame,
	legPhase: number?,
}

function CompanionView.start(player: Player): (() -> (), (Vector3) -> ())
	local model = Instance.new("Model")
	model.Name = "LocalTrailCompanion"
	model:SetAttribute("CosmeticOnly", true)
	model.Parent = workspace
	local pieces: { Piece } = {}
	local bodyHeight = 1.1
	local strike: { origin: CFrame, target: CFrame, elapsed: number }? = nil

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, legPhase: number?, wedge: boolean?): BasePart
		local bodyPart = (if wedge then Instance.new("WedgePart") else Instance.new("Part")) :: BasePart
		bodyPart.Name = name
		bodyPart.Size = size
		bodyPart.Color = color
		bodyPart.Material = Enum.Material.SmoothPlastic
		bodyPart.Anchored = true
		bodyPart.CanCollide = false
		bodyPart.CanTouch = false
		bodyPart.CanQuery = false
		bodyPart.Parent = model
		table.insert(pieces, { part = bodyPart, offset = offset, legPhase = legPhase })
		return bodyPart
	end

	local function buildCompanion()
		strike = nil
		model:ClearAllChildren()
		table.clear(pieces)
		local selected = player:GetAttribute("CompanionId")
		local isFox = selected == "emberfox"
		local isCub = selected == "tidecub"
		local fur = if isFox then Color3.fromRGB(196, 115, 67) elseif isCub then Color3.fromRGB(129, 180, 197) else Color3.fromRGB(222, 230, 220)
		local shadowFur = if isFox then Color3.fromRGB(89, 70, 65) elseif isCub then Color3.fromRGB(104, 146, 169) else Color3.fromRGB(176, 192, 189)
		local accent = if isFox then Color3.fromRGB(239, 205, 133) elseif isCub then Color3.fromRGB(178, 210, 221) else Color3.fromRGB(139, 174, 116)
		bodyHeight = if isCub then 0.95 else 1.1
		model:SetAttribute("CompanionId", if isFox then "emberfox" elseif isCub then "tidecub" else "mosswolf")
		local body = piece("Body", if isCub then Vector3.new(1.5, 1.1, 1.6) else Vector3.new(1.25, 0.95, 2), CFrame.identity, fur)
		model.PrimaryPart = body
		piece("ChestRuff", if isCub then Vector3.new(1.4, 1.05, 0.7) else Vector3.new(1.4, 1.12, 0.8), CFrame.new(0, 0.1, -0.7) * CFrame.Angles(math.rad(-8), 0, 0), if isFox then Color3.fromRGB(238, 219, 177) else fur)
		piece("Head", if isCub then Vector3.new(1.2, 0.95, 0.9) else Vector3.new(0.95, 0.85, 0.95), CFrame.new(0, 0.45, -1.25), fur)
		piece("Muzzle", if isCub then Vector3.new(0.72, 0.4, 0.4) else Vector3.new(0.65, 0.4, 0.65), CFrame.new(0, 0.2, if isCub then -1.78 else -1.92), if isFox then Color3.fromRGB(238, 219, 177) else shadowFur)
		piece("Nose", Vector3.new(0.25, 0.2, 0.16), CFrame.new(0, 0.3, if isCub then -2.02 else -2.29), Color3.fromRGB(43, 54, 57))
		for _, side in { -1, 1 } do
			local ear = piece("Ear", if isFox then Vector3.new(0.45, 0.95, 0.42) elseif isCub then Vector3.new(0.46, 0.46, 0.4) else Vector3.new(0.32, 0.68, 0.4), CFrame.new(side * (if isCub then 0.5 else 0.34), if isFox then 1.15 else 1.05, -1.15) * CFrame.Angles(0, 0, math.rad(-side * 12)), shadowFur, nil, not isCub)
			if isCub and ear:IsA("Part") then
				ear.Shape = Enum.PartType.Ball
			end
			piece("Eye", Vector3.new(0.08, 0.13, 0.17), CFrame.new(side * (if isCub then 0.61 else 0.48), 0.53, -1.56), Color3.fromRGB(47, 72, 83))
			for _, endZ in { -0.63, 0.7 } do
				local phase = if (side == -1 and endZ < 0) or (side == 1 and endZ > 0) then 0 else math.pi
				piece("Leg", if isCub then Vector3.new(0.43, 0.52, 0.45) else Vector3.new(0.32, 0.69, 0.38), CFrame.new(side * (if isCub then 0.53 else 0.46), if isCub then -0.6 else -0.68, endZ), shadowFur, phase)
			end
		end
		piece("Tail", if isFox then Vector3.new(0.68, 0.65, 1.6) elseif isCub then Vector3.new(0.48, 0.45, 0.5) else Vector3.new(0.4, 0.42, 1.22), CFrame.new(0, 0.15, if isCub then 1 else 1.37) * CFrame.Angles(math.rad(-23), 0, 0), fur)
		if isFox then
			piece("FoxTailTip", Vector3.new(0.7, 0.67, 0.5), CFrame.new(0, 0.45, 2.08) * CFrame.Angles(math.rad(-23), 0, 0), Color3.fromRGB(238, 219, 177))
		end
		piece("TrailScarf", Vector3.new(1.43, 0.26, 0.33), CFrame.new(0, 0.3, -0.9), accent)
		piece("ScarfKnot", Vector3.new(0.25, 0.6, 0.25), CFrame.new(0.64, 0.02, -0.97) * CFrame.Angles(0, 0, math.rad(-15)), accent)
	end
	buildCompanion()

	local character = player.Character
	local raycastParameters = RaycastParams.new()
	raycastParameters.FilterType = Enum.RaycastFilterType.Exclude
	local function setCharacter(newCharacter: Model)
		strike = nil
		character = newCharacter
		raycastParameters.FilterDescendantsInstances = { model, newCharacter }
	end
	if character then
		setCharacter(character)
	else
		raycastParameters.FilterDescendantsInstances = { model }
	end

	local currentFrame: CFrame? = nil
	local floorY = 4
	local floorTimer = 0
	local elapsed = 0
	local stopped = false
	local companionConnection = player:GetAttributeChangedSignal("CompanionId"):Connect(buildCompanion)
	local addedConnection = player.CharacterAdded:Connect(function(newCharacter: Model)
		setCharacter(newCharacter)
		currentFrame = nil
		floorTimer = 0
	end)
	local removedConnection = player.CharacterRemoving:Connect(function(oldCharacter: Model)
		if character == oldCharacter then
			strike = nil
			character = nil
			currentFrame = nil
			model.Parent = nil
		end
	end)

	local renderConnection = RunService.RenderStepped:Connect(function(dt: number)
		local activeCharacter = character
		if stopped or not activeCharacter then
			return
		end
		local root = activeCharacter:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		if not model.Parent then
			model.Parent = workspace
		end
		local desired = (root.CFrame * CFrame.new(3.2, 0, 3.6)).Position
		floorTimer -= dt
		if floorTimer <= 0 then
			floorTimer = 0.12
			local ground = workspace:Raycast(desired + Vector3.new(0, 6, 0), Vector3.new(0, -32, 0), raycastParameters)
			floorY = if ground then ground.Position.Y else root.Position.Y - 3
		end
		local target = Vector3.new(desired.X, floorY + bodyHeight, desired.Z)
		local oldFrame = currentFrame
		if not oldFrame or (oldFrame.Position - target).Magnitude > 40 then
			local forward = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if forward.Magnitude < 0.01 then
				forward = Vector3.new(0, 0, -1)
			end
			oldFrame = CFrame.lookAt(target, target + forward)
		end
		local alpha = 1 - math.exp(-math.min(dt, 0.1) * 8)
		local newPosition = oldFrame.Position:Lerp(target, alpha)
		local movement = (newPosition - oldFrame.Position) * Vector3.new(1, 0, 1)
		local direction = if movement.Magnitude > 0.025 then movement.Unit else root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.01 then
			direction = Vector3.new(0, 0, -1)
		end
		local heading = oldFrame:Lerp(CFrame.lookAt(newPosition, newPosition + direction), alpha)
		local newFrame = CFrame.new(newPosition) * heading.Rotation
		local activeStrike = strike
		if activeStrike then
			activeStrike.elapsed += math.min(dt, 0.1)
			local time = activeStrike.elapsed
			if time < 0.2 then
				local progress = time / 0.2
				local approach = activeStrike.origin:Lerp(activeStrike.target, progress)
				newFrame = approach + Vector3.new(0, math.sin(progress * math.pi) * 1.1, 0)
			elseif time < 0.3 then
				newFrame = activeStrike.target
			elseif time < 0.45 then
				-- Return toward the live character, even if they moved during the pounce.
				local returnFrame = CFrame.lookAt(target, target + direction)
				newFrame = activeStrike.target:Lerp(returnFrame, (time - 0.3) / 0.15)
			else
				strike = nil
				newFrame = CFrame.lookAt(target, target + direction)
			end
		end
		currentFrame = newFrame
		local speed = movement.Magnitude / math.max(dt, 0.001)
		local gaitAmount = math.clamp(speed / 12, 0, 1)
		elapsed += math.min(dt, 0.1) * (8 + math.min(speed, 12))
		for _, wolfPiece in pieces do
			local offset = wolfPiece.offset
			local phase = wolfPiece.legPhase
			if phase then
				local stride = math.sin(elapsed + phase) * 0.18 * gaitAmount
				local lift = math.max(0, math.cos(elapsed + phase)) * 0.13 * gaitAmount
				offset *= CFrame.new(0, lift, stride) * CFrame.Angles(stride * 2, 0, 0)
			end
			wolfPiece.part.CFrame = newFrame * offset
		end
	end)

	local function strikeAt(targetPosition: Vector3)
		if stopped or not character or not currentFrame or typeof(targetPosition) ~= "Vector3" then return end
		if targetPosition.X ~= targetPosition.X or targetPosition.Y ~= targetPosition.Y or targetPosition.Z ~= targetPosition.Z
			or math.abs(targetPosition.X) == math.huge or math.abs(targetPosition.Y) == math.huge or math.abs(targetPosition.Z) == math.huge then return end
		local direction = (targetPosition - currentFrame.Position) * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.01 or direction.Magnitude > 40 then return end
		local destination = Vector3.new(targetPosition.X, currentFrame.Position.Y, targetPosition.Z) - direction.Unit * 2.2
		strike = { origin = currentFrame, target = CFrame.lookAt(destination, destination + direction.Unit), elapsed = 0 }
	end
	local function cleanup()
		if stopped then
			return
		end
		stopped = true
		strike = nil
		renderConnection:Disconnect()
		addedConnection:Disconnect()
		removedConnection:Disconnect()
		companionConnection:Disconnect()
		model:Destroy()
	end
	return cleanup, strikeAt
end

return CompanionView
