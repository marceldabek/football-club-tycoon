--!strict
-- One club crest, drawn the same way everywhere it appears: league table rows,
-- the next-match line, the club panel header, the match summary and the
-- in-match scoreboard.
--
-- The crest is a rounded shield filled with the club's kit colour, ringed and
-- lettered in its accent colour. Both colours come from Config.clubCrest, which
-- is keyed by club name, so a caller only needs the name -- no colour has to be
-- threaded through a replication payload to reach the UI.
--
-- Everything scales off `size`, so the same call works at 20px in a table row
-- and at 84px on the summary card. League clubs with crest art show it inside
-- the same shield frame (Crest.applyArt), so no call site changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Theme)

local Crest = {}

export type Options = {
	isPlayer: boolean?, -- the player's own club, which uses the home kit
	layoutOrder: number?,
	position: UDim2?,
	anchorPoint: Vector2?,
}

-- Up to two letters. "FC" is skipped unless it is all there is, so "Hedgerow
-- FC" reads HE rather than HF, and a one-word club falls back to its first two
-- letters: "Bramblewick Rovers" -> BR, "Ravensmoor" -> RA, "Hedgerow FC" -> HE.
function Crest.initials(name: string?): string
	local out = ""
	for word in (name or ""):gmatch("%S+") do
		if word:upper() ~= "FC" or out == "" then
			out ..= word:sub(1, 1):upper()
		end
		if #out >= 2 then
			break
		end
	end
	if out == "" then
		return "?"
	end
	if #out == 1 then
		local first = (name or ""):match("%S+")
		if first and #first >= 2 then
			return first:sub(1, 2):upper()
		end
	end
	return out
end

-- League crest art (docs/CRESTS.md). Kept in this one function so the player's
-- crest (the crest builder) can change around it: it adds or updates an `Art`
-- image inside `shield` and, while art shows, hides the shield's own fill, ring
-- and every other child. Returns true when art is shown. The player's club and
-- unknown clubs have no art and get their shield back.
function Crest.applyArt(shield: Frame, name: string?, isPlayer: boolean?): boolean
	local image = Config.clubCrestImage(name, isPlayer)
	local art = shield:FindFirstChild("Art") :: ImageLabel?
	if image and not art then
		local label = Instance.new("ImageLabel")
		label.Name = "Art"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.ScaleType = Enum.ScaleType.Fit
		label.ZIndex = shield.ZIndex + 1
		label.Parent = shield
		art = label
	end
	if art then
		art.Visible = image ~= nil
		art.Image = image or ""
	end
	local showArt = image ~= nil
	shield.BackgroundTransparency = if showArt then 1 else 0
	for _, child in shield:GetChildren() do
		if child:IsA("UIStroke") then
			child.Enabled = not showArt
		elseif child:IsA("GuiObject") and child ~= art then
			child.Visible = not showArt
		end
	end
	return showArt
end

-- A shield for `name` at `size` pixels square, parented to `parent`.
-- Returns the shield so callers can position it in their own layout.
function Crest.draw(parent: Instance, name: string?, size: number, options: Options?): Frame
	local opts = options or {}
	local kit, accent = Config.clubCrest(name, opts.isPlayer)

	local shield = Instance.new("Frame")
	shield.Name = "Crest"
	shield.Size = UDim2.fromOffset(size, size)
	shield.BackgroundColor3 = kit
	shield.BorderSizePixel = 0
	shield.LayoutOrder = opts.layoutOrder or 0
	if opts.position then
		shield.Position = opts.position
	end
	if opts.anchorPoint then
		shield.AnchorPoint = opts.anchorPoint
	end
	shield.Parent = parent
	Theme.corner(shield, math.max(3, math.floor(size * 0.28)))

	-- The accent ring is what separates two dark-kitted clubs sitting next to
	-- each other in a table, so it is drawn rather than left to the theme.
	local ring = Instance.new("UIStroke")
	ring.Color = accent
	ring.Thickness = math.max(1, size * 0.06)
	ring.Transparency = 0.15
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = shield

	-- Below roughly 24px two letters turn to mush, so the small sizes used in
	-- list rows are a colour chip and nothing else.
	if size >= 24 then
		Theme.text(shield, Crest.initials(name), "display", {
			Name = "Initials",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			TextSize = math.floor(size * 0.46),
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	end

	Crest.applyArt(shield, name, opts.isPlayer)
	return shield
end

-- Repoint an existing shield at a different club. Used by panels that rebuild
-- their contents on every state change and would otherwise leak instances.
function Crest.update(shield: Frame, name: string?, isPlayer: boolean?)
	local kit, accent = Config.clubCrest(name, isPlayer)
	shield.BackgroundColor3 = kit
	local ring = shield:FindFirstChildOfClass("UIStroke")
	if ring then
		ring.Color = accent
	end
	local letters = shield:FindFirstChild("Initials")
	if letters and letters:IsA("TextLabel") then
		letters.Text = Crest.initials(name)
		letters.TextColor3 = accent
	end
	Crest.applyArt(shield, name, isPlayer)
end

return Crest
