--!strict
-- FIFA / FM-style lineup board: the starting XI as headshot cards on a small
-- pitch (own half, own goal at the bottom), the bench and reserves as card
-- strips below. Cards drag onto each other to swap; a tap selects and a second
-- tap swaps (the touch fallback). All rules stay on the server: the board only
-- fires the existing `swap` action with two player ids.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pitch = require(ReplicatedStorage.Shared.Pitch)
local Theme = require(script.Parent.Theme)
local Headshot = require(script.Parent.Headshot)

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
	onRelease: (number) -> (),
	lockScroll: (boolean) -> (),
}

-- TEMP layout
local CARD_W, CARD_H = 64, 86
local PITCH_H = 380
local STRIP_H = CARD_H + 30
local DRAG_THRESHOLD = 6 -- pixels before a press becomes a drag rather than a tap

local PITCH_GREEN = Color3.fromRGB(46, 120, 60)
local LINE = Color3.fromRGB(215, 235, 215)

local function surname(name: string): string
	local last = name:match("(%S+)$")
	return last or name
end

-- ------------------------------------------------------------------ pitch art

local function line(parent: Instance, size: UDim2, pos: UDim2)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = LINE
	f.BackgroundTransparency = 0.35
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
end

local function drawPitch(parent: Frame)
	Theme.corner(parent, 8)
	-- touchlines
	line(parent, UDim2.new(1, -8, 0, 2), UDim2.fromScale(0.5, 0.02))
	line(parent, UDim2.new(1, -8, 0, 2), UDim2.fromScale(0.5, 0.98))
	line(parent, UDim2.new(0, 2, 1, -8), UDim2.fromScale(0.03, 0.5))
	line(parent, UDim2.new(0, 2, 1, -8), UDim2.fromScale(0.97, 0.5))
	-- halfway line near the top: the board shows our half
	line(parent, UDim2.new(1, -8, 0, 2), UDim2.fromScale(0.5, 0.05))
	-- penalty box and goal at the bottom
	line(parent, UDim2.new(0.44, 0, 0, 2), UDim2.fromScale(0.5, 0.8))
	line(parent, UDim2.new(0, 2, 0.18, 0), UDim2.fromScale(0.28, 0.89))
	line(parent, UDim2.new(0, 2, 0.18, 0), UDim2.fromScale(0.72, 0.89))
	line(parent, UDim2.new(0.16, 0, 0, 3), UDim2.fromScale(0.5, 0.98))
	-- centre circle arc peeking in at the top
	local circle = Instance.new("Frame")
	circle.BackgroundTransparency = 1
	circle.Size = UDim2.fromOffset(90, 90)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.05)
	circle.Parent = parent
	Theme.corner(circle, 45)
	Theme.stroke(circle, 0.35, LINE)
end

-- ------------------------------------------------------------------- cards

local function card(parent: Instance, p: Player, kit: Color3, selected: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = ("Card%d"):format(p.id)
	f.Size = UDim2.fromOffset(CARD_W, CARD_H)
	f.BackgroundColor3 = Theme.colors.bg3
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, 6)
	Theme.stroke(f, if selected then 0 else 0.7, if selected then Theme.colors.accent else Theme.colors.text)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, -4, 0, 52)
	face.Position = UDim2.fromOffset(2, 2)
	face.BackgroundTransparency = 1
	face.ClipsDescendants = true
	face.Parent = f
	Theme.corner(face, 5)
	Headshot.attach(face, p.look or p.id, kit, p.number)

	local nameLabel = Theme.text(f, surname(p.name), "body", {
		Size = UDim2.new(1, -4, 0, 14),
		Position = UDim2.fromOffset(2, 55),
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	nameLabel.Name = "Name"

	Theme.text(f, ("%d"):format(p.number), "body", {
		Size = UDim2.fromOffset(26, 14),
		Position = UDim2.fromOffset(3, 70),
		TextSize = 11,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.text(f, ("%d"):format(p.overall), "body", {
		Size = UDim2.fromOffset(26, 14),
		Position = UDim2.new(1, -29, 0, 70),
		TextSize = 12,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Theme.colors.accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Theme.text(f, p.role, "body", {
		Size = UDim2.fromOffset(28, 12),
		Position = UDim2.new(0.5, -14, 0, 71),
		TextSize = 9,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	if p.injured > 0 then
		local inj = Instance.new("Frame")
		inj.Size = UDim2.fromOffset(12, 12)
		inj.Position = UDim2.new(1, -15, 0, 3)
		inj.BackgroundColor3 = Theme.colors.bad
		inj.BorderSizePixel = 0
		inj.ZIndex = 3
		inj.Parent = f
		Theme.corner(inj, 6)
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
		if not opts.canDrag or not board.Parent then
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
			else
				opts.onSwap(sel, id)
			end
		end

		changed = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local pos = guiPos(i)
			if not moved and (pos - start).Magnitude < DRAG_THRESHOLD then
				return
			end
			if not moved then
				moved = true
				opts.lockScroll(true)
				local g = frame:Clone()
				g.Name = "Ghost"
				g.AnchorPoint = Vector2.zero
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

local function strip(parent: Frame, title: string, order: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = title
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, STRIP_H)
	holder.LayoutOrder = order
	holder.Parent = parent
	Theme.text(holder, title, "body", {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.colors.accent,
	})
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 24)
	grid.Size = UDim2.new(1, 0, 0, CARD_H)
	grid.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid
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
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = board

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

	-- pitch with the XI
	local pitch = Instance.new("Frame")
	pitch.Name = "Pitch"
	pitch.BackgroundColor3 = PITCH_GREEN
	pitch.BorderSizePixel = 0
	pitch.Size = UDim2.new(1, 0, 0, PITCH_H)
	pitch.LayoutOrder = 1
	pitch.Parent = board
	drawPitch(pitch)
	for slot, spec in Pitch.FORMATION do
		local u = 0.5 + spec.x * 0.42
		local v = 0.9 - spec.depth * 1.1
		local id = club.lineup.xi[slot]
		local p = if id then byId[id] else nil
		if p then
			used[p.id] = true
			local c = card(pitch, p, opts.kit, opts.selectedId == p.id)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(u, v)
			table.insert(entries, { frame = c, id = p.id })
		else
			local empty = Instance.new("Frame")
			empty.Size = UDim2.fromOffset(CARD_W, CARD_H)
			empty.AnchorPoint = Vector2.new(0.5, 0.5)
			empty.Position = UDim2.fromScale(u, v)
			empty.BackgroundColor3 = Theme.colors.bg
			empty.BackgroundTransparency = 0.4
			empty.BorderSizePixel = 0
			empty.Parent = pitch
			Theme.corner(empty, 6)
			Theme.text(empty, Pitch.ROLES[slot] .. "\nempty", "body", {
				Size = UDim2.fromScale(1, 1),
				TextSize = 11,
				TextColor3 = Theme.colors.bad,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
	end

	-- bench strip
	local bench = strip(board, "BENCH", 2)
	for i, id in club.lineup.bench do
		local p = byId[id]
		if p then
			used[p.id] = true
			local c = card(bench, p, opts.kit, opts.selectedId == p.id)
			c.LayoutOrder = i
			table.insert(entries, { frame = c, id = p.id })
		end
	end

	-- reserves strip (with release)
	local reserves = {}
	for _, p in club.players do
		if not used[p.id] then
			table.insert(reserves, p)
		end
	end
	if #reserves > 0 then
		local grid = strip(board, ("RESERVES (%d)"):format(#reserves), 3)
		for i, p in reserves do
			local c = card(grid, p, opts.kit, opts.selectedId == p.id)
			c.LayoutOrder = i
			table.insert(entries, { frame = c, id = p.id })
			if opts.canRelease then
				local rel = Theme.button(c, "✕", "danger", {
					Size = UDim2.fromOffset(18, 18),
					Position = UDim2.fromOffset(2, 2),
					TextSize = 11,
					ZIndex = 4,
				})
				rel.Activated:Connect(function()
					opts.onRelease(p.id)
				end)
			end
		end
	end

	wireDrag(board, entries, opts, overlay)
	return board
end

return LineupBoard
