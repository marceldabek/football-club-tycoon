--!strict
-- Depth of field only for menus, close-ups and the match intro (CLAUDE.md
-- s27, Q13). Client-local: a DepthOfFieldEffect in Lighting that eases in
-- while any "reason" is active and eases out when the last one ends.
--   Focus.watch(frame)          blur while a menu frame is visible
--   Focus.push(reason, settings?) / Focus.pop(reason)   for scripted shots

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Focus = {}

export type Settings = { focusDistance: number?, inFocusRadius: number?, farIntensity: number?, nearIntensity: number? }

-- A menu blurs everything behind it; a close-up keeps the subject sharp.
local MENU: Settings = { focusDistance = 4, inFocusRadius = 6, farIntensity = 0.55, nearIntensity = 0 }
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

local function refresh()
	local dof = effect()
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
