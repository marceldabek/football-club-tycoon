--!strict
-- The scout pack, full screen. Presentation only: the three cards were rolled
-- by the server before the folder was touched (CLAUDE.md s22); this turns them
-- over. Anything that goes wrong in the show drops straight to the result
-- state, so the player is never left behind a dark screen.
--   1 camera pushes in on the folder (desk only)   2 three backs slide out
--   3 tap to turn, worst first, best last           4 Sign / Pin / Continue
--
--   PackOpening.open(getClub, actionEvent, { fromDesk = true, folder = part })
--   PackOpening.isOpen() / PackOpening.refresh()   the club JSON changed

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared.Format)
local Nations = require(ReplicatedStorage.Shared.Nations)
local Pack = require(ReplicatedStorage.Shared.Pack)
local Squad = require(ReplicatedStorage.Shared.Squad)
local ClubRef = require(script.Parent.ClubRef)
local Focus = require(script.Parent.Focus)
local PlayerCard = require(script.Parent.PlayerCard)
local Theme = require(script.Parent.Theme)

local PackOpening = {}

export type Options = { fromDesk: boolean, folder: BasePart? }

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local drawResult: (() -> ())? = nil

-- the row of cards. Width is what bites: three 2:3 cards side by side on a
-- phone in portrait are sized off the width, not the height, so the slots are
-- measured in pixels rather than left to an aspect constraint that would
-- happily run off both edges. Vertically the row gets whatever the header
-- above and the buttons + CONTINUE below leave it (P6: on a landscape phone the
-- old 60% row put the Sign buttons under the bottom button).
local ROW_W = 0.92
local HEAD_Y = 0.05 -- SCOUT REPORT, as a fraction of the screen
local HEAD_H = 76 -- headline + the "3 PLAYERS DISCOVERED" line under it
local UNDER_CARD = 70 -- the Sign/Pin bar and its caption hang below each card
local FOOT_H = 46 + 12 -- CONTINUE and the gap above it
local FOOT_Y = 0.03
local SLOT_GAP = 12
local EXTRA_SCALE = 0.78 -- a pin from an older report rides smaller, in a fourth slot
local BAR_H = 40
-- the card art's shield is this much of its 2:3 box wide; the buttons match it
-- rather than the box (measured on a 381 x 571 card in Studio)
local ART_W = 0.88
local SIGNED_GREY = Color3.fromRGB(120, 120, 120) -- a signed card's tint

-- TEMP reveal timings, all of them: the whole show has to stay under ~10 s.
local CAMERA_IN = 0.6
local SHADE_IN = 0.3
local SLIDE = 0.35
local SLIDE_STAGGER = 0.14
local BUILD_FLAG = 0.7 -- Rare and better: nation, then role, then the card
local BUILD_ROLE = 0.6
local HOLD_SKIP = 0.5 -- press and hold reveals the rest (design rule 11)
local TURN_WAIT = 3 -- longest the show waits on a card that is mid-turn
local STING_MAX = 1.5 -- "Speed Rise" runs on for seconds; stings must not pile up
local STING_FADE = 0.3
-- Opaque. Roblox blends GUI transparency in linear light, so a "nearly solid"
-- 0.12 or 0.04 still let the HUD's match-summary card read straight through it
-- (measured in Studio at both). The pack is meant to take the screen over.
local SHADE = 0
local TOAST_SECONDS = 2.5 -- as long as the HUD holds one

local TIER_RANK: { [string]: number } = {}
for i, tier in Config.Rarity do
	TIER_RANK[tier.name] = i
end
local BUILD_UP_FROM = TIER_RANK.Rare

local function sound(id: string, pitch: number?, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch or 1
	s.Volume = volume or 0.6
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	-- a long clip is faded out rather than left to run under the next beat
	task.delay(STING_MAX - STING_FADE, function()
		if s.Parent and s.IsPlaying then
			TweenService:Create(s, TweenInfo.new(STING_FADE), { Volume = 0 }):Play()
			task.delay(STING_FADE, function()
				s:Destroy()
			end)
		end
	end)
end

-- Sprint.client.luau's two speeds. The humanoid's WalkSpeed when the pack opens
-- may be a held sprint, so it is not what unfreeze should put back.
local WALK_SPEED = 16
local SPRINT_SPEED = 30

-- Movement lock, so nobody wanders off mid-pack. Not PlayerModule:GetControls():
-- checked in Studio, this place has no PlayerModule in PlayerScripts at all
-- (only RbxCharacterSounds and our own Client folder), so there is no
-- ControlModule to disable and the character kept walking behind the cards.
-- The humanoid is pinned instead, and re-pinned if anything else writes to it --
-- Sprint.client rewrites WalkSpeed on every Shift.
local function freeze(): () -> ()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return function() end
	end
	local power, height = humanoid.JumpPower, humanoid.JumpHeight
	local held = true
	local function pin()
		if held then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
	end
	local conn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(pin)
	pin()
	return function()
		held = false
		conn:Disconnect()
		local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		humanoid.WalkSpeed = if sprinting then SPRINT_SPEED else WALK_SPEED
		humanoid.JumpPower, humanoid.JumpHeight = power, height
	end
end

-- Cash is a ClubState attribute, like everything ClubPanel reads.
local function cash(): number
	local state = ClubRef.state()
	return (state and state:GetAttribute("Cash") :: number?) or 0
end

function PackOpening.isOpen(): boolean
	return gui ~= nil
end

-- One signing rewrites Club and Cash, and ClubPanel watches both, so a single
-- action used to rebuild every card two or three times. The redraws are folded
-- into one deferred pass; if the overlay closed meanwhile it does nothing.
local redrawQueued = false
function PackOpening.refresh()
	if not drawResult or redrawQueued then
		return
	end
	redrawQueued = true
	task.defer(function()
		redrawQueued = false
		if drawResult then
			drawResult()
		end
	end)
end

-- Who can make way when the squad is full: anyone outside the XI, cheapest sale
-- first. The server counts that sale toward the fee, so the card needs this list
-- to know whether a signing is affordable at all.
local function releaseOptions(club: any): { any }
	local inXi: { [number]: boolean } = {}
	for _, id in club.lineup.xi do
		inXi[id] = true
	end
	local options = {}
	for _, p in club.players do
		if not inXi[p.id] then
			table.insert(options, p)
		end
	end
	table.sort(options, function(a, b)
		return Squad.value(a) < Squad.value(b)
	end)
	return options
end

-- Squad full: who makes way? Options that cannot cover the fee are shown, but
-- greyed and dead, so the shortfall is explained rather than silently missing.
local function pickRelease(screen: ScreenGui, club: any, fee: number, purse: number, onPick: (number) -> ())
	if screen:FindFirstChild("ReleasePicker") then
		return -- one picker at a time, however fast the tapping
	end
	local options = releaseOptions(club)
	-- cheapest first, but anyone who actually funds the signing comes first of all
	table.sort(options, function(a, b)
		local av, bv = Squad.value(a), Squad.value(b)
		local ac, bc = purse + av >= fee, purse + bv >= fee
		if ac ~= bc then
			return ac
		end
		return av < bv
	end)
	local shown = math.min(#options, 6)
	local panel = Theme.panel(screen, "ReleasePicker", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 62 + math.max(shown, 1) * 46 + 56),
		BackgroundTransparency = 0,
		ZIndex = 20,
	})
	Theme.text(panel, ("SQUAD FULL (%d). WHO MAKES WAY?"):format(Config.SquadMax), "display", {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 30),
		TextSize = 20,
		ZIndex = 21,
	})
	if shown == 0 then
		Theme.text(panel, "Every player is in your XI. Sell someone from the squad screen first.", "muted", {
			Position = UDim2.fromOffset(16, 56),
			Size = UDim2.new(1, -32, 0, 40),
			ZIndex = 21,
		})
	end
	local picked = false
	for i = 1, shown do
		local p = options[i]
		local sale = Squad.value(p)
		local covers = purse + sale >= fee
		local b = Theme.button(
			panel,
			("%s   %s  %d   sells for %s%s"):format(
				Format.cardName(p.name),
				p.role,
				p.overall,
				Format.money(sale),
				if covers then "" else ("   ·   still %s short"):format(Format.money(fee - purse - sale))
			),
			"ghost",
			{
				Position = UDim2.fromOffset(16, 56 + (i - 1) * 46),
				Size = UDim2.new(1, -32, 0, 40),
				TextSize = 15,
				ZIndex = 21,
			}
		)
		if not covers then
			b.Active = false -- selling him still would not pay for the signing
			b.AutoButtonColor = false
			b.TextColor3 = Theme.colors.muted
		end
		b.Activated:Connect(function()
			if picked then
				return
			end
			picked = true
			panel:Destroy()
			onPick(p.id)
		end)
	end
	local cancel = Theme.button(panel, "CANCEL", "ghost", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(140, 36),
		ZIndex = 21,
	})
	cancel.Activated:Connect(function()
		panel:Destroy()
	end)
end

-- A toast with no overlay to put it in: the desk prompt is in the world, so it
-- can be answered with nothing on screen. Same pill as the HUD's, over the HUD.
local function flash(message: string)
	local screen = Theme.screenGui("PackMessage", 60)
	screen.Parent = player:WaitForChild("PlayerGui")
	local pill = Theme.pill(screen, "Toast", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -72),
		Size = UDim2.new(0.6, 0, 0, 36),
		Text = message,
		TextColor3 = Theme.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
	})
	local max = Instance.new("UITextSizeConstraint") -- TextScaled alone fills the pill
	max.MaxTextSize = 17
	max.Parent = pill
	task.delay(TOAST_SECONDS, function()
		screen:Destroy()
	end)
end

function PackOpening.open(getClub: () -> any?, actionEvent: RemoteEvent, opts: Options)
	local club = getClub()
	if gui or not club then
		return
	end
	-- The desk prompt is a world object on a plot anyone can walk onto, and the
	-- menu button is on screen during a matchday: only the owner of this club,
	-- between matches and past the naming card, opens a report.
	local own = ClubRef.state()
	if not own or own:GetAttribute("Phase") ~= "Manage" or own:GetAttribute("NeedsName") == true then
		return
	end
	local pinnedCount = if club.pinned then 1 else 0
	if #club.shortlist + pinnedCount == 0 then
		flash("No scout report yet. One arrives after your next match.")
		return
	end
	actionEvent:FireServer("openReport") -- the folder stops glowing

	local screen = Theme.screenGui("PackOpening", 60) -- over the HUD and the club panel
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
	local unfreeze = freeze()

	local camera = workspace.CurrentCamera :: Camera
	local savedType, savedCFrame = camera.CameraType, camera.CFrame
	local pushedIn = false -- only the desk shot touches the camera, so only it restores one
	local pushTween: Tween? = nil
	local skipped = false
	-- close() can land in the middle of the show (matchday, death, Escape). Every
	-- wait in the show watches this, or the thread spins on a destroyed screen
	-- for good and the humanoid is never unfrozen.
	local cancelled = false
	local conns: { RBXScriptConnection } = {}

	local shade = Instance.new("TextButton") -- a button so it swallows every tap
	shade.Name = "Shade"
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 9, 16)
	shade.BackgroundTransparency = 1
	shade.Parent = screen

	local resultCards: { PlayerCard.Card } = {}
	-- SIGN goes busy so a double tap cannot buy the same card twice. A refusal
	-- from the server has to free it straight away, not after the timeout.
	local signBusyClears: { () -> () } = {}
	local function freeSignButtons()
		for _, clear in signBusyClears do
			clear()
		end
		table.clear(signBusyClears)
	end
	local function close()
		if gui ~= screen then
			return -- already closed: death and CONTINUE can both land
		end
		gui = nil
		cancelled = true
		drawResult = nil
		for _, c in conns do
			c:Disconnect()
		end
		for _, card in resultCards do
			card:destroy()
		end
		unfreeze()
		Focus.pop("pack")
		if pushTween then
			pushTween:Cancel() -- or the push-in keeps driving the camera after the restore
		end
		if pushedIn then
			camera.CameraType = savedType
			camera.CFrame = savedCFrame
		end
		screen:Destroy()
	end

	-- three slots in a row, plus a smaller fourth for a pin from an older report.
	-- The row runs from under the header to above the buttons, and the cards sit
	-- in its middle. Every slot is full card height, so a smaller card sits at the
	-- bottom of its slot and all the Sign rows still line up.
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, HEAD_Y, HEAD_H)
	row.Size = UDim2.new(ROW_W, 0, 1 - HEAD_Y - FOOT_Y, -(HEAD_H + UNDER_CARD + FOOT_H))
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	-- Card size for `count` cards abreast: whichever of the row's width and
	-- height runs out first. A phone in portrait always runs out of width.
	local function cardPixels(count: number, scale: number): Vector2
		local vp = camera.ViewportSize
		local room = (vp.X * ROW_W - SLOT_GAP * (count - 1)) / math.max(count, 1)
		local tall = vp.Y * (1 - HEAD_Y - FOOT_Y) - (HEAD_H + UNDER_CARD + FOOT_H)
		local height = math.max(math.min(tall, room / Config.CardAspect), 60) * scale
		return Vector2.new(math.floor(height * Config.CardAspect), math.floor(height))
	end
	local function slotSize(count: number, scale: number): UDim2
		local px = cardPixels(count, scale)
		return UDim2.fromOffset(px.X, px.Y)
	end

	local function slot(order: number, size: UDim2): Frame
		local s = Instance.new("Frame")
		s.Name = "Slot"
		s.BackgroundTransparency = 1
		s.LayoutOrder = order
		s.Size = size
		s.Parent = row
		return s
	end

	local function clearRow()
		table.clear(signBusyClears) -- the buttons they belong to are about to go
		for _, card in resultCards do
			card:destroy() -- the wonderkid sweep outlives a plain ClearAllChildren
		end
		table.clear(resultCards)
		for _, child in row:GetChildren() do
			if child ~= layout then
				child:Destroy() -- keep the layout: it is not rebuilt
			end
		end
	end

	-- ------------------------------------------------------------ result state
	local headline = Theme.text(screen, "", "display", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, HEAD_Y),
		Size = UDim2.new(0.9, 0, 0, 44),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- "3 PLAYERS DISCOVERED" under the headline (Marcel's mockup, #19c)
	local subline = Theme.text(screen, "", "accent", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, HEAD_Y, 44),
		Size = UDim2.new(0.9, 0, 0, 22),
		TextSize = 16,
		Font = Theme.fonts.bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	-- The HUD's toast renders at DisplayOrder 1, under this opaque screen, so
	-- "Need £2,000 more" and the like are repeated here while the pack is up.
	-- It borrows the subline's spot for as long as it shows.
	local toast = Theme.pill(screen, "Toast", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, HEAD_Y, 42),
		Size = UDim2.new(0.6, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Visible = false,
		ZIndex = 5,
	})
	local toastMax = Instance.new("UITextSizeConstraint")
	toastMax.MaxTextSize = 17
	toastMax.Parent = toast
	local toastToken = 0
	local sublineWanted = false
	local function showToast(message: string, ok: boolean?)
		toastToken += 1
		local mine = toastToken
		toast.Text = message
		toast.TextColor3 = if ok then Theme.colors.good else Theme.colors.bad
		toast.Visible = true
		subline.Visible = false
		task.delay(TOAST_SECONDS, function()
			if toastToken == mine and toast.Parent then
				toast.Visible = false
				subline.Visible = sublineWanted
			end
		end)
	end

	local done = Theme.button(screen, "CONTINUE  >", "primary", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - FOOT_Y, 0),
		Size = UDim2.fromOffset(220, 46),
		TextSize = 18,
		Font = Theme.fonts.display,
		Visible = false,
	})
	done.Activated:Connect(close)

	-- A map pin drawn from frames: Gotham has no glyph for one. The mockup has
	-- a star; ours is a pin (#19c).
	local function pinIcon(parent: GuiObject, ink: Color3)
		local icon = Instance.new("Frame")
		icon.Name = "PinIcon"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(0.5, 0.62)
		icon.Rotation = 35
		icon.ZIndex = parent.ZIndex + 1
		icon.Parent = parent
		local function bit(name: string, anchor: Vector2, pos: UDim2, size: UDim2, round: boolean): Frame
			local f = Instance.new("Frame")
			f.Name = name
			f.BorderSizePixel = 0
			f.BackgroundColor3 = ink
			f.AnchorPoint = anchor
			f.Position = pos
			f.Size = size
			f.ZIndex = icon.ZIndex
			f.Parent = icon
			if round then
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0.5, 0)
				c.Parent = f
			end
			return f
		end
		local head = bit("Head", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.fromScale(0.62, 0.62), true)
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = head
		bit("Plate", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.new(0.95, 0, 0, 3), true)
		bit("Needle", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.5), UDim2.new(0, 2, 0.5, 0), false)
	end

	-- a card signed while the screen is up gets the stamp; one that was already
	-- signed when the screen opened just shows it
	local stamped: { [number]: boolean } = {}
	local firstDraw = true

	-- `group` holds the card itself: tinting it greys the card along its own
	-- shield outline, where a shade frame over it showed as a grey box
	local function stampSigned(holder: Frame, group: CanvasGroup, animate: boolean)
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local stamp = Instance.new("Frame")
		stamp.Name = "SignedStamp"
		stamp.BackgroundColor3 = Color3.fromRGB(12, 30, 18)
		stamp.BackgroundTransparency = 0.25
		stamp.AnchorPoint = Vector2.new(0.5, 0.5)
		stamp.Position = UDim2.fromScale(0.5, 0.4)
		stamp.Size = UDim2.fromScale(0.8, 0.15)
		stamp.Rotation = -12
		stamp.ZIndex = 6
		stamp.Parent = holder
		Theme.corner(stamp, 6)
		local rim = Instance.new("UIStroke")
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim.Color = Theme.colors.cash
		rim.Thickness = 3
		rim.Parent = stamp
		local word = Instance.new("TextLabel")
		word.BackgroundTransparency = 1
		word.Font = Theme.fonts.display
		word.Text = "SIGNED"
		word.TextColor3 = Theme.colors.cash
		word.TextScaled = true
		word.AnchorPoint = Vector2.new(0.5, 0.5)
		word.Position = UDim2.fromScale(0.5, 0.5)
		word.Size = UDim2.fromScale(0.9, 0.8)
		word.ZIndex = 7
		word.Parent = stamp
		if not animate then
			scale.Scale = 0.95
			group.GroupColor3 = SIGNED_GREY
			return
		end
		-- the stamp comes down from above the card and thumps it back a little
		local stampScale = Instance.new("UIScale")
		stampScale.Scale = 2.2
		stampScale.Parent = stamp
		stamp.BackgroundTransparency = 1
		rim.Transparency = 1
		word.TextTransparency = 1
		local down = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(stampScale, down, { Scale = 1 }):Play()
		TweenService:Create(stamp, down, { BackgroundTransparency = 0.25 }):Play()
		TweenService:Create(rim, down, { Transparency = 0 }):Play()
		TweenService:Create(word, down, { TextTransparency = 0 }):Play()
		task.delay(0.16, function()
			if not holder.Parent then
				return
			end
			sound(Config.PackAudio.flip, 0.55)
			TweenService:Create(group, TweenInfo.new(0.3), { GroupColor3 = SIGNED_GREY }):Play()
			local thump = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.9 })
			thump:Play()
			thump.Completed:Once(function()
				if holder.Parent then
					TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.95 }):Play()
				end
			end)
		end)
	end

	local function result()
		clearRow()
		local now = getClub()
		if not now then
			return close()
		end
		-- P6 (#19a): slots never shuffle. A signed card stays put, stamped; a
		-- pinned one glows where it is.
		local slots = Pack.slots(now.shortlist, now.pinned, now.packSigned, now.packReport)
		local count = #slots
		if count == 0 then
			Theme.text(row, "That is the lot. A new report lands after your next match.", "muted", {
				Size = UDim2.fromScale(1, 0.2),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			})
			return
		end
		local purse = cash()
		-- With a full squad the server puts the released player's sale toward the
		-- fee, so Sign must not be greyed out on cash alone: the dearest man the
		-- player could sell counts too, and the picker says which ones cover it.
		local squadFull = #now.players >= Config.SquadMax
		local releasable = if squadFull then releaseOptions(now) else {}
		local bestSale = if #releasable > 0 then Squad.value(releasable[#releasable]) else 0
		local full = cardPixels(count, 1)
		local function cardWithButtons(entry: Pack.Slot, order: number)
			local p = entry.card
			local pinned = entry.state == "pinned"
			local signed = entry.state == "signed"
			local px = cardPixels(count, if entry.extra then EXTRA_SCALE else 1)
			local s = slot(order, UDim2.fromOffset(px.X, full.Y))
			-- the card's own 2:3 box, at the bottom of a full-height slot
			local holder = Instance.new("Frame")
			holder.Name = "Holder"
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(0.5, 1)
			holder.Position = UDim2.fromScale(0.5, 1)
			holder.Size = UDim2.fromOffset(px.X, px.Y)
			holder.Parent = s
			-- only a signed card pays for a CanvasGroup (it renders offscreen)
			local cardParent: GuiObject = holder
			local group: CanvasGroup? = nil
			if signed then
				local g = Instance.new("CanvasGroup")
				g.Name = "SignedTint"
				g.BackgroundTransparency = 1
				g.Size = UDim2.fromScale(1, 1)
				g.Parent = holder
				group, cardParent = g, g
			end
			-- signed: he wears your kit now
			table.insert(resultCards, PlayerCard.new(cardParent, p, { signed = signed }))
			if pinned then
				-- Gold glow round the pinned card (the mockup's shortlisted card).
				-- A frame showed as a gold slab in the shield's cut corners, so the
				-- halo is the pale Silver art itself, tinted gold and set a little
				-- larger behind the card: it follows the shield outline. Two
				-- layers, the outer one fainter, pulse together.
				for i, grow in { 0.05, 0.1 } do
					local glow = Instance.new("ImageLabel")
					glow.Name = "PinGlow"
					glow.BackgroundTransparency = 1
					glow.Image = Config.CardArt.Silver
					glow.ImageColor3 = Theme.colors.accent
					glow.ImageTransparency = if i == 1 then 0.1 else 0.55
					glow.AnchorPoint = Vector2.new(0.5, 0.5)
					glow.Position = UDim2.fromScale(0.5, 0.5)
					glow.Size = UDim2.fromScale(1 + grow, 1 + grow * Config.CardAspect)
					glow.ZIndex = 0
					glow.Parent = holder
					TweenService:Create(
						glow,
						TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ ImageTransparency = if i == 1 then 0.45 else 0.85 }
					):Play()
				end
			end
			if group then
				local id = p.id :: number
				stampSigned(holder, group, not firstDraw and not stamped[id])
				stamped[id] = true
			end

			local bar = Instance.new("Frame")
			bar.Name = "Actions"
			bar.BackgroundTransparency = 1
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.new(0.5, 0, 1, 8)
			bar.Size = UDim2.fromOffset(math.max(math.floor(px.X * ART_W), 120), BAR_H)
			bar.Parent = s
			local caption = Theme.text(s, "", "muted", {
				Name = "Caption",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 8 + BAR_H + 4),
				Size = UDim2.new(1, 24, 0, 16),
				TextSize = 12,
				Font = Theme.fonts.bold,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local function restCaption()
				if signed then
					caption.Text = "IN YOUR SQUAD"
					caption.TextColor3 = Theme.colors.muted
				elseif pinned then
					caption.Text = "PINNED UNTIL SEASON END"
					caption.TextColor3 = Theme.colors.accent
				else
					caption.Text = "PIN UNTIL SEASON END"
					caption.TextColor3 = Theme.colors.muted
				end
			end
			restCaption()

			local fee = (p.fee :: number?) or 0
			local short = if signed then 0 else fee - purse - (if squadFull then bestSale else 0)
			local signText = if signed
				then "SIGNED"
				elseif fee == 0 then "KEEP FREE"
				elseif short > 0 then ("NEED %s MORE"):format(Format.money(short))
				else ("SIGN %s"):format(Format.money(fee))
			local sign = Theme.button(bar, signText, if short > 0 or signed then "ghost" else "primary", {
				Name = "Sign",
				Size = UDim2.new(1, -(BAR_H + 6), 1, 0),
				Font = Theme.fonts.display,
				TextScaled = true,
			})
			local signMax = Instance.new("UITextSizeConstraint")
			signMax.MaxTextSize = 18
			signMax.Parent = sign
			Theme.padding(sign, 8, 8)

			-- the square pin button beside it: gold while this card holds the pin
			local pin = Theme.button(bar, "", if short > 0 and not pinned then "primary" else "ghost", {
				Name = "Pin",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(BAR_H, BAR_H),
			})
			if pinned then
				pin.BackgroundColor3 = Theme.colors.accent
				pin.BackgroundTransparency = 0
			end
			pinIcon(pin, if pinned then Theme.colors.bg else Theme.colors.text)

			if signed then
				-- both buttons off: he is ours now (#19b)
				for _, b in { sign, pin } do
					b.Active = false
					b.AutoButtonColor = false
					b.BackgroundTransparency = 0.5
				end
				sign.TextColor3 = Theme.colors.muted
				local icon = pin:FindFirstChild("PinIcon") :: Frame?
				if icon then
					icon.Visible = false
				end
				return
			end

			local signing = false -- a fast double tap must not fire two signings
			sign.Activated:Connect(function()
				if short > 0 or signing then
					return
				end
				signing = true
				sound(Config.PackAudio.pick) -- #18h: a tap on SIGN/PIN gets its own sound
				-- a signing that lands redraws this card as SIGNED; if the server
				-- refuses, its toast frees the button at once, and this is only
				-- the backstop for a reply that never arrives
				table.insert(signBusyClears, function()
					signing = false
				end)
				task.delay(1.5, function()
					signing = false
				end)
				if squadFull then
					pickRelease(screen, now, fee, purse, function(releaseId: number)
						actionEvent:FireServer("sign", p.id, releaseId)
					end)
				else
					actionEvent:FireServer("sign", p.id)
				end
			end)
			-- Unpinning throws the card away for good, so it asks twice, and so
			-- does pinning over a pin that is already there. The square has no
			-- room for "SURE?", so the caption asks.
			local confirms = pinned or now.pinned ~= nil
			local armed = false
			pin.Activated:Connect(function()
				sound(Config.PackAudio.pick) -- #18h: every tap, arm or confirm alike
				if armed or not confirms then
					if pinned then
						actionEvent:FireServer("unpin")
					else
						actionEvent:FireServer("pin", p.id)
					end
					return
				end
				armed = true
				caption.Text = if pinned then "TAP AGAIN TO UNPIN" else "TAP AGAIN: REPLACES YOUR PIN"
				caption.TextColor3 = Theme.colors.bad
				task.delay(2, function()
					if caption.Parent then
						armed = false
						restCaption()
					end
				end)
			end)
		end
		for i, entry in slots do
			cardWithButtons(entry, i)
		end
		firstDraw = false
	end

	local function showResult()
		done.Visible = true
		drawResult = function()
			local latest = getClub()
			headline.Text = "SCOUT REPORT"
			-- every report is PackSize cards, whatever is left of it (a rejoin
			-- only knows the cards still on the shortlist)
			subline.Text = if latest and latest.packFree
				then "KEEP ONE TRIALIST FOR FREE"
				else ("%d PLAYERS DISCOVERED"):format(Config.PackSize)
			sublineWanted = latest ~= nil
			subline.Visible = sublineWanted and not toast.Visible
			result()
		end
		;(drawResult :: () -> ())()
	end

	-- ---------------------------------------------------------------- the show
	local function show()
		if opts.fromDesk and opts.folder then
			pushedIn = true
			camera.CameraType = Enum.CameraType.Scriptable
			local target = opts.folder.Position
			local back = (savedCFrame.Position - target)
			back = if back.Magnitude > 0.1 then back.Unit else Vector3.new(0, 0, 1)
			local goal = CFrame.lookAt(target + Vector3.new(0, 2.2, 0) + back * 1.5, target)
			Focus.push("pack", { focusDistance = 2.5, inFocusRadius = 2, farIntensity = 0.7, nearIntensity = 0 })
			pushTween = TweenService:Create(camera, TweenInfo.new(CAMERA_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = goal })
			;(pushTween :: Tween):Play()
			task.wait(CAMERA_IN * 0.75)
		end
		if cancelled then
			return
		end
		TweenService:Create(shade, TweenInfo.new(SHADE_IN), { BackgroundTransparency = SHADE }):Play()
		task.wait(SHADE_IN)
		-- the shade is solid from here, so the close-up's depth of field is only
		-- costing GPU time behind a screen nobody can see through
		Focus.pop("pack")
		if cancelled then
			return
		end

		-- worst first, best last
		local order = table.clone(club.shortlist)
		table.sort(order, function(a, b)
			return a.overall < b.overall
		end)
		local size = slotSize(#order, 1)
		local cards = {}
		for i, p in order do
			local s = slot(i, size)
			local card = PlayerCard.new(s, p, { faceDown = true })
			table.insert(resultCards, card) -- so a close mid-show still tidies up
			card.frame.Position = UDim2.fromScale(0.5, 1.8) -- up out of the folder
			TweenService:Create(card.frame, TweenInfo.new(SLIDE, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5, 0.5),
			}):Play()
			sound(Config.PackAudio.slide, 0.95 + i * 0.05)
			cards[i] = { card = card, slot = s, player = p }
			task.wait(SLIDE_STAGGER)
			if cancelled then
				return
			end
		end
		headline.Text = "TAP A CARD"

		local nextUp = 1
		local turning = false
		local function turn(i: number, quick: boolean)
			local entry = cards[i]
			local rank = TIER_RANK[entry.card.tier] or 1
			if rank >= BUILD_UP_FROM and not quick then
				-- flag, then role, then the card. The glow is a frame behind the
				-- card, not a UIStroke: the slot has no background to outline.
				local glow = Instance.new("Frame")
				glow.Name = "Glow"
				glow.AnchorPoint = Vector2.new(0.5, 0.5)
				glow.Position = UDim2.fromScale(0.5, 0.5)
				glow.Size = UDim2.fromScale(1.12, 1.08)
				glow.BackgroundColor3 = Config.CardTint[entry.card.tier].glow
				glow.BackgroundTransparency = 1
				glow.BorderSizePixel = 0
				glow.ZIndex = 0
				glow.Parent = entry.slot
				Theme.corner(glow, Theme.cardRadius)
				TweenService:Create(glow, TweenInfo.new(0.5), { BackgroundTransparency = 0.45 }):Play()
				headline.Text = string.upper(Nations.get(entry.player.nation).name)
				sound(Config.PackAudio.sting, 0.8)
				task.wait(BUILD_FLAG)
				-- the build-up is the only part of the show that waits seconds:
				-- a close during it must not go on stinging and flipping
				if cancelled then
					glow:Destroy()
					return
				end
				headline.Text = string.upper(tostring(entry.player.role or ""))
				task.wait(BUILD_ROLE)
				glow:Destroy()
				if cancelled then
					return
				end
			end
			sound(Config.PackAudio.flip)
			entry.card:flip()
			-- #18h: a bigger sting for Gold and up -- louder as well as higher,
			-- so Legend actually reads as a bigger moment than Bronze rather
			-- than just a faster chipmunk version of the same beat.
			local bigTier = math.max(0, rank - (TIER_RANK.Gold - 1))
			sound(Config.PackAudio.sting, 0.9 + rank * 0.08, math.min(0.6 + bigTier * 0.12, 1))
			headline.Text = ("%s  %d"):format(string.upper(entry.card.tier), entry.player.overall)
		end
		local function turnNext(quick: boolean)
			if turning or nextUp > #cards or cancelled then
				return
			end
			turning = true
			-- the counter moves before the turn: a card that throws must not be
			-- retried for ever, and `turning` has to clear on every path or the
			-- show hangs with the overlay up and the humanoid frozen (task.spawn
			-- swallows the error)
			local i = nextUp
			nextUp += 1
			local ok, err = pcall(turn, i, quick)
			if not ok then
				warn("[FCT] pack card " .. i .. " failed to turn: " .. tostring(err))
				local entry = cards[i]
				if entry then
					entry.card:setFace(true) -- it still has to end up face up
				end
			end
			turning = false
		end

		-- tap turns the next card; a double tap, a tap mid-turn or a press and
		-- hold reveals the rest (design rule 11)
		local lastTap = 0
		local holding = false
		local conns2 = {
			shade.Activated:Connect(function()
				local t = os.clock()
				if t - lastTap < 0.3 or turning then
					skipped = true
				end
				lastTap = t
				if not skipped then
					task.spawn(turnNext, false)
				end
			end),
			shade.MouseButton1Down:Connect(function()
				holding = true
				task.delay(HOLD_SKIP, function()
					if holding then
						skipped = true
					end
				end)
			end),
			shade.MouseButton1Up:Connect(function()
				holding = false
			end),
		}
		while nextUp <= #cards and not skipped and not cancelled do
			task.wait(0.05)
		end
		for _, c in conns2 do
			c:Disconnect()
		end
		local waited = os.clock()
		while turning and not cancelled and os.clock() - waited < TURN_WAIT do
			task.wait(0.05)
		end
		-- `not turning` as well: if a turn is somehow still stuck after TURN_WAIT,
		-- turnNext would refuse every call and this would spin. The result state
		-- draws every card face up regardless.
		while nextUp <= #cards and not cancelled and not turning do
			turnNext(true)
		end
		if cancelled then
			return
		end
		task.wait(0.4)
		if cancelled then
			return
		end
		actionEvent:FireServer("packRevealed")
	end

	-- Escape and gamepad B skip the show, then close the result state.
	table.insert(conns, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.ButtonB then
			return
		end
		if drawResult then
			close()
		else
			skipped = true
		end
	end))
	-- a matchday starting, or dying at the desk, must not leave the screen dark
	table.insert(conns, own:GetAttributeChangedSignal("Phase"):Connect(function()
		if own:GetAttribute("Phase") ~= "Manage" then
			close()
		end
	end))
	-- the server answers every action with a Toast, and the HUD's toast is
	-- buried under this screen, so it is shown here while the pack is open
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local toastEvent = remotes and remotes:FindFirstChild("Toast")
	if toastEvent and toastEvent:IsA("RemoteEvent") then
		table.insert(conns, toastEvent.OnClientEvent:Connect(function(message: string, ok: boolean?)
			if ok ~= true then
				freeSignButtons() -- a refused signing can be tried again at once
			end
			showToast(message, ok)
		end))
	end
	table.insert(conns, player.CharacterRemoving:Connect(close))
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(conns, humanoid.Died:Connect(close))
	end

	if club.packRevealed or #club.shortlist == 0 then
		-- straight to the result state: no camera move to keep sharp, and the
		-- shade covers the world anyway, so no Focus at all
		shade.BackgroundTransparency = SHADE
	else
		local ok, err = pcall(show)
		if not ok and not cancelled then
			warn("[FCT] pack show failed: " .. tostring(err))
			shade.BackgroundTransparency = SHADE
			actionEvent:FireServer("packRevealed")
		end
	end
	if gui == screen and not cancelled then -- close() may have fired during the show
		showResult()
	end
end

return PackOpening
