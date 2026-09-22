--!strict
-- SL14: suggested club names, so the founding card always has a way out.
--
-- The name box refuses non-ASCII text, names the league already uses, and
-- anything the text filter changes, and a filter outage refuses everything.
-- A player who keeps hitting one of those can take a suggestion instead. The
-- list is developer-authored, so the server accepts it without the filter
-- (Session.applyName) and it cannot fail. Every entry must be plain ASCII,
-- within Config.ClubNameMin/MaxLength and not in Config.Clubs
-- (ClubNamesTest checks all three).

local ClubNames = {}

-- Rivermere places (CLAUDE.md s27) with football club suffixes.
ClubNames.SUGGESTIONS = {
	"Rivermere Rovers",
	"Rivermere Town",
	"Rivermere Athletic",
	"Lune Valley FC",
	"Northfields United",
	"Westdale Wanderers",
	"Riverside Albion",
	"Riverside Park FC",
	"Station Road FC",
	"Old Viaduct United",
	"Market Square Rangers",
	"Lune Bridge Athletic",
	"Rivermere Celtic",
	"Northfields Town",
	"Westdale United",
}

local lookup: { [string]: boolean } = {}
for _, name in ClubNames.SUGGESTIONS do
	lookup[name] = true
end

-- Exactly one of the suggestions (already trimmed; case matters).
function ClubNames.isSuggested(name: string): boolean
	return lookup[name] == true
end

-- A suggestion other than `avoid`, so repeated taps keep changing the box.
function ClubNames.pick(rng: Random, avoid: string?): string
	local n = #ClubNames.SUGGESTIONS
	local i = rng:NextInteger(1, n)
	if ClubNames.SUGGESTIONS[i] == avoid then
		i = i % n + 1
	end
	return ClubNames.SUGGESTIONS[i]
end

return ClubNames
