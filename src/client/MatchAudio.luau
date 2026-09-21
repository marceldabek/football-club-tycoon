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

-- X281: the town's ambient crowd bed stands down while this one plays
function MatchAudio.isCrowdPlaying(): boolean
	return ambient ~= nil
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

-- Background music: shuffled playlist, one track after another. Volume moves
-- with a fade so the match duck and the post-match restore are never a jump.
local TweenService = game:GetService("TweenService")
local music: Sound? = nil
local playlistToken = 0
local ducked = false
local enabled = true

local function targetVolume(): number
	return ducked and Config.MusicMatchVolume or Config.MusicVolume
end

local function fadeTo(volume: number, seconds: number)
	if music then
		TweenService:Create(music, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Volume = volume }):Play()
	end
end

-- Night music while this player's sky is dark. Sky owns the flag (its
-- DARK_ATTRIBUTE on the local player); read by name so audio never needs Sky.
local DARK_ATTRIBUTE = "SkyDark"
local localPlayer = game:GetService("Players").LocalPlayer
local playingNight = false

local function isDark(): boolean
	return localPlayer ~= nil and localPlayer:GetAttribute(DARK_ATTRIBUTE) == true
end

local function playlist(): { string }
	if playingNight and #Config.MusicNight > 0 then
		return Config.MusicNight
	end
	return Config.Music
end

local function nextTrack(token: number, lastId: string?)
	local list = playlist()
	if token ~= playlistToken or #list == 0 or not enabled then
		return
	end
	local id = list[math.random(1, #list)]
	if #list > 1 and id == lastId then
		return nextTrack(token, lastId) -- pick a different one
	end
	local sound = make(id, false, 0)
	if not sound then
		return
	end
	music = sound
	sound.Ended:Once(function()
		sound:Destroy()
		if token == playlistToken then
			music = nil
			nextTrack(token, id)
		end
	end)
	sound:Play()
	fadeTo(targetVolume(), 2)
	-- X224: a track that never loads (removed or unavailable asset) never fires
	-- Ended, which silenced the playlist for good; skip on after a while. 30 s
	-- and only when unloaded, so a slow phone still gets its valid track.
	task.delay(30, function()
		if token == playlistToken and music == sound and sound.Parent and not (sound.IsLoaded and sound.IsPlaying) then
			sound:Destroy()
			music = nil
			nextTrack(token, id)
		end
	end)
end

function MatchAudio.startMusic()
	if music and not music.Parent then
		music = nil -- destroyed from outside; start fresh
	end
	if music or not enabled then
		return
	end
	playlistToken += 1
	playingNight = isDark()
	nextTrack(playlistToken, nil)
end

-- Day/night swap. A fast-forward sweeps the clock through the night in a
-- couple of seconds, so only a sky that stays dark (or light) for a few
-- seconds changes the music; then the old track fades out and the other
-- playlist starts.
local SWAP_SETTLE = 4
local SWAP_FADE = 2.5
if localPlayer then
	local swapCheck = 0
	localPlayer:GetAttributeChangedSignal(DARK_ATTRIBUTE):Connect(function()
		swapCheck += 1
		local mine = swapCheck
		task.delay(SWAP_SETTLE, function()
			local old = music
			-- only swaps a playlist that is running; startMusic picks by the sky itself
			if mine ~= swapCheck or not enabled or not old or isDark() == playingNight then
				return
			end
			playlistToken += 1 -- the old track's Ended no longer chains on
			music = nil
			if old then
				TweenService:Create(old, TweenInfo.new(SWAP_FADE, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
				task.delay(SWAP_FADE, function()
					old:Destroy()
				end)
			end
			playingNight = isDark()
			nextTrack(playlistToken, nil)
		end)
	end)
end

function MatchAudio.stopMusic()
	playlistToken += 1
	if music then
		music:Stop()
		music:Destroy()
		music = nil
	end
end

-- The player's music switch. Off stops the playlist entirely.
function MatchAudio.setMusicEnabled(on: boolean)
	enabled = on
	if on then
		MatchAudio.startMusic()
	else
		MatchAudio.stopMusic()
	end
end

function MatchAudio.isMusicEnabled(): boolean
	return enabled
end

-- Lower the music under the crowd during a match, ease it back afterwards.
function MatchAudio.duckMusic(duck: boolean)
	ducked = duck
	fadeTo(targetVolume(), duck and 1.5 or 4)
end

function MatchAudio.goalCheer()
	oneShot(Config.Sounds.goalCheer, 0.6)
end

-- X183: a home chance saved or missed. No licensed "ooh" clip was found, so
-- the goal cheer plays quieter and slowed into a groan-like swell (TEMP).
function MatchAudio.nearMiss()
	local sound = make(Config.Sounds.goalCheer, false, 0.28)
	if not sound then
		return
	end
	sound.PlaybackSpeed = 0.72
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(1.6, function()
		if sound.Parent then
			local fade = TweenService:Create(sound, TweenInfo.new(0.6), { Volume = 0 })
			fade.Completed:Once(function()
				sound:Destroy()
			end)
			fade:Play()
		end
	end)
end

function MatchAudio.whistle()
	oneShot(Config.Sounds.whistle, 0.5)
end

return MatchAudio
