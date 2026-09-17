--!strict
-- Pure geometry for the town train (backlog X82): rail-top height along the
-- TownLayout.RAIL polyline (ground bed, viaduct approach ramps, the viaduct
-- deck) and carriage frames for a train whose head is `distance` along it.
-- Heights mirror TownBuilder.buildRail: the flat bed tops out at RAIL_BED
-- (0.6), a span with a rail-bridge end climbs a straight embankment of up to
-- RAMP_MAX (180) studs to the deck at VIADUCT (22), rails add 0.5 on top.

local TownLayout = require(script.Parent.TownLayout)
local TrafficMath = require(script.Parent.TrafficMath)

local TrainMath = {}

TrainMath.BED_TOP = 0.6 + 0.5
TrainMath.DECK_TOP = 22 + 0.5
TrainMath.RAMP_MAX = 180
TrainMath.END_TOLERANCE = 2 -- TownBuilder's railBridgeEnd

local function isBridgeEnd(p: Vector3, bridges: { TownLayout.Bridge }): boolean
	for _, bridge in bridges do
		if bridge.kind == "rail" then
			for _, e in { bridge.from, bridge.to } do
				if Vector3.new(p.X - e.X, 0, p.Z - e.Z).Magnitude <= TrainMath.END_TOLERANCE then
					return true
				end
			end
		end
	end
	return false
end

-- Pure: rail-top height `distance` along `points` (clamped to the line).
function TrainMath.heightAt(points: { Vector3 }, bridges: { TownLayout.Bridge }, distance: number): number
	local remaining = math.max(distance, 0)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
		if remaining <= len or i == #points - 1 then
			local x = math.clamp(remaining, 0, len)
			local aEnd, bEnd = isBridgeEnd(a, bridges), isBridgeEnd(b, bridges)
			local rampLen = math.min(len, TrainMath.RAMP_MAX)
			local rise = TrainMath.DECK_TOP - TrainMath.BED_TOP
			if aEnd and bEnd then
				return TrainMath.DECK_TOP
			elseif bEnd then
				local start = len - rampLen
				return if x <= start then TrainMath.BED_TOP else TrainMath.BED_TOP + rise * (x - start) / rampLen
			elseif aEnd then
				return if x >= rampLen then TrainMath.BED_TOP else TrainMath.DECK_TOP - rise * x / rampLen
			end
			return TrainMath.BED_TOP
		end
		remaining -= len
	end
	return TrainMath.BED_TOP
end

-- Pure: CFrames for `count` carriages `length` long with `gap` between them,
-- the first carriage's leading end at `head`, the train extending back
-- against `direction` (+1 / -1 along the line). Each frame sits on the rail
-- top at the carriage centre, looking from its rear end to its front end
-- (so it pitches on ramps), shifted `lateral` studs to the left of travel.
function TrainMath.carriageFrames(points: { Vector3 }, bridges: { TownLayout.Bridge }, head: number, direction: number, count: number, length: number, gap: number, lateral: number): { CFrame }
	local out = {}
	for k = 0, count - 1 do
		local front = head - direction * k * (length + gap)
		local rear = front - direction * length
		local pf, dirF = TrafficMath.pointAt(points, front)
		local pr = TrafficMath.pointAt(points, rear)
		local travel = dirF * direction
		local side = Vector3.new(-travel.Z, 0, travel.X) * -lateral
		local f = Vector3.new(pf.X, TrainMath.heightAt(points, bridges, front), pf.Z) + side
		local r = Vector3.new(pr.X, TrainMath.heightAt(points, bridges, rear), pr.Z) + side
		if (f - r).Magnitude < 1e-3 then
			f = r + travel
		end
		table.insert(out, CFrame.lookAt((f + r) / 2, f))
	end
	return out
end

return TrainMath
