-- Exercise the actual local animation module against reflected rigs and joints.
-- Motion quality, Animator ordering and the rendered arc still require Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local checks, now = 0, 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local record = { connected = true, callback = callback }
			table.insert(listeners, record)
			return { Disconnect = function() record.connected = false end }
		end,
		Fire = function(_, ...) for _, record in listeners do if record.connected then record.callback(...) end end end,
		Active = function() local count = 0; for _, record in listeners do if record.connected then count += 1 end end; return count end,
	}
end
local function sameFrame(a, b)
	return (a.Position - b.Position).Magnitude < 0.0001
		and (a.LookVector - b.LookVector).Magnitude < 0.0001 and (a.UpVector - b.UpVector).Magnitude < 0.0001
end
local function rig(r15)
	local character = roblox.Instance.new("Model")
	character.Name = if r15 then "R15Character" else "R6Character"
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Health, humanoid.Parent = 100, character
	local root = roblox.Instance.new("Part")
	root.Name, root.CFrame, root.Parent = "HumanoidRootPart", roblox.CFrame.new(5, 7, 2), character
	root.Position = roblox.Vector3.new(5, 7, 2) -- Lune reflects Position independently of CFrame.
	local torso = roblox.Instance.new("Part")
	torso.Name, torso.Parent = if r15 then "UpperTorso" else "Torso", character
	local shoulder = roblox.Instance.new("Motor6D")
	shoulder.Name, shoulder.Parent = if r15 then "RightShoulder" else "Right Shoulder", torso
	shoulder.Transform = roblox.CFrame.Angles(0.1, 0.2, 0.3)
	local rootJoint = roblox.Instance.new("Motor6D")
	rootJoint.Name, rootJoint.Parent = if r15 then "Root" else "RootJoint", root
	rootJoint.Transform = roblox.CFrame.Angles(0.04, 0.02, 0)
	return character, humanoid, root, shoulder, rootJoint
end
local scene = roblox.Instance.new("Workspace")
local preSimulation, added, removed = signal(), signal(), signal()
local character, humanoid, root, shoulder, rootJoint = rig(false)
character.Parent = scene
local player = { Character = character, CharacterAdded = added, CharacterRemoving = removed }
local environment = {
	game = { GetService = function(_, name) assert(name == "RunService"); return { PreSimulation = preSimulation } end },
	workspace = scene, os = { clock = function() return now end },
}
for _, name in { "Instance", "Vector3", "CFrame", "Color3", "Enum" } do environment[name] = roblox[name] end
local View = luau.load(fs.readFile("src/client/PlayerCombatView.luau"), { environment = environment, debugName = "PlayerCombatView" })()
local cleanup, attackFx, dodgeFx = View.start(player)
local effects = assert(scene:FindFirstChild("LocalPlayerCombatEffects"))
check(effects:GetAttribute("CosmeticOnly") == true and #effects:GetChildren() == 7, "Attack arc is an original seven-part local cosmetic")
for _, shard in effects:GetChildren() do
	check(shard.Anchored and not shard.CanCollide and not shard.CanQuery and not shard.CanTouch and shard.Transparency == 1, "Hidden swing pieces cannot block movement or target queries")
end
local shoulderBase, rootBase, positionBefore = shoulder.Transform, rootJoint.Transform, root.CFrame
preSimulation:Fire()
check(sameFrame(shoulder.Transform, shoulderBase) and sameFrame(rootJoint.Transform, rootBase), "No animation plays before an accepted effect")
attackFx(roblox.Vector3.new(5, 7, -3))
now = 0.06
preSimulation:Fire()
check(not sameFrame(shoulder.Transform, shoulderBase) and not sameFrame(rootJoint.Transform, rootBase), "R6 accepted attack poses the real shoulder and root joint")
check(root.CFrame == positionBefore, "Attack presentation never writes physical character position")
check(effects:GetChildren()[1].Transparency < 1, "Accepted attack renders a subdued swing arc")
local repeatPose = shoulder.Transform
preSimulation:Fire()
check(sameFrame(shoulder.Transform, repeatPose), "Repeated frames do not accumulate additive poses on an unanimated rig")

local animatedShoulder = roblox.CFrame.Angles(-0.3, 0.15, 0.2)
local animatedRoot = roblox.CFrame.Angles(0, 0.12, 0)
shoulder.Transform, rootJoint.Transform = animatedShoulder, animatedRoot
now = 0.12
preSimulation:Fire()
check(not sameFrame(shoulder.Transform, animatedShoulder), "Combat composes over an updated Animate pose")
now = 0.25
preSimulation:Fire()
check(sameFrame(shoulder.Transform, animatedShoulder) and sameFrame(rootJoint.Transform, animatedRoot), "Completed swing restores the latest Animate base pose")
check(effects:GetChildren()[1].Transparency == 1, "Completed attack hides its arc")

now = 0.5
attackFx(roblox.Vector3.new(7, 7, 0))
now = 0.56
preSimulation:Fire()
removed:Fire(character)
check(sameFrame(shoulder.Transform, animatedShoulder) and effects:GetChildren()[1].Transparency == 1, "Respawn cancels and restores the old avatar's pose")
local nextCharacter, nextHumanoid, nextRoot, nextShoulder, nextJoint = rig(true)
nextCharacter.Parent = scene
player.Character = nextCharacter
added:Fire(nextCharacter)
local nextShoulderBase, nextRootBase = nextShoulder.Transform, nextJoint.Transform
now = 0.6
attackFx(roblox.Vector3.new(4, 7, -2))
now = 0.68
preSimulation:Fire()
check(not sameFrame(nextShoulder.Transform, nextShoulderBase), "R15 RightShoulder is discovered after respawn")
now = 0.85
preSimulation:Fire()
check(sameFrame(nextShoulder.Transform, nextShoulderBase), "R15 attack completes without leaving a stuck arm")

local nextPositionBefore = nextRoot.CFrame
dodgeFx(roblox.Vector3.new(1, 0, 0))
now = 0.96
preSimulation:Fire()
check(not sameFrame(nextJoint.Transform, nextRootBase), "Accepted dodge produces a directional body lean")
check(nextRoot.CFrame == nextPositionBefore, "Dodge presentation leaves physical travel to the server")
now = 1.08
preSimulation:Fire()
check(sameFrame(nextJoint.Transform, nextRootBase) and sameFrame(nextShoulder.Transform, nextShoulderBase), "Dodge finishes and restores both joints")
dodgeFx(roblox.Vector3.new(0 / 0, 0, 0))
preSimulation:Fire()
check(sameFrame(nextJoint.Transform, nextRootBase), "Nonfinite cosmetic direction is ignored")
nextHumanoid.Health = 0
attackFx(roblox.Vector3.new(5, 7, -3))
preSimulation:Fire()
check(sameFrame(nextShoulder.Transform, nextShoulderBase), "Dead avatars do not start attack animations")
nextHumanoid.Health = 100
now = 1.2
attackFx(roblox.Vector3.new(5, 7, -3))
now = 1.26
preSimulation:Fire()
cleanup()
cleanup()
check(sameFrame(nextShoulder.Transform, nextShoulderBase) and sameFrame(nextJoint.Transform, nextRootBase), "Cleanup restores any unfinished additive pose")
check(preSimulation.Active() == 0 and added.Active() == 0 and removed.Active() == 0 and scene:FindFirstChild("LocalPlayerCombatEffects") == nil, "Cleanup disconnects all subscriptions and removes cosmetics")
attackFx(roblox.Vector3.new(5, 7, -3))
dodgeFx(roblox.Vector3.new(0, 0, -1))
preSimulation:Fire()
check(sameFrame(nextShoulder.Transform, nextShoulderBase) and sameFrame(nextJoint.Transform, nextRootBase), "Late effects cannot revive a destroyed view")
print("Player combat view: " .. checks .. " actual-module rig, pose composition, lifecycle and cosmetic checks passed; Animator rendering requires Studio")
