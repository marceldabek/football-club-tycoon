--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubNames = require(ReplicatedStorage.Shared.ClubNames)
local Config = require(ReplicatedStorage.Shared.Config)

local T = {}

-- SL14: a suggestion must pass every rule Session.applyName checks before
-- the filter, or "always succeeds" is a lie.
function T.everySuggestionPassesTheNameRules()
	local taken: { [string]: boolean } = {}
	for _, division in Config.Clubs do
		for _, club in division do
			taken[string.lower(club.name)] = true
		end
	end
	local seen: { [string]: boolean } = {}
	for _, name in ClubNames.SUGGESTIONS do
		assert(name == name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "), name .. " is not trimmed")
		local length = utf8.len(name) or #name
		assert(length >= Config.ClubNameMinLength and length <= Config.ClubNameMaxLength, name .. " length")
		assert(name:match("^[%w%s'%-%.]+$"), name .. " charset")
		assert(not taken[string.lower(name)], name .. " is a league club")
		assert(not seen[name], name .. " listed twice")
		seen[name] = true
		assert(ClubNames.isSuggested(name), name .. " should be recognised")
	end
	assert(#ClubNames.SUGGESTIONS >= 10, "enough to feel like a choice")
end

function T.isSuggestedIsExact()
	assert(not ClubNames.isSuggested("rivermere rovers"), "case matters")
	assert(not ClubNames.isSuggested("Rivermere Rovers "), "no trailing space")
	assert(not ClubNames.isSuggested(""), "empty")
end

function T.pickAvoidsTheCurrentName()
	local rng = Random.new(7)
	for _ = 1, 50 do
		local first = ClubNames.pick(rng)
		assert(ClubNames.pick(rng, first) ~= first, "a repeat tap must change the box")
	end
end

return T
