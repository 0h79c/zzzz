--!strict
local DodgeRules = {
	distance = 16,
	duration = 0.3,
	maxStepDistance = 2,
	invulnerabilityDuration = 0.18,
	cooldown = 4,
	collisionMargin = 1.25,
}

export type Point = { x: number, y: number, z: number }

local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < math.huge
end

function DodgeRules.direction(point: any): Point?
	if typeof(point) ~= "table" or not finite(point.x) or not finite(point.y) or not finite(point.z) then
		return nil
	end
	local length = point.x * point.x + point.z * point.z
	if math.abs(point.y) > 0.15 or length < 0.01 or length > 2.25 then
		return nil
	end
	local scale = math.sqrt(length)
	return { x = point.x / scale, y = 0, z = point.z / scale }
end

function DodgeRules.ready(now: number, previous: number?): boolean
	return finite(now) and (previous == nil or (finite(previous) and now >= previous + DodgeRules.cooldown))
end

return table.freeze(DodgeRules)
