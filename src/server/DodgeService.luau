--!nonstrict
-- Server-owned horizontal movement, collision checks and a short evade window.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Wildbond"):WaitForChild("DodgeRules"))

local DodgeService = {}

function DodgeService.start()
	local active, lastDodge = {}, {}
	local destroyed = false
	local function finish(player)
		local dash = active[player]
		if not dash then return end
		active[player] = nil
		dash.character:SetAttribute("DodgeUntil", 0)
		if dash.humanoid.Parent then
			dash.humanoid.WalkSpeed = dash.walkSpeed
			dash.humanoid.AutoRotate = dash.autoRotate
		end
		if dash.root.Parent then
			pcall(function()
				if dash.wasAutomatic then dash.root:SetNetworkOwnershipAuto()
				else dash.root:SetNetworkOwner(dash.owner) end
			end)
		end
	end
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		for player, dash in active do
			if player.Parent ~= Players or player.Character ~= dash.character or not dash.root.Parent or dash.humanoid.Health <= 0 then
				finish(player)
				continue
			end
			local delta = math.min(dt, math.max(0, dash.endsAt - dash.lastStep))
			if now >= dash.endsAt then
				-- Do not stretch a dash over a stalled server frame.
				delta = math.min(delta, math.max(0, dash.endsAt - dash.lastStep))
			end
			local step = math.min(Rules.distance - dash.travelled, Rules.distance / Rules.duration * delta)
			local position = dash.root.Position
			local blocked = false
			for _, height in { -1.5, 0, 1.5 } do
				if Workspace:Raycast(position + Vector3.new(0, height, 0), dash.direction * (step + Rules.collisionMargin), dash.parameters) then
					blocked = true
					break
				end
			end
			local nextPosition = position + dash.direction * step
			local floor = Workspace:Raycast(nextPosition + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), dash.parameters)
			if blocked or not floor or floor.Normal.Y < 0.55 or floor.Position.Y < position.Y - 12 then
				finish(player)
				continue
			end
			dash.root.CFrame += dash.direction * step
			dash.travelled += step
			dash.lastStep = math.min(now, dash.endsAt)
			if now >= dash.endsAt or dash.travelled >= Rules.distance then finish(player) end
		end
	end)
	local leaving = Players.PlayerRemoving:Connect(function(player)
		finish(player)
		lastDodge[player] = nil
	end)
	local service = {}
	function service.dodge(player, requestedDirection)
		if destroyed then return false, "Dodge is unavailable." end
		if player.Parent ~= Players or typeof(requestedDirection) ~= "Vector3" then return false, "Invalid dodge." end
		local direction = Rules.direction({ x = requestedDirection.X, y = requestedDirection.Y, z = requestedDirection.Z })
		if not direction then return false, "Invalid dodge direction." end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
			return false, "Wait until your character is ready."
		end
		local now = Workspace:GetServerTimeNow()
		if active[player] or not Rules.ready(now, lastDodge[player]) then return false, "Your dodge is recovering." end
		local wasAutomatic, owner
		local acquired = pcall(function()
			wasAutomatic = root:GetNetworkOwnershipAuto()
			owner = root:GetNetworkOwner()
			root:SetNetworkOwner(nil)
		end)
		if not acquired then return false, "Your character cannot dodge yet." end
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = { character }
		parameters.RespectCanCollide = true
		local vector = Vector3.new(direction.x, 0, direction.z)
		active[player] = {
			character = character, root = root, humanoid = humanoid, direction = vector,
			parameters = parameters, endsAt = now + Rules.duration, lastStep = now, travelled = 0,
			walkSpeed = humanoid.WalkSpeed, autoRotate = humanoid.AutoRotate, wasAutomatic = wasAutomatic, owner = owner,
		}
		lastDodge[player] = now
		humanoid.WalkSpeed, humanoid.AutoRotate = 0, false
		character:SetAttribute("DodgeUntil", now + Rules.invulnerabilityDuration)
		return true, "Dodge!", vector
	end
	function service.destroy()
		if destroyed then return end
		destroyed = true
		heartbeat:Disconnect()
		leaving:Disconnect()
		for player in active do finish(player) end
		table.clear(lastDodge)
	end
	return service
end

return DodgeService
