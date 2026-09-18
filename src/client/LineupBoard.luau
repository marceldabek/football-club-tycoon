--!strict
-- Squad board: a STARTING XI panel with headshot cards on a full pitch, a
-- scrolling BENCH / RESERVES column, and a player detail window under it.
--
-- The board is built once and then *updated* — cards and rows belong to a
-- player id for as long as that player is on screen, so a swap moves two
-- widgets instead of rebuilding the screen (no flash, no headshot reload).
--
-- Cards drag onto each other to swap: the pressed card lights up immediately,
-- a ghost follows the cursor, and the card under the cursor is outlined as the
-- drop target. A tap selects, and a second tap on another card swaps (the
-- touch fallback). All rules stay on the server: the board only reports
-- `onSwap`, `onSelect` and `onSell` with player ids.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Theme = require(script.Parent.Theme)
local Headshot = require(script.Parent.Headshot)
local Squad = require(ReplicatedStorage.Shared.Squad)
local Config = require(ReplicatedStorage.Shared.Config)

local LineupBoard = {}

export type Player = {
	id: number,
	name: string,
	number: number,
	role: string,
	age: number,
	overall: number,
	potential: number?,
	injured: number,
	apps: number?,
	goals: number?,
	look: number?,
}
export type Club = {
	players: { Player },
	lineup: { xi: { number }, bench: { number } },
}
export type Options = {
	kit: Color3,
	onSwap: (number, number) -> (),
	onSelect: (number?) -> (),
	onSell: (number) -> (),
}

-- Optional pitch artwork (rbxassetid://...). Empty draws the pitch from frames.
LineupBoard.BACKGROUND_IMAGE = "rbxassetid://109275890815433" -- assets/references/pitch-board.png, 1536x1024

-- TEMP layout
local CARD_W, CARD_H = 86, 108
local ROW_H = 62
local PITCH_FRACTION = 0.63
local COLUMN_GAP = 12
local DETAIL_H = 286 -- the player window under the bench
local DRAG_THRESHOLD = 4 -- pixels before a press becomes a drag rather than a tap
local TAP_SLOP = 20 -- pixels a press may wander and still count as a tap (a finger wobbles)

local PANEL_BG = Color3.fromRGB(23, 30, 44)
local CARD_BG = Color3.fromRGB(16, 24, 44)
local PITCH_GREEN = Color3.fromRGB(44, 128, 60)
local PITCH_STRIPE = Color3.fromRGB(50, 138, 66)
local LINE = Color3.fromRGB(225, 240, 225)

local function surname(name: string): string
	local last = name:match("(%S+)$")
	return last or name
end

-- ------------------------------------------------------------------ pitch art

local function line(parent: Instance, size: UDim2, pos: UDim2)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = LINE
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
end

local function circle(parent: Instance, size: number, pos: UDim2, filled: boolean)
	local c = Instance.new("Frame")
	c.BackgroundColor3 = LINE
	c.BackgroundTransparency = if filled then 0.3 else 1
	c.BorderSizePixel = 0
	c.Size = UDim2.fromOffset(size, size)
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = pos
	c.Parent = parent
	Theme.corner(c, math.ceil(size / 2))
	if not filled then
		local s = Theme.stroke(c)
		s.Color = LINE
		s.Transparency = 0.3
	end
end

-- Full pitch, our goal at the bottom. Mowing stripes, both boxes, centre circle.
local function drawPitch(parent: Frame)
	Theme.corner(parent, Theme.cardRadius)
	parent.ClipsDescendants = true
	if LineupBoard.BACKGROUND_IMAGE ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Art"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = LineupBoard.BACKGROUND_IMAGE
		img.ScaleType = Enum.ScaleType.Crop
		img.Parent = parent
		return
	end
	for i = 0, 7 do
		if i % 2 == 1 then
			local stripe = Instance.new("Frame")
			stripe.BackgroundColor3 = PITCH_STRIPE
			stripe.BorderSizePixel = 0
			stripe.Size = UDim2.new(1, 0, 1 / 8, 0)
			stripe.Position = UDim2.fromScale(0, i / 8)
			stripe.Parent = parent
		end
	end
	-- touchlines and goal lines
	line(parent, UDim2.new(0.92, 0, 0, 2), UDim2.fromScale(0.5, 0.03))
	line(parent, UDim2.new(0.92, 0, 0, 2), UDim2.fromScale(0.5, 0.97))
	line(parent, UDim2.new(0, 2, 0.94, 0), UDim2.fromScale(0.04, 0.5))
	line(parent, UDim2.new(0, 2, 0.94, 0), UDim2.fromScale(0.96, 0.5))
	-- halfway line and centre circle
	line(parent, UDim2.new(0.92, 0, 0, 2), UDim2.fromScale(0.5, 0.5))
	circle(parent, 84, UDim2.fromScale(0.5, 0.5), false)
	circle(parent, 6, UDim2.fromScale(0.5, 0.5), true)
	-- penalty boxes, goal areas and spots at both ends
	for _, endY in { 0.03, 0.97 } do
		local dir = if endY < 0.5 then 1 else -1
		line(parent, UDim2.new(0.5, 0, 0, 2), UDim2.fromScale(0.5, endY + dir * 0.17))
		line(parent, UDim2.new(0, 2, 0.17, 0), UDim2.fromScale(0.25, endY + dir * 0.085))
		line(parent, UDim2.new(0, 2, 0.17, 0), UDim2.fromScale(0.75, endY + dir * 0.085))
		line(parent, UDim2.new(0.24, 0, 0, 2), UDim2.fromScale(0.5, endY + dir * 0.06))
		line(parent, UDim2.new(0, 2, 0.06, 0), UDim2.fromScale(0.38, endY + dir * 0.03))
		line(parent, UDim2.new(0, 2, 0.06, 0), UDim2.fromScale(0.62, endY + dir * 0.03))
		circle(parent, 5, UDim2.fromScale(0.5, endY + dir * 0.115), true)
		line(parent, UDim2.new(0.14, 0, 0, 4), UDim2.fromScale(0.5, endY))
	end
end

-- Where slot `i` of the formation sits on the artwork.
local function slotPosition(slot: number): UDim2
	local spec = Pitch.FORMATION[slot]
	-- GK on the goal line of the artwork, FWD near the far box
	return UDim2.fromScale(0.5 + spec.x * 0.42, 0.9 - spec.depth * 1.0)
end

-- ------------------------------------------------------------------- widgets

-- X265: the dot says "not available" only by colour, and the number of matches
-- lived in the detail window. The chip spells both out on the row itself.
local function injuryChip(parent: Instance, matches: number)
	local chip = Instance.new("TextLabel")
	chip.Name = "InjuredChip"
	chip.Size = UDim2.fromOffset(44, 16)
	chip.Position = UDim2.new(1, -52, 1, -22)
	chip.BackgroundColor3 = Theme.colors.bad
	chip.BorderSizePixel = 0
	chip.Font = Theme.fonts.bold
	chip.TextSize = 12
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Text = ("INJ %d"):format(matches)
	chip.ZIndex = 3
	chip.Parent = parent
	Theme.corner(chip, Theme.chipRadius)
end

local function injuryDot(parent: Instance)
	local inj = Instance.new("Frame")
	inj.Name = "Injured"
	inj.Size = UDim2.fromOffset(12, 12)
	inj.Position = UDim2.new(1, -16, 0, 4)
	inj.BackgroundColor3 = Theme.colors.bad
	inj.BorderSizePixel = 0
	inj.ZIndex = 3
	inj.Parent = parent
	Theme.corner(inj, 6)
	Theme.stroke(inj)
end

-- A player with no appearances yet: an academy graduate or a new signing.
local function newChip(parent: Instance)
	if parent:FindFirstChild("NewChip") then
		return
	end
	local chip = Instance.new("TextLabel")
	chip.Name = "NewChip"
	chip.Size = UDim2.fromOffset(34, 15)
	chip.Position = UDim2.fromOffset(4, 4)
	chip.BackgroundColor3 = Theme.colors.info
	chip.BorderSizePixel = 0
	chip.Font = Theme.fonts.bold
	chip.TextSize = 11
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Text = "NEW"
	chip.ZIndex = 3
	chip.Parent = parent
	Theme.corner(chip, Theme.chipRadius)
end

-- X287: age belongs on the card now that players retire (X277). X285 coloured
-- it in the detail panel, but a player scanning the XI could not see who was 36
-- without tapping every face, so a retirement still arrived as a surprise.
local function ageColour(age: number): Color3
	if age >= Config.RetireMaxAge then
		return Theme.colors.bad
	elseif age >= Config.RetireAge then
		return Theme.colors.accent
	end
	return Theme.colors.muted
end

-- X287 (review): the same trap as the injury dot below - a card is built once
-- and kept, so an academy graduate wore NEW for his whole career and an age
-- froze at whatever it was the day the card appeared. Called on every update.
local function refreshAge(frame: Frame, p: Player)
	local label = frame:FindFirstChild("Age")
	if label and label:IsA("TextLabel") then
		label.Text = if string.find(label.Text, "aged", 1, true) then ("aged %d"):format(p.age) else ("%d"):format(p.age)
		label.TextColor3 = ageColour(p.age)
	end
	local chip = frame:FindFirstChild("NewChip")
	if (p.apps or 0) == 0 then
		if not chip then
			newChip(frame)
		end
	elseif chip then
		chip:Destroy()
	end
end

-- X265: cards and rows are cached per player and only built once, so an injury
-- picked up later never showed its dot at all. Called on every update.
local function refreshInjury(frame: Frame, p: Player, dotParent: Instance, withChip: boolean)
	local dot = dotParent:FindFirstChild("Injured")
	local chip = frame:FindFirstChild("InjuredChip")
	if p.injured > 0 then
		if not dot then
			injuryDot(dotParent)
		end
		if withChip then
			if chip and chip:IsA("TextLabel") then
				chip.Text = ("INJ %d"):format(p.injured)
			else
				injuryChip(frame, p.injured)
			end
		end
	else
		if dot then
			dot:Destroy()
		end
		if chip then
			chip:Destroy()
		end
	end
end

-- Pitch card: shoulder headshot, surname, role bottom-left, OVR bottom-right.
local function card(parent: Instance, p: Player, kit: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = ("Card%d"):format(p.id)
	f.Size = UDim2.fromOffset(CARD_W, CARD_H)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = CARD_BG
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, Theme.cardRadius)
	Theme.stroke(f)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, -8, 0, 64)
	face.Position = UDim2.fromOffset(4, 4)
	face.BackgroundTransparency = 1
	face.ClipsDescendants = true
	face.Parent = f
	Theme.corner(face, Theme.chipRadius)
	Headshot.attach(face, p.look or p.id, kit, p.number, { shoulders = true })
	Theme.stroke(face)

	Theme.text(f, surname(p.name), "body", {
		Name = "Name",
		Size = UDim2.new(1, -6, 0, 16),
		Position = UDim2.fromOffset(3, 70),
		TextSize = 13,
		Font = Theme.fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Theme.text(f, p.role, "muted", {
		Size = UDim2.fromOffset(30, 16),
		Position = UDim2.fromOffset(6, 88),
		TextSize = 11,
		Font = Theme.fonts.bold,
	})
	Theme.text(f, ("%d"):format(p.age), "muted", {
		Name = "Age",
		Size = UDim2.fromOffset(24, 16),
		Position = UDim2.fromOffset(36, 88),
		TextSize = 11,
		Font = Theme.fonts.bold,
		TextColor3 = ageColour(p.age),
	})
	Theme.text(f, ("%d"):format(p.overall), "body", {
		Size = UDim2.fromOffset(30, 18),
		Position = UDim2.new(1, -36, 0, 85),
		TextSize = 18,
		Font = Theme.fonts.display,
		TextColor3 = Theme.colors.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	if p.injured > 0 then
		injuryDot(f)
	end
	if (p.apps or 0) == 0 then
		newChip(f)
	end
	return f
end

-- Bench / reserve row: headshot left, name + role, OVR right.
local function row(parent: Instance, p: Player, kit: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = ("Row%d"):format(p.id)
	f.Size = UDim2.new(1, -6, 0, ROW_H)
	f.BackgroundColor3 = CARD_BG
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, Theme.cardRadius)
	Theme.stroke(f)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(ROW_H - 12, ROW_H - 12)
	face.Position = UDim2.fromOffset(6, 6)
	face.BackgroundTransparency = 1
	face.ClipsDescendants = true
	face.Parent = f
	Theme.corner(face, Theme.chipRadius)
	Headshot.attach(face, p.look or p.id, kit, p.number, { shoulders = true })
	Theme.stroke(face)

	Theme.text(f, surname(p.name), "body", {
		Name = "Name",
		Size = UDim2.new(1, -ROW_H - 60, 0, 22),
		Position = UDim2.fromOffset(ROW_H + 2, 10),
		TextSize = 16,
		Font = Theme.fonts.display,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Theme.text(f, p.role, "muted", {
		Size = UDim2.fromOffset(34, 16),
		Position = UDim2.fromOffset(ROW_H + 2, 34),
		TextSize = 12,
		Font = Theme.fonts.bold,
	})
	Theme.text(f, ("aged %d"):format(p.age), "muted", {
		Name = "Age",
		Size = UDim2.fromOffset(60, 16),
		Position = UDim2.fromOffset(ROW_H + 38, 34),
		TextSize = 12,
		Font = Theme.fonts.bold,
		TextColor3 = ageColour(p.age),
	})
	Theme.text(f, ("%d"):format(p.overall), "body", {
		Size = UDim2.fromOffset(50, ROW_H),
		Position = UDim2.new(1, -58, 0, 0),
		TextSize = 26,
		Font = Theme.fonts.display,
		TextColor3 = Theme.colors.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	if p.injured > 0 then
		injuryDot(face)
		injuryChip(f, p.injured)
	end
	return f
end

-- Dark rounded panel with a gold display title and an optional right-hand label.
local function panel(parent: Instance, name: string, title: string, size: UDim2, position: UDim2?): (Frame, Frame, TextLabel)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = PANEL_BG
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position or UDim2.fromOffset(0, 0)
	f.Parent = parent
	Theme.corner(f, Theme.radius)
	Theme.stroke(f)
	Theme.text(f, title, "display", {
		Name = "Title",
		Size = UDim2.new(0.6, 0, 0, 30),
		Position = UDim2.fromOffset(14, 10),
		TextSize = 22,
	})
	local right = Theme.text(f, "", "muted", {
		Name = "Right",
		Size = UDim2.new(0.4, -14, 0, 30),
		Position = UDim2.new(1, -14, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(12, 48)
	inner.Size = UDim2.new(1, -24, 1, -60)
	inner.Parent = f
	return f, inner, right
end

-- --------------------------------------------------------------- the board

type Entry = { frame: Frame, id: number }

export type Board = {
	frame: Frame,
	update: (club: Club, selectedId: number?, canDrag: boolean, canRelease: boolean) -> (),
	destroy: () -> (),
}

local function pointerInside(frame: GuiObject, pos: Vector2): boolean
	local a, s = frame.AbsolutePosition, frame.AbsoluteSize
	return pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
end

-- InputObject positions are already in GUI space (top bar inset removed), the
-- same space as AbsolutePosition. Verified in Studio: a press on a card's
-- centre reports the centre's AbsolutePosition.
local function guiPos(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

function LineupBoard.new(parent: GuiObject, opts: Options): Board
	local board = Instance.new("Frame")
	board.Name = "LineupBoard"
	board.BackgroundTransparency = 1
	board.Size = UDim2.fromScale(1, 1)
	board.Parent = parent

	-- ghosts float above everything in the same absolute space as the cards, so
	-- a drag can be positioned by simple subtraction whatever the GUI inset is
	local overlay = Instance.new("Frame")
	overlay.Name = "DragOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 100
	overlay.Active = false
	overlay.Parent = parent:FindFirstAncestorOfClass("ScreenGui") or parent

	-- ---------------------------------------------------------- left: the XI
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(PITCH_FRACTION, -COLUMN_GAP / 2, 1, 0)
	left.Parent = board
	local xiPanel, xiInner = panel(left, "StartingXI", "STARTING XI", UDim2.fromScale(1, 1))
	local formation = Theme.text(xiPanel, "4 - 4 - 2", "body", {
		Name = "Formation",
		Size = UDim2.fromOffset(96, 30),
		Position = UDim2.new(1, -14, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = CARD_BG,
		Font = Theme.fonts.display,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Theme.corner(formation, Theme.chipRadius)
	Theme.stroke(formation)

	local pitch = Instance.new("Frame")
	pitch.Name = "Pitch"
	pitch.BackgroundColor3 = PITCH_GREEN
	pitch.BorderSizePixel = 0
	pitch.Size = UDim2.fromScale(1, 1)
	pitch.Parent = xiInner
	drawPitch(pitch)

	-- ------------------------------------------------------ right: the bench
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(PITCH_FRACTION, COLUMN_GAP / 2, 0, 0)
	right.Size = UDim2.new(1 - PITCH_FRACTION, -COLUMN_GAP / 2, 1, 0)
	right.Parent = board

	local _, benchInner, benchCount = panel(right, "Bench", "SQUAD", UDim2.new(1, 0, 1, -DETAIL_H - COLUMN_GAP))

	-- the one and only scrolling region on this screen
	local benchScroll = Instance.new("ScrollingFrame")
	benchScroll.Name = "BenchList"
	benchScroll.BackgroundTransparency = 1
	benchScroll.BorderSizePixel = 0
	benchScroll.Size = UDim2.fromScale(1, 1)
	benchScroll.ScrollBarThickness = 5
	benchScroll.ScrollBarImageTransparency = 0.4
	benchScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	benchScroll.CanvasSize = UDim2.new()
	benchScroll.Parent = benchInner
	local benchLayout = Instance.new("UIListLayout")
	benchLayout.Padding = UDim.new(0, 8)
	benchLayout.SortOrder = Enum.SortOrder.LayoutOrder
	benchLayout.Parent = benchScroll

	local _, detailInner = panel(right, "Detail", "PLAYER", UDim2.new(1, 0, 0, DETAIL_H), UDim2.new(0, 0, 1, -DETAIL_H))

	-- ------------------------------------------------------------- the state
	local cards: { [number]: Frame } = {} -- player id -> pitch card
	local rows: { [number]: Frame } = {} -- player id -> bench / reserve row
	local headers: { [string]: Frame } = {} -- section heading rows, reused
	local empties: { [number]: Frame } = {} -- slot -> "empty" placeholder
	local entries: { Entry } = {}
	local byId: { [number]: Player } = {}
	local selectedId: number? = nil
	local canDrag, canRelease = false, false
	local detailFor: number? = nil
	local detailDirty = true

	local function strokeOf(frame: Frame): UIStroke?
		return frame:FindFirstChildOfClass("UIStroke")
	end

	local function setState(frame: Frame, state: Theme.StrokeState?)
		local s = strokeOf(frame)
		if s then
			Theme.setStroke(s, state)
		end
	end

	local function restingState(id: number): Theme.StrokeState?
		return if selectedId == id then "selected" else nil
	end

	-- ------------------------------------------------------- detail window
	local function clearDetail()
		for _, child in detailInner:GetChildren() do
			child:Destroy()
		end
	end

	local function stat(parent: Instance, index: number, title: string, value: string, color: Color3?)
		local col, line = (index - 1) % 3, math.floor((index - 1) / 3)
		local box = Instance.new("Frame")
		box.Name = title
		box.BackgroundColor3 = CARD_BG
		box.BorderSizePixel = 0
		box.Size = UDim2.new(1 / 3, -6, 0, 50)
		box.Position = UDim2.new(col / 3, col * 3, 0, line * 56)
		box.Parent = parent
		Theme.corner(box, Theme.chipRadius)
		Theme.stroke(box)
		Theme.text(box, title, "muted", {
			Size = UDim2.new(1, -12, 0, 14),
			Position = UDim2.fromOffset(8, 6),
			TextSize = 11,
			Font = Theme.fonts.bold,
		})
		Theme.text(box, value, "body", {
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.fromOffset(8, 20),
			TextSize = 22,
			Font = Theme.fonts.display,
			TextColor3 = color or Theme.colors.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end

	-- Rebuilt only when the selection changes: one small panel, never the screen.
	local function renderDetail()
		clearDetail()
		local p = if selectedId then byId[selectedId] else nil
		if not p then
			Theme.text(detailInner, "Select a player to see their details.", "muted", {
				Size = UDim2.fromScale(1, 1),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
			return
		end

		local face = Instance.new("Frame")
		face.Name = "Face"
		face.Size = UDim2.fromOffset(64, 64)
		face.BackgroundTransparency = 1
		face.ClipsDescendants = true
		face.Parent = detailInner
		Theme.corner(face, Theme.chipRadius)
		Headshot.attach(face, p.look or p.id, opts.kit, p.number, { shoulders = true })
		Theme.stroke(face)

		Theme.text(detailInner, p.name, "body", {
			Size = UDim2.new(1, -76, 0, 26),
			Position = UDim2.fromOffset(74, 4),
			TextSize = 20,
			Font = Theme.fonts.display,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local status = if p.injured > 0
			then ("Injured · out %d match%s"):format(p.injured, if p.injured == 1 then "" else "es")
			else ("Squad number %d"):format(p.number)
		Theme.text(detailInner, ("%s  ·  %s"):format(p.role, status), "muted", {
			Size = UDim2.new(1, -76, 0, 20),
			Position = UDim2.fromOffset(74, 30),
			TextSize = 13,
			TextColor3 = if p.injured > 0 then Theme.colors.bad else Theme.colors.muted,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local value = Squad.value(p :: any)
		Theme.text(detailInner, ("Value %s"):format(Theme.money(value)), "cash", {
			Size = UDim2.new(1, -76, 0, 20),
			Position = UDim2.fromOffset(74, 48),
			TextSize = 14,
		})

		local grid = Instance.new("Frame")
		grid.Name = "Stats"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(0, 74)
		grid.Size = UDim2.new(1, 0, 0, 106)
		grid.Parent = detailInner
		stat(grid, 1, "OVERALL", tostring(p.overall), Theme.colors.accent)
		stat(grid, 2, "POTENTIAL", tostring(p.potential or p.overall), Theme.colors.info)
		-- X285: now that veterans retire (X277), the age a player is at is a
		-- decision, not a statistic: sell them while they still fetch a fee, or
		-- keep them and take the free academy replacement. So the number is
		-- coloured once they are in the window and the window is spelled out.
		local ageColor = if p.age >= Config.RetireMaxAge
			then Theme.colors.bad
			elseif p.age >= Config.RetireAge then Theme.colors.accent
			else nil
		stat(grid, 3, "AGE", tostring(p.age), ageColor)
		stat(grid, 4, "APPS", tostring(p.apps or 0))
		stat(grid, 5, "GOALS", tostring(p.goals or 0))
		stat(grid, 6, "SHIRT", ("#%d"):format(p.number))

		if p.age >= Config.RetireAge then
			Theme.text(detailInner, if p.age >= Config.RetireMaxAge
				then "Retires at the end of this season."
				else "Near the end — may retire at the end of a season.", "muted", {
				Name = "Retirement",
				Size = UDim2.new(1, 0, 0, 20),
				-- above the sell button / XI advice, which own the bottom 34px
				-- (review of X285: at y=182 the two overlapped by 10px)
				Position = UDim2.new(0, 0, 1, -58),
				TextSize = 12,
				TextColor3 = ageColor or Theme.colors.muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end

		-- Sell sits in the window, always on screen. Two taps: arm, then confirm.
		local inXi = cards[p.id] ~= nil
		if not canRelease then
			return
		end
		if inXi then
			-- X203: canDrag is off here only because Auto Squad is on
			local advice = if canDrag then "In the starting XI. Move them out of the team to sell." else "In the starting XI. Turn Auto Squad off to move them out and sell."
			Theme.text(detailInner, advice, "muted", {
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 1, -30),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
			return
		end
		local sell = Theme.button(detailInner, ("SELL  ·  %s"):format(Theme.money(value)), "danger", {
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.new(0, 0, 1, -34),
			TextSize = 14,
			Font = Theme.fonts.display,
		})
		local armed = false
		sell.Activated:Connect(function()
			if not armed then
				armed = true
				sell.Text = ("TAP AGAIN TO CONFIRM  ·  %s"):format(Theme.money(value))
				sell.BackgroundColor3 = Theme.colors.accent
				sell.TextColor3 = Theme.colors.bg
				return
			end
			opts.onSell(p.id)
		end)
	end

	-- ------------------------------------------------------------ list header
	local function sectionHeader(key: string, title: string, count: number, order: number)
		local head = headers[key]
		if not head then
			head = Instance.new("Frame")
			head.Name = key
			head.BackgroundTransparency = 1
			head.Size = UDim2.new(1, -6, 0, 24)
			head.Parent = benchScroll
			Theme.text(head, title, "display", { Name = "Title", Size = UDim2.new(0.6, 0, 1, 0), TextSize = 16 })
			Theme.text(head, "", "muted", {
				Name = "Count",
				Size = UDim2.new(0.4, 0, 1, 0),
				Position = UDim2.fromScale(1, 0),
				AnchorPoint = Vector2.new(1, 0),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
			});
			headers[key] = head
		end
		(head:FindFirstChild("Count") :: TextLabel).Text = ("%d player%s"):format(count, if count == 1 then "" else "s")
		head.LayoutOrder = order
		head.Visible = true
	end

	-- ------------------------------------------------------------- the update
	local function update(club: Club, newSelected: number?, drag: boolean, release: boolean)
		local previous = selectedId
		selectedId, canDrag, canRelease = newSelected, drag, release
		table.clear(byId)
		for _, p in club.players do
			byId[p.id] = p
		end

		-- starting XI: a card belongs to a player, so a swap only moves cards
		local wantCard: { [number]: boolean } = {}
		for slot = 1, #Pitch.FORMATION do
			local id = club.lineup.xi[slot]
			local p = if id then byId[id] else nil
			if p then
				wantCard[p.id] = true
				local c = cards[p.id]
				if not c then
					c = card(pitch, p, opts.kit)
					cards[p.id] = c
				end
				refreshInjury(c, p, c, false)
				refreshAge(c, p) -- X287 (review)
				c.Position = slotPosition(slot)
				if empties[slot] then
					empties[slot]:Destroy()
					empties[slot] = nil
				end
			elseif not empties[slot] then
				local empty = Instance.new("Frame")
				empty.Name = ("Empty%d"):format(slot)
				empty.Size = UDim2.fromOffset(CARD_W, CARD_H)
				empty.AnchorPoint = Vector2.new(0.5, 0.5)
				empty.Position = slotPosition(slot)
				empty.BackgroundColor3 = CARD_BG
				empty.BackgroundTransparency = 0.4
				empty.BorderSizePixel = 0
				empty.Parent = pitch
				Theme.corner(empty, Theme.cardRadius)
				Theme.stroke(empty, "danger")
				Theme.text(empty, Pitch.ROLES[slot] .. "\nempty", "body", {
					Size = UDim2.fromScale(1, 1),
					TextSize = 12,
					TextColor3 = Theme.colors.bad,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				empties[slot] = empty
			end
		end
		for id, frame in cards do
			if not wantCard[id] then
				frame:Destroy()
				cards[id] = nil
			end
		end

		-- bench then reserves, as one scrolling list with two headings
		local onBench: { [number]: boolean } = {}
		local order, wantRow = 0, {}
		local function place(p: Player)
			order += 1
			local r = rows[p.id]
			if not r then
				r = row(benchScroll, p, opts.kit)
				rows[p.id] = r
			end
			refreshInjury(r, p, r:FindFirstChild("Face") or r, true)
			refreshAge(r, p) -- X287 (review)
			r.LayoutOrder = order
			wantRow[p.id] = true
		end
		local bench: { Player } = {}
		for _, id in club.lineup.bench do
			local p = byId[id]
			if p then
				onBench[id] = true
				table.insert(bench, p)
			end
		end
		local reserves: { Player } = {}
		for _, p in club.players do
			if not onBench[p.id] and not wantCard[p.id] then
				table.insert(reserves, p)
			end
		end
		-- X265: squad order put the best reserve anywhere in the list once a few
		-- signings landed. Fit players first, then strongest, then by shirt.
		table.sort(reserves, function(a, b)
			local aFit, bFit = a.injured == 0, b.injured == 0
			if aFit ~= bFit then
				return aFit
			end
			if a.overall ~= b.overall then
				return a.overall > b.overall
			end
			return a.number < b.number
		end)
		order += 1
		sectionHeader("BenchHead", "BENCH", #bench, order)
		for _, p in bench do
			place(p)
		end
		if #reserves > 0 then
			order += 1
			sectionHeader("ReserveHead", "RESERVES", #reserves, order)
			for _, p in reserves do
				place(p)
			end
		elseif headers.ReserveHead then
			headers.ReserveHead.Visible = false
		end
		for id, frame in rows do
			if not wantRow[id] then
				frame:Destroy()
				rows[id] = nil
			end
		end
		benchCount.Text = ("%d players"):format(#club.players)

		-- hit-test list, and the resting outline for everything on screen
		table.clear(entries)
		for id, frame in cards do
			table.insert(entries, { frame = frame, id = id })
			setState(frame, restingState(id))
		end
		for id, frame in rows do
			table.insert(entries, { frame = frame, id = id })
			setState(frame, restingState(id))
		end

		-- the detail window is the only thing rebuilt, and only when it changed
		if detailDirty or previous ~= selectedId or detailFor ~= selectedId then
			detailDirty = false
			detailFor = selectedId
			renderDetail()
		end
	end

	-- ---------------------------------------------------------- drag & drop
	local function cardAt(pos: Vector2, except: number?): Entry?
		for _, entry in entries do
			-- X241: bench cards scrolled out of the list's view can't be hit
			local clipped = entry.frame:IsDescendantOf(benchScroll) and not pointerInside(benchScroll, pos)
			if entry.id ~= except and entry.frame.Parent and not clipped and pointerInside(entry.frame, pos) then
				return entry
			end
		end
		return nil
	end

	-- One listener with manual hit-testing, so mouse and touch behave the same
	-- and nothing depends on which child of the card is under the pointer.
	local began = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if not board.Parent or not board.Visible then
			return
		end
		local start = guiPos(input)
		local entry = cardAt(start, nil)
		if not entry then
			return
		end
		local frame, id = entry.frame, entry.id
		local restBackground = frame.BackgroundTransparency
		-- press feedback straight away, so a click never looks ignored
		setState(frame, "selected")
		local moved = false
		local travelled = 0 -- furthest the pointer got from the press, in pixels
		local onBench = frame:IsDescendantOf(benchScroll)
		local swiping = false -- a vertical drag on the bench: scrolling, not dragging
		local ghost: Frame? = nil
		local target: Entry? = nil
		local grab = start - frame.AbsolutePosition
		local changed: RBXScriptConnection
		local ended: RBXScriptConnection

		local function clearTarget()
			if target then
				setState(target.frame, restingState(target.id))
				target = nil
			end
		end

		local function finish(pos: Vector2)
			changed:Disconnect()
			ended:Disconnect()
			if ghost then
				ghost:Destroy()
			end
			frame.BackgroundTransparency = restBackground
			for _, d in frame:GetChildren() do
				if d:IsA("GuiObject") then
					d.Visible = true
				end
			end
			setState(frame, restingState(id))
			local dropped = target
			clearTarget()
			benchScroll.ScrollingEnabled = true
			if moved or swiping or travelled >= TAP_SLOP then
				-- X241: a press that wandered is never a tap (a scroll, or a drag
				-- attempt with Auto Squad on)
				if moved and dropped then
					opts.onSwap(id, dropped.id)
				end
				return
			end
			-- a tap: select, or swap with the earlier selection
			if selectedId == nil then
				opts.onSelect(id)
			elseif selectedId == id then
				opts.onSelect(nil)
			elseif canDrag then
				opts.onSwap(selectedId, id)
			else
				opts.onSelect(id)
			end
		end

		-- X241: follow only the finger (or mouse) that pressed; a second touch
		-- (thumbstick, camera) must not move or drop the card
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		local function ours(i: InputObject, moving: boolean): boolean
			if isTouch then
				return i == input
			end
			return i.UserInputType == (if moving then Enum.UserInputType.MouseMovement else Enum.UserInputType.MouseButton1)
		end

		changed = UserInputService.InputChanged:Connect(function(i)
			if not ours(i, true) then
				return
			end
			local pos = guiPos(i)
			travelled = math.max(travelled, (pos - start).Magnitude)
			if not canDrag or (not moved and (pos - start).Magnitude < DRAG_THRESHOLD) then
				return
			end
			if not moved and onBench and math.abs(pos.Y - start.Y) > math.abs(pos.X - start.X) then
				-- a mostly vertical swipe on the bench list scrolls it instead, and
				-- keeps scrolling even if the finger curves sideways later
				swiping = true
			end
			if swiping then
				return
			end
			if not moved then
				moved = true
				benchScroll.ScrollingEnabled = false
				-- X252: the overlay is outside the scaled panel, so the clone
				-- carries the same scale itself and is sized in design pixels
				local k = Theme.scaleOf(frame)
				local g = frame:Clone()
				g.Name = "Ghost"
				g.AnchorPoint = Vector2.zero
				local ghostScale = Instance.new("UIScale")
				ghostScale.Scale = k
				ghostScale.Parent = g
				g.Size = UDim2.fromOffset(frame.AbsoluteSize.X / k, frame.AbsoluteSize.Y / k)
				g.Visible = true
				g.ZIndex = 100
				for _, d in g:GetDescendants() do
					if d:IsA("GuiObject") then
						d.ZIndex = 100
					end
				end
				g.BackgroundTransparency = 0 -- opaque, so it reads over any panel
				g.Parent = overlay
				ghost = g
				-- the card is "in hand": leave an empty slot behind rather than
				-- hiding the frame, so the bench list does not reflow mid-drag
				frame.BackgroundTransparency = 0.75
				for _, d in frame:GetChildren() do
					if d:IsA("GuiObject") then
						d.Visible = false
					end
				end
			end
			-- overlay and cards share one absolute space, whatever the GUI inset is
			local origin = overlay.AbsolutePosition
			local g = ghost :: Frame
			g.Position = UDim2.fromOffset(pos.X - grab.X - origin.X, pos.Y - grab.Y - origin.Y)
			local hit = cardAt(pos, id)
			if hit ~= target then
				clearTarget()
				if hit then
					target = hit
					setState(hit.frame, "target")
				end
			end
		end)
		ended = UserInputService.InputEnded:Connect(function(i)
			if ours(i, false) then
				finish(guiPos(i))
			end
		end)
	end)

	local function destroy()
		began:Disconnect()
		overlay:Destroy()
		board:Destroy()
	end
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(game) then
			began:Disconnect()
			overlay:Destroy()
		end
	end)

	renderDetail()
	return { frame = board, update = update, destroy = destroy }
end

return LineupBoard
