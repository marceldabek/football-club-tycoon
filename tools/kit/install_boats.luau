-- EDIT MODE ONLY (command bar / MCP execute_luau). Rebuilds ServerStorage.Kit.Boats
-- from free Creator Store meshes (docs/FREE_ASSETS.md section 16). Rojo can't own
-- these, so re-run this on a fresh place file, then save the place.
--
-- Every template ends up: scripts and sounds stripped, anchored, no collision,
-- bow towards -Z, scaled to `length` studs (or by `scale`), pivot in the plan
-- centre on the waterline (`draft` studs above the lowest point). That is what
-- RiverDresser.buildBoat and ClientKit's Cruiser expect.

-- Sizes were felt out against a standard R15 character (5.2 tall but 4 wide):
-- at true 2.75 studs a metre the cockpits were narrower than the character, so
-- every boat is about 1.35x that, big enough for a character to sit in.
-- name, asset id, yaw (deg) that turns the bow to -Z, length, scale, draft
local BOATS = {
	{ "BoatSailYacht", 13217041580, 0, 38, nil, 7.0 }, -- deep keel; 11.4 wide, the widest a marina berth takes
	{ "BoatLaunch", 15676599201, -90, 32, nil, 1.4 },
	{ "BoatCruiser", 4959431139, 0, 40, nil, 2.8 }, -- 14.7 wide: river moorings only
	{ "BoatRowing", 116487004496295, 0, 16, nil, 1.3 },
	{ "BoatDayBoat", 6954360328, 0, 27, nil, 1.5 },
	-- the kayak mesh lies 33 degrees askew inside its own box, so its bounding
	-- box can't give a length: scale found by eye, about 16 studs long
	{ "BoatKayak", 14477799492, -33, nil, 0.8, 0.5 },
}

local kit = game:GetService("ServerStorage"):FindFirstChild("Kit")
assert(kit, "ServerStorage.Kit is missing")
local old = kit:FindFirstChild("Boats")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Boats"

local report = {}
for _, e in BOATS do
	local name, id, yaw, length, scale, draft = e[1], e[2], e[3], e[4], e[5], e[6]
	local m = Instance.new("Model")
	m.Name = name
	for _, o in game:GetObjects("rbxassetid://" .. id) do
		o.Parent = m
	end
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d.Name == "HumanoidRootPart" then
			d:Destroy()
		end
	end
	local parts = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m:PivotTo(CFrame.new()) -- some models come with a turned pivot
	m:PivotTo(CFrame.Angles(0, math.rad(yaw), 0) * m:GetPivot())
	m.WorldPivot = CFrame.new(m:GetPivot().Position)
	local _, size = m:GetBoundingBox()
	m:ScaleTo(scale or length / size.Z)
	local cf, scaled = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - scaled.Y / 2 + draft, cf.Position.Z)
	m:PivotTo(CFrame.new())
	m:SetAttribute("SourceAssetId", id)
	m.Parent = folder
	table.insert(report, ("%s parts=%d size=%.1f,%.1f,%.1f"):format(name, parts, scaled.X, scaled.Y, scaled.Z))
end
folder.Parent = kit
return table.concat(report, "\n")
