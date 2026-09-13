--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Appearance = require(ReplicatedStorage.Shared.Appearance)

local T = {}

local function inList(list: { number }, v: number): boolean
	if v == 0 then
		return true
	end
	for _, x in list do
		if x == v then
			return true
		end
	end
	return false
end

function T.deterministicAndInRange()
	for seed = 1, 200 do
		local a, b = Appearance.fromSeed(seed), Appearance.fromSeed(seed)
		assert(a.hair == b.hair and a.face == b.face and a.heightScale == b.heightScale, "not deterministic")
		assert(a.heightScale >= 0.92 and a.heightScale <= 1.08, "height out of range")
		assert(a.widthScale >= 0.9 and a.widthScale <= 1.1, "width out of range")
		assert(inList(Appearance.HAIR, a.hair), "unknown hair id")
		assert(inList(Appearance.FACES, a.face), "unknown face id")
		assert(inList(Appearance.SHADES, a.shades), "unknown shades id")
		assert(inList(Appearance.HEADBANDS, a.headband), "unknown headband id")
	end
end

function T.seedsVary()
	local hairs, skins = {}, {}
	for seed = 1, 60 do
		local look = Appearance.fromSeed(seed)
		hairs[look.hair] = true
		skins[look.skin] = true
	end
	local n = 0
	for _ in hairs do
		n += 1
	end
	assert(n >= 4, "too little hair variety: " .. n)
	local s = 0
	for _ in skins do
		s += 1
	end
	assert(s >= 4, "too little skin variety: " .. s)
end

function T.descriptionCarriesLook()
	local look = Appearance.fromSeed(5)
	local d = Appearance.toDescription(look)
	assert(math.abs(d.HeightScale - look.heightScale) < 1e-6, "scale not applied")
	assert(d.HeadColor == look.skin, "skin not applied")
	assert(d.Face == look.face, "face not applied")
	if look.hair ~= 0 then
		assert(d.HairAccessory == tostring(look.hair), "hair not applied")
	end
	d:Destroy()
end

function T.applyKitPaintsParts()
	local model = Instance.new("Model")
	for _, n in { "UpperTorso", "LowerTorso", "LeftLowerLeg", "LeftFoot", "LeftLowerArm" } do
		local p = Instance.new("Part")
		p.Name = n
		p.Parent = model
	end
	local look = Appearance.fromSeed(9)
	local shirt, shorts, socks = Color3.new(1, 0, 0), Color3.new(0, 0, 1), Color3.new(0, 1, 0)
	Appearance.applyKit(model, look, shirt, shorts, socks)
	assert((model.UpperTorso :: Part).Color == shirt, "shirt not painted")
	assert((model.LowerTorso :: Part).Color == shorts, "shorts not painted")
	assert((model.LeftLowerLeg :: Part).Color == socks, "socks not painted")
	assert((model.LeftFoot :: Part).Color == look.boots, "boots not painted")
	assert((model.LeftLowerArm :: Part).Color == look.skin, "sleeves should be skin")
	model:Destroy()
end

return T
