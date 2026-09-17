--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local KitPlacer = require(ServerScriptService.Server.KitPlacer)

local T = {}

local EPS = 1e-4

local function cframeClose(a: CFrame, b: CFrame, eps: number): boolean
	if (a.Position - b.Position).Magnitude > eps then
		return false
	end
	return (a.XVector - b.XVector).Magnitude < eps and (a.YVector - b.YVector).Magnitude < eps and (a.ZVector - b.ZVector).Magnitude < eps
end

-- ------------------------------------------------------------- pure algebra
-- bottomCentreOffset must satisfy `pivot * offset == bboxCFrame * lower`
-- (where lower drops from the box centre to its bottom) for any pivot,
-- including ones that don't share the box's rotation -- that's the whole
-- point of taking the pivot as an argument instead of assuming it's centred
-- under the box, since kit templates have arbitrary pivots.
local function checkContract(bboxCFrame: CFrame, bboxSize: Vector3, pivot: CFrame)
	local offset = KitPlacer.bottomCentreOffset(bboxCFrame, bboxSize, pivot)
	local expected = bboxCFrame * CFrame.new(0, -bboxSize.Y / 2, 0)
	local actual = pivot * offset
	assert(cframeClose(actual, expected, EPS), ("pivot*offset %s ~= bbox bottom %s"):format(tostring(actual), tostring(expected)))
end

function T.bottomCentreOffsetIdentityPivot()
	checkContract(CFrame.new(2, 5, -3), Vector3.new(2, 10, 4), CFrame.new(0, 0, 0))
end

function T.bottomCentreOffsetOffsetPivot()
	-- pivot sits above the box's own centre and off to the side -- the usual
	-- case for a template whose PrimaryPart isn't at the geometric centre.
	checkContract(CFrame.new(0, 8, 0), Vector3.new(2, 10, 2), CFrame.new(1, 3, -2))
end

function T.bottomCentreOffsetRotatedBbox()
	-- pivot rotated 90 degrees around Y and offset from the box; GetBoundingBox
	-- itself is always world-axis-aligned, so this is the case where the
	-- naive "assume pivot and box share an orientation" shortcut breaks.
	local pivot = CFrame.new(5, 0, 5) * CFrame.Angles(0, math.rad(90), 0)
	checkContract(CFrame.new(5, 4, 5), Vector3.new(2, 8, 6), pivot)

	local pivot2 = CFrame.new(-4, 12, 9) * CFrame.Angles(0, math.rad(37), 0)
	checkContract(CFrame.new(-1, 6, 2), Vector3.new(3, 5, 7), pivot2)
end

-- ---------------------------------------------------------------- fixtures

-- A little two-part "house": Base sits on the ground, Roof is offset up and
-- to the side, so the model's bounding box centre is nowhere near either
-- part and the PrimaryPart (Base) isn't at the bbox centre either -- i.e. an
-- arbitrary pivot, same as a real kit template. Roof carries a Script and a
-- ClickDetector so place() has something to strip.
local function buildFixture(): (Folder, Model)
	local root = Instance.new("Folder")
	root.Name = "KitPlacerTestRoot"

	local template = Instance.new("Model")
	template.Name = "TestProp"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 6, 2)
	base.CFrame = CFrame.new(0, 3, 0) -- bottom at y = 0
	base.Anchored = false
	base.Parent = template

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(2, 2, 2)
	roof.CFrame = CFrame.new(1, 7, 0)
	roof.Anchored = false
	roof.Parent = template

	local leftoverScript = Instance.new("Script")
	leftoverScript.Name = "Leftover"
	leftoverScript.Parent = roof

	local clicker = Instance.new("ClickDetector")
	clicker.Parent = roof

	template.PrimaryPart = base -- pivot = (0, 3, 0), not the bbox centre (0, 4, 0)
	template.Parent = root

	return root, template
end

function T.placeLandsBottomCentreAtTarget()
	local root, template = buildFixture()
	KitPlacer.setLibraryRoot(root)
	local ok, err = pcall(function()
		local target = CFrame.new(50, 10, -20) * CFrame.Angles(0, math.rad(37), 0)
		local model = KitPlacer.place("TestProp", target, workspace)

		local cf, size = model:GetBoundingBox()
		local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
		assert((bottom - target.Position).Magnitude < 0.01, "bottom centre not at target: " .. tostring(bottom))
		assert(model:GetAttribute("Kit") == "TestProp", "Kit attribute not set")

		model:Destroy()
	end)
	KitPlacer.setLibraryRoot(nil)
	root:Destroy()
	assert(ok, err)
end

function T.placeStripsScriptsAndClickDetectorsAndAnchorsParts()
	local root, template = buildFixture()
	KitPlacer.setLibraryRoot(root)
	local ok, err = pcall(function()
		local model = KitPlacer.place("TestProp", CFrame.new(0, 0, 0), workspace)

		local partCount, anchoredCount = 0, 0
		for _, d in model:GetDescendants() do
			assert(not d:IsA("LuaSourceContainer"), "script not stripped: " .. d:GetFullName())
			assert(not d:IsA("ClickDetector"), "click detector not stripped: " .. d:GetFullName())
			if d:IsA("BasePart") then
				partCount += 1
				if d.Anchored then
					anchoredCount += 1
				end
			end
		end
		assert(partCount == 2, "expected 2 parts to survive, got " .. partCount)
		assert(anchoredCount == partCount, "not every part was anchored")

		model:Destroy()
	end)
	KitPlacer.setLibraryRoot(nil)
	root:Destroy()
	assert(ok, err)
end

function T.placeFallsBackWhenTemplateMissing()
	local root = Instance.new("Folder")
	root.Name = "KitPlacerTestRootEmpty"
	KitPlacer.setLibraryRoot(root)
	local ok, err = pcall(function()
		local target = CFrame.new(10, 5, 10)
		local model = KitPlacer.place("DoesNotExist", target, workspace, { fallbackSize = Vector3.new(6, 2, 6) })

		assert(model:GetAttribute("KitMissing") == "DoesNotExist", "KitMissing attribute not set")
		assert(model:GetAttribute("Kit") == "DoesNotExist", "Kit attribute not set")

		local cf, size = model:GetBoundingBox()
		local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
		assert((bottom - target.Position).Magnitude < 0.01, "fallback bottom centre not at target: " .. tostring(bottom))
		assert(size == Vector3.new(6, 2, 6), "fallback did not use fallbackSize")

		model:Destroy()
	end)
	KitPlacer.setLibraryRoot(nil)
	root:Destroy()
	assert(ok, err)
end

function T.footprintMatchesTemplateBoundingBox()
	local root, template = buildFixture()
	KitPlacer.setLibraryRoot(root)
	local ok, err = pcall(function()
		local footprint = KitPlacer.footprint("TestProp")
		assert(footprint ~= nil, "expected a footprint")
		local _, expectedSize = template:GetBoundingBox()
		assert((footprint :: Vector3) == expectedSize, "footprint did not match template bounding box")
		assert(KitPlacer.footprint("DoesNotExist") == nil, "expected nil footprint for missing name")
	end)
	KitPlacer.setLibraryRoot(nil)
	root:Destroy()
	assert(ok, err)
end

function T.rowPlacesCountModelsAlongRightVector()
	local root = buildFixture()
	KitPlacer.setLibraryRoot(root)
	local ok, err = pcall(function()
		local from = CFrame.new(0, 0, 0)
		local models = KitPlacer.row("TestProp", from, 3, 5, workspace)
		assert(#models == 3, "expected 3 models, got " .. #models)
		for i, model in models do
			local cf = model:GetBoundingBox()
			local expectedX = (i - 1) * 5
			assert(math.abs(cf.Position.X - expectedX) < 0.01, ("model %d at wrong X: %f"):format(i, cf.Position.X))
			model:Destroy()
		end
	end)
	KitPlacer.setLibraryRoot(nil)
	root:Destroy()
	assert(ok, err)
end

return T
