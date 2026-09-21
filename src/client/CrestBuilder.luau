--!strict
-- The crest builder card (docs/superpowers/specs/2026-09-21-crest-builder-design.md):
-- step 2 of founding the club, and the office's "Edit crest". A live preview,
-- Randomise, then a row each for shape, pattern and emblem (tiles drawn in the
-- club's current colours, so every tile is a preview) and two swatch rows for
-- the colours. The card only edits a local spec; the caller sends it
-- (ClubCrest remote) in onConfirm, and the server normalizes it again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClubCrest = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClubCrest"))
local Theme = require(script.Parent.Theme)

local CrestBuilder = {}

export type Options = {
	title: string,
	confirmText: string,
	backText: string?, -- a secondary footer button (Back / Cancel); nil = none
	spec: ClubCrest.Spec,
	onConfirm: (ClubCrest.Spec) -> (),
	onBack: (() -> ())?,
}

local CARD_W, CARD_H = 560, 484
local PREVIEW = 150
local COL_X = 190 -- the option rows' left edge
local COL_W = CARD_W - COL_X - 20
local SWATCH_ROW_W = CARD_W - 40

local gui: ScreenGui? = nil
local card: any = nil
local spec: ClubCrest.Spec = ClubCrest.default()
local current: Options? = nil
local refreshers: { () -> () } = {}
local confirmButton: TextButton? = nil
local backButton: TextButton? = nil

local function refresh()
	for _, f in refreshers do
		f()
	end
end

local function select(frame: GuiObject, on: boolean)
	local stroke = frame:FindFirstChild("Pick") :: UIStroke?
	if stroke then
		stroke.Color = if on then Theme.colors.accent else Theme.colors.bg3
		stroke.Thickness = if on then 3 else 1
		stroke.Transparency = if on then 0 else 0.4
	end
end

local function tileFrame(parent: Instance, name: string, x: number, y: number, size: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.colors.bg2
	b.BorderSizePixel = 0
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(size, size)
	b.Parent = parent
	Theme.corner(b, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Pick"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	return b
end

local function rowLabel(parent: Instance, text: string, x: number, y: number)
	Theme.text(parent, text, "muted", {
		Name = text:gsub("%s", "") .. "Label",
		Size = UDim2.fromOffset(200, 16),
		Position = UDim2.fromOffset(x, y),
		TextSize = 13,
		Font = Theme.fonts.bold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

-- A row of crest tiles: `field` takes each value in `values`; every tile draws
-- the current spec with that one field swapped, so it previews the result.
local function crestRow(parent: Instance, label: string, field: string, values: { string }, y: number, size: number)
	rowLabel(parent, label, COL_X, y)
	local gap = (COL_W - size * #values) / math.max(#values - 1, 1)
	for i, value in values do
		local tile = tileFrame(parent, field .. "_" .. value, COL_X + (i - 1) * (size + gap), y + 18, size)
		local function variant(): ClubCrest.Spec
			local v = table.clone(spec) :: any
			v[field] = value
			if field == "emblem" or field == "shape" then
				v.pattern = "plain" -- a plain field reads best at tile size
			end
			return v :: ClubCrest.Spec
		end
		local mini = ClubCrest.draw(tile, variant(), UDim2.new(1, -6, 1, -6), {
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		})
		tile.Activated:Connect(function()
			(spec :: any)[field] = value
			refresh()
		end)
		table.insert(refreshers, function()
			ClubCrest.update(mini, variant())
			select(tile, (spec :: any)[field] == value)
		end)
	end
end

-- Twelve swatches across the card. Picking the colour the other slot holds
-- swaps the two, so main and second can never match.
local function swatchRow(parent: Instance, label: string, field: string, other: string, y: number)
	rowLabel(parent, label, 20, y)
	local n = #ClubCrest.PALETTE
	local size = 38
	local gap = (SWATCH_ROW_W - size * n) / (n - 1)
	for i, swatch in ClubCrest.PALETTE do
		local tile = tileFrame(parent, field .. "_" .. swatch.key, 20 + (i - 1) * (size + gap), y + 18, size)
		tile.BackgroundColor3 = ClubCrest.colour(swatch.key)
		tile.Activated:Connect(function()
			local s = spec :: any
			if s[other] == swatch.key then
				s[other] = s[field]
			end
			s[field] = swatch.key
			refresh()
		end)
		table.insert(refreshers, function()
			select(tile, (spec :: any)[field] == swatch.key)
		end)
	end
end

local function build()
	local player = Players.LocalPlayer
	local screen = Theme.screenGui("CrestBuilder", 9)
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
	local c = Theme.card(screen, "Card", "DESIGN YOUR CREST", UDim2.fromOffset(CARD_W, CARD_H), UDim2.fromScale(0.5, 0.5))
	card = c
	c.body.Visible = false
	local frame = c.frame

	local previewBack = Instance.new("Frame")
	previewBack.Name = "PreviewBack"
	previewBack.BackgroundColor3 = Theme.colors.bg2
	previewBack.BorderSizePixel = 0
	previewBack.Position = UDim2.fromOffset(20, 76)
	previewBack.Size = UDim2.fromOffset(PREVIEW, PREVIEW)
	previewBack.Parent = frame
	Theme.corner(previewBack, 12)
	local preview = ClubCrest.draw(previewBack, spec, UDim2.new(1, -16, 1, -16), {
		name = "Preview",
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})
	table.insert(refreshers, function()
		ClubCrest.update(preview, spec)
	end)

	local randomise = Theme.button(frame, "Randomise", "secondary", {
		Name = "Randomise",
		Position = UDim2.fromOffset(20, 76 + PREVIEW + 10),
		Size = UDim2.fromOffset(PREVIEW, 38),
		TextSize = 16,
	})
	randomise.Activated:Connect(function()
		spec = ClubCrest.random()
		refresh()
	end)

	crestRow(frame, "SHAPE", "shape", ClubCrest.SHAPES, 72, 46)
	crestRow(frame, "PATTERN", "pattern", ClubCrest.PATTERNS, 142, 46)
	crestRow(frame, "EMBLEM", "emblem", ClubCrest.EMBLEMS, 212, 38)
	swatchRow(frame, "MAIN COLOUR", "main", "second", 282)
	swatchRow(frame, "SECOND COLOUR", "second", "main", 346)

	local back = c.addButton("Back", "secondary")
	back.Size = UDim2.fromOffset(130, 44)
	back.Activated:Connect(function()
		local o = current
		if o and o.onBack then
			o.onBack()
		end
	end)
	backButton = back
	local confirm = c.addButton("Found the club", "primary")
	confirm.Name = "Confirm"
	confirm.Size = UDim2.fromOffset(210, 44)
	confirm.Activated:Connect(function()
		local o = current
		if o then
			o.onConfirm(table.clone(spec))
		end
	end)
	confirmButton = confirm
end

function CrestBuilder.open(options: Options)
	if not gui then
		build()
	end
	current = options
	spec = table.clone(options.spec)
	card.title.Text = options.title
	local confirm = confirmButton :: TextButton
	confirm.Text = options.confirmText
	local back = backButton :: TextButton
	back.Visible = options.backText ~= nil
	back.Text = options.backText or ""
	refresh()
	card.frame.Visible = true
end

function CrestBuilder.close()
	current = nil
	if card then
		card.frame.Visible = false
	end
end

function CrestBuilder.isOpen(): boolean
	return card ~= nil and card.frame.Visible
end

-- Relabel the confirm button while the caller waits on the server.
function CrestBuilder.setBusy(text: string?)
	local confirm = confirmButton
	if confirm and current then
		confirm.Text = text or current.confirmText
	end
end

return CrestBuilder
