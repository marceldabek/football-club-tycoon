--!strict
-- Wheels for the town's one-mesh hatchbacks. Each car is a single MeshPart with
-- its wheels baked in, so they cannot turn, and the store orange car's texture
-- paints its wheels orange and black. This lays real wheels over the baked
-- ones: one black cylinder per axle, as wide as the car, so it hides both baked
-- tyres with a single part, and a spoked face on each end of it. Only the four
-- faces need to turn (a spinning plain cylinder looks the same as a still one).
-- 6 parts a car.
--
-- The spoked face is the Fiesta's (Kit.Vehicles.HatchbackWhite, the part named
-- FACE_PART). The server reads it from the kit; ClientKit publishes a copy for
-- client scripts as ReplicatedStorage.ClientKit.WheelFace.

local CarWheels = {}

export type Axle = { z: number, radius: number }
export type Spec = {
	length: number, -- the stored mesh's Size.Z, to read a scaled copy's scale from
	inset: number, -- tyre's outer face in from the mesh's side (negative: proud of it)
	axles: { Axle },
	parked: boolean, -- wheels on parked copies too (the baked ones look wrong standing still)
}

-- Measured in Studio on each unscaled, unrotated mesh (side-on and head-on
-- captures with marker dots): z is along the mesh, radius is the baked tyre's.
CarWheels.SPEC = {
	HatchbackOrange = { length = 19.4, inset = -0.05, parked = true, axles = { { z = -5.85, radius = 2.0 }, { z = 5.8, radius = 1.9 } } },
	HatchbackNavy = { length = 18.04, inset = 0.3, parked = false, axles = { { z = -5.4, radius = 1.65 }, { z = 5.4, radius = 1.65 } } },
	HatchbackRed = { length = 16.3, inset = 0.3, parked = false, axles = { { z = -5.45, radius = 1.6 }, { z = 4.65, radius = 1.6 } } },
	HatchbackSilver = { length = 15.52, inset = 0.3, parked = false, axles = { { z = -5.1, radius = 1.6 }, { z = 4.5, radius = 1.6 } } },
} :: { [string]: Spec }

CarWheels.FACE_KIT = "HatchbackWhite"
CarWheels.FACE_PART = "Meshes/untitled_wheel.001 (4)"
local FACE_OF_TYRE = 0.74 -- the spoked face's diameter as a share of the tyre's
local TYRE_COLOR = Color3.fromRGB(22, 22, 24)

export type Wheel = {
	part: BasePart,
	offset: CFrame, -- from the car mesh's CFrame
	radius: number,
	spins: boolean,
}

local function still(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- The wheels for `mesh` (a copy of kit car `kitName` at any scale), parented to
-- `parent` and not yet placed. Nil when the car has no spec. Without `face`
-- (the FACE_PART template) the car gets its axles alone.
function CarWheels.build(mesh: BasePart, kitName: string, face: BasePart?, parent: Instance): { Wheel }?
	local spec = CarWheels.SPEC[kitName]
	if not spec then
		return nil
	end
	local scale = mesh.Size.Z / spec.length
	local half = mesh.Size.X / 2 - spec.inset * scale
	local wheels: { Wheel } = {}
	for _, axle in spec.axles do
		local radius = axle.radius * scale
		local y = -mesh.Size.Y / 2 + radius
		local z = axle.z * scale
		local tyres = Instance.new("Part")
		tyres.Name = "Tyres"
		tyres.Shape = Enum.PartType.Cylinder
		tyres.Size = Vector3.new(half * 2, radius * 2, radius * 2)
		tyres.Color = TYRE_COLOR
		tyres.Material = Enum.Material.SmoothPlastic
		tyres:SetAttribute("V3Exempt", "EI4") -- docs/TOWN_V3_BUILD.md s7
		still(tyres)
		tyres.Parent = parent
		table.insert(wheels, { part = tyres, offset = CFrame.new(0, y, z), radius = radius, spins = false })
		if face then
			for _, side in { -1, 1 } do
				local copy = face:Clone()
				copy.Name = "WheelFace"
				copy:ClearAllChildren() -- the store car's welds
				copy.Size *= radius * 2 * FACE_OF_TYRE / face.Size.Y
				still(copy)
				copy.Parent = parent
				-- the template's outward side is its -X (it is the Fiesta's front left)
				local x = side * (half + copy.Size.X / 2 - 0.02 * scale)
				local turn = if side == 1 then math.pi else 0
				table.insert(wheels, { part = copy, offset = CFrame.new(x, y, z) * CFrame.Angles(0, turn, 0), radius = radius, spins = true })
			end
		end
	end
	return wheels
end

-- Where a wheel goes on a car whose mesh is at `meshCFrame`, having rolled
-- `angle` radians about the axle.
function CarWheels.cframe(wheel: Wheel, meshCFrame: CFrame, angle: number): CFrame
	if wheel.spins and angle ~= 0 then
		return meshCFrame * CFrame.new(wheel.offset.Position) * CFrame.Angles(angle, 0, 0) * wheel.offset.Rotation
	end
	return meshCFrame * wheel.offset
end

-- A parked car: standing wheels on `model`'s one mesh, if its kit needs them.
function CarWheels.fitParked(model: Model, kitName: string, face: BasePart?)
	local spec = CarWheels.SPEC[kitName]
	if not (spec and spec.parked) then
		return
	end
	local mesh = model:FindFirstChildWhichIsA("BasePart", true)
	if not mesh then
		return
	end
	local wheels = CarWheels.build(mesh, kitName, face, model)
	for _, wheel in wheels or {} do
		wheel.part.CFrame = CarWheels.cframe(wheel, mesh.CFrame, 0)
	end
end

return CarWheels
