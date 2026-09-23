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
-- it reads well in a tight portrait crop. Its accessories are scaled to match
-- (see buildBust), or the hair sinks into it (#18d).
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

	-- Shoulders for the wider "bust" framing: a Roblox torso in a football
	-- shirt, like the card mockup (assets/ui/cards/card_filled_reference.png):
	-- a torso block, short sleeves with rounded shoulder caps, a crew collar in
	-- the trim colour, bare forearms below. Shirt, Sleeve, Cap and Collar/Cuff
	-- are repainted per headshot (#18e/#19d). Hidden by the tight face camera
	-- in the default framing.
	local function block(name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?, rot: CFrame?)
		local b = Instance.new("Part")
		b.Name = name
		b.Shape = shape or Enum.PartType.Block
		b.Size = size
		b.Color = color
		b.Material = Enum.Material.SmoothPlastic
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CFrame = head.CFrame * CFrame.new(offset) * (rot or CFrame.identity)
		b.Parent = bust
		return b
	end
	local kitPlaceholder = Color3.fromRGB(200, 40, 50)
	local neckY = -0.75 * spec.headScale -- bottom of the rendered head
	local shoulderY = neckY - 0.22 -- top of the shirt
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X
	local alongZ = CFrame.Angles(0, math.rad(90), 0)
	block("Neck", Vector3.new(0.4, 0.62, 0.62), Vector3.new(0, neckY - 0.12, 0), spec.skin, Enum.PartType.Cylinder, upright)
	block("Collar", Vector3.new(0.1, 0.86, 0.86), Vector3.new(0, shoulderY + 0.03, 0), kitPlaceholder, Enum.PartType.Cylinder, upright)
	block("Shirt", Vector3.new(2, 2, 1), Vector3.new(0, shoulderY - 1, 0), kitPlaceholder)
	for _, side in { -1, 1 } do
		local x = side * 1.5
		-- round shoulder cap over a short sleeve, then a cuff and the bare arm
		block("Cap", Vector3.new(1, 1, 1), Vector3.new(x, shoulderY - 0.5, 0), kitPlaceholder, Enum.PartType.Cylinder, alongZ)
		block("Sleeve", Vector3.new(1, 0.5, 1), Vector3.new(x, shoulderY - 0.75, 0), kitPlaceholder)
		block("Cuff", Vector3.new(1.02, 0.12, 1.02), Vector3.new(x, shoulderY - 1.04, 0), kitPlaceholder)
		block("Arm", Vector3.new(0.96, 1, 0.96), Vector3.new(x, shoulderY - 1.6, 0), spec.skin)
	end

	-- Accessories were never welded (the rig is torn down before physics ran),
	-- so place each handle by matching its attachment to the head's. The bust
	-- head renders HEAD_MESH_SCALE past its Size, so it is ~1.27x the rig head
	-- the hair was fitted to: scale every accessory by the same factor about the
	-- head (its size and both attachment offsets), or the hair sinks into the
	-- bigger head and only a sliver shows (#18d).
	local k = head.Size.Y * HEAD_MESH_SCALE / srcHead.Size.Y
	local function grown(cf: CFrame): CFrame
		return (cf - cf.Position) + cf.Position * k
	end
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			local att = handle and handle:FindFirstChildOfClass("Attachment")
			local headAtt = att and srcHead:FindFirstChild(att.Name)
			if handle and handle:IsA("BasePart") and att and headAtt and headAtt:IsA("Attachment") then
				for _, d in handle:GetDescendants() do
					if d:IsA("Weld") or d:IsA("WeldConstraint") then
						d:Destroy()
					elseif d:IsA("SpecialMesh") then
						d.Scale *= k
					end
				end
				handle.Anchored = true
				handle.CanCollide = false
				handle.CanQuery = false
				handle.Size *= k
				handle.CFrame = head.CFrame * grown(headAtt.CFrame) * grown(att.CFrame):Inverse()
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

export type Options = { shoulders: boolean?, keeper: boolean?, trim: Color3?, card: boolean? }

-- Fills `parent` with a headshot. Shows the shirt number on the kit colour
-- until the face is ready (or if it never loads). `opts.shoulders` pulls the
-- camera back to show the kit, for the post-match development cards.
-- `opts.card` is the player-card framing: a wider window, so the camera sits
-- further back and the shirt's shoulders fill it like the card mockup.
-- `opts.trim` colours the collar and cuffs (the club's second colour; a
-- darker kit shade if nil). `opts.keeper` wears Config.KeeperKit instead, with
-- long sleeves, so a goalkeeper is never shown in his teammates' colours
-- (#18e/#19d).
function Headshot.attach(parent: GuiObject, look: number, kit: Color3, number: number, opts: Options?): ViewportFrame
	local card = opts ~= nil and opts.card == true
	local shoulders = card or (opts ~= nil and opts.shoulders == true)
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
		local trimColor = if keeper
			then Config.KeeperKit:Lerp(Color3.new(), 0.45)
			else (opts and opts.trim) or kit:Lerp(Color3.new(), 0.35)
		for _, part in bust:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end
			if part.Name == "Shirt" or part.Name == "Cap" or part.Name == "Sleeve" then
				part.Color = shirtColor
			elseif part.Name == "Collar" or part.Name == "Cuff" then
				part.Color = trimColor
			elseif keeper and part.Name == "Arm" then
				-- long sleeves: the keeper shirt covers the forearm too
				part.Color = shirtColor
			end
		end
		bust.Parent = vf
		local cam = Instance.new("Camera")
		cam.FieldOfView = 28
		-- the face decal is on the head's Front (-Z), so the camera sits on -Z
		if card then
			cam.CFrame = CFrame.lookAt(Vector3.new(-0.2, 0.2, -8.4), Vector3.new(0, -0.62, 0))
		elseif shoulders then
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
