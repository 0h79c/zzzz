-- Executes the actual view with reflected Roblox instances and explicit
-- streaming/clock doubles. Native rendering must still be checked in Studio.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local checks, now = 0, 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = { active = true }
			function connection:Disconnect() self.active = false end
			listeners[connection] = callback
			return connection
		end,
		Fire = function(_, ...)
			for connection, callback in listeners do if connection.active then callback(...) end end
		end,
		Count = function()
			local count = 0
			for connection in listeners do if connection.active then count += 1 end end
			return count
		end,
	}
end
local events = {}
local function event(item, name)
	events[item] = events[item] or {}
	events[item][name] = events[item][name] or signal()
	return events[item][name]
end
for _, name in { "ChildAdded", "ChildRemoved" } do
	roblox.implementProperty("Instance", name, function(item) return event(item, name) end)
end
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(item, name) return event(item, name) end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return now end)
local scene, render = roblox.Instance.new("Workspace"), signal()
local player = { UserId = 7, Character = nil }
local environment = {
	game = { GetService = function(_, name) assert(name == "RunService"); return { RenderStepped = render } end },
	workspace = scene,
}
for _, name in { "Instance", "CFrame", "Vector3", "Color3", "Enum", "UDim2" } do environment[name] = roblox[name] end
local CompanionView = luau.load(fs.readFile("src/client/CompanionView.luau"), { environment = environment, debugName = "CompanionView" })()
local cleanup, strike = CompanionView.start(player)
local container = assert(scene:FindFirstChild("LocalCompanionVisuals"))
local function step(frames, dt)
	for _ = 1, frames do now += dt; render:Fire(dt) end
end
local function moveTo(root, frame)
	root.CFrame, root.Position = frame, frame.Position
end
step(1, 1 / 60)
check(#container:GetChildren() == 0, "No cosmetic pet is invented while server actors are absent")
check(type(strike) == "function", "Legacy Bond effect callback remains API-compatible")

local folder = roblox.Instance.new("Folder")
folder.Name, folder.Parent = "PendingCompanions", scene
scene.ChildAdded:Fire(folder)
local actor = roblox.Instance.new("Model")
actor.Name, actor.Parent = "Companion_7", folder
actor:SetAttribute("OwnerUserId", 7)
folder.ChildAdded:Fire(actor)
check(#container:GetChildren() == 0, "Unrelated folders cannot create local pets")
folder.Name = "WildbondCompanions"
event(folder, "Name"):Fire()
local visual = assert(container:FindFirstChild(actor.Name))
step(1, 1 / 60)
check(visual.Parent == nil, "A streamed model with no PrimaryPart safely hides its pending visual")
local root = roblox.Instance.new("Part")
root.Name, root.Transparency, root.Anchored, root.CanCollide = "Root", 1, true, false
moveTo(root, roblox.CFrame.new(0, 5.35, 0))
root.Parent, actor.PrimaryPart = actor, root
step(1, 1 / 60)
check(visual.Parent == nil, "Root arrival alone does not invent an unknown pet type")
actor:SetAttribute("PetId", "mosswolf")
step(1, 1 / 60)
check(visual.Parent == nil, "Known species arriving before HP does not display an invented living pet")
actor:SetAttribute("Health", 60)
actor:SetAttribute("MaxHealth", 60)
actor:SetAttribute("State", "Follow")
actor:SetAttribute("ActionStartedAt", now)
actor:SetAttribute("ActionDuration", 0)
step(1, 1 / 60)
check(visual.Parent == container and visual:GetAttribute("CosmeticOnly") == true, "Server actor creates a nonauthoritative cosmetic model")
check(visual:GetAttribute("PetId") == "mosswolf" and visual:GetAttribute("OwnerUserId") == 7, "Visual identifies its server pet and owner")
local body = assert(visual:FindFirstChild("Body"))
check((body.CFrame.Position - root.CFrame.Position).Magnitude < 0.001, "Pet body starts at its server actor, even without a player character")
check(visual.PrimaryPart == body, "Body anchors the visual health billboard")
local billboard = assert(visual:FindFirstChild("PetHealth"))
check(billboard.Enabled and billboard.Adornee == body and billboard.MaxDistance == 85, "Owner pet has a health billboard attached to its visual body")
check(billboard.HealthLabel.Text == "Moss Wolf  60 / 60", "Health label uses the server pet's separate HP")
local function assertCosmetic(model)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			check(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch, "Articulation geometry cannot block or participate in combat queries")
		end
	end
end
assertCosmetic(visual)
actor:SetAttribute("Health", 21)
step(1, 1 / 60)
check(billboard.HealthLabel.Text == "Moss Wolf  21 / 60" and math.abs(billboard.HealthBar.Fill.Size.X.Scale - 0.35) < 0.001, "Pet health changes update both text and fill without touching server HP")
actor:SetAttribute("Health", 100)
step(1, 1 / 60)
check(billboard.HealthBar.Fill.Size.X.Scale == 1, "Transient over-max replicated HP cannot overflow the bar")
actor:SetAttribute("Health", 60)
local before = body.CFrame.Position
moveTo(root, roblox.CFrame.new(8, 5.35, 0))
step(1, 1 / 60)
check(body.CFrame.Position.X > before.X and body.CFrame.Position.X < 8, "Server movement is interpolated instead of following a local player offset")
local leg = assert(visual:FindFirstChild("Leg"))
local walkingPose = body.CFrame:ToObjectSpace(leg.CFrame)
step(1, 1 / 60)
check(body.CFrame:ToObjectSpace(leg.CFrame) ~= walkingPose, "Replicated movement produces articulated four-legged gait")
step(90, 1 / 60)
check((body.CFrame.Position - root.CFrame.Position).Magnitude < 0.001, "Visual converges to the authoritative actor position")
local rootFrame = root.CFrame
local function action(state, duration)
	actor:SetAttribute("State", state)
	actor:SetAttribute("ActionStartedAt", now)
	actor:SetAttribute("ActionDuration", duration)
	actor:SetAttribute("AttackTarget", roblox.Vector3.new(8, 5.35, -7))
end
local jaw = assert(visual:FindFirstChild("Jaw"))
local restingJaw = body.CFrame:ToObjectSpace(jaw.CFrame)
action("Attack", 0.6)
step(9, 1 / 60)
check(body.CFrame:ToObjectSpace(jaw.CFrame) ~= restingJaw, "Automatic basic attack opens and articulates the pet jaw without a remote callback")
local windupJaw = body.CFrame:ToObjectSpace(jaw.CFrame)
step(14, 1 / 60)
check(body.CFrame.Position.Y > root.CFrame.Position.Y + 0.1 and body.CFrame.Position.Z < root.CFrame.Position.Z - 0.3, "Basic attack shows a short bite lunge")
check(body.CFrame:ToObjectSpace(jaw.CFrame) ~= windupJaw, "Bite recovers from its drawn-back anticipation pose")
check(root.CFrame == rootFrame and actor:GetAttribute("Health") == 60, "Animation never writes authoritative position or HP")
for _, item in visual:GetChildren() do
	if item.Name == "SkillSpark" then check(item.Transparency == 1, "Normal attack does not display the skill burst") end
end
step(20, 1 / 60)
check((body.CFrame.Position - root.CFrame.Position).Magnitude < 0.001, "An elapsed basic action returns to its actor even if state replication is late")
action("Attack", 0.6)
step(9, 1 / 60)
check(body.CFrame:ToObjectSpace(jaw.CFrame) ~= restingJaw, "Repeated Attack state uses each new server timestamp rather than requiring a state-name change")
action("Skill", 0.8)
step(30, 1 / 60)
check(body.CFrame.Position.Y > root.CFrame.Position.Y + 0.7 and body.CFrame.Position.Z < root.CFrame.Position.Z - 0.9, "Automatic skill has a larger rising pounce than a basic bite")
local visibleSparks = 0
for _, item in visual:GetChildren() do
	if item.Name == "SkillSpark" and item.Transparency < 0.8 then visibleSparks += 1 end
end
check(visibleSparks == 6, "Automatic skill produces a six-part expressive burst from replicated action state")
local duringSkill = body.CFrame
strike(roblox.Vector3.new(-20, 100, -20))
check(body.CFrame == duringSkill and root.CFrame == rootFrame, "Legacy manual callback cannot replace or double-trigger the authoritative action")

-- Switching skin preserves the existing actor's death and health history.
action("Dead", 0.45)
actor:SetAttribute("Health", 0)
step(12, 1 / 60)
check(body.Transparency > 0.3 and body.Transparency < 0.6 and not billboard.Enabled, "Pet death collapses and fades its visual and hides HP")
step(20, 1 / 60)
check(body.Transparency == 1, "Dead pet finishes disappearing")
step(900, 1 / 60)
check(body.Transparency == 1 and actor:GetAttribute("Health") == 0, "Elapsed local time never respawns a pet; only server state can revive it")
actor:SetAttribute("PetId", "emberfox")
step(1, 1 / 60)
body, billboard = visual.Body, visual.PetHealth
check(visual:GetAttribute("PetId") == "emberfox" and visual:FindFirstChild("FoxTailTip") ~= nil, "Server pet type change updates the fox silhouette")
check(body.Transparency == 1 and not billboard.Enabled, "Changing equipped pet does not locally bypass its dead state")
action("Follow", 0)
step(1, 1 / 60)
check(body.Transparency == 1, "Follow arriving before positive HP cannot show a resurrected pet")
actor:SetAttribute("Health", 60)
step(1, 1 / 60)
check(body.Transparency == 0 and billboard.Enabled and billboard.HealthLabel.Text == "Ember Fox  60 / 60", "Positive HP and an alive state restore the pet after server revival")
actor:SetAttribute("PetId", "tidecub")
step(1, 1 / 60)
body, billboard = visual.Body, visual.PetHealth
check(visual.Ear:IsA("Part") and visual.Ear.Shape == roblox.Enum.PartType.Ball and not visual:FindFirstChild("FoxTailTip"), "Cub uses round ears and discards fox-only parts")
check(math.abs(body.Size.Z - 1.6) < 0.001 and billboard.HealthLabel.Text == "Tide Cub  60 / 60", "Cub retains its distinct shorter model and HP label")
actor:SetAttribute("PetId", "unrecognized")
step(1, 1 / 60)
check(visual.Parent == nil, "An unknown replicated species hides rather than inventing a living fallback")
actor:SetAttribute("PetId", "tidecub")
step(1, 1 / 60)
check(visual.Parent == container, "Recognized pet attributes can stream back safely")

root.Parent = nil
step(1, 1 / 60)
check(visual.Parent == nil, "A streamed-out server root hides its visual")
root.Parent = actor
moveTo(root, roblox.CFrame.new(80, 5.35, -50))
step(1, 1 / 60)
check(visual.Parent == container and (body.CFrame.Position - root.CFrame.Position).Magnitude < 0.001, "Returning root snaps to its server location instead of flying across the map")

local other = roblox.Instance.new("Model")
other.Name, other.Parent = "Companion_8", folder
other:SetAttribute("OwnerUserId", 8)
other:SetAttribute("PetId", "mosswolf")
other:SetAttribute("Health", 42)
other:SetAttribute("MaxHealth", 60)
other:SetAttribute("State", "Follow")
local otherRoot = roblox.Instance.new("Part")
otherRoot.Name, otherRoot.Parent = "Root", other
moveTo(otherRoot, roblox.CFrame.new(-20, 5.35, 0))
other.PrimaryPart = otherRoot
folder.ChildAdded:Fire(other)
step(1, 1 / 60)
local otherVisual = assert(container:FindFirstChild(other.Name))
check(#container:GetChildren() == 2 and otherVisual.PetHealth.MaxDistance == 55, "Other players' server pets appear with their own independent HP billboards")
check(otherVisual.PetHealth.HealthLabel.Text == "Moss Wolf  42 / 60", "Remote player's pet reads its own HP")
local oldOtherFrame = otherVisual.Body.CFrame
folder.ChildRemoved:Fire(actor)
actor.Parent = nil
check(#container:GetChildren() == 1 and otherVisual.Body.CFrame == oldOtherFrame, "Removing one pet cleans only its own visual")
actor.Parent = folder
folder.ChildAdded:Fire(actor)
step(1, 1 / 60)
visual = assert(container:FindFirstChild(actor.Name))
check(#container:GetChildren() == 2 and visual.Body.Transparency == 0, "A model reintroduced through streaming gets a fresh visual")
folder.Name = "RetiredCompanions"
event(folder, "Name"):Fire()
check(#container:GetChildren() == 0 and actor.Parent == folder and root.CFrame.Position.X == 80, "Folder rename cleans only local geometry and leaves server actors intact")
folder.Name = "WildbondCompanions"
event(folder, "Name"):Fire()
step(1, 1 / 60)
check(#container:GetChildren() == 2, "Matching folder can reattach after a rename")
folder.Parent = nil
scene.ChildRemoved:Fire(folder)
check(#container:GetChildren() == 0, "Removing the streamed folder detaches every local pet")
folder.Parent = scene
scene.ChildAdded:Fire(folder)
step(1, 1 / 60)
check(#container:GetChildren() == 2, "A streamed folder can return safely")
cleanup()
cleanup()
check(scene:FindFirstChild("LocalCompanionVisuals") == nil and folder.Parent == scene and actor.Parent == folder, "Idempotent cleanup removes only the cosmetic container")
check(render:Count() == 0 and scene.ChildAdded:Count() == 0 and scene.ChildRemoved:Count() == 0, "Cleanup disconnects render and workspace subscriptions")
check(folder.ChildAdded:Count() == 0 and folder.ChildRemoved:Count() == 0 and event(folder, "Name"):Count() == 0, "Cleanup disconnects folder subscriptions")
render:Fire(1 / 60)
folder.ChildAdded:Fire(other)
strike(roblox.Vector3.zero)
check(scene:FindFirstChild("LocalCompanionVisuals") == nil, "Late events and old callbacks cannot revive a stopped view")

local function movementAtRate(fps)
	moveTo(root, roblox.CFrame.new(0, 5.35, 0))
	local stop = CompanionView.start(player)
	step(1, 1 / fps)
	moveTo(root, roblox.CFrame.new(8, 5.35, 0))
	step(fps / 2, 1 / fps)
	local position = scene.LocalCompanionVisuals[actor.Name].Body.CFrame.Position
	stop()
	return position
end
check((movementAtRate(30) - movementAtRate(120)).Magnitude < 0.01, "Server translation smoothing is stable across common display refresh rates")
check(render:Count() == 0 and scene:FindFirstChild("LocalCompanionVisuals") == nil, "Frame-rate cases leave no visuals or event subscriptions")
print("CompanionView: " .. checks .. " checks passed (reflected instances; mocked streaming/clock, no Studio rendering)")
