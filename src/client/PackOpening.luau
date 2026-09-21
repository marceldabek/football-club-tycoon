--!strict
-- The scout pack, full screen. Presentation only: the three cards were rolled
-- by the server before the folder was touched (CLAUDE.md s22); this turns them
-- over. Anything that goes wrong in the show drops straight to the result
-- state, so the player is never left behind a dark screen.
--   1 camera pushes in on the folder (desk only)   2 three backs slide out
--   3 tap to turn, worst first, best last           4 Sign / Pin / Done
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

-- the row of cards, as a fraction of the screen. Width is what bites: three
-- 2:3 cards side by side on a phone in portrait are sized off the width, not
-- the height, so the slots are measured in pixels rather than left to an
-- aspect constraint that would happily run off both edges.
local ROW_W, ROW_H = 0.92, 0.6
local SLOT_GAP = 12
local PINNED_SCALE = 0.78 -- the pinned card rides smaller, in a fourth slot

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

local TIER_RANK: { [string]: number } = {}
for i, tier in Config.Rarity do
	TIER_RANK[tier.name] = i
end
local BUILD_UP_FROM = TIER_RANK.Rare

local function sound(id: string, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = pitch or 1
	s.Volume = 0.6
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
	local walk, power, height = humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight
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
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = walk, power, height
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

function PackOpening.refresh()
	if drawResult then
		drawResult()
	end
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

function PackOpening.open(getClub: () -> any?, actionEvent: RemoteEvent, opts: Options)
	local club = getClub()
	if gui or not club then
		return
	end
	local pinnedCount = if club.pinned then 1 else 0
	if #club.shortlist + pinnedCount == 0 then
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
	local function close()
		if gui ~= screen then
			return -- already closed: death and DONE can both land
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

	-- three slots in a row, plus a smaller fourth for the pinned card
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.44)
	row.Size = UDim2.fromScale(ROW_W, ROW_H)
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- bottoms aligned, not centres: the pinned card is smaller, and its Sign/Unpin
	-- row would otherwise float half a button above the other two
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, SLOT_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	-- Card size for `count` cards abreast: whichever of the row's width and
	-- height runs out first. A phone in portrait always runs out of width.
	local function slotSize(count: number, scale: number): UDim2
		local vp = camera.ViewportSize
		local room = (vp.X * ROW_W - SLOT_GAP * (count - 1)) / math.max(count, 1)
		local height = math.min(vp.Y * ROW_H, room / Config.CardAspect) * scale
		return UDim2.fromOffset(math.floor(height * Config.CardAspect), math.floor(height))
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
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.new(0.9, 0, 0, 44),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local done = Theme.button(screen, "DONE", "primary", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.97, 0),
		Size = UDim2.fromOffset(200, 46),
		TextSize = 18,
		Font = Theme.fonts.display,
		Visible = false,
	})
	done.Activated:Connect(close)

	local function result()
		clearRow()
		local now = getClub()
		if not now then
			return close()
		end
		local count = #now.shortlist + (if now.pinned then 1 else 0)
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
		local function cardWithButtons(p: any, order: number, pinned: boolean)
			local s = slot(order, slotSize(count, if pinned then PINNED_SCALE else 1))
			table.insert(resultCards, PlayerCard.new(s, p))
			local bar = Instance.new("Frame")
			bar.Name = "Actions"
			bar.BackgroundTransparency = 1
			bar.AnchorPoint = Vector2.new(0.5, 0)
			bar.Position = UDim2.new(0.5, 0, 1, 8)
			bar.Size = UDim2.new(1, 0, 0, 40)
			bar.Parent = s
			local fee = (p.fee :: number?) or 0
			local short = fee - purse - (if squadFull then bestSale else 0)
			local signText = if fee == 0
				then "KEEP  FREE"
				elseif short > 0 then ("NEED %s MORE"):format(Format.money(short))
				else ("SIGN  %s"):format(Format.money(fee))
			local sign = Theme.button(bar, signText, if short > 0 then "ghost" else "primary", {
				Size = UDim2.new(0.62, -4, 1, 0),
				TextSize = 15,
			})
			local signing = false -- a fast double tap must not fire two signings
			sign.Activated:Connect(function()
				if short > 0 or signing then
					return
				end
				signing = true
				-- a signing that lands redraws this card away; if the server
				-- refuses, the button has to come back so it can be tried again
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
			-- Unpinning throws the card away for good, so it asks twice.
			local pin = Theme.button(bar, if pinned then "UNPIN" else "PIN", if short > 0 and not pinned then "primary" else "ghost", {
				Size = UDim2.new(0.38, -4, 1, 0),
				Position = UDim2.new(0.62, 4, 0, 0),
				TextSize = 15,
			})
			local armed = false
			pin.Activated:Connect(function()
				if not pinned then
					actionEvent:FireServer("pin", p.id)
					return
				end
				if armed then
					actionEvent:FireServer("unpin")
					return
				end
				armed = true
				pin.Text = "SURE?"
				task.delay(2, function()
					if pin.Parent then
						armed = false
						pin.Text = "UNPIN"
					end
				end)
			end)
			if pinned then
				Theme.text(s, "PINNED", "accent", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 0, -6),
					Size = UDim2.new(1, 0, 0, 20),
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end
		end
		for i, p in now.shortlist do
			cardWithButtons(p, i, false)
		end
		if now.pinned then
			cardWithButtons(now.pinned, 10, true)
		end
	end

	local function showResult()
		done.Visible = true
		drawResult = function()
			local latest = getClub()
			headline.Text = if latest and latest.packFree then "KEEP ONE TRIALIST FOR FREE" else "SCOUT REPORT"
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
		else
			Focus.push("pack")
		end
		if cancelled then
			return
		end
		TweenService:Create(shade, TweenInfo.new(SHADE_IN), { BackgroundTransparency = SHADE }):Play()
		task.wait(SHADE_IN)
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
				headline.Text = string.upper(tostring(entry.player.role or ""))
				task.wait(BUILD_ROLE)
				glow:Destroy()
			end
			sound(Config.PackAudio.flip)
			entry.card:flip()
			sound(Config.PackAudio.sting, 0.9 + rank * 0.08)
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
	local state = ClubRef.state()
	if state then
		table.insert(conns, state:GetAttributeChangedSignal("Phase"):Connect(function()
			if state:GetAttribute("Phase") ~= "Manage" then
				close()
			end
		end))
	end
	table.insert(conns, player.CharacterRemoving:Connect(close))
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(conns, humanoid.Died:Connect(close))
	end

	if club.packRevealed or #club.shortlist == 0 then
		Focus.push("pack")
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
