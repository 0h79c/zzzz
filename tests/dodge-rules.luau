local Rules = require("../src/shared/DodgeRules")
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
for _, value in { false, "forward", {}, {x=1,y=math.huge,z=0}, {x=0/0,y=0,z=0}, {x=0,y=0,z=0}, {x=2,y=0,z=0}, {x=0,y=1,z=1} } do
	check(Rules.direction(value) == nil, "Reject malformed, vertical and oversized directions")
end
local direction = Rules.direction({x=0.7,y=0,z=-0.7})
check(direction ~= nil and math.abs(direction.x^2 + direction.z^2 - 1) < 0.001 and direction.y==0, "Normalize diagonal without extra distance")
check(Rules.ready(0,nil), "First dodge available")
check(not Rules.ready(3.99,0), "Cooldown cannot be shortened")
check(Rules.ready(4,0), "Exact cooldown boundary is valid")
check(not Rules.ready(4,5), "Backwards clock not ready")
check(not Rules.ready(math.huge,nil) and not Rules.ready(0/0,nil), "Reject invalid clocks")
check(Rules.invulnerabilityDuration <= Rules.duration and Rules.duration < Rules.cooldown, "Evade window is brief")
print("DodgeRules: " .. tostring(checks) .. " checks passed")
