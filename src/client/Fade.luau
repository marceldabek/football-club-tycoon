--!strict
-- Fade transition: a full-screen black frame fades in (close) and back out
-- (open). Replaced the iris circle (playtest #1): the circle was sized for a
-- normal screen shape and left a round mask on ultrawide screens. A plain
-- fade covers any aspect ratio.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Fade = {}

local cover: Frame

local function ensure(): Frame
	if cover and cover.Parent then
		return cover
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Fade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 1
	cover.BorderSizePixel = 0
	cover.Visible = false -- an invisible full-screen frame still eats touches on some devices
	cover.Parent = gui
	return cover
end

-- X259: one frame, so a bus trip or a picker close that overlaps the walkout
-- used to cancel the other's tween and still report success. Each call takes a
-- token; whoever holds the newest one owns the fade.
local token = 0

local function play(transparency: number, duration: number): number?
	local frame = ensure()
	token += 1
	local mine = token
	frame.Visible = true
	local tween = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { BackgroundTransparency = transparency })
	tween:Play()
	local state = tween.Completed:Wait()
	if mine == token and state == Enum.PlaybackState.Completed then
		if transparency >= 1 then
			frame.Visible = false
		end
		return mine
	end
	return nil
end

-- True while `ticket` is still the newest transition. A caller that waits
-- before fading back in should check this first: something else may have
-- taken it over in between (the matchday walkout, say).
function Fade.owns(ticket: number?): boolean
	return ticket ~= nil and ticket == token
end

-- Both yield until the transition finishes. Nil means a newer transition took
-- over: it owns the fade now, so don't tween it back.
function Fade.close(duration: number): number?
	return play(0, duration)
end

function Fade.open(duration: number): number?
	return play(1, duration)
end

return Fade
