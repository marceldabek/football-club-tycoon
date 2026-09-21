--!strict
-- One football card: tier art, overall, role, flag, crest, bust, name and the
-- six stats, laid out in scale units so it is the same card at any size. The
-- caller sizes the parent; the card keeps its own 2:3 shape inside it.
--   card:flip()          squash to a line, swap back/face, open again
--   card:setFace(up)     no animation
--
-- Every number below is a fraction of the card, measured off
-- assets/ui/cards/card_filled_reference.png.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CardStats = require(ReplicatedStorage.Shared.CardStats)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Nations = require(ReplicatedStorage.Shared.Nations)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Crest = require(script.Parent.Crest)
local FlagView = require(script.Parent.FlagView)
local Headshot = require(script.Parent.Headshot)
local Theme = require(script.Parent.Theme)

local PlayerCard = {}

export type Options = { signed: boolean?, clubName: string?, faceDown: boolean? }
export type Card = {
	frame: Frame,
	tier: string,
	faceUp: boolean,
	flip: (self: Card) -> (),
	setFace: (self: Card, up: boolean) -> (),
	destroy: (self: Card) -> (),
}

local HALF_FLIP = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local OPEN_FLIP = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- the left column of the art: overall, role, flag, crest, each centred on this x
local SPINE_X = 0.213
local STAT_ROW_Y = { 0.693, 0.758, 0.823 } -- the three rows under the name
local STAT_VALUE_RIGHT = { 0.318, 0.683 } -- where each column's number ends
local STAT_LABEL_LEFT = { 0.343, 0.708 } -- where its three letters start

-- text that scales with the card: TextScaled inside a scale-sized box, one line
local function label(
	parent: Instance,
	text: string,
	centre: Vector2,
	size: Vector2,
	ink: Color3,
	align: Enum.TextXAlignment?
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = text
	t.Font = Theme.fonts.display
	t.TextColor3 = ink
	-- TextScaled forces TextWrapped on and clearing it silently turns TextScaled
	-- back off, so the boxes below are wide enough that the largest size that
	-- fits is always a single line.
	t.TextScaled = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	-- the art is busy under the text, so every label carries a soft outline in
	-- the other direction: dark behind light ink, light behind dark ink
	local light = 0.2126 * ink.R + 0.7152 * ink.G + 0.0722 * ink.B > 0.5
	t.TextStrokeColor3 = if light then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.6
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(centre.X, centre.Y)
	t.Size = UDim2.fromScale(size.X, size.Y)
	t.ZIndex = 4
	t.Parent = parent
	return t
end

-- a hairline rule in the card's own ink: under the name, and between the two
-- stat columns. The tier art has neither.
local function rule(parent: Instance, centre: Vector2, size: Vector2, ink: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = "Rule"
	f.BackgroundColor3 = ink
	f.BackgroundTransparency = 0.55
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(centre.X, centre.Y)
	f.Size = UDim2.fromScale(size.X, size.Y)
	f.ZIndex = 4
	f.Parent = parent
	return f
end

function PlayerCard.new(parent: Instance, p: any, opts: Options?): Card
	local signed = opts ~= nil and opts.signed == true
	local tier = Squad.rarity(p.overall)
	local tint = Config.CardTint[tier]
	local ink = tint.ink

	local frame = Instance.new("Frame")
	frame.Name = "PlayerCard"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = Config.CardAspect
	aspect.Parent = frame
	frame.Parent = parent

	local back = Instance.new("ImageLabel")
	back.Name = "Back"
	back.BackgroundTransparency = 1
	back.Image = Config.CardArt.Back
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 2
	back.Parent = frame

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundTransparency = 1
	face.Image = Config.CardArt[tier]
	face.Size = UDim2.fromScale(1, 1)
	face.ZIndex = 2
	face.Parent = frame

	-- the bust sits behind the text and is clipped to the portrait window
	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.BackgroundTransparency = 1
	portrait.ClipsDescendants = true
	-- as tall as the art's upper panel allows: the bust is drawn to a fixed
	-- framing, so the window's height is the only thing that sets the head size
	-- Width is what crops the bust sideways: any wider and the bare upper arms
	-- come into shot beside the shirt.
	portrait.Position = UDim2.fromScale(0.315, 0.04)
	portrait.Size = UDim2.fromScale(0.49, 0.549) -- bottom lands on the art's divider
	portrait.ZIndex = 3
	portrait.Parent = face
	local kit = if signed then Config.HomeKit else Config.ProspectKit
	local shot = Headshot.attach(portrait, p.look or p.id, kit, p.number or 0, { shoulders = true })
	shot.ZIndex = 3
	shot.BackgroundTransparency = 1
	local backdrop = portrait:FindFirstChild("Backdrop")
	if backdrop then
		backdrop:Destroy() -- the card art is the backdrop
	end

	label(face, tostring(p.overall), Vector2.new(SPINE_X, 0.177), Vector2.new(0.28, 0.105), ink)
	label(face, tostring(p.role or ""), Vector2.new(SPINE_X, 0.273), Vector2.new(0.26, 0.05), ink)

	local flagBox = Instance.new("Frame")
	flagBox.Name = "FlagBox"
	flagBox.BackgroundTransparency = 1
	flagBox.AnchorPoint = Vector2.new(0.5, 0.5)
	flagBox.Position = UDim2.fromScale(SPINE_X, 0.35)
	flagBox.Size = UDim2.fromScale(0.146, 0.068) -- ~10:7, the shape FlagView assumes
	flagBox.ZIndex = 4
	flagBox.Parent = face
	FlagView.draw(flagBox, Nations.get(p.nation).flag).ZIndex = 4

	if signed then
		-- square in pixels, so the shield is not stretched by the 2:3 card
		local crestBox = Instance.new("Frame")
		crestBox.Name = "CrestBox"
		crestBox.BackgroundTransparency = 1
		crestBox.AnchorPoint = Vector2.new(0.5, 0.5)
		crestBox.Position = UDim2.fromScale(SPINE_X, 0.458)
		crestBox.Size = UDim2.fromScale(0.13, 0.13 * Config.CardAspect)
		crestBox.ZIndex = 4
		crestBox.Parent = face
		-- Crest.draw works in pixels; on a card everything has to be in scale or
		-- the shield keeps one size while the card grows.
		local shield = Crest.draw(crestBox, opts and opts.clubName, 40, { isPlayer = true })
		shield.Size = UDim2.fromScale(1, 1)
		shield.ZIndex = 4
		local corner = shield:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.26, 0)
		end
		local initials = shield:FindFirstChild("Initials")
		if initials and initials:IsA("TextLabel") then
			initials.AnchorPoint = Vector2.new(0.5, 0.5)
			initials.Position = UDim2.fromScale(0.5, 0.5)
			initials.Size = UDim2.fromScale(0.66, 0.5)
			initials.TextScaled = true
		end
		for _, d in shield:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 5
			end
		end
	end

	label(face, string.upper(Format.cardName(p.name)), Vector2.new(0.5, 0.608), Vector2.new(0.76, 0.06), ink)
	rule(face, Vector2.new(0.5, 0.652), Vector2.new(0.78, 0.003), ink)
	rule(face, Vector2.new(0.503, 0.758), Vector2.new(0.006, 0.19), ink)

	for i, stat in CardStats.of(p) do
		local column = if i <= 3 then 1 else 2
		local y = STAT_ROW_Y[((i - 1) % 3) + 1]
		label(
			face,
			tostring(stat.value),
			Vector2.new(STAT_VALUE_RIGHT[column] - 0.065, y),
			Vector2.new(0.13, 0.048),
			ink,
			Enum.TextXAlignment.Right
		)
		label(
			face,
			stat.label,
			Vector2.new(STAT_LABEL_LEFT[column] + 0.075, y + 0.002),
			Vector2.new(0.15, 0.04),
			ink,
			Enum.TextXAlignment.Left
		)
	end

	local shine: Tween? = nil
	if p.wonderkid then
		-- The shiny: a real band of light sweeping across the face. A UIGradient
		-- can only multiply, so it can darken but never brighten -- this is a
		-- white bar over the art instead. The layer is inset to the shield's
		-- inner rectangle so the bar never shows over the art's transparent
		-- corners or its bottom point.
		-- a CanvasGroup, not a Frame: ClipsDescendants does not clip a *rotated*
		-- child, and the bar would stream out across the whole screen
		local layer = Instance.new("CanvasGroup")
		layer.Name = "Shine"
		layer.BackgroundTransparency = 1
		layer.ClipsDescendants = true
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.48)
		layer.Size = UDim2.fromScale(0.82, 0.78)
		layer.ZIndex = 6 -- over the text as well as the art
		layer.Parent = face

		local band = Instance.new("Frame")
		band.Name = "Band"
		band.BackgroundColor3 = Color3.new(1, 1, 1)
		band.BackgroundTransparency = 0.4
		band.BorderSizePixel = 0
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(-0.2, 0.5)
		band.Size = UDim2.fromScale(0.22, 2.05) -- ~0.18 x 1.6 of the whole card
		band.Rotation = 20
		band.ZIndex = 6
		band.Parent = layer
		local soft = Instance.new("UIGradient")
		soft.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		soft.Parent = band

		shine = TweenService:Create(
			band,
			TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 1.2),
			{ Position = UDim2.fromScale(1.2, 0.5) }
		)
		;(shine :: Tween):Play()
	end

	local card = { frame = frame, tier = tier, faceUp = true } :: any

	function card.setFace(self: Card, up: boolean)
		self.faceUp = up
		face.Visible = up
		back.Visible = not up
	end

	-- 2D spin: the back is left-right symmetrical so the swap at zero width
	-- does not jump (docs/CARD_BACKGROUND_PROMPTS.md s7). A tap while it is
	-- already turning is ignored, or the second flip would read `full` off a
	-- half-squashed card and leave it that shape.
	local flipping = false
	function card.flip(self: Card)
		if flipping then
			return
		end
		flipping = true
		local full = frame.Size
		aspect.Parent = nil -- or the constraint fights the squash
		local shut = TweenService:Create(frame, HALF_FLIP, { Size = UDim2.new(0, 0, full.Y.Scale, full.Y.Offset) })
		shut:Play()
		shut.Completed:Wait()
		self:setFace(not self.faceUp)
		local open = TweenService:Create(frame, OPEN_FLIP, { Size = full })
		open:Play()
		open.Completed:Wait()
		aspect.Parent = frame
		flipping = false
	end

	function card.destroy(self: Card)
		if shine then
			shine:Cancel() -- the sweep tween outlives the instance otherwise
		end
		frame:Destroy()
	end

	card:setFace(not (opts ~= nil and opts.faceDown == true))
	return card :: Card
end

return PlayerCard
