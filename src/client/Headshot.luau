--!strict
-- Face-only ViewportFrame for a look seed. A rig is built once per seed (same
-- Appearance path as the match rigs) and its head, hair, face and accessories
-- are kept as a small bust that every headshot clones. Cached for the session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Config = require(ReplicatedStorage.Shared.Config)

local Headshot = {}

local cache: { [number]: Model } = {}
local pending: { [number]: boolean } = {}

-- The bust's head is a classic mesh head blown up past the part's own Size so
-- it reads well in a tight portrait crop. Hair/face accessories weld to an
-- attachment whose offset was measured on the *real* rig head (Size only, no
-- extra mesh scale), so that offset has to grow by the same factor or it lands
-- inside the now-bigger head and only the last sliver of the hair pokes out
-- the front (#18d: "hair renders behind the head").
local HEAD_MESH_SCALE = 1.25

local function buildBust(look: number): Model?
	local spec = Appearance.fromSeed(look)
	local desc = Appearance.toDescription(spec)
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	desc:Destroy()
	if not ok then
		return nil
	end
	local srcHead = model:FindFirstChild("Head")
	if not srcHead or not srcHead:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	-- The rig's dynamic head renders untextured white inside a ViewportFrame,
	-- so the bust uses a classic mesh head with the face as a decal instead.
	local bust = Instance.new("Model")
	bust.Name = "Bust"
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2) * spec.headScale
	head.Color = spec.skin
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CFrame = CFrame.identity
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(HEAD_MESH_SCALE, HEAD_MESH_SCALE, HEAD_MESH_SCALE)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	-- a Face asset id does not resolve as a texture, but its thumbnail does
	face.Texture = if spec.face ~= 0
		then ("rbxthumb://type=Asset&id=%d&w=420&h=420"):format(spec.face)
		else "rbxasset://textures/face.png"
	face.Parent = head
	head.Parent = bust
	bust.PrimaryPart = head

	-- Shoulders for the wider "bust" framing: the standard blocky Roblox torso
	-- and square sleeves / upper arms, painted with the kit colour when the
	-- bust is attached. Hidden by the tight face camera in the default framing.
	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?)
		local b = Instance.new("Part")
		b.Name = name
		b.Shape = shape or Enum.PartType.Block
		b.Size = size
		b.Color = color
		b.Material = Enum.Material.SmoothPlastic
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CFrame = head.CFrame * CFrame.new(offset)
		b.Parent = bust
		return b
	end
	local neckY = -0.75 * spec.headScale
	local kitPlaceholder = Color3.fromRGB(200, 40, 50)
	block("Shirt", Vector3.new(1.9, 1.7, 1.0), Vector3.new(0, neckY - 1.0, 0), kitPlaceholder)
	block("Neck", Vector3.new(0.62, 0.3, 0.62), Vector3.new(0, neckY - 0.1, 0), spec.skin)
	-- a V of visible neck breaks up the shirt's flat top edge (#18e/#19d: "flat
	-- grey block shoulders" -- a collar reads as a shirt, not a slab)
	for _, side in { -1, 1 } do
		local collar = block(
			"Collar",
			Vector3.new(0.5, 0.34, 1.02),
			Vector3.new(side * 0.24, neckY - 0.16, 0),
			spec.skin,
			Enum.PartType.Wedge
		)
		collar.Orientation = Vector3.new(0, if side < 0 then 180 else 0, 90)
	end
	for _, side in { -1, 1 } do
		-- a rounded shoulder cap, then the square upper arm below it -- the cap
		-- was a second block and read as a stacked box rather than a shoulder
		block("Sleeve", Vector3.new(0.78, 0.72, 1.0), Vector3.new(side * 1.31, neckY - 0.42, 0), kitPlaceholder, Enum.PartType.Ball)
		block("Arm", Vector3.new(0.72, 1.1, 0.96), Vector3.new(side * 1.31, neckY - 1.36, 0), spec.skin)
	end

	-- Accessories were never welded (the rig is torn down before physics ran),
	-- so place each handle by matching its attachment to the head's. The
	-- attachment offset was measured on the real rig head, which has no extra
	-- mesh scale, so its *position* (not rotation) has to grow by the bust
	-- head's HEAD_MESH_SCALE or it lands inside the bigger mesh and only a
	-- sliver of hair pokes out the front (#18d).
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			local att = handle and handle:FindFirstChildOfClass("Attachment")
			local headAtt = att and srcHead:FindFirstChild(att.Name)
			if handle and handle:IsA("BasePart") and att and headAtt and headAtt:IsA("Attachment") then
				for _, d in handle:GetDescendants() do
					if d:IsA("Weld") or d:IsA("WeldConstraint") then
						d:Destroy()
					end
				end
				handle.Anchored = true
				handle.CanCollide = false
				handle.CanQuery = false
				local scaledAtt = (headAtt.CFrame - headAtt.CFrame.Position) + headAtt.CFrame.Position * HEAD_MESH_SCALE
				handle.CFrame = head.CFrame * scaledAtt * att.CFrame:Inverse()
				handle.Name = child.Name
				handle.Parent = bust
			end
		end
	end
	model:Destroy()
	return bust
end

local function getBust(look: number): Model?
	while pending[look] do
		task.wait(0.1)
	end
	if cache[look] == nil then
		pending[look] = true
		cache[look] = buildBust(look) :: any
		pending[look] = nil
	end
	return cache[look]
end

export type Options = { shoulders: boolean?, keeper: boolean? }

-- Fills `parent` with a headshot. Shows the shirt number on the kit colour
-- until the face is ready (or if it never loads). `opts.shoulders` pulls the
-- camera back to show the kit, for the post-match development cards.
-- `opts.keeper` wears Config.KeeperKit instead, with the arms shirted too
-- (a keeper's long sleeves), so a goalkeeper never gets shown in his
-- teammates' colours (#18e/#19d).
function Headshot.attach(parent: GuiObject, look: number, kit: Color3, number: number, opts: Options?): ViewportFrame
	local shoulders = opts ~= nil and opts.shoulders == true
	local keeper = opts ~= nil and opts.keeper == true
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Headshot"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = kit
	vf.BackgroundTransparency = 0.25
	vf.BorderSizePixel = 0
	-- Studio-portrait lighting: bright warm key from the upper front-left, a
	-- lifted cool ambient so nothing goes muddy, and a navy gradient backdrop
	-- for the card framing.
	vf.Ambient = Color3.fromRGB(178, 182, 198)
	vf.LightColor = Color3.fromRGB(255, 246, 228)
	vf.LightDirection = Vector3.new(-0.45, -0.7, 0.62) -- travels toward +Z, so it lights the -Z face
	if shoulders then
		-- backdrop is a sibling underneath: a UIGradient on the viewport itself
		-- would tint the rendered bust too
		local backdrop = Instance.new("Frame")
		backdrop.Name = "Backdrop"
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3 = Color3.fromRGB(44, 72, 132)
		backdrop.BorderSizePixel = 0
		backdrop.ZIndex = vf.ZIndex
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 74, 92)),
		})
		grad.Parent = backdrop
		backdrop.Parent = parent
		vf.BackgroundTransparency = 1
	end
	vf.Parent = parent

	local fallback = Instance.new("TextLabel")
	fallback.Name = "Number"
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.BackgroundTransparency = 1
	fallback.Font = Enum.Font.GothamBlack
	fallback.TextScaled = true
	fallback.TextColor3 = Color3.new(1, 1, 1)
	fallback.TextStrokeTransparency = 0.6
	fallback.Text = tostring(number)
	fallback.Parent = vf

	task.spawn(function()
		local src = getBust(look)
		if not src or not vf.Parent then
			return
		end
		local bust = src:Clone()
		bust:PivotTo(CFrame.new(0, 0, 0))
		local shirtColor = if keeper then Config.KeeperKit else kit
		for _, part in bust:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end
			if part.Name == "Shirt" or part.Name == "Sleeve" then
				part.Color = shirtColor
			elseif keeper and part.Name == "Arm" then
				-- long sleeves: the keeper shirt covers the forearm too
				part.Color = shirtColor
			end
		end
		bust.Parent = vf
		local cam = Instance.new("Camera")
		cam.FieldOfView = 28
		-- the face decal is on the head's Front (-Z), so the camera sits on -Z
		if shoulders then
			cam.CFrame = CFrame.lookAt(Vector3.new(-0.25, 0.35, -6.3), Vector3.new(0, -0.4, 0))
		else
			cam.CFrame = CFrame.lookAt(Vector3.new(-0.3, 0.55, -3.6), Vector3.new(0, 0.15, 0))
		end
		cam.Parent = vf
		vf.CurrentCamera = cam
		fallback.Visible = false
	end)
	return vf
end

return Headshot
