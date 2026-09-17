--!strict
-- Client-side lighting looks and the fast-forward transitions between them.
-- Pure: no Instances, no services. Scenery.luau (server) still owns the
-- authoritative Lighting/Atmosphere/ColorCorrection/SunRays instances for now;
-- this module is the data the client-side day/night work (A1.x) reads from.
-- See CLAUDE.md section 27 "Time & lighting": time of day is client-side per
-- player, normal play sits on one fixed "hero afternoon", most matches are
-- afternoon with some evening floodlit games, and a skippable fast-forward
-- (sun sweep -> sunset -> lights on -> night -> morning -> hero afternoon)
-- plays after each match (~4s) and at season end (~10s).

local DayCycle = {}

export type Look = {
	clock: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmosphereDensity: number,
	atmosphereOffset: number,
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	atmosphereGlare: number,
	atmosphereHaze: number,
	bloomIntensity: number,
	sunRays: number,
	gradeBrightness: number,
	gradeContrast: number,
	gradeSaturation: number,
	gradeTint: Color3,
	floodlights: boolean,
	streetLights: boolean,
}

-- Atmosphere densities were cut ~30% on 2026-09-17 so the town reads at
-- 1,000+ studs (the club-only values hid everything past ~600).
-- Named looks. HeroAfternoon mirrors Scenery.setupLighting's current values
-- (kept close on purpose), nudged slightly brighter/bluer per the brief.
local LOOKS: { [string]: Look } = {
	HeroAfternoon = {
		clock = 15.0,
		brightness = 2.7,
		exposure = 0.15,
		ambient = Color3.fromRGB(70, 75, 85),
		outdoorAmbient = Color3.fromRGB(125, 135, 150),
		atmosphereDensity = 0.22,
		atmosphereOffset = 0.25,
		atmosphereColor = Color3.fromRGB(210, 215, 230),
		atmosphereDecay = Color3.fromRGB(120, 110, 130),
		atmosphereGlare = 0.35,
		atmosphereHaze = 0.9,
		bloomIntensity = 0.35,
		sunRays = 0.08,
		gradeBrightness = 0.02,
		gradeContrast = 0.1,
		gradeSaturation = 0.14,
		gradeTint = Color3.fromRGB(255, 250, 240),
		floodlights = false,
		streetLights = false,
	},
	EveningMatch = {
		clock = 19.2,
		brightness = 1.4,
		exposure = 0.05,
		ambient = Color3.fromRGB(45, 48, 60),
		outdoorAmbient = Color3.fromRGB(60, 65, 85),
		atmosphereDensity = 0.3,
		atmosphereOffset = 0.2,
		atmosphereColor = Color3.fromRGB(140, 130, 160),
		atmosphereDecay = Color3.fromRGB(80, 70, 100),
		atmosphereGlare = 0.2,
		atmosphereHaze = 1.4,
		bloomIntensity = 0.5,
		sunRays = 0.02,
		gradeBrightness = 0.0,
		gradeContrast = 0.12,
		gradeSaturation = 0.05,
		gradeTint = Color3.fromRGB(230, 235, 255),
		floodlights = true,
		streetLights = true,
	},
	Sunset = {
		clock = 18.3,
		brightness = 1.9,
		exposure = 0.1,
		ambient = Color3.fromRGB(90, 70, 70),
		outdoorAmbient = Color3.fromRGB(180, 120, 90),
		atmosphereDensity = 0.32,
		atmosphereOffset = 0.22,
		atmosphereColor = Color3.fromRGB(255, 170, 120),
		atmosphereDecay = Color3.fromRGB(140, 90, 80),
		atmosphereGlare = 0.5,
		atmosphereHaze = 1.6,
		bloomIntensity = 0.55,
		sunRays = 0.15,
		gradeBrightness = 0.02,
		gradeContrast = 0.12,
		gradeSaturation = 0.2,
		gradeTint = Color3.fromRGB(255, 215, 190),
		floodlights = false,
		streetLights = true,
	},
	Night = {
		clock = 0.5,
		brightness = 0.9,
		exposure = -0.1,
		ambient = Color3.fromRGB(20, 22, 32),
		outdoorAmbient = Color3.fromRGB(25, 28, 42),
		atmosphereDensity = 0.24,
		atmosphereOffset = 0.3,
		atmosphereColor = Color3.fromRGB(40, 45, 70),
		atmosphereDecay = Color3.fromRGB(20, 20, 35),
		atmosphereGlare = 0.05,
		atmosphereHaze = 0.9,
		bloomIntensity = 0.2,
		sunRays = 0.0,
		gradeBrightness = -0.03,
		gradeContrast = 0.08,
		gradeSaturation = 0.0,
		gradeTint = Color3.fromRGB(220, 225, 245),
		floodlights = false,
		streetLights = true,
	},
	Dawn = {
		clock = 6.5,
		brightness = 1.6,
		exposure = 0.05,
		ambient = Color3.fromRGB(80, 80, 95),
		outdoorAmbient = Color3.fromRGB(150, 140, 160),
		atmosphereDensity = 0.28,
		atmosphereOffset = 0.24,
		atmosphereColor = Color3.fromRGB(210, 180, 200),
		atmosphereDecay = Color3.fromRGB(110, 95, 120),
		atmosphereGlare = 0.3,
		atmosphereHaze = 1.3,
		bloomIntensity = 0.4,
		sunRays = 0.1,
		gradeBrightness = 0.0,
		gradeContrast = 0.09,
		gradeSaturation = 0.08,
		gradeTint = Color3.fromRGB(235, 225, 240),
		floodlights = false,
		streetLights = true,
	},
	Overcast = {
		clock = 14.0,
		brightness = 1.8,
		exposure = 0.0,
		ambient = Color3.fromRGB(90, 92, 95),
		outdoorAmbient = Color3.fromRGB(140, 142, 148),
		atmosphereDensity = 0.35,
		atmosphereOffset = 0.2,
		atmosphereColor = Color3.fromRGB(190, 192, 198),
		atmosphereDecay = Color3.fromRGB(130, 130, 135),
		atmosphereGlare = 0.1,
		atmosphereHaze = 2.0,
		bloomIntensity = 0.15,
		sunRays = 0.0,
		gradeBrightness = -0.02,
		gradeContrast = 0.06,
		gradeSaturation = 0.0,
		gradeTint = Color3.fromRGB(245, 245, 245),
		floodlights = false,
		streetLights = false,
	},
}
DayCycle.LOOKS = LOOKS

-- Lerps a-to-b going forward through the clock, wrapping at 24h, so e.g.
-- 22.5 -> 6.5 sweeps through midnight rather than running backwards.
local function lerpClockForward(a: number, b: number, t: number): number
	local forwardSpan = if b >= a then b - a else (b + 24) - a
	return (a + forwardSpan * t) % 24
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function DayCycle.lerpLook(a: Look, b: Look, t: number): Look
	local switchToB = t >= 0.5
	return {
		clock = lerpClockForward(a.clock, b.clock, t),
		brightness = lerpNumber(a.brightness, b.brightness, t),
		exposure = lerpNumber(a.exposure, b.exposure, t),
		ambient = a.ambient:Lerp(b.ambient, t),
		outdoorAmbient = a.outdoorAmbient:Lerp(b.outdoorAmbient, t),
		atmosphereDensity = lerpNumber(a.atmosphereDensity, b.atmosphereDensity, t),
		atmosphereOffset = lerpNumber(a.atmosphereOffset, b.atmosphereOffset, t),
		atmosphereColor = a.atmosphereColor:Lerp(b.atmosphereColor, t),
		atmosphereDecay = a.atmosphereDecay:Lerp(b.atmosphereDecay, t),
		atmosphereGlare = lerpNumber(a.atmosphereGlare, b.atmosphereGlare, t),
		atmosphereHaze = lerpNumber(a.atmosphereHaze, b.atmosphereHaze, t),
		bloomIntensity = lerpNumber(a.bloomIntensity, b.bloomIntensity, t),
		sunRays = lerpNumber(a.sunRays, b.sunRays, t),
		gradeBrightness = lerpNumber(a.gradeBrightness, b.gradeBrightness, t),
		gradeContrast = lerpNumber(a.gradeContrast, b.gradeContrast, t),
		gradeSaturation = lerpNumber(a.gradeSaturation, b.gradeSaturation, t),
		gradeTint = a.gradeTint:Lerp(b.gradeTint, t),
		floodlights = if switchToB then b.floodlights else a.floodlights,
		streetLights = if switchToB then b.streetLights else a.streetLights,
	}
end

export type Keyframe = { at: number, look: string }
export type Track = { duration: number, keys: { Keyframe } }

-- Skippable fast-forward played after a match (~4s) or at season end (~10s):
-- sun sweep -> sunset -> lights on -> night -> morning -> back to the hero
-- afternoon look play resumes on. `fromEvening` starts the sweep from the
-- floodlit look instead, for a match that kicked off in the evening.
function DayCycle.fastForward(kind: "match" | "season", fromEvening: boolean?): Track
	local startLook = if fromEvening then "EveningMatch" else "HeroAfternoon"
	if kind == "match" then
		local duration = 4
		return {
			duration = duration,
			keys = {
				{ at = 0, look = startLook },
				{ at = 0.8, look = "Sunset" },
				{ at = 1.6, look = "EveningMatch" }, -- lights on
				{ at = 2.4, look = "Night" },
				{ at = 3.2, look = "Dawn" },
				{ at = duration, look = "HeroAfternoon" },
			},
		}
	end
	-- "season"
	local duration = 10
	return {
		duration = duration,
		keys = {
			{ at = 0, look = startLook },
			{ at = 2, look = "Sunset" },
			{ at = 4, look = "EveningMatch" }, -- lights on
			{ at = 6, look = "Night" },
			{ at = 8, look = "Dawn" },
			{ at = duration, look = "HeroAfternoon" },
		},
	}
end

local function smoothstep(t: number): number
	return t * t * (3 - 2 * t)
end

-- Samples a fast-forward track at `time` seconds, clamped to [0, duration].
function DayCycle.sample(track: Track, time: number): Look
	local keys = track.keys
	local t = math.clamp(time, 0, track.duration)
	local firstKey, lastKey = keys[1], keys[#keys]
	if t <= firstKey.at then
		return LOOKS[firstKey.look]
	end
	if t >= lastKey.at then
		return LOOKS[lastKey.look]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a.at and t <= b.at then
			local span = b.at - a.at
			local frac = if span > 0 then (t - a.at) / span else 1
			return DayCycle.lerpLook(LOOKS[a.look], LOOKS[b.look], smoothstep(frac))
		end
	end
	return LOOKS[lastKey.look]
end

-- TEMP: which league fixtures kick off in the evening, before the season
-- schedule carries a real kickoff time. Deterministic and roughly 1 in 4,
-- never the two onboarding matches so early games stay in the easy, legible
-- afternoon look.
function DayCycle.isEveningFixture(matchIndex: number): boolean
	if matchIndex <= 2 then
		return false
	end
	return matchIndex % 4 == 3
end

return DayCycle
