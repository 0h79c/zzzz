-- Executes the real service with reflected character Instances. Rays, signals,
-- clock and network ownership are narrow stubs; Studio physics/networking still
-- need playtesting. Lune does not synchronize Position/CFrame, so ticks do so.
local fs, luau, roblox = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Rules = require("../src/shared/DodgeRules")
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local checks, activeHarness, ownership = 0, nil, {}
local function check(condition, message) assert(condition, message); checks += 1 end
local function near(a, b) return math.abs(a - b) < 0.0001 end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { connected = true }
			function connection:Disconnect() self.connected = false end
			listeners[connection] = callback
			return connection
		end,
		Fire = function(_, ...) for connection, callback in listeners do if connection.connected then callback(...) end end end,
		Count = function() local count = 0; for connection in listeners do if connection.connected then count += 1 end end; return count end,
	}
end
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return activeHarness.now end)
roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction, parameters)
	local h = activeHarness
	check(parameters.RespectCanCollide and parameters.FilterType == roblox.Enum.RaycastFilterType.Exclude,
		"Dodge rays respect solid collisions and exclude the character")
	check(#parameters.FilterDescendantsInstances == 1, "Ray filter must contain exactly the current character")
	if direction.Y < -1 then
		table.insert(h.floorSamples, origin.X)
		if h.noGround or (h.groundLimitX and origin.X >= h.groundLimitX)
			or (h.gapStart and origin.X >= h.gapStart and origin.X <= h.gapEnd) then return nil end
		local floorY = h.floorY or 4
		if floorY > origin.Y or floorY < origin.Y + direction.Y then return nil end
		return { Instance = h.ground, Position = Vector3.new(origin.X, floorY, origin.Z), Normal = h.normal or Vector3.yAxis }
	end
	h.rayHeights[math.round((origin.Y - 7) * 10)] = true
	if not h.wall then return nil end
	local half, center = h.wall.Size / 2, h.wall.Position
	local tmin, tmax = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local low, high = center[axis] - half[axis], center[axis] + half[axis]
		if math.abs(direction[axis]) < 0.000001 then
			if origin[axis] < low or origin[axis] > high then return nil end
		else
			local first, last = (low - origin[axis]) / direction[axis], (high - origin[axis]) / direction[axis]
			if first > last then first, last = last, first end
			tmin, tmax = math.max(tmin, first), math.min(tmax, last)
			if tmin > tmax then return nil end
		end
	end
	return { Instance = h.wall, Position = origin + direction * tmin, Normal = Vector3.new(-1, 0, 0) }
end)
for _, method in { "GetNetworkOwnershipAuto", "GetNetworkOwner", "SetNetworkOwner", "SetNetworkOwnershipAuto" } do
	roblox.implementMethod("BasePart", method, function(root, owner)
		local record = assert(ownership[root], "Unregistered character root")
		if record.fail == method then error("Simulated unavailable network ownership") end
		if method == "GetNetworkOwnershipAuto" then return record.automatic end
		if method == "GetNetworkOwner" then return record.owner end
		if method == "SetNetworkOwner" then record.automatic, record.owner = false, owner
		else record.automatic, record.owner, record.autoRestores = true, nil, record.autoRestores + 1 end
	end)
end
local function harness()
	local h = { now = 0, roots = {}, rayHeights = {}, floorSamples = {} }
	activeHarness = h
	local game = Instance.new("DataModel")
	h.workspace = game:GetService("Workspace")
	h.ground = Instance.new("Part")
	h.ground.Name, h.ground.Size, h.ground.Position, h.ground.Parent = "UnrelatedGround", Vector3.new(100, 1, 100), Vector3.new(0, 3.5, 0), h.workspace
	h.heartbeat, h.removing = signal(), signal()
	h.players = { PlayerRemoving = h.removing }
	function h:player(name, position, automatic)
		local character = Instance.new("Model")
		character.Name, character.Parent = name, self.workspace
		local root = Instance.new("Part")
		root.Name, root.Anchored, root.Parent = "HumanoidRootPart", false, character
		root.Position, root.CFrame = position or Vector3.new(0, 7, 0), CFrame.new(position or Vector3.new(0, 7, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		local humanoid = Instance.new("Humanoid")
		humanoid.Health, humanoid.WalkSpeed, humanoid.AutoRotate, humanoid.Parent = 100, 19, true, character
		local player = { Name = name, Character = character, Parent = self.players }
		ownership[root] = { automatic = automatic ~= false, owner = player, autoRestores = 0 }
		table.insert(self.roots, root)
		return player, root, humanoid
	end
	function h:tick(now, dt)
		self.now = now
		self.heartbeat:Fire(dt)
		for _, root in self.roots do if root.Parent then root.Position = root.CFrame.Position end end
	end
	function h:complete(at) for index = 1, 4 do self:tick(at + index * Rules.duration / 4, Rules.duration / 4) end end
	local token = {}
	local services = {
		Workspace = h.workspace, Players = h.players, RunService = { Heartbeat = h.heartbeat },
		ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function() return token end } end },
	}
	local environment = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		RaycastParams = { new = function() return {} end },
		require = function(request) assert(request == token); return Rules end,
		Vector3 = Vector3, Enum = roblox.Enum,
	}
	h.service = luau.load(fs.readFile("src/server/DodgeService.luau"), { environment = environment, debugName = "DodgeService" })().start()
	return h
end

local h = harness()
local player, root, humanoid = h:player("Invalid")
for _, direction in { true, "forward", {}, Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(2, 0, 0), Vector3.new(0.001, 0, 0), Vector3.new(0 / 0, 0, 1), Vector3.new(math.huge, 0, 0) } do
	check(not h.service.dodge(player, direction), "Malformed or unsafe direction must be rejected")
end
check(not h.service.dodge(player, nil), "Missing direction must be rejected")
humanoid.Health = 0
check(not h.service.dodge(player, Vector3.xAxis), "Dead character cannot dodge")
humanoid.Health, root.Anchored = 100, true
check(not h.service.dodge(player, Vector3.xAxis), "Anchored character cannot dodge")
root.Anchored, player.Parent = false, nil
check(not h.service.dodge(player, Vector3.xAxis), "Disconnected player cannot dodge")
player.Parent = h.players
check(near(humanoid.WalkSpeed, 19) and humanoid.AutoRotate and player.Character:GetAttribute("DodgeUntil") == nil,
	"Rejected inputs do not alter movement or invulnerability")
local ok, _, direction = h.service.dodge(player, Vector3.new(1, 0, 1))
check(ok and near(direction.Magnitude, 1) and direction.Y == 0, "Diagonal direction is normalized by the server")
check(humanoid.WalkSpeed == 0 and not humanoid.AutoRotate and not ownership[root].automatic and ownership[root].owner == nil,
	"Accepted dodge temporarily takes server ownership and disables ordinary steering")
check(near(player.Character:GetAttribute("DodgeUntil"), Rules.invulnerabilityDuration), "Evade window follows the server rule")
check(not h.service.dodge(player, Vector3.xAxis), "One player cannot run overlapping dodges")
h:complete(0)
check(near((root.Position - Vector3.new(0, 7, 0)).Magnitude, Rules.distance) and near(root.Position.Y, 7), "Completed normalized dodge travels the full configured horizontal distance")
check(humanoid.WalkSpeed == 19 and humanoid.AutoRotate and player.Character:GetAttribute("DodgeUntil") == 0,
	"Completion restores movement and clears the evade attribute")
check(ownership[root].automatic and ownership[root].autoRestores == 1, "Originally automatic ownership is restored")
check(h.rayHeights[-15] and h.rayHeights[0] and h.rayHeights[15], "Movement checks three collision heights")
h.now = Rules.cooldown - 0.001
check(not h.service.dodge(player, Vector3.xAxis), "Cooldown rejects immediately before its boundary")
h.now = Rules.cooldown
check(h.service.dodge(player, Vector3.xAxis), "Cooldown accepts at the exact server boundary")
h:complete(Rules.cooldown)
h.service.destroy()

-- Airborne second-tap dodges preserve jump intent and height; manual ownership
-- must return to its prior owner rather than always switching to automatic.
h = harness()
player, root, humanoid = h:player("Airborne", Vector3.new(0, 9, 0), false)
humanoid.Jump, humanoid.AutoRotate, humanoid.WalkSpeed = true, false, 23
root.AssemblyLinearVelocity = Vector3.new(20, 6, -12)
check(h.service.dodge(player, Vector3.xAxis), "An airborne character can dodge without requiring grounded state")
h:complete(0)
check(near(root.Position.X, Rules.distance) and near(root.Position.Y, 9) and humanoid.Jump, "Full-distance dodge preserves airborne height and first jump intent")
check(root.AssemblyLinearVelocity == Vector3.new(0, 6, 0), "Dodge suppresses inherited horizontal momentum while preserving jump velocity; engine integration remains untested")
check(humanoid.WalkSpeed == 23 and not humanoid.AutoRotate and not ownership[root].automatic and ownership[root].owner == player,
	"Completion restores custom movement settings and original manual owner")
h.service.destroy()

for _, unavailable in { "GetNetworkOwnershipAuto", "GetNetworkOwner", "SetNetworkOwner" } do
	h = harness()
	player, root, humanoid = h:player("Capability")
	ownership[root].fail = unavailable
	check(not h.service.dodge(player, Vector3.xAxis), "Missing network ownership capability rejects without crashing: " .. unavailable)
	check(humanoid.WalkSpeed == 19 and humanoid.AutoRotate and player.Character:GetAttribute("DodgeUntil") == nil,
		"Failed acquisition never grants immunity or disables movement")
	ownership[root].fail = nil
	check(h.service.dodge(player, Vector3.xAxis), "A rejected acquisition does not spend cooldown")
	h.service.destroy()
end

for _, height in { -1.5, 0, 1.5 } do
	h = harness()
	player, root, humanoid = h:player("Wall")
	h.wall = Instance.new("Part")
	h.wall.Size, h.wall.Position, h.wall.Parent = Vector3.new(0.5, 0.4, 8), Vector3.new(5, 7 + height, 0), h.workspace
	check(h.service.dodge(player, Vector3.xAxis), "Wall test begins with accepted dodge")
	h:complete(0)
	local wallSurface = h.wall.Position.X - h.wall.Size.X / 2
	check(root.Position.X > 0 and near(wallSurface - root.Position.X, Rules.collisionMargin),
		"Ray at each supported height uses safe partial travel and preserves the full margin before the actual wall surface")
	check(humanoid.WalkSpeed == 19 and player.Character:GetAttribute("DodgeUntil") == 0, "Blocked dodge restores movement immediately")
	h.service.destroy()
end

for _, reason in { "void", "edge", "steep", "drop" } do
	h = harness()
	player, root, humanoid = h:player("Floor")
	if reason == "void" then h.noGround = true
	elseif reason == "edge" then h.groundLimitX = 4
	elseif reason == "steep" then h.normal = Vector3.new(math.sqrt(0.84), 0.4, 0)
	else h.floorY = -7 end
	check(h.service.dodge(player, Vector3.xAxis), "Floor guard test begins with accepted dodge")
	h:complete(0)
	check(if reason == "edge" then root.Position.X > 0 and root.Position.X < h.groundLimitX else near(root.Position.X, 0),
		"Unsafe floor stops movement before crossing: " .. reason)
	check(humanoid.WalkSpeed == 19 and ownership[root].automatic, "Floor rejection restores movement and ownership")
	h.service.destroy()
end

for _, reason in { "death", "respawn" } do
	h = harness()
	player, root, humanoid = h:player("OldLife")
	local oldCharacter = player.Character
	check(h.service.dodge(player, Vector3.xAxis), "Lifecycle test begins active")
	h:tick(0.05, 0.05)
	local before = root.Position
	if reason == "death" then humanoid.Health = 0 else player.Character = h:player("NewLife", Vector3.new(30, 7, 0)).Character end
	h:tick(0.1, 0.05)
	check(root.Position == before and oldCharacter:GetAttribute("DodgeUntil") == 0, "Old-life dash cancels after " .. reason)
	check(humanoid.WalkSpeed == 19 and ownership[root].automatic, "Old-life movement and ownership restore after " .. reason)
	if reason == "respawn" then check(player.Character:GetAttribute("DodgeUntil") == nil, "Old-life immunity cannot attach to a respawn") end
	h.service.destroy()
end

-- Final travel is independent of normal frame rates. Use a partial last frame
-- at the exact deadline, rather than requiring elapsed time to divide evenly.
for _, rate in { 12, 30, 60 } do
	h = harness()
	player, root = h:player("Rate" .. rate)
	check(h.service.dodge(player, Vector3.xAxis), "Frame-rate test starts active")
	local elapsed = 0
	while elapsed < Rules.duration do
		local dt = math.min(1 / rate, Rules.duration - elapsed)
		elapsed += dt
		h:tick(elapsed, dt)
		check(root.Position.X <= Rules.distance + 0.0001, "No frame rate can exceed the configured distance")
	end
	check(near(root.Position.X, Rules.distance) and player.Character:GetAttribute("DodgeUntil") == 0,
		"An unobstructed dodge reaches full distance at " .. rate .. " Hz")
	h.service.destroy()
end

for _, dt in { 0.02, 8 } do
	h = harness()
	player, root = h:player("Stalled")
	check(h.service.dodge(player, Vector3.xAxis), "Coarse clock test starts active")
	h:tick(8, dt)
	check(root.Position.X >= 0 and root.Position.X <= Rules.distance + 0.0001 and player.Character:GetAttribute("DodgeUntil") == 0,
		"A stalled server frame finishes without exceeding the configured distance")
	if dt >= Rules.duration then check(near(root.Position.X, Rules.distance), "A safe coarse frame retains full travel") end
	h.service.destroy()
end

-- Supported start/end points do not permit tunneling across an intervening pit.
h = harness()
player, root, humanoid = h:player("MidpathVoid")
h.gapStart, h.gapEnd = 4, 12
check(Rules.distance > h.gapEnd, "Void regression needs a supported destination beyond the hole")
check(h.service.dodge(player, Vector3.xAxis), "Midpath void test begins active")
h:tick(8, 8)
check(root.Position.X > 0 and root.Position.X < h.gapStart, "Coarse movement samples intervening support and stops before the pit")
check(#h.floorSamples >= 2 and h.floorSamples[#h.floorSamples] >= h.gapStart and h.floorSamples[#h.floorSamples] <= h.gapEnd,
	"Void guard rejects an actual unsupported intermediate sample")
check(humanoid.WalkSpeed == 19 and ownership[root].automatic and player.Character:GetAttribute("DodgeUntil") == 0,
	"A midpath stop restores movement, ownership and immunity bookkeeping")
h.service.destroy()

h = harness()
player, root, humanoid = h:player("Leaving")
local other, otherRoot, otherHumanoid = h:player("Remaining", Vector3.new(0, 7, 20))
check(h.service.dodge(player, Vector3.xAxis) and h.service.dodge(other, Vector3.xAxis), "Different players can dodge independently")
h.removing:Fire(player)
player.Parent = nil
check(humanoid.WalkSpeed == 19 and otherHumanoid.WalkSpeed == 0, "Removing one player restores only that player's dash")
h:tick(Rules.duration / 4, Rules.duration / 4)
check(root.Position.X == 0 and near(otherRoot.Position.X, Rules.distance / 4), "A remaining player continues moving after another leaves")
player.Parent = h.players
check(h.service.dodge(player, Vector3.xAxis), "Removal clears the departing player's cooldown bookkeeping")
h.service.destroy()
check(humanoid.WalkSpeed == 19 and otherHumanoid.WalkSpeed == 19 and ownership[root].automatic and ownership[otherRoot].automatic,
	"Destroy restores every active player's movement and ownership")
check(h.heartbeat:Count() == 0 and h.removing:Count() == 0, "Destroy disconnects both service signals")
check(h.ground.Parent == h.workspace and player.Character.Parent == h.workspace and other.Character.Parent == h.workspace,
	"Service cleanup preserves unrelated world and character Instances")
check(not h.service.dodge(player, Vector3.xAxis), "Destroyed service rejects future actions")
h.service.destroy()
print("DodgeService: " .. checks .. " authority, ray guard, movement, ownership and lifecycle checks passed; Studio physics/networking remain untested")
