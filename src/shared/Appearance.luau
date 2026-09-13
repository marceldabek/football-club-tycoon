--!strict
-- Turns a player's look seed into a deterministic appearance and the
-- HumanoidDescription that builds it. Pure apart from creating the
-- description instance. Shared by the match rigs and the lineup headshots.
--
-- Only Roblox-published catalog items are used: free, script-free and
-- loadable from any experience. Ids were verified in Studio with
-- MarketplaceService:GetProductInfo (creator "Roblox") on 2026-09-13.

local Appearance = {}

export type Look = {
	skin: Color3,
	heightScale: number,
	widthScale: number,
	depthScale: number,
	headScale: number,
	hair: number, -- catalog id or 0
	face: number, -- catalog id or 0
	shades: number, -- catalog id or 0 (rare cosmetic)
	headband: number, -- catalog id or 0
	boots: Color3,
}

local SKIN = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(240, 200, 165),
	Color3.fromRGB(225, 180, 140),
	Color3.fromRGB(200, 150, 110),
	Color3.fromRGB(165, 115, 80),
	Color3.fromRGB(130, 85, 55),
	Color3.fromRGB(95, 60, 40),
	Color3.fromRGB(70, 45, 30),
}

-- TEMP curated lists. Add more ids here; each must be a Roblox-made item.
Appearance.HAIR = {
	13745548, -- Cinnamon Hair
	14815761, -- Black and Red
	16630147, -- Beautiful Hair for Beautiful People
	376524487, -- Blonde Spiked Hair
	62234425, -- Brown Hair
	63690008, -- Pal Hair
	13476917, -- Golden Hair
	376526888, -- Straight Blonde Hair
	376548738, -- Brown Charmer Hair
	451221329, -- True Blue Hair
	7193454569, -- Braided Hair - Black
	9244148336, -- Braided Hair - Blonde
	9244150641, -- Braided Hair - Cool Brown
	7193455510, -- Braided Hair - Red
}
Appearance.FACES = {
	10907541, -- Mr. Chuckles
	7074729, -- Glee
	20418658, -- Err...
	21635565, -- Heeeeeey...
	15432080, -- :3
	7075469, -- :-/
	8560971, -- Stare
	20722130, -- Shiny Teeth
	26019070, -- Yum!
}
Appearance.SHADES = {
	376527500, -- Orange Shades
	376526673, -- Stylish Aviators
	30331986, -- Midnight Shades
}
Appearance.HEADBANDS = {
	1286495, -- Buildermaster Headband
	128208025, -- Ultimate Victory Headband
}
local BOOTS = {
	Color3.fromRGB(20, 20, 20),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(255, 90, 30),
	Color3.fromRGB(40, 200, 120),
	Color3.fromRGB(60, 120, 255),
	Color3.fromRGB(255, 220, 40),
}

-- TEMP odds
local HAIR_CHANCE = 0.9
local SHADES_CHANCE = 0.04
local HEADBAND_CHANCE = 0.1

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function maybe(rng: Random, list: { number }, chance: number): number
	local roll = rng:NextNumber() -- always consumed, so odds tweaks do not reshuffle later fields
	if #list == 0 or roll > chance then
		return 0
	end
	return pick(rng, list)
end

function Appearance.fromSeed(seed: number): Look
	local rng = Random.new(seed)
	return {
		skin = pick(rng, SKIN),
		heightScale = rng:NextNumber(0.92, 1.08),
		widthScale = rng:NextNumber(0.9, 1.1),
		depthScale = rng:NextNumber(0.95, 1.05),
		headScale = rng:NextNumber(0.95, 1.05),
		hair = maybe(rng, Appearance.HAIR, HAIR_CHANCE),
		face = if #Appearance.FACES > 0 then pick(rng, Appearance.FACES) else 0,
		shades = maybe(rng, Appearance.SHADES, SHADES_CHANCE),
		headband = maybe(rng, Appearance.HEADBANDS, HEADBAND_CHANCE),
		boots = pick(rng, BOOTS),
	}
end

function Appearance.toDescription(look: Look): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = look.skin
	d.TorsoColor = look.skin
	d.LeftArmColor = look.skin
	d.RightArmColor = look.skin
	d.LeftLegColor = look.skin
	d.RightLegColor = look.skin
	d.HeightScale = look.heightScale
	d.WidthScale = look.widthScale
	d.DepthScale = look.depthScale
	d.HeadScale = look.headScale
	d.HairAccessory = if look.hair ~= 0 then tostring(look.hair) else ""
	d.Face = look.face
	d.FaceAccessory = if look.shades ~= 0 then tostring(look.shades) else ""
	d.HatAccessory = if look.headband ~= 0 then tostring(look.headband) else ""
	return d
end

local SHIRT = { "UpperTorso", "LeftUpperArm", "RightUpperArm" }
local SLEEVES = { "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand" } -- skin: short sleeves
local SHORTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }
local SOCKS = { "LeftLowerLeg", "RightLowerLeg" }
local FEET = { "LeftFoot", "RightFoot" }

local function paint(model: Model, names: { string }, color: Color3)
	for _, n in names do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

-- Colours the R15 body parts as a kit. Sleeves and hands stay skin.
function Appearance.applyKit(model: Model, look: Look, shirt: Color3, shorts: Color3, socks: Color3)
	paint(model, SHIRT, shirt)
	paint(model, SLEEVES, look.skin)
	paint(model, SHORTS, shorts)
	paint(model, SOCKS, socks)
	paint(model, FEET, look.boots)
end

return Appearance
