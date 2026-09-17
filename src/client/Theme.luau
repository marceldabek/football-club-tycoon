--!strict
-- One visual language for every screen: palette, type, panels, cards, buttons
-- and pills. Built in code so it lives in git. Every client UI goes through
-- this module so a change here restyles the whole game.

local Theme = {}

Theme.colors = {
	bg = Color3.fromRGB(16, 20, 26), -- cards and panels
	bg2 = Color3.fromRGB(27, 33, 41), -- rows, inputs
	bg3 = Color3.fromRGB(37, 45, 55), -- alternate rows, secondary buttons
	line = Color3.fromRGB(255, 255, 255), -- strokes (used with high transparency)
	text = Color3.fromRGB(245, 247, 250),
	muted = Color3.fromRGB(158, 166, 178),
	accent = Color3.fromRGB(255, 205, 80), -- club gold: titles, highlights
	outline = Color3.fromRGB(140, 162, 200), -- the one outline colour for every box
	cash = Color3.fromRGB(120, 230, 130),
	good = Color3.fromRGB(70, 175, 95),
	bad = Color3.fromRGB(215, 75, 75),
	info = Color3.fromRGB(80, 150, 230),
	selected = Color3.fromRGB(86, 70, 26),
	playerRow = Color3.fromRGB(74, 62, 24),
}

Theme.fonts = {
	display = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	body = Enum.Font.Gotham,
}

-- One outline for the whole game: same colour, same weight, same softness. Only
-- state changes it (selected / drop target / danger), never decoration.
Theme.outlineTransparency = 0.7

-- Corner radii, generous enough that nothing reads as a square box. Anything
-- rounded should pick one of these rather than inventing its own number.
Theme.radius = 16 -- panels, cards, big surfaces
Theme.cardRadius = 12 -- player cards, list rows, inner panels
Theme.buttonRadius = 10
Theme.chipRadius = 8 -- small chips, dots, meters

local function apply(inst: Instance, props: { [string]: any }?)
	if props then
		for k, v in props do
			(inst :: any)[k] = v
		end
	end
end

function Theme.corner(inst: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.radius)
	c.Parent = inst
	return c
end

-- Every box outline in the game comes from here. Callers do not pick a colour:
-- they pick a state, so the resting look is identical on every panel.
export type StrokeState = "rest" | "selected" | "target" | "danger"

function Theme.stroke(inst: Instance, state: StrokeState?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = inst
	Theme.setStroke(s, state)
	return s
end

-- Retints an existing stroke, so a card can change state without being rebuilt.
function Theme.setStroke(s: UIStroke, state: StrokeState?)
	local st = state or "rest"
	if st == "selected" then
		s.Color = Theme.colors.accent
		s.Transparency = 0
		s.Thickness = 2
	elseif st == "target" then
		s.Color = Theme.colors.cash
		s.Transparency = 0
		s.Thickness = 3
	elseif st == "danger" then
		s.Color = Theme.colors.bad
		s.Transparency = 0.25
		s.Thickness = 2
	else
		s.Color = Theme.colors.outline
		s.Transparency = Theme.outlineTransparency
		s.Thickness = 1
	end
end

function Theme.padding(inst: Instance, all: number, horizontal: number?)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, horizontal or all)
	p.PaddingRight = UDim.new(0, horizontal or all)
	p.Parent = inst
	return p
end

function Theme.screenGui(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = order or 0
	return gui
end

-- A dark rounded surface with a hairline stroke.
function Theme.panel(parent: Instance, name: string, props: { [string]: any }?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Theme.colors.bg
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	apply(f, props)
	Theme.corner(f)
	Theme.stroke(f)
	f.Parent = parent
	return f
end

export type TextStyle = "display" | "title" | "body" | "muted" | "accent" | "cash"

function Theme.text(parent: Instance, text: string, style: TextStyle?, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Theme.colors.text
	l.Font = Theme.fonts.body
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, 24)
	local s = style or "body"
	if s == "display" then
		l.Font = Theme.fonts.display
		l.TextSize = 26
		l.TextColor3 = Theme.colors.accent
	elseif s == "title" then
		l.Font = Theme.fonts.bold
		l.TextSize = 15
		l.TextColor3 = Theme.colors.accent
	elseif s == "muted" then
		l.TextColor3 = Theme.colors.muted
		l.TextSize = 15
	elseif s == "accent" then
		l.Font = Theme.fonts.bold
		l.TextColor3 = Theme.colors.accent
	elseif s == "cash" then
		l.Font = Theme.fonts.bold
		l.TextColor3 = Theme.colors.cash
	end
	apply(l, props)
	l.Parent = parent
	return l
end

export type ButtonVariant = "primary" | "secondary" | "danger" | "info" | "ghost"

function Theme.button(parent: Instance, text: string, variant: ButtonVariant?, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.Font = Theme.fonts.bold
	b.TextSize = 15
	b.TextColor3 = Theme.colors.text
	b.Text = text
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(160, 34)
	local v = variant or "secondary"
	if v == "primary" then
		b.BackgroundColor3 = Theme.colors.good
	elseif v == "danger" then
		b.BackgroundColor3 = Theme.colors.bad
	elseif v == "info" then
		b.BackgroundColor3 = Theme.colors.info
	elseif v == "ghost" then
		b.BackgroundColor3 = Theme.colors.bg2
		b.BackgroundTransparency = 0.2
	else
		b.BackgroundColor3 = Theme.colors.bg3
	end
	apply(b, props)
	Theme.corner(b, Theme.buttonRadius)
	Theme.stroke(b)
	b.Parent = parent
	return b
end

-- Close button: an X drawn from two rotated bars, so it never depends on the
-- font having a glyph (Gotham renders "✕" as a box).
function Theme.closeButton(parent: Instance, props: { [string]: any }?): TextButton
	local b = Theme.button(parent, "", "ghost", {
		Name = "Close",
		Size = UDim2.fromOffset(32, 32),
	})
	apply(b, props)
	for _, angle in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(0.5, 0, 0, 2)
		bar.Rotation = angle
		bar.BackgroundColor3 = Theme.colors.text
		bar.BorderSizePixel = 0
		bar.ZIndex = b.ZIndex + 1
		bar.Parent = b
	end
	return b
end

-- Rounded label with a dark backing: cash, hint, toast, scoreboard clock.
function Theme.pill(parent: Instance, name: string, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundColor3 = Theme.colors.bg
	l.BackgroundTransparency = 0.18
	l.BorderSizePixel = 0
	l.Font = Theme.fonts.bold
	l.TextSize = 16
	l.TextColor3 = Theme.colors.text
	l.Text = ""
	l.Size = UDim2.fromOffset(200, 34)
	apply(l, props)
	Theme.corner(l, 17)
	Theme.stroke(l)
	Theme.padding(l, 0, 14)
	l.Parent = parent
	return l
end

export type Card = {
	frame: Frame,
	title: TextLabel,
	body: TextLabel,
	addButton: (text: string, variant: ButtonVariant?) -> TextButton,
}

-- Centre card: display title, accent rule, rich-text body, buttons in a footer row.
function Theme.card(parent: Instance, name: string, title: string, size: UDim2, position: UDim2?): Card
	local frame = Theme.panel(parent, name, {
		Size = size,
		Position = position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
	})
	local titleLabel = Theme.text(frame, title, "display", {
		Name = "Title",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Theme.colors.accent
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(0, 48, 0, 3)
	rule.Position = UDim2.fromOffset(20, 56)
	rule.Parent = frame
	local body = Theme.text(frame, "", "body", {
		Name = "Body",
		Size = UDim2.new(1, -40, 1, -136),
		Position = UDim2.fromOffset(20, 70),
		TextSize = 17,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	})
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, -40, 0, 44)
	footer.Position = UDim2.new(0, 20, 1, -60)
	footer.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder -- buttons sit in the order they were added
	layout.Parent = footer
	local added = 0
	local function addButton(text: string, variant: ButtonVariant?): TextButton
		added += 1
		return Theme.button(footer, text, variant or "primary", {
			Name = text:gsub("%s", ""),
			Size = UDim2.fromOffset(190, 44),
			TextSize = 18,
			LayoutOrder = added,
		})
	end
	return { frame = frame, title = titleLabel, body = body, addButton = addButton }
end

function Theme.money(n: number): string
	local s = tostring(math.floor(n))
	local withCommas = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return "£" .. withCommas
end

function Theme.ordinal(n: number): string
	local suffix = "th"
	local last = n % 10
	if n % 100 < 11 or n % 100 > 13 then
		suffix = if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	end
	return ("%d%s"):format(n, suffix)
end

-- Rich text helpers so colours stay consistent across screens.
local function hex(c: Color3): string
	return ("#%02x%02x%02x"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
function Theme.rich(text: string, color: Color3, bold: boolean?): string
	local inner = if bold then "<b>" .. text .. "</b>" else text
	return ("<font color=\"%s\">%s</font>"):format(hex(color), inner)
end

return Theme
