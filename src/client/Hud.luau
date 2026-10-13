--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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

function Hud.start(command, catalog, rules)
	rules = rules or { meleeCooldown = 0.6, petCooldown = 3.2 }
	local player = Players.LocalPlayer
	local destroyed = false
	local currentState, stateClock, refreshTiming, refreshCooldowns
	local screen = make("ScreenGui", { Name = "WildbondHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	local gui = make("Frame", { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen)
	local scale = make("UIScale", { Scale = 1 }, gui)
	local attackButton, bondButton
	local function resize()
		local camera = workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(math.min(camera.ViewportSize.X / 850, camera.ViewportSize.Y / 480), 0.5, 1)
			gui.Size = UDim2.fromScale(1 / scale.Scale, 1 / scale.Scale)
			if attackButton and UserInputService.TouchEnabled then
				-- Keep the real pixel gap above Roblox's jump control as the HUD scales.
				local controlTop = -math.round(194 / scale.Scale)
				attackButton.Position = UDim2.new(1, -134, 1, controlTop)
				bondButton.Position = UDim2.new(1, -260, 1, controlTop)
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
	label(mission, "GREYWATER ISLE  /  PVE ALPHA", UDim2.fromOffset(18, 42), UDim2.fromOffset(280, 18), 10)
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
	button(gui, "Companions", UDim2.new(1, -174, 0, 105), UDim2.fromOffset(156, 42), function()
		petPanel.Visible = not petPanel.Visible
	end)

	local lastAttack = -math.huge
	local lastBondRequest, bondReadyAt = -math.huge, 0
	local function attack()
		if os.clock() - lastAttack < rules.meleeCooldown then return end
		lastAttack = os.clock()
		command:FireServer("attack")
	end
	local function bond()
		local now = os.clock()
		if now < bondReadyAt or now - lastBondRequest < 0.2 then return end
		lastBondRequest = now
		command:FireServer("bond")
	end
	attackButton = button(gui, "STRIKE", UDim2.new(1, -134, 1, if UserInputService.TouchEnabled then -194 else -96), UDim2.fromOffset(116, 66), attack)
	bondButton = button(gui, "BOND", UDim2.new(1, -260, 1, if UserInputService.TouchEnabled then -194 else -96), UDim2.fromOffset(116, 66), bond)
	refreshCooldowns = function()
		local now = os.clock()
		for _, entry in { { attackButton, lastAttack + rules.meleeCooldown, "STRIKE" }, { bondButton, bondReadyAt, "BOND" } } do
			local remaining = math.max(0, entry[2] - now)
			entry[1].Text = if remaining > 0 then string.format("%s %.1f", entry[3], remaining) else entry[3]
			entry[1].BackgroundColor3 = if remaining > 0 then amber else mint
		end
	end
	resize()
	label(gui, if UserInputService.TouchEnabled then "STRIKE + BOND · move out of red circles" else "F / R2 strike · Q / L2 bond · E interact", UDim2.new(0.5, -170, 1, -87), UDim2.fromOffset(340, 20), 11).TextXAlignment = Enum.TextXAlignment.Center
	local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 or input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack()
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL2 then
			bond()
		elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonY then
			petPanel.Visible = not petPanel.Visible
		end
	end)

	local waypoint = make("Part", { Name = "LocalHuntWaypoint", Size = Vector3.new(1.2, 8, 1.2), Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Material = Enum.Material.Neon, Color = mint, Transparency = 0.65 }, workspace)
	local waypointBillboard = make("BillboardGui", { Size = UDim2.fromOffset(210, 50), StudsOffset = Vector3.new(0, 5, 0), AlwaysOnTop = true, MaxDistance = 400 }, waypoint)
	local waypointText = label(waypointBillboard, "HUNT BOARD", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 16, cream)
	waypointText.TextXAlignment = Enum.TextXAlignment.Center
	waypointText.TextStrokeTransparency = 0.2

	local welcome = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 312), BackgroundColor3 = ink, BorderSizePixel = 0 }, gui)
	welcome.ZIndex = 10
	round(welcome, 18)
	label(welcome, "A small island. A wild bond.", UDim2.fromOffset(26, 23), UDim2.fromOffset(408, 54), 26, mint)
	label(welcome, "Take a hunt at the village board. Strike nearby guardians and dodge their red circles. Send your companion with Q / L2 or BOND.\n\nHold to collect each crystal (0.35s), then return to camp for 60 shells. Unlock companions with earned shells.", UDim2.fromOffset(26, 87), UDim2.fromOffset(408, 127), 15)
	label(welcome, "Early prototype · progress resets when you leave.\nCompanions share combat strength. No purchases enabled.", UDim2.fromOffset(26, 219), UDim2.fromOffset(408, 37), 11, amber)
	button(welcome, "Explore Greywater", UDim2.fromOffset(26, 266), UDim2.fromOffset(408, 34), function()
		welcome:Destroy()
	end)
	for _, child in welcome:GetDescendants() do
		if child:IsA("GuiObject") then child.ZIndex = 11 end
	end

	local api = {}
	function api:bondAccepted(cooldown)
		if destroyed then return end
		bondReadyAt = os.clock() + (cooldown or rules.petCooldown)
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
		characterConnection:Disconnect()
		if healthConnection then healthConnection:Disconnect() end
		waypoint:Destroy()
		screen:Destroy()
	end
	return api
end

return Hud
