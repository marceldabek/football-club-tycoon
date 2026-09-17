--!strict
-- Every `Enum.<Type>.<Item>` written in the game's scripts must exist. A bad
-- name only fails at runtime when that line runs: `Enum.Material.CorrugatedSteel`
-- on the level-4 stand roof stopped the whole club from starting, and no other
-- test builds a plot at that level. Reads script Source, so it runs from the
-- command bar / MCP like the rest of RunAll.

local T = {}

local ENUMS = { "Material", "Font", "PartType", "NormalId", "SurfaceType", "EasingStyle", "EasingDirection", "KeyCode" }

local function scripts(): { LuaSourceContainer }
	local out = {}
	for _, root in { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer"), game:GetService("StarterGui") } do
		for _, d in root:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				table.insert(out, d)
			end
		end
	end
	return out
end

function T.enumItemNamesExist()
	local bad = {}
	local checked = 0
	for _, s in scripts() do
		local source = (s :: any).Source :: string
		for _, enumName in ENUMS do
			for item in source:gmatch("Enum%." .. enumName .. "%.([%a_][%w_]*)") do
				checked += 1
				local ok = pcall(function()
					return (Enum :: any)[enumName][item]
				end)
				if not ok then
					table.insert(bad, s.Name .. ": Enum." .. enumName .. "." .. item)
				end
			end
		end
	end
	assert(checked > 100, "only " .. checked .. " enum uses found")
	assert(#bad == 0, "unknown enum items: " .. table.concat(bad, ", "))
end

return T
