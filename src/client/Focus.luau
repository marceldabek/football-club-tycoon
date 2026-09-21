--!strict
-- Depth of field only for menus, close-ups and the match intro (CLAUDE.md
-- s27, Q13). Client-local: a DepthOfFieldEffect in Lighting that eases in
-- while any "reason" is active and eases out when the last one ends. Menus
-- also get a full-screen BlurEffect (Marcel, 2026-09-21: "blur whenever we
-- enter menus"); a close-up passes its own settings without `blur`.
--   Focus.watch(frame)          blur while a menu frame is visible
--   Focus.push(reason, settings?) / Focus.pop(reason)   for scripted shots

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Focus = {}

export type Settings = {
	focusDistance: number?,
	inFocusRadius: number?,
	farIntensity: number?,
	nearIntensity: number?,
	blur: number?, -- BlurEffect size; nil = none
}

-- A menu blurs everything behind it; a close-up keeps the subject sharp.
local MENU: Settings = { focusDistance = 4, inFocusRadius = 6, farIntensity = 0.55, nearIntensity = 0, blur = 16 }
local EASE = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local active: { [string]: Settings } = {}
local order: { string } = {}

local function effect(): DepthOfFieldEffect
	local existing = Lighting:FindFirstChild("FocusDoF")
	if existing and existing:IsA("DepthOfFieldEffect") then
		return existing
	end
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "FocusDoF"
	dof.FarIntensity = 0
	dof.NearIntensity = 0
	dof.Enabled = false
	dof.Parent = Lighting
	return dof
end

local function blurEffect(): BlurEffect
	local existing = Lighting:FindFirstChild("FocusBlur")
	if existing and existing:IsA("BlurEffect") then
		return existing
	end
	local blur = Instance.new("BlurEffect")
	blur.Name = "FocusBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting
	return blur
end

-- The strongest blur any active reason asks for, so a close-up pushed over an
-- open menu doesn't unblur it.
local function blurSize(): number
	local size = 0
	for _, settings in active do
		size = math.max(size, settings.blur or 0)
	end
	return size
end

local function refresh()
	local dof = effect()
	local blur = blurEffect()
	local size = blurSize()
	if size > 0 then
		blur.Enabled = true
	end
	local blurTween = TweenService:Create(blur, EASE, { Size = size })
	blurTween.Completed:Connect(function()
		if blurSize() == 0 then
			blur.Enabled = false
		end
	end)
	blurTween:Play()

	local top = order[#order]
	local settings = top and active[top]
	if not settings then
		local tween = TweenService:Create(dof, EASE, { FarIntensity = 0, NearIntensity = 0 })
		tween.Completed:Connect(function()
			if #order == 0 then
				dof.Enabled = false
			end
		end)
		tween:Play()
		return
	end
	dof.Enabled = true
	dof.FocusDistance = settings.focusDistance or MENU.focusDistance :: number
	dof.InFocusRadius = settings.inFocusRadius or MENU.inFocusRadius :: number
	TweenService:Create(dof, EASE, {
		FarIntensity = settings.farIntensity or MENU.farIntensity,
		NearIntensity = settings.nearIntensity or MENU.nearIntensity,
	}):Play()
end

function Focus.push(reason: string, settings: Settings?)
	if not active[reason] then
		table.insert(order, reason)
	end
	active[reason] = settings or MENU
	refresh()
end

function Focus.pop(reason: string)
	if not active[reason] then
		return
	end
	active[reason] = nil
	local i = table.find(order, reason)
	if i then
		table.remove(order, i)
	end
	refresh()
end

-- Blur while `frame` (and its ScreenGui) is showing.
function Focus.watch(frame: GuiObject, settings: Settings?)
	local reason = "gui:" .. frame:GetFullName()
	local function update()
		if frame.Visible and frame.Parent then
			Focus.push(reason, settings)
		else
			Focus.pop(reason)
		end
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(update)
	frame.AncestryChanged:Connect(update)
	update()
end

return Focus
