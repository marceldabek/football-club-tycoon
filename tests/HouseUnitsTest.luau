--!strict
-- Shared/HouseUnits is GENERATED from Shared/HouseRecipes by tools/kit/make_house_units.py, and
-- the merged meshes it names are uploaded assets. These tests catch the two ways they drift
-- apart: a recipe edited without re-running the script, and a kit whose meshes are not the ones
-- the table describes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local HouseRecipes = require(ReplicatedStorage.Shared.HouseRecipes)
local HouseUnits = require(ReplicatedStorage.Shared.HouseUnits)

local tests = {}

-- Same rounding as signature() in make_house_units.py: tenths of a stud, whole degrees.
local function signature(pieces): string
	local function t(v: number): number
		return math.floor(v * 10 + 0.5)
	end
	local parts = {}
	for _, p in pieces do
		table.insert(parts, ("%s@%d,%d,%d,%d,%d,%d"):format(p.piece, t(p.offset.X), t(p.offset.Y), t(p.offset.Z), math.round(p.yaw) % 360, t(p.scale or 1), t(p.stretchX or 1)))
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

local function expected(): { [string]: string }
	local out = {}
	for _, r in HouseRecipes.RECIPES do
		if not r.prefab then
			out[r.id] = signature(HouseRecipes.pieces(r, false))
			if r.kind == "semi" then
				out[r.id .. "_m"] = signature(HouseRecipes.pieces(r, true))
			end
		end
	end
	for _, side in { -1, 1 } do
		for _, windowed in { false, true } do
			local key = ("cap_%s_%s"):format(if windowed then "win" else "plain", if side < 0 then "left" else "right")
			out[key] = signature(HouseRecipes.endCap(side, windowed))
		end
	end
	return out
end

function tests.every_recipe_has_a_unit_built_from_its_current_pieces()
	local want = expected()
	for key, sig in want do
		local unit = HouseUnits.UNITS[key]
		assert(unit, "no merged unit for " .. key .. ": run python tools/kit/make_house_units.py")
		assert(unit.signature == sig, key .. " changed since its unit mesh was built: re-run tools/kit/make_house_units.py and upload")
	end
	for key in HouseUnits.UNITS do
		assert(want[key], "unit " .. key .. " has no recipe any more")
	end
end

function tests.units_are_at_most_three_meshes_inside_the_body()
	local seen = {}
	for key, unit in HouseUnits.UNITS do
		assert(#unit.meshes >= 2 and #unit.meshes <= 3, key .. " has " .. #unit.meshes .. " meshes")
		for _, mesh in unit.meshes do
			assert(not seen[mesh.name], "duplicate mesh name " .. mesh.name)
			seen[mesh.name] = true
			assert(mesh.layer == "masonry" or mesh.layer == "roof" or mesh.layer == "trim", mesh.name .. ": unknown layer")
			assert(mesh.size.X <= HouseRecipes.BODY.X + 1 and mesh.size.Z <= HouseRecipes.BODY.Z + 3, mesh.name .. " is bigger than a body")
			assert(math.abs(mesh.offset.X) <= HouseRecipes.MODULE + 0.5 and mesh.offset.Y >= -0.01, mesh.name .. " sits outside the body")
		end
	end
end

-- The full-width layers of neighbouring units must meet exactly: no gap, no overlap.
function tests.unit_masonry_spans_the_body_exactly()
	for key, unit in HouseUnits.UNITS do
		if key:sub(1, 4) ~= "cap_" then
			local masonry = unit.meshes[1]
			assert(masonry.layer == "masonry")
			-- a semi's chimney stack sits on the party wall and leans 0.1 over it, nothing else may
			local over = masonry.size.X - HouseRecipes.BODY.X
			assert(over > -0.01 and over < 0.25 and math.abs(masonry.offset.X) <= over / 2 + 0.01, key .. ": masonry is not one body wide")
		end
	end
end

function tests.installed_meshes_match_the_table()
	local kit = ServerStorage:FindFirstChild("Kit")
	local meshes = kit and kit:FindFirstChild("Meshes")
	if not meshes or not meshes:FindFirstChild("HOUSE__T01_plain__masonry") then
		return -- a place without the merged units builds houses module by module
	end
	for key, unit in HouseUnits.UNITS do
		for _, mesh in unit.meshes do
			local template = meshes:FindFirstChild(mesh.name)
			assert(template, mesh.name .. " is not installed: run assets/kit/_export/install_house_units.luau")
			local part = if template:IsA("MeshPart") then template else template:FindFirstChildWhichIsA("MeshPart", true)
			assert(part, mesh.name .. " holds no MeshPart")
			assert((part.Size - mesh.size).Magnitude < 0.05, ("%s: installed size %s, table says %s"):format(mesh.name, tostring(part.Size), tostring(mesh.size)))
			assert(not part:FindFirstChildOfClass("SurfaceAppearance"), mesh.name .. ": templates stay untextured, the assembler adds the look")
		end
		local _ = key
	end
	local looks = kit:FindFirstChild("Appearances")
	for _, trim in HouseRecipes.TRIMS do
		for _, name in { "HouseBrick_" .. trim, "HouseSlate_" .. trim } do
			local sa = looks and looks:FindFirstChild(name)
			assert(sa and sa:IsA("SurfaceAppearance") and sa.ColorMap ~= "", name .. " is missing from Kit.Appearances")
		end
	end
end

return tests
