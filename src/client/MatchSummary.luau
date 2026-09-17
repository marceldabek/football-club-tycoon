--!strict
-- Post-match summary card: crests and score, league line, earnings panel,
-- attendance bar, player development cards with shoulder-height headshots,
-- club balance and a single "Back to Club" button. Built once, filled by
-- `show(data)` with the MatchSummary remote payload.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Headshot = require(script.Parent.Headshot)
local Crest = require(script.Parent.Crest)

local MatchSummary = {}

local C = Theme.colors
local money, ordinal = Theme.money, Theme.ordinal

-- TEMP layout numbers, all in pixels at the card's design width
local CARD_W = 540
local PAD = 16
local SECTION_GAP = 10
local INNER_BG = Color3.fromRGB(23, 30, 44)
local CARD_BG = Color3.fromRGB(14, 20, 34)
local LINE_COLOR = Color3.fromRGB(255, 255, 255)

export type Summary = {
	frame: Frame,
	show: (data: any) -> (),
	continueButton: TextButton,
}

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local initials = Crest.initials

-- Dark inset panel used for every section.
local function section(parent: Instance, name: string, height: number, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = INNER_BG
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	Theme.corner(f, Theme.cardRadius)
	Theme.stroke(f)
	return f
end

local function divider(parent: Instance, x: UDim, y: number, height: number)
	local d = Instance.new("Frame")
	d.Name = "Divider"
	d.BackgroundColor3 = LINE_COLOR
	d.BackgroundTransparency = 0.85
	d.BorderSizePixel = 0
	d.Size = UDim2.new(0, 1, 0, height)
	d.Position = UDim2.new(x.Scale, x.Offset, 0, y)
	d.Parent = parent
end

-- Two rotated bars: an arrow-free "->" or up chevron, so no font glyph is needed.
local function chevron(parent: Instance, direction: "up" | "right", color: Color3, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Chevron"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	for _, side in { -1, 1 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.fromOffset(size * 0.62, math.max(size * 0.18, 2))
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		if direction == "up" then
			bar.Position = UDim2.fromScale(0.5 + side * 0.2, 0.5)
			bar.Rotation = side * 45
		else
			-- ">" : the upper bar slopes down to the right, the lower bar up
			bar.Position = UDim2.fromScale(0.55, 0.5 + side * 0.2)
			bar.Rotation = -side * 45
		end
		bar.Parent = holder
	end
	Theme.corner(holder, 2)
	return holder
end

-- Recolour a shield's outline to the club's accent, which is what keeps two
-- dark-kitted clubs apart on the card.
local function tintStroke(shield: Frame, accent: Color3)
	local stroke = shield:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
		stroke.Transparency = 0.15
	end
end

-- Simple club crest: rounded shield in the kit colour with the club initials.
local function crest(parent: Instance, name: string, size: number): (Frame, TextLabel, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(0, size + 76, 0, size + 52)
	holder.Parent = parent
	local shield = Instance.new("Frame")
	shield.Name = "Shield"
	shield.AnchorPoint = Vector2.new(0.5, 0)
	shield.Position = UDim2.new(0.5, 0, 0, 0)
	shield.Size = UDim2.fromOffset(size, size)
	shield.BackgroundColor3 = C.bg3
	shield.BorderSizePixel = 0
	shield.Parent = holder
	Theme.corner(shield, math.floor(size * 0.28))
	Theme.stroke(shield)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -10, 1, -10)
	inner.BackgroundColor3 = CARD_BG
	inner.BackgroundTransparency = 0.35
	inner.BorderSizePixel = 0
	inner.Parent = shield
	Theme.corner(inner, math.floor(size * 0.22))
	local letters = Theme.text(inner, "", "display", {
		Name = "Initials",
		Size = UDim2.fromScale(1, 1),
		TextSize = math.floor(size * 0.42),
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local label = Theme.text(holder, "", "body", {
		Name = "ClubName",
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, size + 6),
		Font = Theme.fonts.display,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local sub = Theme.text(holder, "", "muted", {
		Name = "Sub",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, size + 28),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	return shield, letters, label, sub
end

function MatchSummary.new(gui: ScreenGui): Summary
	local frame = Theme.panel(gui, "Summary", {
		Size = UDim2.new(0, CARD_W, 0.94, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = CARD_BG,
		BackgroundTransparency = 0.02,
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(CARD_W, 820)
	limit.Parent = frame

	-- scrolling body so short screens still reach the button
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(PAD, PAD)
	body.Size = UDim2.new(1, -PAD * 2, 1, -PAD * 2 - 66)
	body.ScrollBarThickness = 4
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, SECTION_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	-- ------------------------------------------------------------ header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 190)
	header.LayoutOrder = 1
	header.Parent = body
	Theme.text(header, "FULL TIME", "muted", {
		Name = "FullTime",
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 2),
		Font = Theme.fonts.display,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local matchLine = Theme.text(header, "", "muted", {
		Name = "MatchLine",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 20),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local homeShield, homeInitials, homeName, homeSub = crest(header, "Home", 84)
	homeShield.Parent.Position = UDim2.fromOffset(0, 40)
	local awayShield, awayInitials, awayName, awaySub = crest(header, "Away", 84)
	awayShield.Parent.AnchorPoint = Vector2.new(1, 0)
	awayShield.Parent.Position = UDim2.new(1, 0, 0, 40)
	local score = Theme.text(header, "", "display", {
		Name = "Score",
		Size = UDim2.new(1, -330, 0, 70),
		Position = UDim2.new(0.5, 0, 0, 48),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 60,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local resultPill = Theme.text(header, "", "body", {
		Name = "Result",
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.new(0.5, 0, 0, 126),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.bad,
		Font = Theme.fonts.display,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Theme.corner(resultPill, Theme.chipRadius)

	-- ------------------------------------------------------------ league
	local league = section(body, "League", 48, 2)
	local trophy = Instance.new("Frame")
	trophy.Name = "Trophy"
	trophy.Size = UDim2.fromOffset(24, 24)
	trophy.Position = UDim2.fromOffset(14, 12)
	trophy.BackgroundColor3 = C.accent
	trophy.BorderSizePixel = 0
	trophy.Parent = league
	Theme.corner(trophy, 12)
	Theme.text(trophy, "1", "display", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 14,
		TextColor3 = CARD_BG,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local leagueName = Theme.text(league, "", "display", {
		Name = "Division",
		Size = UDim2.new(0.55, 0, 1, 0),
		Position = UDim2.fromOffset(48, 0),
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local leagueRight = Theme.text(league, "", "body", {
		Name = "Standing",
		Size = UDim2.new(0.42, 0, 1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 14,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
	})

	-- ---------------------------------------------------------- earnings
	local earnings = section(body, "Earnings", 150, 3)
	Theme.text(earnings, "MATCH EARNINGS", "muted", {
		Size = UDim2.new(1, -28, 0, 20),
		Position = UDim2.fromOffset(16, 12),
		Font = Theme.fonts.display,
		TextSize = 15,
	})
	local total = Theme.text(earnings, "", "cash", {
		Name = "Total",
		Size = UDim2.new(1, -28, 0, 52),
		Position = UDim2.fromOffset(16, 32),
		Font = Theme.fonts.display,
		TextSize = 46,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local columns: { [string]: TextLabel } = {}
	local columnTitles: { [string]: TextLabel } = {}
	for i, spec in { { "Tickets", "tickets" }, { "Concessions", "concessions" }, { "Result bonus", "bonus" } } do
		local x = UDim.new((i - 1) / 3, 16)
		if i > 1 then
			divider(earnings, UDim.new((i - 1) / 3, 0), 92, 46)
		end
		columnTitles[spec[2]] = Theme.text(earnings, spec[1], "muted", {
			Size = UDim2.new(1 / 3, -24, 0, 18),
			Position = UDim2.new(x.Scale, x.Offset, 0, 92),
			TextSize = 14,
		})
		columns[spec[2]] = Theme.text(earnings, "", "body", {
			Name = spec[2],
			Size = UDim2.new(1 / 3, -24, 0, 24),
			Position = UDim2.new(x.Scale, x.Offset, 0, 112),
			Font = Theme.fonts.display,
			TextSize = 20,
		})
	end

	-- -------------------------------------------------------- attendance
	local attendance = section(body, "Attendance", 64, 4)
	Theme.text(attendance, "Attendance", "muted", {
		Size = UDim2.fromOffset(150, 18),
		Position = UDim2.fromOffset(16, 12),
		TextSize = 14,
	})
	local attendanceLabel = Theme.text(attendance, "", "body", {
		Name = "Count",
		Size = UDim2.fromOffset(150, 24),
		Position = UDim2.fromOffset(16, 30),
		Font = Theme.fonts.display,
		TextSize = 20,
	})
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 176, 0.5, 0)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Size = UDim2.new(1, -176 - 96, 0, 14)
	track.BackgroundColor3 = C.bg3
	track.BorderSizePixel = 0
	track.Parent = attendance
	Theme.corner(track, 7)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = C.cash
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, 7)
	local percent = Theme.text(attendance, "", "body", {
		Name = "Percent",
		Size = UDim2.fromOffset(80, 24),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Font = Theme.fonts.bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- ------------------------------------------------------- development
	local dev = section(body, "Development", 0, 5)
	dev.AutomaticSize = Enum.AutomaticSize.Y
	dev.Visible = false
	Theme.text(dev, "PLAYER DEVELOPMENT", "display", {
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.fromOffset(14, 12),
		TextSize = 17,
	})
	local devCards = Instance.new("Frame")
	devCards.Name = "Cards"
	devCards.BackgroundTransparency = 1
	devCards.Position = UDim2.fromOffset(12, 40)
	devCards.Size = UDim2.new(1, -24, 0, 0)
	devCards.AutomaticSize = Enum.AutomaticSize.Y
	devCards.Parent = dev
	local devGrid = Instance.new("UIGridLayout")
	devGrid.CellSize = UDim2.new(0.25, -8, 0, 176)
	devGrid.CellPadding = UDim2.fromOffset(10, 10)
	devGrid.SortOrder = Enum.SortOrder.LayoutOrder
	devGrid.Parent = devCards
	local devPad = Instance.new("UIPadding")
	devPad.PaddingBottom = UDim.new(0, 52)
	devPad.Parent = dev

	-- ------------------------------------------------------------ news
	local news = Theme.text(body, "", "body", {
		Name = "News",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		TextColor3 = C.info,
		RichText = true,
		LayoutOrder = 6,
		Visible = false,
	})

	-- --------------------------------------------------------- balance
	local balance = Instance.new("Frame")
	balance.Name = "Balance"
	balance.BackgroundTransparency = 1
	balance.Size = UDim2.new(1, 0, 0, 30)
	balance.LayoutOrder = 7
	balance.Parent = body
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = LINE_COLOR
	rule.BackgroundTransparency = 0.85
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.Parent = balance
	local balanceLabel = Theme.text(balance, "", "body", {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(4, 8),
		TextSize = 15,
		RichText = true,
	})

	-- ------------------------------------------------------------ footer
	local continueButton = Theme.button(frame, "Back to Club", "primary", {
		Name = "Continue",
		Size = UDim2.new(1, -PAD * 2, 0, 50),
		Position = UDim2.new(0, PAD, 1, -PAD),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 22,
		Font = Theme.fonts.display,
	})
	local go = chevron(continueButton, "right", Color3.new(1, 1, 1), 16)
	go.Position = UDim2.new(0.5, 78, 0.5, 0)
	go.AnchorPoint = Vector2.new(0, 0.5)

	-- --------------------------------------------------------------- show
	local function devCard(c: any, order: number)
		local up = c.to > c.from
		local color = if up then C.cash else C.bad
		local card = Instance.new("Frame")
		card.Name = ("Dev%d"):format(c.id)
		card.BackgroundColor3 = C.bg3
		card.BorderSizePixel = 0
		card.LayoutOrder = order
		card.Parent = devCards
		Theme.corner(card, Theme.cardRadius)
		Theme.stroke(card)
		local face = Instance.new("Frame")
		face.Name = "Face"
		face.Position = UDim2.fromOffset(6, 6)
		face.Size = UDim2.new(1, -12, 0, 96)
		face.BackgroundTransparency = 1
		face.ClipsDescendants = true
		face.Parent = card
		Theme.corner(face, Theme.chipRadius)
		Headshot.attach(face, c.look or c.id, Config.HomeKit, c.number, { shoulders = true })
		Theme.stroke(face)
		Theme.text(card, (c.name :: string):match("(%S+)$") or c.name, "body", {
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 106),
			Font = Theme.fonts.display,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		-- "57 -> 58": old rating, chevron, new rating in the change colour
		local ratings = Instance.new("Frame")
		ratings.Name = "Ratings"
		ratings.BackgroundTransparency = 1
		ratings.Size = UDim2.new(1, 0, 0, 22)
		ratings.Position = UDim2.fromOffset(0, 124)
		ratings.Parent = card
		local ratingsLayout = Instance.new("UIListLayout")
		ratingsLayout.FillDirection = Enum.FillDirection.Horizontal
		ratingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ratingsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ratingsLayout.Padding = UDim.new(0, 4)
		ratingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ratingsLayout.Parent = ratings
		Theme.text(ratings, tostring(c.from), "body", {
			Size = UDim2.fromOffset(28, 22),
			Font = Theme.fonts.display,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			LayoutOrder = 1,
		})
		local arrow = chevron(ratings, "right", C.muted, 12)
		arrow.LayoutOrder = 2
		Theme.text(ratings, tostring(c.to), "body", {
			Size = UDim2.fromOffset(28, 22),
			Font = Theme.fonts.display,
			TextSize = 18,
			TextColor3 = color,
			LayoutOrder = 3,
		})
		-- "+1 OVR" pill
		local pill = Instance.new("Frame")
		pill.Name = "Pill"
		pill.AnchorPoint = Vector2.new(0.5, 0)
		pill.Position = UDim2.new(0.5, 0, 0, 148)
		pill.Size = UDim2.new(1, -20, 0, 22)
		pill.BackgroundColor3 = if up then Color3.fromRGB(32, 92, 52) else Color3.fromRGB(110, 40, 40)
		pill.BorderSizePixel = 0
		pill.Parent = card
		Theme.corner(pill, Theme.chipRadius)
		Theme.stroke(pill)
		local icon = chevron(pill, "up", color, 12)
		icon.Position = UDim2.new(0, 8, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		if not up then
			icon.Rotation = 180
		end
		Theme.text(pill, ("%+d OVR"):format(c.to - c.from), "body", {
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(22, 0),
			Font = Theme.fonts.display,
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
	end

	local function show(data: any)
		local clubName = (Config :: any).ClubName
		local stateFolder = require(script.Parent.ClubRef).state()
		if stateFolder then
			clubName = stateFolder:GetAttribute("ClubName") or clubName
		end
		matchLine.Text = if data.friendly then "FRIENDLY" else ("MATCH %d / %d"):format(data.round or 0, data.rounds or 10)
		-- Same colours the crest uses everywhere else, looked up by club name.
		local homeKit, homeAccent = Config.clubCrest(clubName, true)
		homeInitials.Text = initials(clubName)
		homeInitials.TextColor3 = homeAccent
		homeShield.BackgroundColor3 = homeKit
		tintStroke(homeShield, homeAccent)
		homeName.Text = clubName
		homeSub.Text = if data.scorers and #data.scorers > 0 then table.concat(data.scorers, "\n") else ""
		local opponent = data.opponent or "Away"
		local awayKit, awayAccent = Config.clubCrest(opponent)
		awayInitials.Text = initials(opponent)
		awayInitials.TextColor3 = awayAccent
		awayShield.BackgroundColor3 = awayKit
		tintStroke(awayShield, awayAccent)
		awayName.Text = opponent
		awaySub.Text = ""
		score.Text = ("%d - %d"):format(data.homeGoals, data.awayGoals)
		if data.outcome == "Win" then
			resultPill.Text = "VICTORY"
			resultPill.BackgroundColor3 = C.good
		elseif data.outcome == "Draw" then
			resultPill.Text = "DRAW"
			resultPill.BackgroundColor3 = C.bg3
		else
			resultPill.Text = "DEFEAT"
			resultPill.BackgroundColor3 = C.bad
		end

		leagueName.Text = string.upper(data.division or "LEAGUE")
		local remaining = math.max((data.rounds or 0) - (data.round or 0), 0)
		local remainingText = if remaining == 1 then "1 match remaining" elseif remaining == 0 then "Season complete" else ("%d matches remaining"):format(remaining)
		leagueRight.Text = ("<b>%s</b> place   <font color=\"#7c8594\">|</font>   <b>%d</b> %s"):format(
			ordinal(data.position or 1), remaining, remainingText:gsub("^%d+ ", ""))
		if remaining == 0 then
			leagueRight.Text = ("<b>%s</b> place   <font color=\"#7c8594\">|</font>   Season complete"):format(ordinal(data.position or 1))
		end
		if data.friendly then
			leagueRight.Text = "No league points · no injuries"
		end

		total.Text = "+" .. money(data.total or 0)
		columns.tickets.Text = money(data.ticketRevenue or 0)
		-- X225: a friendly pays the home club a share of the gate, not every ticket
		columnTitles.tickets.Text = if data.friendly then "Gate share" else "Tickets"
		columns.concessions.Text = money(data.concessionRevenue or 0)
		columns.bonus.Text = money(data.resultBonus or 0)

		local capacity = math.max(data.capacity or 1, 1)
		local att = data.attendance or 0
		attendanceLabel.Text = ("%s / %s"):format(withCommas(att), withCommas(capacity))
		local frac = math.clamp(att / capacity, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		percent.Text = ("%d%% full"):format(math.floor(frac * 100 + 0.5))

		for _, child in devCards:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local changes = data.development or {}
		dev.Visible = #changes > 0
		for i, c in changes do
			devCard(c, i)
		end

		-- injuries and returns stay as text; rating moves are the cards above
		local lines = {}
		for _, line in data.news or {} do
			local isRating = line:find("improved to", 1, true) or line:find("slowing down", 1, true)
			if not (#changes > 0 and isRating) then
				table.insert(lines, line)
			end
		end
		news.Visible = #lines > 0
		news.Text = table.concat(lines, "\n")

		balanceLabel.Text = ("Club balance   %s"):format(Theme.rich(money(data.cash or 0), C.cash, true))
		-- X217: the season prize is already in the balance but not in the match earnings
		local prize = if type(data.season) == "table" then data.season.prize else nil
		if type(prize) == "number" and prize > 0 then
			balanceLabel.Text ..= ("   <font color=\"#7c8594\">includes %s season prize</font>"):format(money(prize))
		end
		body.CanvasPosition = Vector2.zero
		frame.Visible = true
	end

	return { frame = frame, show = show, continueButton = continueButton }
end

return MatchSummary
