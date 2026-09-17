--!strict
-- "Welcome to Rivermere" signs where the main roads come into town (backlog
-- X132; RivermereAImap.png: "RIVERMERE — OUR TOWN. OUR GAME." with roads out
-- to Mapleford, Greenbridge and Hollingford). One sign per road, on the
-- incoming driver's left verge (UK), facing them, and a green route sign
-- facing drivers leaving town on the other verge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local GatewayDresser = {}

-- road name, the town it leads to, and the distance back from the road's
-- outer end where the signs stand
GatewayDresser.GATEWAYS = {
	{ road = "Mapleford Road", to = "Mapleford", number = "A417", back = 80 },
	{ road = "Greenbridge Road", to = "Greenbridge", number = "M6", back = 80 },
	{ road = "Hollingford Road", to = "Hollingford", number = "A423", back = 80 },
}
GatewayDresser.VERGE = 6 -- past the pavement's outer edge

export type Gateway = { welcome: CFrame, route: CFrame, to: string, number: string }

local function roadNamed(name: string): TownLayout.Road?
	for _, r in TownLayout.ROADS do
		if r.name == name then
			return r
		end
	end
	return nil
end

-- Pure: sign ground CFrames. The welcome sign's LookVector points at drivers
-- coming in; the route sign's at drivers going out. The road's last point is
-- its outer end.
function GatewayDresser.gateways(): { Gateway }
	local out: { Gateway } = {}
	for _, g in GatewayDresser.GATEWAYS do
		local road = roadNamed(g.road)
		if not road then
			continue
		end
		local n = #road.points
		local far, near = road.points[n], road.points[n - 1]
		local seg = Vector3.new(near.X - far.X, 0, near.Z - far.Z)
		local intoTown = seg.Unit
		local p = Vector3.new(far.X, 0, far.Z) + intoTown * math.min(g.back, seg.Magnitude - 40)
		local left = Vector3.new(intoTown.Z, 0, -intoTown.X) -- UK: incoming drivers' left
		local reach = road.width / 2 + TownLayout.PAVEMENT_WIDTH + GatewayDresser.VERGE
		local welcomeAt = p + left * reach
		local routeAt = p - left * reach - intoTown * 30
		table.insert(out, {
			welcome = CFrame.lookAt(welcomeAt, welcomeAt - intoTown),
			route = CFrame.lookAt(routeAt, routeAt + intoTown),
			to = g.to,
			number = g.number,
		})
	end
	return out
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- each line: { text, height share, colour, font }
local function label(board: BasePart, face: Enum.NormalId, lines: { { any } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.MaxDistance = 300
	gui.Parent = board
	local y = 0.06
	for _, line in lines do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.05, y)
		t.Size = UDim2.fromScale(0.9, line[2])
		t.Font = line[4]
		t.TextScaled = true
		t.TextColor3 = line[3]
		t.Text = line[1]
		t.Parent = gui
		y += line[2] + 0.03
	end
end

function GatewayDresser.build(): string
	local town = workspace:FindFirstChild("Town")
	if not town then
		return "gateways: no town"
	end
	local old = town:FindFirstChild("Gateways")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Gateways"
	root.Parent = town
	local white = Color3.new(1, 1, 1)
	local count = 0
	for _, g in GatewayDresser.gateways() do
		local m = Instance.new("Model")
		m.Name = "Welcome to Rivermere"
		m.Parent = root
		-- welcome board: 16 x 8 on two posts, bottom 3 up
		for _, x in { -6, 6 } do
			part(m, "Post", Vector3.new(0.5, 11, 0.5), g.welcome * CFrame.new(x, 5.5, 0.4), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		end
		local board = part(m, "Board", Vector3.new(16, 8, 0.3), g.welcome * CFrame.new(0, 7, 0), Color3.fromRGB(24, 40, 78))
		label(board, Enum.NormalId.Front, {
			{ "WELCOME TO", 0.14, white, Enum.Font.GothamBold },
			{ "RIVERMERE", 0.3, white, Enum.Font.GothamBlack },
			{ "OUR TOWN. OUR GAME.", 0.14, Color3.fromRGB(236, 196, 40), Enum.Font.GothamBold },
			{ "Please drive carefully", 0.12, white, Enum.Font.Gotham },
		})
		-- green primary-route sign for drivers leaving town
		local r = Instance.new("Model")
		r.Name = "Route sign"
		r.Parent = root
		for _, x in { -3.5, 3.5 } do
			part(r, "Post", Vector3.new(0.4, 8, 0.4), g.route * CFrame.new(x, 4, 0.3), Color3.fromRGB(150, 152, 156), Enum.Material.Metal)
		end
		local green = part(r, "Board", Vector3.new(10, 5, 0.25), g.route * CFrame.new(0, 6, 0), Color3.fromRGB(20, 96, 60))
		label(green, Enum.NormalId.Front, {
			{ "(" .. g.number .. ")", 0.3, Color3.fromRGB(252, 208, 40), Enum.Font.GothamBold },
			{ g.to .. "  ↑", 0.4, white, Enum.Font.GothamBold },
		})
		count += 1
	end
	return ("gateways: %d welcome signs"):format(count)
end

return GatewayDresser
