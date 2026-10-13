--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local Hud = {}
local ink = Color3.fromRGB(30, 52, 55)
local cream = Color3.fromRGB(250, 245, 226)
local mint = Color3.fromRGB(119, 214, 173)
local amber = Color3.fromRGB(244, 186, 91)
local targetInfo = {
	{ id = "moss", title = "Bramble Sprout", position = Vector3.new(-45, 7, -25) },
	{ id = "river", title = "Reed Guardian", position = Vector3.new(0, 7, -65) },
	{ id = "ruins", title = "The Hollow Crown", position = Vector3.new(65, 7, -80) },
}

local function make(class, properties, parent)
	local item = Instance.new(class)
	for key, value in properties do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function round(item, pixels)
	make("UICorner", { CornerRadius = UDim.new(0, pixels or 12) }, item)
end

local function label(parent, text, position, size, fontSize, color)
	return make("TextLabel", {
		BackgroundTransparency = 1, Text = text, Position = position, Size = size,
		TextColor3 = color or cream, TextSize = fontSize or 16,
		Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end

local function button(parent, text, position, size, callback)
	local item = make("TextButton", {
		Text = text, Position = position, Size = size,
		BackgroundColor3 = mint, TextColor3 = ink, Font = Enum.Font.GothamBold,
		TextSize = 15, AutoButtonColor = true, BorderSizePixel = 0,
	}, parent)
	round(item, 10)
	item.Activated:Connect(callback)
	return item
end

function Hud.start(command, catalog, rules, dodgeRules)
	rules = rules or { meleeCooldown = 0.6, petCooldown = 3.2 }
	dodgeRules = dodgeRules or { cooldown = 4, doubleTapWindow = 0.28 }
	local player = Players.LocalPlayer
	local destroyed = false
	local currentState, stateClock, refreshTiming, refreshCooldowns
	local screen = make("ScreenGui", { Name = "WildbondHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	local gui = make("Frame", { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen)
	local scale = make("UIScale", { Scale = 1 }, gui)
	local attackButton, bondButton, dodgeButton, hotbar, companionToggle
	local function resize()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 850, camera.ViewportSize.Y / 480), 0.5, 1)
			gui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
			if attackButton then
				local hotbarBottom = if UserInputService.TouchEnabled then 145 else 76 * scale.Scale
				-- Keep at least the former 194-pixel native-jump gap, and put
				-- the action row above the hotbar at every scale and aspect ratio.
				local hintGap = if UserInputService.TouchEnabled then 12 else 36 * scale.Scale
				local rowTop = hotbarBottom + 132 * scale.Scale + hintGap
				if UserInputService.TouchEnabled then rowTop = math.max(194, rowTop) end
				attackButton.Position = UDim2.new(1, -134, 1, -math.round(rowTop / scale.Scale))
				bondButton.Position = UDim2.new(1, -260, 1, attackButton.Position.Y.Offset)
				dodgeButton.Position = UDim2.new(1, -134, 1, -math.round((rowTop + 58 * scale.Scale + 20) / scale.Scale))
				hotbar.Position = UDim2.new(0.5, 0, 1, -math.round(hotbarBottom / scale.Scale))
				if UserInputService.TouchEnabled then companionToggle.Position = UDim2.new(1, -340, 0, 18) end
			end
		end
	end
	resize()
	-- Polling covers camera replacement after respawn without retaining camera connections.
	local resizeClock = 0
	local resizeConnection = RunService.RenderStepped:Connect(function(dt)
		if refreshCooldowns then refreshCooldowns() end
		resizeClock += dt
		if resizeClock >= 1 then
			resizeClock = 0
			resize()
			if refreshTiming then refreshTiming() end
		end
	end)

	local mission = make("Frame", {
		Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(320, 272),
		BackgroundColor3 = ink, BackgroundTransparency = 0.08, BorderSizePixel = 0,
	}, gui)
	round(mission, 16)
	label(mission, "WILDBOND", UDim2.fromOffset(18, 12), UDim2.fromOffset(280, 26), 23, mint)
	label(mission, "GREYWATER REACH  /  PVE ALPHA", UDim2.fromOffset(18, 42), UDim2.fromOffset(280, 18), 10)
	local objective = label(mission, "Find the hunt board in the village.", UDim2.fromOffset(18, 70), UDim2.fromOffset(284, 42), 16)
	local rows = {}
	for index, target in targetInfo do
		rows[target.id] = label(mission, "○  " .. target.title, UDim2.fromOffset(18, 111 + index * 25), UDim2.fromOffset(284, 23), 14)
	end
	local timingLabel = label(mission, "Hunt timer starts at the board.", UDim2.fromOffset(18, 217), UDim2.fromOffset(284, 22), 11, amber)
	label(mission, "Session progress · saving comes next", UDim2.fromOffset(18, 246), UDim2.fromOffset(284, 16), 10, Color3.fromRGB(184, 201, 198))
	local function duration(seconds)
		local whole = math.max(0, math.floor(seconds))
		return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
	end
	local function falls(count)
		return tostring(count) .. (if count == 1 then " fall" else " falls")
	end
	refreshTiming = function()
		if not currentState or not currentState.timing then return end
		local timing = currentState.timing
		if currentState.active then
			timingLabel.Text = duration((timing.elapsed or 0) + os.clock() - stateClock) .. " elapsed · " .. falls(timing.deaths or 0)
		elseif timing.lastDuration then
			timingLabel.Text = "Last " .. duration(timing.lastDuration) .. " · best " .. duration(timing.bestDuration or timing.lastDuration) .. " · falls " .. tostring(timing.lastDeaths or 0)
		end
	end

	local purse = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(156, 78), BackgroundColor3 = ink, BorderSizePixel = 0 }, gui)
	round(purse, 14)
	local shells = label(purse, "0 shells", UDim2.fromOffset(14, 9), UDim2.fromOffset(132, 27), 22, amber)
	local hunts = label(purse, "0 hunts completed", UDim2.fromOffset(14, 41), UDim2.fromOffset(132, 18), 11)

	local health = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -23), Size = UDim2.fromOffset(220, 14), BackgroundColor3 = ink, BorderSizePixel = 0 }, gui)
	round(health, 7)
	local healthFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = mint, BorderSizePixel = 0 }, health)
	round(healthFill, 7)
	local healthText = label(gui, "100 / 100", UDim2.new(0.5, -50, 1, -60), UDim2.fromOffset(100, 22), 13)
	healthText.TextXAlignment = Enum.TextXAlignment.Center
	local healthConnection
	local function watchCharacter(character)
		if healthConnection then
			healthConnection:Disconnect()
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if destroyed or not humanoid then return end
		local function changed()
			local fraction = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
			TweenService:Create(healthFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(fraction, 1) }):Play()
			healthText.Text = string.format("%d / %d", humanoid.Health, humanoid.MaxHealth)
		end
		healthConnection = humanoid.HealthChanged:Connect(changed)
		changed()
	end
	local characterConnection = player.CharacterAdded:Connect(watchCharacter)
	if player.Character then task.spawn(watchCharacter, player.Character) end

	local toast = label(gui, "", UDim2.new(0.5, -230, 0, 106), UDim2.fromOffset(460, 48), 16)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.BackgroundColor3 = ink
	toast.BackgroundTransparency = 0.08
	toast.Visible = false
	round(toast, 12)
	local toastVersion = 0
	local function notify(message, success)
		if not message then return end
		toastVersion += 1
		local version = toastVersion
		toast.Text = message
		toast.TextColor3 = if success == false then amber else cream
		toast.Visible = true
		task.delay(3.5, function()
			if version == toastVersion then toast.Visible = false end
		end)
	end

	local petPanel = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 160), Size = UDim2.fromOffset(320, 213), BackgroundColor3 = ink, BorderSizePixel = 0, Visible = false }, gui)
	round(petPanel, 14)
	label(petPanel, "YOUR COMPANIONS", UDim2.fromOffset(16, 10), UDim2.fromOffset(240, 22), 15, mint)
	label(petPanel, "Earn shells from hunts · equal combat strength.", UDim2.fromOffset(16, 36), UDim2.fromOffset(288, 20), 11)
	local petButtons = {}
	for index, pet in catalog do
		label(petPanel, pet.name, UDim2.fromOffset(16, 66 + (index - 1) * 45), UDim2.fromOffset(160, 34), 14)
		petButtons[pet.id] = button(petPanel, tostring(pet.cost) .. " shells", UDim2.fromOffset(182, 65 + (index - 1) * 45), UDim2.fromOffset(122, 34), function()
			if not currentState then return end
			local action = if currentState.owned[pet.id] then "equip" else "unlock"
			command:FireServer(action, pet.id)
		end)
	end
	companionToggle = button(gui, "Companions", UDim2.new(1, -174, 0, 105), UDim2.fromOffset(156, 42), function()
		petPanel.Visible = not petPanel.Visible
	end)

	local lastAttackRequest, attackReadyAt = -math.huge, 0
	local lastBondRequest, bondReadyAt = -math.huge, 0
	local lastDodgeRequest, dodgeReadyAt = -math.huge, 0
	local function focused()
		return destroyed or UserInputService:GetFocusedTextBox() ~= nil
	end
	local function attack()
		if focused() then return end
		local now = os.clock()
		if now < attackReadyAt or now - lastAttackRequest < rules.meleeCooldown then return end
		lastAttackRequest = now
		command:FireServer("attack")
	end
	local function bond()
		if focused() then return end
		local now = os.clock()
		if now < bondReadyAt or now - lastBondRequest < 0.2 then return end
		lastBondRequest = now
		command:FireServer("bond")
	end
	local function dodge()
		if focused() then return end
		local now = os.clock()
		if now < dodgeReadyAt or now - lastDodgeRequest < 0.2 then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then return end
		local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.01 then direction = root.CFrame.LookVector * Vector3.new(1, 0, 1) end
		if direction.Magnitude < 0.01 then return end
		lastDodgeRequest = now
		command:FireServer("dodge", direction.Unit)
	end
	attackButton = button(gui, "STRIKE", UDim2.new(1, -134, 1, if UserInputService.TouchEnabled then -194 else -96), UDim2.fromOffset(116, 66), attack)
	bondButton = button(gui, "BOND", UDim2.new(1, -260, 1, if UserInputService.TouchEnabled then -194 else -96), UDim2.fromOffset(116, 66), bond)
	dodgeButton = button(gui, "DODGE", UDim2.new(1, -134, 1, if UserInputService.TouchEnabled then -276 else -174), UDim2.fromOffset(116, 58), dodge)
	-- Slot 1 is a temporary companion command while class skills are being built.
	-- Empty slots deliberately have no click or key actions.
	hotbar = make("Frame", { Name = "SkillHotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(566, 66), BackgroundTransparency = 1 }, gui)
	local slots = {}
	for index = 1, 8 do
		local slot = make(if index == 1 then "TextButton" else "TextLabel", {
			Name = "SkillSlot" .. tostring(index), Position = UDim2.fromOffset((index - 1) * 72, 0), Size = UDim2.fromOffset(62, 62),
			Text = "", BackgroundColor3 = if index == 1 then ink else Color3.fromRGB(43, 58, 61),
			BackgroundTransparency = if index == 1 then 0.08 else 0.25, BorderSizePixel = 0,
		}, hotbar)
		round(slot, 10)
		label(slot, tostring(index), UDim2.fromOffset(6, 3), UDim2.fromOffset(18, 16), 11, if index == 1 then mint else Color3.fromRGB(160, 170, 171))
		slots[index] = label(slot, if index == 1 then "Bond" else "Unlearned", UDim2.fromOffset(3, 22), UDim2.fromOffset(56, 30), if index == 1 then 13 else 9, if index == 1 then cream else Color3.fromRGB(160, 170, 171))
		if index == 1 then slot.Activated:Connect(bond) end
	end
	refreshCooldowns = function()
		local now = os.clock()
		for _, entry in { { attackButton, attackReadyAt, "STRIKE" }, { bondButton, bondReadyAt, "BOND" }, { dodgeButton, dodgeReadyAt, "DODGE" } } do
			local remaining = math.max(0, entry[2] - now)
			entry[1].Text = if remaining > 0 then string.format("%s %.1f", entry[3], remaining) else entry[3]
			entry[1].BackgroundColor3 = if remaining > 0 then amber else mint
		end
		local remaining = math.max(0, bondReadyAt - now)
		slots[1].Text = if remaining > 0 then string.format("Bond\n%.1f", remaining) else "Bond"
	end
	resize()
	local controlsHint = label(gui, "Click / R2 strike · 1 / L2 companion · double Space / B dodge", UDim2.new(0.5, -245, 1, -166), UDim2.fromOffset(490, 20), 10)
	controlsHint.TextXAlignment = Enum.TextXAlignment.Center
	controlsHint.Visible = not UserInputService.TouchEnabled
	local lastSpace = -math.huge
	local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		-- ContextActionService alone owns Space history. Roblox's normal jump
		-- can mark the first tap processed after our action returned Pass.
		if processed or focused() then return end
		if input.KeyCode == Enum.KeyCode.ButtonR2 or input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack()
		elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonL2 then
			bond()
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			dodge()
		elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonY then
			petPanel.Visible = not petPanel.Visible
		end
	end)
	local spaceAction = "WildbondDoubleSpaceDodge"
	ContextActionService:BindActionAtPriority(spaceAction, function(_, state)
		if focused() then
			lastSpace = -math.huge
			return Enum.ContextActionResult.Pass
		end
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		local now = os.clock()
		if now - lastSpace <= (dodgeRules.doubleTapWindow or 0.28) then
			lastSpace = -math.huge
			dodge()
			-- The first tap remains Roblox's normal jump; the second is the dodge.
			return Enum.ContextActionResult.Sink
		end
		lastSpace = now
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space)

	local waypoint = make("Part", { Name = "LocalHuntWaypoint", Size = Vector3.new(1.2, 8, 1.2), Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Material = Enum.Material.Neon, Color = mint, Transparency = 0.65 }, workspace)
	local waypointBillboard = make("BillboardGui", { Size = UDim2.fromOffset(210, 50), StudsOffset = Vector3.new(0, 5, 0), AlwaysOnTop = true, MaxDistance = 400 }, waypoint)
	local waypointText = label(waypointBillboard, "HUNT BOARD", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 16, cream)
	waypointText.TextXAlignment = Enum.TextXAlignment.Center
	waypointText.TextStrokeTransparency = 0.2

	local welcome = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 312), BackgroundColor3 = ink, BorderSizePixel = 0 }, gui)
	welcome.ZIndex = 10
	round(welcome, 18)
	label(welcome, "A woodland trail. A wild bond.", UDim2.fromOffset(26, 23), UDim2.fromOffset(408, 54), 26, mint)
	label(welcome, "Take a hunt at the village board. Click / R2 to strike. Double-tap Space or press B / DODGE to evade. Slot 1 / L2 temporarily commands your companion.\n\nSlots 2–8 await learned class skills. Collect each crystal, then return to camp for 60 shells.", UDim2.fromOffset(26, 87), UDim2.fromOffset(408, 127), 15)
	label(welcome, "Early prototype · progress resets when you leave.\nCompanions share combat strength. No purchases enabled.", UDim2.fromOffset(26, 219), UDim2.fromOffset(408, 37), 11, amber)
	button(welcome, "Explore Greywater Reach", UDim2.fromOffset(26, 266), UDim2.fromOffset(408, 34), function()
		welcome:Destroy()
	end)
	for _, child in welcome:GetDescendants() do
		if child:IsA("GuiObject") then child.ZIndex = 11 end
	end

	local api = {}
	function api:meleeAccepted(cooldown)
		if destroyed then return end
		attackReadyAt = os.clock() + (cooldown or rules.meleeCooldown)
		refreshCooldowns()
	end
	function api:bondAccepted(cooldown)
		if destroyed then return end
		bondReadyAt = os.clock() + (cooldown or rules.petCooldown)
		refreshCooldowns()
	end
	function api:dodgeAccepted(cooldown)
		if destroyed then return end
		dodgeReadyAt = os.clock() + (cooldown or dodgeRules.cooldown)
		refreshCooldowns()
	end
	function api:render(state, message, success)
		if destroyed then return end
		currentState = state
		stateClock = os.clock()
		refreshTiming()
		shells.Text = tostring(state.shells) .. " shells"
		hunts.Text = tostring(state.huntsCompleted) .. " hunts completed"
		local collected = 0
		local nextTarget
		for _, target in targetInfo do
			local done = state.collected[target.id]
			if done then collected += 1 elseif not nextTarget then nextTarget = target end
			rows[target.id].Text = (if done then "✓  " elseif state.defeated[target.id] then "◇  " else "○  ") .. target.title .. (if state.defeated[target.id] and not done then " · collect" else "")
			rows[target.id].TextColor3 = if done then mint else cream
		end
		if not state.active then
			objective.Text = "Take a hunt from the village board."
			waypoint.Position = Vector3.new(0, 10, 15)
			waypointText.Text = "HUNT BOARD"
		elseif collected == 3 then
			objective.Text = "Return to camp · 60 shells waiting."
			waypoint.Position = Vector3.new(12, 10, 15)
			waypointText.Text = "RETURN TO CAMP"
		else
			objective.Text = tostring(collected) .. "/3 crystals · dodge red circles."
			local destination = nextTarget.position
			if not state.defeated[nextTarget.id] then
				for _, foe in rules.foes or {} do
					if foe.id == nextTarget.id then destination = Vector3.new(foe.position.x, foe.position.y, foe.position.z) end
				end
			end
			waypoint.Position = destination + Vector3.new(0, 3, 0)
			waypointText.Text = if state.defeated[nextTarget.id] then "COLLECT CRYSTAL" else nextTarget.title
		end
		for _, pet in catalog do
			petButtons[pet.id].Text = if state.equipped == pet.id then "Equipped" elseif state.owned[pet.id] then "Equip" else tostring(pet.cost) .. " shells"
			petButtons[pet.id].BackgroundColor3 = if state.equipped == pet.id then amber else mint
		end
		notify(message, success)
	end
	function api:destroy()
		if destroyed then return end
		destroyed = true
		toastVersion += 1
		resizeConnection:Disconnect()
		inputConnection:Disconnect()
		ContextActionService:UnbindAction(spaceAction)
		characterConnection:Disconnect()
		if healthConnection then healthConnection:Disconnect() end
		waypoint:Destroy()
		screen:Destroy()
	end
	return api
end

return Hud
