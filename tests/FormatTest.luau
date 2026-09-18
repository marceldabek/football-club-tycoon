--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Format)

local T = {}

function T.moneyGroupsInThrees()
	assert(Format.money(0) == "£0", "got " .. Format.money(0))
	assert(Format.money(50) == "£50", "got " .. Format.money(50))
	assert(Format.money(1500) == "£1,500", "got " .. Format.money(1500))
	assert(Format.money(94620) == "£94,620", "got " .. Format.money(94620))
	assert(Format.money(3412694) == "£3,412,694", "got " .. Format.money(3412694))
end

function T.moneyHandlesANegativeWithoutAStrayComma()
	-- X342: every copy of this printed "£-,500"
	assert(Format.money(-500) == "-£500", "got " .. Format.money(-500))
	assert(Format.money(-12345) == "-£12,345", "got " .. Format.money(-12345))
end

function T.moneyRoundsDownLikeEveryOtherFigure()
	assert(Format.money(1500.99) == "£1,500", "got " .. Format.money(1500.99))
	assert(Format.money(-1500.99) == "-£1,500", "got " .. Format.money(-1500.99))
end

function T.ordinalKnowsTheTeens()
	local want = {
		[1] = "1st", [2] = "2nd", [3] = "3rd", [4] = "4th",
		[11] = "11th", [12] = "12th", [13] = "13th",
		[21] = "21st", [22] = "22nd", [23] = "23rd", [111] = "111th",
	}
	for n, text in want do
		assert(Format.ordinal(n) == text, ("ordinal(%d) should be %s, got %s"):format(n, text, Format.ordinal(n)))
	end
end

function T.surnameIsTheLastWord()
	assert(Format.surname("Danny Rashford-Lyle") == "Rashford-Lyle", "hyphens stay together")
	assert(Format.surname("Pelé") == "Pelé", "one name is its own surname")
	assert(Format.surname("") == "", "and nothing is nothing")
end

return T
