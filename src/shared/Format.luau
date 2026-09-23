--!strict
-- X342: the same three formatters had grown five, two and two copies of
-- themselves - money in Theme, MatchSummary, UpgradeService, ClubService and
-- Trade (X204 "fixed" a call site by adding the fifth), ordinal in Theme and
-- ClubCard, surname in LineupBoard and WorldBuilder. The root cause is that
-- Theme is a client module, so shared and server code could not reach it.
-- These live here, where everything can.
--
-- Every copy of `money` also printed a negative as "£-,500", because grouping
-- the digits in threes from the right catches the minus sign and the `^,`
-- strip only ever looked at the front of the string.

local Format = {}

-- "£1,500", "£0", "-£500". Rounded down, like every figure the player is
-- quoted; the sign is kept outside the grouping.
function Format.money(n: number): string
	local whole = math.floor(math.abs(n))
	local digits = tostring(whole)
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	grouped = grouped:gsub("^,", "")
	return (if n < 0 then "-£" else "£") .. grouped
end

-- 1st, 2nd, 3rd, 4th... 11th, 12th, 13th, 21st.
function Format.ordinal(n: number): string
	local last, lastTwo = n % 10, n % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return n .. "th"
	end
	return n .. (if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th")
end

-- "Danny Rashford-Lyle" -> "Rashford-Lyle", for shirt backs and cards.
-- Everything after the first name, so "Matteo De Luca" keeps his "De Luca".
function Format.surname(full: string): string
	local rest = string.match(full, "^%S+%s+(.+)$")
	return rest or full
end

-- "Killian Moreau" -> "K. Moreau", how a card names a player (Marcel,
-- 2026-09-21). A single name stays as it is. The initial is one whole UTF-8
-- character, so "Álvaro" is "Á." rather than half a letter.
function Format.cardName(full: string): string
	local first, rest = string.match(full, "^(%S+)%s+(.+)$")
	if not first then
		return full
	end
	return (string.match(first, utf8.charpattern) or "") .. ". " .. rest
end

-- The capital of one lower-case code point in Latin-1 and Latin Extended-A
-- (every accent the nations' name pools use), or the code point unchanged.
local function upperCode(c: number): number
	if c >= 0xE0 and c <= 0xFE and c ~= 0xF7 then -- à..þ, not ÷
		return c - 0x20
	elseif c == 0xFF then -- ÿ
		return 0x178
	elseif c == 0x131 then -- Turkish dotless ı
		return 0x49
	elseif c >= 0x100 and c <= 0x137 then -- Ā ā .. Ķ ķ: upper even, lower odd
		return if c % 2 == 1 then c - 1 else c
	elseif c >= 0x139 and c <= 0x148 then -- Ĺ ĺ .. Ň ň: upper odd, lower even
		return if c % 2 == 0 then c - 1 else c
	elseif c >= 0x14A and c <= 0x177 then -- Ŋ ŋ .. Ŷ ŷ
		return if c % 2 == 1 then c - 1 else c
	elseif c >= 0x179 and c <= 0x17E then -- Ź ź .. Ž ž
		return if c % 2 == 0 then c - 1 else c
	end
	return c
end

-- P7 (#18c): string.upper only knows ASCII, so "Lefèvre" came out "LEFèVRE".
-- Upper-cases accented letters too. Bytes that are not valid UTF-8 go through
-- string.upper untouched rather than failing.
function Format.upper(s: string): string
	if not utf8.len(s) then
		return string.upper(s)
	end
	local out = table.create(#s)
	for _, c in utf8.codes(s) do
		if c < 0x80 then
			table.insert(out, string.upper(string.char(c)))
		else
			table.insert(out, utf8.char(upperCode(c)))
		end
	end
	return table.concat(out)
end

return Format
