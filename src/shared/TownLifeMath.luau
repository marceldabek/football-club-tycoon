--!strict
-- Pure maths for TownLife.client.luau (backlog F4.1 wind turbines, H1.1 club
-- banners, G2.1 matchday bunting). Kept separate from the LocalScript so the
-- geometry can be unit tested without building anything in the workspace,
-- same split as StreetDresser.stations / MatchdayRoutes.

local TownLifeMath = {}

export type Station = { position: Vector3, direction: Vector3 }

-- Short label for a club banner: the full name if it's short enough to read
-- on a 1.6-stud-wide panel, otherwise its initials (one letter per word,
-- upper-cased). A name with no word characters at all just comes back as-is.
function TownLifeMath.bannerText(clubName: string): string
	if #clubName <= 12 then
		return clubName
	end
	local initials = {}
	for word in clubName:gmatch("%S+") do
		table.insert(initials, word:sub(1, 1):upper())
	end
	if #initials == 0 then
		return clubName
	end
	return table.concat(initials)
end

-- Points along a polyline every `spacing`, starting half a gap in, carrying
-- the remainder across bends -- the same semantics as StreetDresser.stations,
-- reused here so lamp scans and bunting strings land on the same spots a
-- street's lamps do.
function TownLifeMath.stationsAlong(points: { Vector3 }, spacing: number): { Station }
	local out: { Station } = {}
	local carry = spacing / 2
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length < 1e-6 then
			continue
		end
		local dir = flat / length
		local s = carry
		while s <= length do
			table.insert(out, { position = Vector3.new(a.X, 0, a.Z) + dir * s, direction = dir })
			s += spacing
		end
		carry = s - length
	end
	return out
end

-- A wind turbine blade's world CFrame `angle` radians into its spin: `offset`
-- was captured once as the blade's CFrame relative to an unrotated frame at
-- `hub` (offset = CFrame.new(hub):Inverse() * blade.CFrame at build time), so
-- rotating a fresh frame at `hub` about world X and re-applying that offset
-- spins the blade rigidly about the axis through the hub without needing to
-- touch the blade's own orientation each frame.
function TownLifeMath.bladeCFrame(hub: Vector3, offset: CFrame, angle: number): CFrame
	return CFrame.new(hub) * CFrame.Angles(angle, 0, 0) * offset
end

return TownLifeMath
