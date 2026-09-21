--!strict
-- Crest builder: specs are always valid, colours come from the palette, every
-- option has an uploaded layer, and drawing / repainting work in place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubCrest = require(ReplicatedStorage.Shared.ClubCrest)
local CrestImages = require(ReplicatedStorage.Shared.CrestImages) :: any
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

-- Part.Color is stored at 8 bits a channel, so a lerped colour comes back rounded
local function near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

local function valid(spec: ClubCrest.Spec): boolean
	local _, changed = ClubCrest.normalize(spec)
	return not changed
end

function T.defaultIsTheOldRedAndWhite()
	local d = ClubCrest.default()
	assert(valid(d), "default is valid")
	local kit, accent = ClubCrest.colours(d)
	assert(kit == Config.HomeKit, "default kit is the old home red")
	assert(accent == Color3.fromRGB(245, 245, 245), "default accent is the old white")
end

function T.normalizeFallsBackFieldByField()
	local spec, changed = ClubCrest.normalize({ shape = "square", pattern = 7, emblem = "lion", main = "sky", second = "pink" })
	assert(changed, "junk is a change")
	assert(spec.shape == "square" and spec.emblem == "lion" and spec.main == "sky", "good fields kept")
	assert(spec.pattern == "plain", "bad pattern -> default")
	assert(spec.second == "white", "bad colour -> default")
	local same = ClubCrest.normalize({ shape = "round", pattern = "plain", emblem = "star", main = "gold", second = "gold" })
	assert(same.main == "gold" and same.second == "white", "a clash moves second")
	local white = ClubCrest.normalize({ shape = "round", pattern = "plain", emblem = "star", main = "white", second = "white" })
	assert(white.second == "black", "a white clash goes black")
	assert(ClubCrest.normalize(nil).main == "red", "nil -> default")
	assert(ClubCrest.normalize("x").shape == "classic", "string -> default")
end

function T.randomIsAlwaysValidAndReadable()
	local rng = Random.new(7)
	for _ = 1, 300 do
		local spec = ClubCrest.random(rng)
		assert(valid(spec), "random crest valid: " .. ClubCrest.encode(spec))
		assert(spec.main ~= spec.second, "random colours differ")
	end
end

function T.encodeDecodeRoundTrip()
	local spec = { shape = "pointed", pattern = "stripes", emblem = "oak", main = "claret", second = "sky" }
	local back = ClubCrest.decode(ClubCrest.encode(spec))
	assert(ClubCrest.equal(back, spec), "round trip")
	assert(ClubCrest.equal(ClubCrest.decode("{not json"), ClubCrest.default()), "junk decodes to default")
	assert(ClubCrest.equal(ClubCrest.decode(nil), ClubCrest.default()), "nil decodes to default")
end

function T.everyOptionHasUploadedLayers()
	for _, shape in ClubCrest.SHAPES do
		assert(type(CrestImages["shape_" .. shape]) == "number", "shape layer " .. shape)
		assert(type(CrestImages["rim_" .. shape]) == "number", "rim layer " .. shape)
		for _, pattern in ClubCrest.PATTERNS do
			if pattern ~= "plain" then
				assert(type(CrestImages["pattern_" .. pattern .. "_" .. shape]) == "number", "pattern layer " .. pattern .. "_" .. shape)
			end
		end
	end
	for _, emblem in ClubCrest.EMBLEMS do
		assert(type(CrestImages["emblem_" .. emblem]) == "number", "emblem layer " .. emblem)
		assert(type(CrestImages["halo_" .. emblem]) == "number", "halo layer " .. emblem)
		assert(ClubCrest.LABELS[emblem], "label " .. emblem)
	end
	assert(#ClubCrest.PALETTE == 12, "twelve swatches")
end

function T.drawAndUpdateInPlace()
	local holder = Instance.new("Frame")
	local frame = ClubCrest.draw(holder, ClubCrest.default(), 80)
	local shape = frame:FindFirstChild("Shape") :: ImageLabel
	local pattern = frame:FindFirstChild("Pattern") :: ImageLabel
	assert(shape.ImageColor3 == Config.HomeKit, "shape in the kit colour")
	assert(not pattern.Visible, "plain has no pattern layer")
	local spec = { shape = "round", pattern = "halves", emblem = "crown", main = "navy", second = "gold" }
	ClubCrest.update(frame, spec)
	assert(pattern.Visible and pattern.Image == "rbxassetid://" .. CrestImages.pattern_halves_round, "pattern layer for the shape")
	assert(shape.ImageColor3 == ClubCrest.colour("navy"), "recoloured")
	assert((frame:FindFirstChild("Emblem") :: ImageLabel).ImageColor3 == ClubCrest.colour("gold"), "emblem in the second colour")
	assert((frame:FindFirstChild("Halo") :: ImageLabel).ImageColor3 == ClubCrest.colour("navy"), "halo in the main colour")
	holder:Destroy()
end

function T.paintAndRepaint()
	local root = Instance.new("Model")
	local part = Instance.new("Part")
	part.Parent = root
	local text = Instance.new("TextLabel")
	text.Parent = part
	local d = ClubCrest.default()
	ClubCrest.paint(part, d, "kit", 0.45)
	ClubCrest.paint(text, d, "accent", 0, "TextColor3")
	local badge = ClubCrest.badge(part, d, UDim2.fromOffset(40, 40), UDim2.new())
	assert(near(part.Color, Config.HomeKit:Lerp(Color3.new(0, 0, 0), 0.45)), "darkened kit")
	local spec = { shape = "square", pattern = "plain", emblem = "ball", main = "green", second = "black" }
	local n = ClubCrest.repaint(root, spec)
	assert(n == 3, "three tagged things repainted, got " .. n)
	assert(near(part.Color, ClubCrest.colour("green"):Lerp(Color3.new(0, 0, 0), 0.45)), "part repainted")
	assert(text.TextColor3 == ClubCrest.colour("black"), "text repainted")
	assert((badge:FindFirstChild("Shape") :: ImageLabel).ImageColor3 == ClubCrest.colour("green"), "badge redrawn")
	root:Destroy()
end

-- the player's club colours come from its crest; opponents clear the home kit
function T.configReadsTheCrest()
	local kit = Config.clubCrest("No Such Player Club", true)
	assert(kit == Config.HomeKit, "unknown player club -> default")
	local red = Color3.fromRGB(205, 45, 45)
	local shifted = Config.pitchKit(red, Config.HomeKit)
	assert(shifted ~= red, "a red opponent moves off a red home kit")
	assert(Config.pitchKit(red, ClubCrest.colour("royal")) == red, "but stays red against a blue home kit")
	assert(Config.pitchKit(red, ClubCrest.colour("white")) == red, "and against a white one")
end

return T
