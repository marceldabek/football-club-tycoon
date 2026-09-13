--!strict
-- Runs every sibling *Test module. Each test module returns { [name] = function }.
--
-- Modules are compiled fresh from their Source on every run (with `require`
-- redirected to do the same) so the Studio command bar / MCP VM's require
-- cache never serves stale code after a sync.
--
-- Invoke from the command bar / MCP execute_luau (Edit mode):
--   print(loadstring(game.ServerStorage.Tests.RunAll.Source)()())

local function makeFreshRequire()
	local cache: { [Instance]: any } = {}
	local function freshRequire(inst: Instance): any
		if cache[inst] ~= nil then
			return cache[inst]
		end
		local container = inst :: LuaSourceContainer
		local fn, err = loadstring(container.Source, "=" .. inst:GetFullName())
		assert(fn, err)
		local env = setmetatable({ script = inst, require = freshRequire }, { __index = getfenv(0) })
		setfenv(fn :: any, env :: any)
		local result = (fn :: any)()
		cache[inst] = result
		return result
	end
	return freshRequire
end

return function(): string
	local lines = {}
	local passed, failed = 0, 0
	local freshRequire = makeFreshRequire()
	local tests = game:GetService("ServerStorage"):WaitForChild("Tests")
	for _, child in tests:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:match("Test$") then
			local loaded, suiteOrErr = pcall(freshRequire, child)
			if not loaded then
				failed += 1
				table.insert(lines, ("FAIL %s (load): %s"):format(child.Name, tostring(suiteOrErr)))
				continue
			end
			local suite = suiteOrErr :: { [string]: () -> () }
			local names = {}
			for name in suite do
				table.insert(names, name)
			end
			table.sort(names)
			for _, name in names do
				local ok, err = pcall(suite[name])
				if ok then
					passed += 1
				else
					failed += 1
					table.insert(lines, ("FAIL %s.%s: %s"):format(child.Name, name, tostring(err)))
				end
			end
		end
	end
	table.insert(lines, ("%d passed, %d failed"):format(passed, failed))
	return table.concat(lines, "\n")
end
