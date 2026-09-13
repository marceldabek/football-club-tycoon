--!strict
-- Matchday sounds. Every ID comes from Config.Sounds; an empty ID means the
-- sound is silently skipped, so the game never depends on audio loading.
-- Crowd volume follows attendance so a full stand sounds fuller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage.Shared.Config)

local MatchAudio = {}

local ambient: Sound? = nil

local function make(id: string, looped: boolean, volume: number): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

-- 0..1 crowd fullness; scales the ambient volume.
function MatchAudio.startCrowd(fullness: number)
	MatchAudio.stopCrowd()
	local sound = make(Config.Sounds.crowdAmbient, true, Config.CrowdVolume * math.clamp(0.4 + fullness * 0.6, 0.4, 1))
	if sound then
		sound:Play()
		ambient = sound
	end
end

function MatchAudio.stopCrowd()
	if ambient then
		ambient:Stop()
		ambient:Destroy()
		ambient = nil
	end
end

local function oneShot(id: string, volume: number)
	local sound = make(id, false, volume)
	if not sound then
		return
	end
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function MatchAudio.goalCheer()
	oneShot(Config.Sounds.goalCheer, 0.6)
end

function MatchAudio.whistle()
	oneShot(Config.Sounds.whistle, 0.5)
end

return MatchAudio
