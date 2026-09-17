--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local BridgeDresser = require(ServerScriptService.Server.BridgeDresser)

local T = {}

local function close(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-3
end

function T.archesSplitSpansEvenly()
	local arches = BridgeDresser.arches({ s0 = 10, s1 = 70 }, 24)
	assert(#arches == 3, "60 wide at max 24 -> 3 arches, got " .. #arches)
	assert(math.abs(arches[1].s0 - 10) < 1e-6 and math.abs(arches[3].s1 - 70) < 1e-6, "arches cover the span")
	assert(math.abs(arches[2].s0 - 30) < 1e-6 and math.abs(arches[2].s1 - 50) < 1e-6, "equal widths")
	assert(#BridgeDresser.arches({ s0 = 0, s1 = 24 }, 24) == 1, "exactly max stays one arch")
	assert(#BridgeDresser.arches({ s0 = 0, s1 = 5 }, 24) == 1, "short span is one arch")
end

function T.cutwaterWedgesFormAPointedNose()
	local halfWidth, halfDepth, projection, height = 20, 4, 5, 10
	for _, s in { -1, 1 } do
		for _, t in { -1, 1 } do
			local cf, size = BridgeDresser.cutwater(s, t, halfWidth, halfDepth, projection, height)
			assert(close(size, Vector3.new(height, halfDepth, projection)), "size is (height, halfDepth, projection)")
			local h, l = size.Y, size.Z
			-- WedgePart corners in its own frame: right angle, far end of the -Z leg, top of the +Y leg
			local rightAngle = cf * Vector3.new(0, -h / 2, l / 2)
			local nose = cf * Vector3.new(0, -h / 2, -l / 2)
			local faceCorner = cf * Vector3.new(0, h / 2, l / 2)
			assert(close(rightAngle, Vector3.new(s * halfWidth, 0, 0)), "right angle on the pier end face centre")
			assert(close(nose, Vector3.new(s * (halfWidth + projection), 0, 0)), "nose points away from the pier")
			assert(close(faceCorner, Vector3.new(s * halfWidth, 0, t * halfDepth)), "back edge reaches the pier corner")
			assert(math.abs(math.abs(cf.XVector.Y) - 1) < 1e-6, "extrusion is vertical")
			assert(cf.XVector:Cross(cf.YVector):Dot(cf.ZVector) > 0.99, "right-handed frame")
		end
	end
end

return T
