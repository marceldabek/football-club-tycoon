--!strict
-- Squad board: a STARTING XI panel with headshot cards on a full pitch, and a
-- BENCH / RESERVES column of list rows on the right. Cards drag onto each
-- other to swap; a tap selects and a second tap swaps (the touch fallback).
-- Selecting a bench or reserve player shows a Sell strip. All rules stay on
-- the server: the board only fires `swap` and `release` with player ids.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Theme = require(script.Parent.Theme)
local Headshot = require(script.Parent.Headshot)
local Squad = require(ReplicatedStorage.Shared.Squad)

local LineupBoard = {}

export type Player = {
	id: number,
	name: string,
	number: number,
	role: string,
	age: number,
	overall: number,
	injured: number,
	look: number?,
}
export type Club = {
	players: { Player },
	lineup: { xi: { number }, bench: { number } },
}
export type Options = {
	club: Club,
	kit: Color3,
	canDrag: boolean,
	canRelease: boolean,
	selectedId: number?,
	layoutOrder: number,
	onSwap: (number, number) -> (),
	onSelect: (number?) -> (),
	onSell: (number) -> (),
	lockScroll: (boolean) -> (),
}

-- Optional pitch artwork (rbxassetid://...). Empty draws the pitch from frames.
LineupBoard.BACKGROUND_IMAGE = "rbxassetid://109275890815433" -- assets/references/pitch-board.png, 1536x1024

-- TEMP layout
local CARD_W, CARD_H = 86, 108
local ROW_H = 62
local PITCH_H = 500 -- the artwork is 3:2; Crop trims the sides a little
local PITCH_FRACTION = 0.64
local COLUMN_GAP = 12
local DRAG_THRESHOLD = 6 -- pixels before a press becomes a drag rather than a tap

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
		Theme.stroke(c, 0.3, LINE)
	end
end

-- Full pitch, our goal at the bottom. Mowing stripes, both boxes, centre circle.
local function drawPitch(parent: Frame)
	Theme.corner(parent, 8)
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

-- ------------------------------------------------------------------- cards

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
	Theme.stroke(inj, 0.2, Color3.new(1, 1, 1))
end

-- Pitch card: shoulder headshot, surname, role bottom-left, OVR bottom-right.
local function card(parent: Instance, p: Player, kit: Color3, selected: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = ("Card%d"):format(p.id)
	f.Size = UDim2.fromOffset(CARD_W, CARD_H)
	f.BackgroundColor3 = CARD_BG
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, 8)
	Theme.stroke(f, if selected then 0 else 0.55, if selected then Theme.colors.accent else Color3.fromRGB(120, 150, 210))

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, -8, 0, 64)
	face.Position = UDim2.fromOffset(4, 4)
	face.BackgroundTransparency = 1
	face.ClipsDescendants = true
	face.Parent = f
	Theme.corner(face, 6)
	local vf = Headshot.attach(face, p.look or p.id, kit, p.number, { shoulders = true })
	vf.BackgroundTransparency = 1

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
		Size = UDim2.fromOffset(34, 16),
		Position = UDim2.fromOffset(6, 88),
		TextSize = 11,
		Font = Theme.fonts.bold,
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
	return f
end

-- Bench / reserve row: headshot left, name + role, OVR right.
local function row(parent: Instance, p: Player, kit: Color3, selected: boolean, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = ("Row%d"):format(p.id)
	f.Size = UDim2.new(1, 0, 0, ROW_H)
	f.BackgroundColor3 = CARD_BG
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.Parent = parent
	Theme.corner(f, 8)
	Theme.stroke(f, if selected then 0 else 0.6, if selected then Theme.colors.accent else Color3.fromRGB(120, 150, 210))

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(ROW_H - 12, ROW_H - 12)
	face.Position = UDim2.fromOffset(6, 6)
	face.BackgroundTransparency = 1
	face.ClipsDescendants = true
	face.Parent = f
	Theme.corner(face, 6)
	local vf = Headshot.attach(face, p.look or p.id, kit, p.number, { shoulders = true })
	vf.BackgroundTransparency = 1

	Theme.text(f, surname(p.name), "body", {
		Name = "Name",
		Size = UDim2.new(1, -ROW_H - 60, 0, 22),
		Position = UDim2.fromOffset(ROW_H + 2, 10),
		TextSize = 16,
		Font = Theme.fonts.display,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Theme.text(f, p.role, "muted", {
		Size = UDim2.fromOffset(60, 16),
		Position = UDim2.fromOffset(ROW_H + 2, 34),
		TextSize = 12,
		Font = Theme.fonts.bold,
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
	end
	return f
end

-- ------------------------------------------------------------- drag & drop

type CardEntry = { frame: Frame, id: number }

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

local function cardAt(entries: { CardEntry }, pos: Vector2, except: number?): CardEntry?
	for _, entry in entries do
		if entry.id ~= except and entry.frame.Parent and pointerInside(entry.frame, pos) then
			return entry
		end
	end
	return nil
end

-- One listener per board on UserInputService with manual hit-testing, so
-- mouse and touch behave the same and nothing depends on which child of the
-- card happens to be under the pointer.
local function wireDrag(board: Frame, entries: { CardEntry }, opts: Options, overlay: ScreenGui)
	local began = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		-- taps always select (so a reserve can be sold with Auto Squad on);
		-- dragging and swapping need canDrag
		if not board.Parent then
			return
		end
		local start = guiPos(input)
		local entry = cardAt(entries, start, nil)
		if not entry then
			return
		end
		local frame, id = entry.frame, entry.id
		local moved = false
		local ghost: Frame? = nil
		local grab = start - frame.AbsolutePosition
		local changed: RBXScriptConnection
		local ended: RBXScriptConnection

		local function finish(pos: Vector2)
			changed:Disconnect()
			ended:Disconnect()
			opts.lockScroll(false)
			if ghost then
				ghost:Destroy()
			end
			if moved then
				local target = cardAt(entries, pos, id)
				if target then
					opts.onSwap(id, target.id)
				end
				return
			end
			-- a tap: select, or swap with the earlier selection
			local sel = opts.selectedId
			if sel == nil then
				opts.onSelect(id)
			elseif sel == id then
				opts.onSelect(nil)
			elseif opts.canDrag then
				opts.onSwap(sel, id)
			else
				opts.onSelect(id)
			end
		end

		changed = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local pos = guiPos(i)
			if not opts.canDrag or (not moved and (pos - start).Magnitude < DRAG_THRESHOLD) then
				return
			end
			if not moved then
				moved = true
				opts.lockScroll(true)
				local g = frame:Clone()
				g.Name = "Ghost"
				g.AnchorPoint = Vector2.zero
				g.Size = UDim2.fromOffset(frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
				g.ZIndex = 50
				for _, d in g:GetDescendants() do
					if d:IsA("GuiObject") then
						d.ZIndex = 50
					end
				end
				g.BackgroundTransparency = 0.15
				g.Parent = overlay
				ghost = g
			end
			local g = ghost :: Frame
			g.Position = UDim2.fromOffset(pos.X - grab.X, pos.Y - grab.Y)
		end)
		ended = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				finish(guiPos(i))
			end
		end)
	end)
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(game) then
			began:Disconnect()
		end
	end)
end

-- ------------------------------------------------------------------- render

-- Dark rounded panel with a gold display title and an optional right-hand label.
local function panel(parent: Instance, name: string, title: string, right: string?): (Frame, Frame)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = PANEL_BG
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Parent = parent
	Theme.corner(f, 10)
	Theme.stroke(f, 0.88)
	Theme.text(f, title, "display", {
		Name = "Title",
		Size = UDim2.new(0.6, 0, 0, 30),
		Position = UDim2.fromOffset(14, 10),
		TextSize = 22,
	})
	if right then
		Theme.text(f, right, "muted", {
			Name = "Right",
			Size = UDim2.new(0.4, -14, 0, 30),
			Position = UDim2.new(1, -14, 0, 10),
			AnchorPoint = Vector2.new(1, 0),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	end
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(12, 48)
	inner.Size = UDim2.new(1, -24, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = f
	return f, inner
end

local function listSection(parent: Instance, title: string, count: number, order: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = title
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.LayoutOrder = order
	holder.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 22)
	head.LayoutOrder = 0
	head.Parent = holder
	Theme.text(head, title, "display", { Size = UDim2.new(0.6, 0, 1, 0), TextSize = 16 })
	Theme.text(head, ("%d players"):format(count), "muted", {
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return holder
end

-- Sell strip for the selected bench / reserve player. Two taps: the first
-- arms the button and shows the fee, the second sells.
local function sellStrip(parent: Instance, p: Player, order: number, onSell: (number) -> ())
	local value = Squad.value(p :: any)
	local strip = Instance.new("Frame")
	strip.Name = "Sell"
	strip.BackgroundColor3 = CARD_BG
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, 0, 0, 78)
	strip.LayoutOrder = order
	strip.Parent = parent
	Theme.corner(strip, 8)
	Theme.stroke(strip, 0.2, Theme.colors.accent)
	Theme.text(strip, ("%s  ·  %s  ·  OVR %d  ·  age %d"):format(p.name, p.role, p.overall, p.age), "body", {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 6),
		TextSize = 13,
		Font = Theme.fonts.bold,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Theme.text(strip, ("Transfer value %s. Selling adds it to club cash."):format(Theme.money(value)), "muted", {
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(8, 26),
		TextSize = 12,
	})
	local sell = Theme.button(strip, ("SELL  ·  %s"):format(Theme.money(value)), "danger", {
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 44),
		TextSize = 13,
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
		onSell(p.id)
	end)
end

function LineupBoard.render(parent: GuiObject, opts: Options): Frame
	local club = opts.club
	local byId: { [number]: Player } = {}
	for _, p in club.players do
		byId[p.id] = p
	end

	local board = Instance.new("Frame")
	board.Name = "LineupBoard"
	board.BackgroundTransparency = 1
	board.Size = UDim2.new(1, -10, 0, 0)
	board.AutomaticSize = Enum.AutomaticSize.Y
	board.LayoutOrder = opts.layoutOrder
	board.Parent = parent

	-- ghosts live on their own ScreenGui so they float above the panel
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "LineupDrag"
	overlay.DisplayOrder = 50
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = false -- same GUI space as the cards' AbsolutePosition
	overlay.Parent = parent:FindFirstAncestorOfClass("ScreenGui") and (parent:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui).Parent or parent
	board.AncestryChanged:Connect(function()
		if not board:IsDescendantOf(game) then
			overlay:Destroy()
		end
	end)

	local entries: { CardEntry } = {}
	local used: { [number]: boolean } = {}
	local inXi: { [number]: boolean } = {}

	-- left: STARTING XI panel with the pitch
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(PITCH_FRACTION, -COLUMN_GAP / 2, 0, 0)
	left.AutomaticSize = Enum.AutomaticSize.Y
	left.Parent = board
	local xiPanel, xiInner = panel(left, "StartingXI", "STARTING XI")
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
	Theme.corner(formation, 8)
	Theme.stroke(formation, 0.6, Color3.fromRGB(120, 150, 210))

	local pitch = Instance.new("Frame")
	pitch.Name = "Pitch"
	pitch.BackgroundColor3 = PITCH_GREEN
	pitch.BorderSizePixel = 0
	pitch.Size = UDim2.new(1, 0, 0, PITCH_H)
	pitch.Parent = xiInner
	drawPitch(pitch)
	for slot, spec in Pitch.FORMATION do
		local u = 0.5 + spec.x * 0.42
		local v = 0.9 - spec.depth * 1.0 -- GK on the goal line of the artwork, FWD near the far box
		local id = club.lineup.xi[slot]
		local p = if id then byId[id] else nil
		if p then
			used[p.id] = true
			inXi[p.id] = true
			local c = card(pitch, p, opts.kit, opts.selectedId == p.id)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(u, v)
			table.insert(entries, { frame = c, id = p.id })
		else
			local empty = Instance.new("Frame")
			empty.Size = UDim2.fromOffset(CARD_W, CARD_H)
			empty.AnchorPoint = Vector2.new(0.5, 0.5)
			empty.Position = UDim2.fromScale(u, v)
			empty.BackgroundColor3 = CARD_BG
			empty.BackgroundTransparency = 0.4
			empty.BorderSizePixel = 0
			empty.Parent = pitch
			Theme.corner(empty, 8)
			Theme.stroke(empty, 0.3, Theme.colors.bad)
			Theme.text(empty, Pitch.ROLES[slot] .. "\nempty", "body", {
				Size = UDim2.fromScale(1, 1),
				TextSize = 12,
				TextColor3 = Theme.colors.bad,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
	end

	-- right: BENCH panel with the bench rows, reserves below, sell strip
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(PITCH_FRACTION, COLUMN_GAP / 2, 0, 0)
	right.Size = UDim2.new(1 - PITCH_FRACTION, -COLUMN_GAP / 2, 0, 0)
	right.AutomaticSize = Enum.AutomaticSize.Y
	right.Parent = board
	local benchPanel, benchInner = panel(right, "Bench", "BENCH", ("%d players"):format(#club.lineup.bench))
	local benchLayout = Instance.new("UIListLayout")
	benchLayout.Padding = UDim.new(0, 10)
	benchLayout.SortOrder = Enum.SortOrder.LayoutOrder
	benchLayout.Parent = benchInner

	local benchList = Instance.new("Frame")
	benchList.Name = "BenchList"
	benchList.BackgroundTransparency = 1
	benchList.Size = UDim2.new(1, 0, 0, 0)
	benchList.AutomaticSize = Enum.AutomaticSize.Y
	benchList.LayoutOrder = 1
	benchList.Parent = benchInner
	local benchListLayout = Instance.new("UIListLayout")
	benchListLayout.Padding = UDim.new(0, 8)
	benchListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	benchListLayout.Parent = benchList
	for i, id in club.lineup.bench do
		local p = byId[id]
		if p then
			used[p.id] = true
			local r = row(benchList, p, opts.kit, opts.selectedId == p.id, i)
			table.insert(entries, { frame = r, id = p.id })
		end
	end

	local reserves = {}
	for _, p in club.players do
		if not used[p.id] then
			table.insert(reserves, p)
		end
	end
	if #reserves > 0 then
		local list = listSection(benchInner, "RESERVES", #reserves, 2)
		for i, p in reserves do
			local r = row(list, p, opts.kit, opts.selectedId == p.id, i)
			table.insert(entries, { frame = r, id = p.id })
		end
	end

	-- selling: only the owner, only players outside the XI (the server enforces both too)
	local selected = if opts.selectedId then byId[opts.selectedId] else nil
	if selected and opts.canRelease and not inXi[selected.id] then
		sellStrip(benchInner, selected, 3, opts.onSell)
	else
		Theme.text(benchInner, "Select a reserve to view details or sell.", "muted", {
			Name = "Hint",
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 3,
		})
	end
	benchPanel.Visible = true

	wireDrag(board, entries, opts, overlay)
	return board
end

return LineupBoard
