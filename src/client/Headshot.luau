--!strict
-- Face-only ViewportFrame for a look seed. A rig is built once per seed (same
-- Appearance path as the match rigs) and its head, hair, face and accessories
-- are kept as a small bust that every headshot clones. Cached for the session.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Appearance = require(ReplicatedStorage.Shared.Appearance)

local Headshot = {}

local cache: { [number]: Model } = {}
local pending: { [number]: boolean } = {}

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
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
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

	-- Accessories were never welded (the rig is torn down before physics ran),
	-- so place each handle by matching its attachment to the head's.
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
				handle.CFrame = head.CFrame * headAtt.CFrame * att.CFrame:Inverse()
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

-- Fills `parent` with a headshot. Shows the shirt number on the kit colour
-- until the face is ready (or if it never loads).
function Headshot.attach(parent: GuiObject, look: number, kit: Color3, number: number): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Headshot"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = kit
	vf.BackgroundTransparency = 0.25
	vf.BorderSizePixel = 0
	vf.Ambient = Color3.fromRGB(140, 140, 150)
	vf.LightColor = Color3.fromRGB(235, 230, 220)
	vf.LightDirection = Vector3.new(0.4, -0.8, 0.7) -- travels toward +Z, so it lights the -Z face
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
		bust.Parent = vf
		local cam = Instance.new("Camera")
		cam.FieldOfView = 28
		-- the face decal is on the head's Front (-Z), so the camera sits on -Z
		cam.CFrame = CFrame.lookAt(Vector3.new(-0.3, 0.55, -3.6), Vector3.new(0, 0.15, 0))
		cam.Parent = vf
		vf.CurrentCamera = cam
		fallback.Visible = false
	end)
	return vf
end

return Headshot
