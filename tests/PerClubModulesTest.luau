--!strict
-- PlotService clones PER_CLUB into ServerScriptService.ClubRuntime.PlotN, and every
-- server module reaches its neighbours as `require(script.Parent.<name>)`. Inside
-- that per-plot folder `script.Parent` is the clone folder, so a cloned module can
-- only require something that was also cloned.
--
-- Nothing else catches this: the rest of the suite requires modules straight out of
-- ServerScriptService.Server, where every module is a sibling and every require
-- resolves. The gap only shows at runtime, as "X is not a valid member of Folder
-- ServerScriptService.ClubRuntime.PlotN", and it stops a club being claimed at all
-- ("BUILD MY CLUB HERE" fails). That is exactly how X369 broke it, by adding a
-- KitPlacer require to PlotGrounds without adding KitPlacer to PER_CLUB.

local ServerScriptService = game:GetService("ServerScriptService")

local server = ServerScriptService:WaitForChild("Server")
local PlotService = require(server.PlotService)

local T = {}

local function perClubSet(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, name in PlotService.PER_CLUB do
		set[name] = true
	end
	return set
end

function T.everyPerClubModuleIsPresentOnTheServer()
	for _, name in PlotService.PER_CLUB do
		assert(server:FindFirstChild(name), ("PER_CLUB lists %q but ServerScriptService.Server has no such module"):format(name))
	end
end

function T.perClubModulesOnlyRequireOtherPerClubModules()
	local set = perClubSet()
	local missing: { string } = {}
	for _, name in PlotService.PER_CLUB do
		local mod = server:FindFirstChild(name)
		if not mod or not mod:IsA("ModuleScript") then
			continue
		end
		-- `require(script.Parent.Foo)` and `require(script.Parent["Foo"])`
		for dep in string.gmatch((mod :: ModuleScript).Source, "require%s*%(%s*script%.Parent%.([%w_]+)") do
			if not set[dep] then
				table.insert(missing, ("%s requires %s"):format(name, dep))
			end
		end
		for dep in string.gmatch((mod :: ModuleScript).Source, 'require%s*%(%s*script%.Parent%[%s*"([%w_]+)"') do
			if not set[dep] then
				table.insert(missing, ("%s requires %s"):format(name, dep))
			end
		end
	end
	assert(
		#missing == 0,
		"these cloned modules require something PER_CLUB does not clone, so claiming a plot will fail: "
			.. table.concat(missing, "; ")
	)
end

return T
