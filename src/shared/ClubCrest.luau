--!strict
-- A player club's crest, built on the found-club card (docs/superpowers/specs/
-- 2026-09-21-crest-builder-design.md): shape, pattern, emblem and two colours.
--
-- The two colours are the club's colours everywhere: kit = main, accent =
-- second. The spec is saved as profile.crest and replicated as a JSON `Crest`
-- attribute on the club's state folder, so anything holding a club name can
-- find its crest (forClub) without threading it through a payload.
--
-- Drawn as stacked tinted ImageLabels (Roblox has no image masks): shape in the
-- main colour, pattern and rim in the second, then the emblem on a halo of the
-- main colour so it still reads where a pattern puts the second colour behind
-- it. Every layer shares one square canvas (tools/make_crest_parts.py), so the
-- stack lines up at any size, in a ScreenGui or a SurfaceGui alike.
--
-- Deliberately requires nothing from Config: Config.clubCrest reads this.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrestImages = require(script.Parent.CrestImages)

local ClubCrest = {}

export type Spec = {
	shape: string,
	pattern: string,
	emblem: string,
	main: string,
	second: string,
}

ClubCrest.SHAPES = { "classic", "round", "square", "pointed" }
ClubCrest.PATTERNS = { "plain", "halves", "stripes", "sash" }
ClubCrest.EMBLEMS = { "castle", "ball", "lion", "waves", "star", "oak", "bridge", "crown" }

-- The fixed palette, in swatch order. `red` is the old Config.HomeKit, so a
-- club that never touches the builder looks exactly as it always did.
ClubCrest.PALETTE = {
	{ key = "red", label = "Red", rgb = { 200, 40, 50 } },
	{ key = "claret", label = "Claret", rgb = { 122, 28, 52 } },
	{ key = "orange", label = "Orange", rgb = { 232, 118, 30 } },
	{ key = "gold", label = "Gold", rgb = { 246, 196, 40 } },
	{ key = "green", label = "Green", rgb = { 30, 140, 70 } },
	{ key = "darkgreen", label = "Bottle", rgb = { 18, 82, 48 } },
	{ key = "sky", label = "Sky", rgb = { 110, 176, 230 } },
	{ key = "royal", label = "Royal", rgb = { 30, 70, 170 } },
	{ key = "navy", label = "Navy", rgb = { 20, 32, 72 } },
	{ key = "purple", label = "Purple", rgb = { 100, 46, 140 } },
	{ key = "black", label = "Black", rgb = { 28, 28, 32 } },
	{ key = "white", label = "White", rgb = { 245, 245, 245 } },
}

ClubCrest.LABELS = {
	classic = "Classic",
	round = "Round",
	square = "Square",
	pointed = "Pointed",
	plain = "Plain",
	halves = "Halves",
	stripes = "Stripes",
	sash = "Sash",
	castle = "Castle",
	ball = "Ball",
	lion = "Lion",
	waves = "Waves",
	star = "Star",
	oak = "Oak",
	bridge = "Bridge",
	crown = "Crown",
} :: { [string]: string }

-- Emblem box per shape: (share of the canvas, vertical centre). Mirrors
-- EMBLEM_BOX in tools/make_crest_parts.py, which renders the preview sheet.
local EMBLEM_BOX: { [string]: { scale: number, y: number } } = {
	classic = { scale = 0.50, y = 0.46 },
	round = { scale = 0.52, y = 0.50 },
	square = { scale = 0.54, y = 0.50 },
	pointed = { scale = 0.46, y = 0.47 },
}

local colourByKey: { [string]: Color3 } = {}
for _, swatch in ClubCrest.PALETTE do
	colourByKey[swatch.key] = Color3.fromRGB(swatch.rgb[1], swatch.rgb[2], swatch.rgb[3])
end

local function member(list: { string }, value: any): boolean
	return type(value) == "string" and table.find(list, value) ~= nil
end

function ClubCrest.default(): Spec
	return { shape = "classic", pattern = "plain", emblem = "castle", main = "red", second = "white" }
end

function ClubCrest.colour(key: string): Color3
	return colourByKey[key] or colourByKey.red
end

-- Anything (a save, a remote argument, a replicated attribute) -> a valid spec,
-- plus whether anything had to change. Bad fields fall back one at a time, so a
-- save with one unknown emblem keeps its colours. Main and second must differ:
-- a clash keeps main and moves second to white (or black on a white club).
function ClubCrest.normalize(raw: any): (Spec, boolean)
	local d = ClubCrest.default()
	if type(raw) ~= "table" then
		return d, raw ~= nil
	end
	local changed = false
	local function pick(field: string, list: { string }): string
		local v = raw[field]
		if member(list, v) then
			return v
		end
		changed = true
		return (d :: any)[field]
	end
	local function swatch(field: string): string
		local v = raw[field]
		if type(v) == "string" and colourByKey[v] then
			return v
		end
		changed = true
		return (d :: any)[field]
	end
	local out: Spec = {
		shape = pick("shape", ClubCrest.SHAPES),
		pattern = pick("pattern", ClubCrest.PATTERNS),
		emblem = pick("emblem", ClubCrest.EMBLEMS),
		main = swatch("main"),
		second = swatch("second"),
	}
	if out.main == out.second then
		out.second = if out.main == "white" then "black" else "white"
		changed = true
	end
	return out, changed
end

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- A random crest whose two colours are far enough apart in brightness to read
-- (no red on claret). Always valid.
function ClubCrest.random(rng: Random?): Spec
	local r = rng or Random.new()
	local function any(list: { string }): string
		return list[r:NextInteger(1, #list)]
	end
	local palette = ClubCrest.PALETTE
	local main = palette[r:NextInteger(1, #palette)].key
	local mainL = luminance(colourByKey[main])
	local seconds = {}
	for _, swatch in palette do
		if math.abs(luminance(colourByKey[swatch.key]) - mainL) >= 0.3 then
			table.insert(seconds, swatch.key)
		end
	end
	local second = if #seconds > 0 then any(seconds) else (if main == "white" then "black" else "white")
	return {
		shape = any(ClubCrest.SHAPES),
		pattern = any(ClubCrest.PATTERNS),
		emblem = any(ClubCrest.EMBLEMS),
		main = main,
		second = second,
	}
end

function ClubCrest.encode(spec: Spec): string
	return HttpService:JSONEncode(spec)
end

-- Never errors: junk decodes to the default.
function ClubCrest.decode(json: any): Spec
	if type(json) ~= "string" or json == "" then
		return ClubCrest.default()
	end
	local ok, raw = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	return (ClubCrest.normalize(if ok then raw else nil))
end

function ClubCrest.equal(a: Spec, b: Spec): boolean
	return a.shape == b.shape and a.pattern == b.pattern and a.emblem == b.emblem and a.main == b.main and a.second == b.second
end

-- kit (main), accent (second)
function ClubCrest.colours(spec: Spec): (Color3, Color3)
	return ClubCrest.colour(spec.main), ClubCrest.colour(spec.second)
end

-- ------------------------------------------------------------ finding a crest

-- The crest on a club state folder (ReplicatedStorage.Clubs.PlotN).
function ClubCrest.forFolder(folder: Instance?): Spec
	return ClubCrest.decode(folder and folder:GetAttribute("Crest"))
end

local function clubFolders(): { Instance }
	local out = {}
	local clubs = ReplicatedStorage:FindFirstChild("Clubs")
	if clubs then
		for _, f in clubs:GetChildren() do
			table.insert(out, f)
		end
	end
	local legacy = ReplicatedStorage:FindFirstChild("ClubState")
	if legacy then
		table.insert(out, legacy)
	end
	return out
end

-- The crest of the player club called `name`, or the default for a name no
-- plot holds (a club that just left, or a test).
function ClubCrest.forClub(name: string?): Spec
	if name and name ~= "" then
		for _, folder in clubFolders() do
			if folder:GetAttribute("ClubName") == name then
				return ClubCrest.forFolder(folder)
			end
		end
	end
	return ClubCrest.default()
end

-- Client only: the viewing player's own club (their ClubPlot), else the old
-- single ClubState, else nil. The server has no "own club" and gets nil.
function ClubCrest.localFolder(): Instance?
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local plot = player:GetAttribute("ClubPlot")
	if type(plot) == "number" then
		local clubs = ReplicatedStorage:FindFirstChild("Clubs")
		return clubs and clubs:FindFirstChild("Plot" .. plot)
	end
	return ReplicatedStorage:FindFirstChild("ClubState")
end

-- Client: the viewing player's club colours (kit, accent). Default before a plot.
function ClubCrest.localColours(): (Color3, Color3)
	return ClubCrest.colours(ClubCrest.forFolder(ClubCrest.localFolder()))
end

-- ------------------------------------------------------------------- drawing

local LAYERS = { "Shape", "Pattern", "Rim", "Halo", "Emblem" }

local function image(stem: string): string
	local id = (CrestImages :: any)[stem]
	return if id then "rbxassetid://" .. id else ""
end

-- Point an existing crest frame (from draw) at `spec`.
function ClubCrest.update(frame: Instance, spec: Spec)
	local main, second = ClubCrest.colours(spec)
	local box = EMBLEM_BOX[spec.shape] or EMBLEM_BOX.classic
	local layers: { [string]: ImageLabel } = {}
	for _, name in LAYERS do
		local label = frame:FindFirstChild(name)
		if label and label:IsA("ImageLabel") then
			layers[name] = label
		end
	end
	if layers.Shape then
		layers.Shape.Image = image("shape_" .. spec.shape)
		layers.Shape.ImageColor3 = main
	end
	if layers.Pattern then
		layers.Pattern.Visible = spec.pattern ~= "plain"
		layers.Pattern.Image = if spec.pattern ~= "plain" then image("pattern_" .. spec.pattern .. "_" .. spec.shape) else ""
		layers.Pattern.ImageColor3 = second
	end
	if layers.Rim then
		layers.Rim.Image = image("rim_" .. spec.shape)
		layers.Rim.ImageColor3 = second
	end
	for _, name in { "Halo", "Emblem" } do
		local label = layers[name]
		if label then
			label.Image = image((if name == "Halo" then "halo_" else "emblem_") .. spec.emblem)
			label.ImageColor3 = if name == "Halo" then main else second
			label.Size = UDim2.fromScale(box.scale, box.scale)
			label.Position = UDim2.fromScale(0.5, box.y)
		end
	end
end

export type DrawOptions = {
	name: string?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
}

-- A crest for `spec` in `parent`. `size` is pixels (a square) or a UDim2; the
-- frame keeps itself square either way, so a UDim2 sized by height works on
-- a SurfaceGui sign.
function ClubCrest.draw(parent: Instance, spec: Spec, size: number | UDim2, options: DrawOptions?): Frame
	local opts = options or {}
	local frame = Instance.new("Frame")
	frame.Name = opts.name or "ClubCrest"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = if typeof(size) == "UDim2" then size else UDim2.fromOffset(size :: number, size :: number)
	frame.Position = opts.position or UDim2.new()
	frame.AnchorPoint = opts.anchorPoint or Vector2.zero
	frame.LayoutOrder = opts.layoutOrder or 0
	local z = opts.zIndex or (if parent:IsA("GuiObject") then parent.ZIndex else 1)
	frame.ZIndex = z
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = frame
	for i, name in LAYERS do
		local label = Instance.new("ImageLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(1, 1)
		label.ScaleType = Enum.ScaleType.Fit
		label.ZIndex = z + i
		label.Parent = frame
	end
	ClubCrest.update(frame, spec)
	frame.Parent = parent
	return frame
end

-- ------------------------------------------------------- world colour repaint

-- Colour `inst` with the club's `role` colour ("kit" or "accent"), `darken`
-- (0..1) towards black (a negative value lightens towards white), and remember
-- all of it so repaint can redo it when the crest changes. `property` defaults
-- to Color on a part and BackgroundColor3 on a GUI object; pass "TextColor3"
-- for club-coloured lettering. Returns `inst` so it can wrap a constructor.
function ClubCrest.paint<T>(inst: T, spec: Spec, role: string, darken: number?, property: string?): T
	local i = inst :: any
	i:SetAttribute("ClubPaint", role)
	i:SetAttribute("ClubPaintDarken", darken or 0)
	if property then
		i:SetAttribute("ClubPaintProperty", property)
	end
	ClubCrest.applyPaint(i, spec)
	return inst
end

function ClubCrest.paintColour(spec: Spec, role: string, darken: number?): Color3
	local kit, accent = ClubCrest.colours(spec)
	local c = if role == "accent" then accent else kit
	if darken and darken > 0 then
		c = c:Lerp(Color3.new(0, 0, 0), darken)
	elseif darken and darken < 0 then
		c = c:Lerp(Color3.new(1, 1, 1), -darken)
	end
	return c
end

function ClubCrest.applyPaint(inst: Instance, spec: Spec)
	local role = inst:GetAttribute("ClubPaint")
	if type(role) ~= "string" then
		return
	end
	local c = ClubCrest.paintColour(spec, role, inst:GetAttribute("ClubPaintDarken") :: number?)
	local property = inst:GetAttribute("ClubPaintProperty")
	if type(property) == "string" then
		(inst :: any)[property] = c
	elseif inst:IsA("BasePart") then
		inst.Color = c
	elseif inst:IsA("GuiObject") then
		inst.BackgroundColor3 = c
	end
end

-- A world crest badge on a SurfaceGui (replaces CrestBadge for the club's own
-- signs). Tagged so repaint redraws it.
function ClubCrest.badge(parent: Instance, spec: Spec, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local frame = ClubCrest.draw(parent, spec, size, {
		name = "CrestBadge",
		position = position,
		anchorPoint = anchor or Vector2.new(0.5, 0.5),
	})
	frame:SetAttribute("ClubCrestBadge", true)
	return frame
end

-- Every painted part and crest badge under `root`, brought up to `spec`.
function ClubCrest.repaint(root: Instance, spec: Spec): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:GetAttribute("ClubPaint") ~= nil then
			ClubCrest.applyPaint(d, spec)
			n += 1
		elseif d:GetAttribute("ClubCrestBadge") then
			ClubCrest.update(d, spec)
			n += 1
		end
	end
	return n
end

return ClubCrest
