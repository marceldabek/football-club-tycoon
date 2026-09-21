--!strict
-- The one-page club designer (Marcel's mockup, 2026-09-21): CLUB NAME, CLUB
-- CREST (a live preview beside Shape / Pattern / Emblem tabs, each tile drawn
-- in the club's current colours so it previews the result), CLUB COLOURS (two
-- swatch rows) and Randomise. Founding the club shows the name section; the
-- office's "Edit crest" hides it. The card only edits a local spec; the caller
-- sends it (ClubCrest / ClubName remotes) in onConfirm, and the server
-- normalizes it again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClubCrest = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClubCrest"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Focus = require(script.Parent.Focus)

local CrestBuilder = {}

export type Options = {
	name: string?, -- shows the CLUB NAME section, prefilled; nil = crest only
	confirmText: string,
	backText: string?, -- a secondary footer button (Cancel); nil = none
	spec: ClubCrest.Spec,
	onConfirm: (ClubCrest.Spec, string?) -> (),
	onBack: (() -> ())?,
}

-- design pixels; the card scales down to fit the screen
local W = 520
local PAD = 20
local INNER = W - PAD * 2
local NAME_H = 136 -- the name section, dropped when editing the crest only
local BODY_H = 574 -- crest + colours + buttons
local PREVIEW = 172
local GRID_X = PAD + PREVIEW + 14
local GRID_W = W - GRID_X - PAD
local TILE = 50
local PER_ROW = 5

local gui: ScreenGui? = nil
local card: Frame? = nil
local fitScale: UIScale? = nil
local nameSection: Frame? = nil
local body: Frame? = nil
local nameBox: TextBox? = nil
local nameHint: TextLabel? = nil
local counter: TextLabel? = nil
local confirmButton: TextButton? = nil
local backButton: TextButton? = nil
local spec: ClubCrest.Spec = ClubCrest.default()
local current: Options? = nil
local refreshers: { () -> () } = {}

local NAME_HINT = "Choose a name for your club."

local function refresh()
	for _, f in refreshers do
		f()
	end
end

local function select(tile: GuiObject, on: boolean)
	local stroke = tile:FindFirstChild("Pick") :: UIStroke?
	if stroke then
		if on then
			stroke.Color = Theme.colors.accent
			stroke.Transparency = 0
			stroke.Thickness = 3
		else
			Theme.setStroke(stroke, "rest")
		end
	end
end

local function tile(parent: Instance, name: string, x: number, y: number, size: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.colors.bg2
	b.BorderSizePixel = 0
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(size, size)
	b.Parent = parent
	Theme.corner(b, Theme.chipRadius)
	Theme.stroke(b).Name = "Pick"
	return b
end

local function heading(parent: Instance, text: string, y: number)
	Theme.text(parent, text, "body", {
		Name = text:gsub("%s", "") .. "Heading",
		Size = UDim2.fromOffset(INNER, 24),
		Position = UDim2.fromOffset(PAD, y),
		Font = Theme.fonts.display,
		TextSize = 22,
	})
end

local function subtitle(parent: Instance, text: string, y: number): TextLabel
	return Theme.text(parent, text, "muted", {
		Name = "Subtitle",
		Size = UDim2.fromOffset(INNER, 18),
		Position = UDim2.fromOffset(PAD, y),
		TextSize = 14,
	})
end

local function smallLabel(parent: Instance, text: string, y: number)
	Theme.text(parent, text, "muted", {
		Name = text:gsub("%s", "") .. "Label",
		Size = UDim2.fromOffset(INNER, 14),
		Position = UDim2.fromOffset(PAD, y),
		TextSize = 12,
		Font = Theme.fonts.bold,
	})
end

local function divider(parent: Instance, y: number)
	local line = Instance.new("Frame")
	line.Name = "Divider"
	line.BackgroundColor3 = Theme.colors.line
	line.BackgroundTransparency = 0.9
	line.BorderSizePixel = 0
	line.Position = UDim2.fromOffset(PAD, y)
	line.Size = UDim2.fromOffset(INNER, 1)
	line.Parent = parent
end

local function nameLength(text: string): number
	return utf8.len(text) or #text -- X190: letters, not bytes
end

-- ------------------------------------------------------------ name section

local function buildName(parent: Frame)
	local section = Instance.new("Frame")
	section.Name = "NameSection"
	section.BackgroundTransparency = 1
	section.Size = UDim2.fromOffset(W, NAME_H)
	section.Parent = parent
	nameSection = section

	heading(section, "CLUB NAME", 18)
	nameHint = subtitle(section, NAME_HINT, 44)

	local box = Instance.new("TextBox")
	box.Name = "NameBox"
	box.Size = UDim2.fromOffset(INNER, 50)
	box.Position = UDim2.fromOffset(PAD, 70)
	box.BackgroundColor3 = Theme.colors.bg2
	box.BorderSizePixel = 0
	box.Font = Theme.fonts.bold
	box.TextSize = 20
	box.TextColor3 = Theme.colors.text
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.PlaceholderColor3 = Theme.colors.muted
	box.PlaceholderText = "Club name"
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = section
	Theme.corner(box, Theme.buttonRadius)
	Theme.stroke(box)
	local pad = Theme.padding(box, 0, 16)
	pad.PaddingRight = UDim.new(0, 70) -- room for the counter
	nameBox = box

	local count = Theme.text(section, "", "muted", {
		Name = "Counter",
		Size = UDim2.fromOffset(60, 50),
		Position = UDim2.fromOffset(PAD + INNER - 76, 70),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	counter = count

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if nameLength(box.Text) > Config.ClubNameMaxLength then
			local cut = utf8.offset(box.Text, Config.ClubNameMaxLength + 1)
			box.Text = if cut then box.Text:sub(1, cut - 1) else box.Text:sub(1, Config.ClubNameMaxLength)
			return
		end
		count.Text = ("%d / %d"):format(nameLength(box.Text), Config.ClubNameMaxLength)
	end)
	box.FocusLost:Connect(function(enterPressed)
		local o = current
		if enterPressed and o then
			o.onConfirm(table.clone(spec), box.Text)
		end
	end)

	divider(section, NAME_H - 1)
end

-- ----------------------------------------------------------- crest section

-- One tab's grid of crest tiles: `field` takes each value in `values`; every
-- tile draws the current spec with that one field swapped.
local function crestGrid(parent: Instance, field: string, values: { string }, y: number): Frame
	local grid = Instance.new("Frame")
	grid.Name = field:sub(1, 1):upper() .. field:sub(2) .. "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(GRID_X, y)
	grid.Size = UDim2.fromOffset(GRID_W, TILE * 2 + 12)
	grid.Parent = parent
	local gap = (GRID_W - TILE * PER_ROW) / (PER_ROW - 1)
	for i, value in values do
		local col, row = (i - 1) % PER_ROW, (i - 1) // PER_ROW
		local t = tile(grid, field .. "_" .. value, col * (TILE + gap), row * (TILE + gap), TILE)
		local function variant(): ClubCrest.Spec
			local v = table.clone(spec) :: any
			v[field] = value
			if field == "emblem" or field == "shape" then
				v.pattern = "plain" -- a plain field reads best at tile size
			end
			return v :: ClubCrest.Spec
		end
		local mini = ClubCrest.draw(t, variant(), UDim2.new(1, -10, 1, -10), {
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		})
		t.Activated:Connect(function()
			(spec :: any)[field] = value
			refresh()
		end)
		table.insert(refreshers, function()
			ClubCrest.update(mini, variant())
			select(t, (spec :: any)[field] == value)
		end)
	end
	return grid
end

local function buildCrest(parent: Frame)
	heading(parent, "CLUB CREST", 14)
	subtitle(parent, "Pick a shape, pattern and emblem to create your crest.", 40)

	local top = 68
	local previewBack = Instance.new("Frame")
	previewBack.Name = "PreviewBack"
	previewBack.BackgroundColor3 = Theme.colors.bg2
	previewBack.BorderSizePixel = 0
	previewBack.Position = UDim2.fromOffset(PAD, top)
	previewBack.Size = UDim2.fromOffset(PREVIEW, PREVIEW)
	previewBack.Parent = parent
	Theme.corner(previewBack, Theme.cardRadius)
	Theme.stroke(previewBack)
	local preview = ClubCrest.draw(previewBack, spec, UDim2.new(1, -28, 1, -28), {
		name = "Preview",
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})
	table.insert(refreshers, function()
		ClubCrest.update(preview, spec)
	end)

	-- tab bar: the picked tab is gold with dark lettering
	local tabs = {
		{ label = "SHAPE", grid = crestGrid(parent, "shape", ClubCrest.SHAPES, top + 50) },
		{ label = "PATTERN", grid = crestGrid(parent, "pattern", ClubCrest.PATTERNS, top + 50) },
		{ label = "EMBLEM", grid = crestGrid(parent, "emblem", ClubCrest.EMBLEMS, top + 50) },
	}
	local tabGap = 8
	local tabW = (GRID_W - tabGap * (#tabs - 1)) / #tabs
	local buttons: { TextButton } = {}
	local function pick(index: number)
		for i, t in tabs do
			local on = i == index
			t.grid.Visible = on
			local b = buttons[i]
			b.BackgroundColor3 = if on then Theme.colors.accent else Theme.colors.bg2
			b.TextColor3 = if on then Theme.colors.bg else Theme.colors.text
		end
	end
	for i, t in tabs do
		local b = Theme.button(parent, t.label, "ghost", {
			Name = t.label:sub(1, 1) .. t.label:sub(2):lower() .. "Tab",
			Position = UDim2.fromOffset(GRID_X + (i - 1) * (tabW + tabGap), top),
			Size = UDim2.fromOffset(tabW, 36),
			TextSize = 13,
			AutoButtonColor = false,
			BackgroundTransparency = 0,
		})
		b.Activated:Connect(function()
			pick(i)
		end)
		buttons[i] = b
	end
	pick(1)

	divider(parent, top + PREVIEW + 16)
end

-- ---------------------------------------------------------- colour section

-- One swatch per palette colour across the card. Picking the colour the other
-- slot holds swaps the two, so main and second can never match.
local function swatchRow(parent: Instance, field: string, other: string, y: number)
	local n = #ClubCrest.PALETTE
	local size = 34
	local gap = (INNER - size * n) / (n - 1)
	for i, swatch in ClubCrest.PALETTE do
		local t = tile(parent, field .. "_" .. swatch.key, PAD + (i - 1) * (size + gap), y, size)
		t.BackgroundColor3 = ClubCrest.colour(swatch.key)
		t.Activated:Connect(function()
			local s = spec :: any
			if s[other] == swatch.key then
				s[other] = s[field]
			end
			s[field] = swatch.key
			refresh()
		end)
		table.insert(refreshers, function()
			select(t, (spec :: any)[field] == swatch.key)
		end)
	end
end

local function buildColours(parent: Frame, top: number)
	heading(parent, "CLUB COLOURS", top)
	subtitle(parent, "Choose your main and secondary colours.", top + 26)
	smallLabel(parent, "MAIN COLOUR", top + 54)
	swatchRow(parent, "main", "second", top + 72)
	smallLabel(parent, "SECONDARY COLOUR", top + 116)
	swatchRow(parent, "second", "main", top + 134)

	local randomise = Theme.button(parent, "Randomise Crest & Colours", "ghost", {
		Name = "Randomise",
		Position = UDim2.fromOffset(PAD, top + 184),
		Size = UDim2.fromOffset(INNER, 44),
		TextSize = 16,
		BackgroundTransparency = 0,
	})
	randomise.Activated:Connect(function()
		spec = ClubCrest.random()
		refresh()
	end)

	-- footer: Cancel (edit only) and the confirm button share the last row
	local y = top + 240
	local back = Theme.button(parent, "Cancel", "secondary", {
		Name = "Back",
		Position = UDim2.fromOffset(PAD, y),
		Size = UDim2.fromOffset(150, 48),
		TextSize = 17,
	})
	back.Activated:Connect(function()
		local o = current
		if o and o.onBack then
			o.onBack()
		end
	end)
	backButton = back
	local confirm = Theme.button(parent, "Found the club", "primary", {
		Name = "Confirm",
		Position = UDim2.fromOffset(PAD, y),
		Size = UDim2.fromOffset(INNER, 48),
		TextSize = 18,
	})
	confirm.Activated:Connect(function()
		local o = current
		if o then
			o.onConfirm(table.clone(spec), if nameBox and o.name then nameBox.Text else nil)
		end
	end)
	confirmButton = confirm
end

-- ----------------------------------------------------------------- fitting

local function cardHeight(): number
	return BODY_H + (if current and current.name then NAME_H else 0)
end

-- Scale to fit the screen. X252: on a phone the on-screen keyboard covers the
-- bottom of the screen while the name is typed, so the card pins its top to
-- the top of the screen then, keeping the name box above the keyboard.
local function place()
	local c, s = card, fitScale
	if not c or not s then
		return
	end
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local h = cardHeight()
	s.Scale = math.min(1, (viewport.X - 16) / W, (viewport.Y - 16) / h)
	if UserInputService.OnScreenKeyboardVisible and UserInputService.OnScreenKeyboardSize.Y > 0 then
		c.AnchorPoint = Vector2.new(0.5, 0)
		c.Position = UDim2.new(0.5, 0, 0, 8)
	else
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(0.5, 0.5)
	end
end

local function build()
	local screen = Theme.screenGui("CrestBuilder", 9)
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen

	-- not parented straight to the ScreenGui: Theme.panel would add its own
	-- fit scale, whose 0.75 floor is too big for a card this tall on a phone
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = screen
	local c = Theme.panel(holder, "Card", {
		Size = UDim2.fromOffset(W, cardHeight()),
		Visible = false,
		ClipsDescendants = true,
	})
	card = c
	local s = Instance.new("UIScale")
	s.Name = "FitScale"
	s.Parent = c
	fitScale = s
	Focus.watch(c) -- blur the world behind the designer

	buildName(c)
	local b = Instance.new("Frame")
	b.Name = "Body"
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(W, BODY_H)
	b.Parent = c
	body = b
	buildCrest(b)
	buildColours(b, 68 + PREVIEW + 30)

	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
		end
		place()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(place)
	UserInputService:GetPropertyChangedSignal("OnScreenKeyboardSize"):Connect(place)
end

-- --------------------------------------------------------------------- API

function CrestBuilder.open(options: Options)
	if not gui then
		build()
	end
	current = options
	spec = table.clone(options.spec)
	local c = card :: Frame
	local hasName = options.name ~= nil
	;(nameSection :: Frame).Visible = hasName
	;(body :: Frame).Position = UDim2.fromOffset(0, if hasName then NAME_H else 0)
	c.Size = UDim2.fromOffset(W, cardHeight())
	if hasName then
		local box = nameBox :: TextBox
		box.Text = options.name :: string
		;(counter :: TextLabel).Text = ("%d / %d"):format(nameLength(box.Text), Config.ClubNameMaxLength)
		CrestBuilder.setNameHint(nil)
	end
	local back = backButton :: TextButton
	local confirm = confirmButton :: TextButton
	back.Visible = options.backText ~= nil
	back.Text = options.backText or ""
	confirm.Text = options.confirmText
	if options.backText then
		confirm.Position = UDim2.fromOffset(PAD + 160, confirm.Position.Y.Offset)
		confirm.Size = UDim2.fromOffset(INNER - 160, 48)
	else
		confirm.Position = UDim2.fromOffset(PAD, confirm.Position.Y.Offset)
		confirm.Size = UDim2.fromOffset(INNER, 48)
	end
	refresh()
	place()
	c.Visible = true
end

function CrestBuilder.close()
	current = nil
	if card then
		card.Visible = false
	end
end

function CrestBuilder.isOpen(): boolean
	return card ~= nil and card.Visible
end

-- Relabel the confirm button while the caller waits on the server.
function CrestBuilder.setBusy(text: string?)
	local confirm = confirmButton
	if confirm and current then
		confirm.Text = text or current.confirmText
	end
end

-- The line under CLUB NAME: the default prompt, or a problem in red.
function CrestBuilder.setNameHint(problem: string?)
	local hint = nameHint
	if hint then
		hint.Text = problem or NAME_HINT
		hint.TextColor3 = if problem then Theme.colors.bad else Theme.colors.muted
	end
end

return CrestBuilder
