--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ViaductDresser = require(ServerScriptService.Server.ViaductDresser)

local T = {}

function T.spansSitBetweenPiers()
	local spans = ViaductDresser.spans(100, { 60, 30 }, 10)
	assert(#spans == 3, "expected 3 spans, got " .. #spans)
	assert(spans[1].s0 == 0 and spans[1].s1 == 25, "first span 0..25")
	assert(spans[2].s0 == 35 and spans[2].s1 == 55, "middle span 35..55")
	assert(spans[3].s0 == 65 and spans[3].s1 == 100, "last span 65..100")
end

function T.archIsHighestAtTheCrown()
	local crown = ViaductDresser.archHeight(0, 30, 9, 6)
	local edge = ViaductDresser.archHeight(15, 30, 9, 6)
	assert(math.abs(crown - 15) < 1e-6, "crown at springing + rise")
	assert(math.abs(edge - 9) < 1e-6, "springs at the pier face")
	assert(ViaductDresser.archHeight(40, 30, 9, 6) == 9, "clamps outside the span")
end

return T
