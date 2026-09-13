-- Fallback one-shot sync: pulls the current tree from a running `rojo serve`
-- (http://localhost:34872) straight into the open Studio place via HttpService.
-- Use when the Rojo plugin session is stale but the server is fine. Run through
-- the Studio command bar or the MCP execute_luau tool in Edit mode.
-- Only Folders and script Sources are synced; anything else is left alone.

local HttpService = game:GetService("HttpService")
local BASE = "http://localhost:34872"

local info = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "/api/rojo"))
local tree = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "/api/read/" .. info.rootInstanceId))
local instances = tree.instances

local changed, created = {}, {}

local function sync(id, parent)
	local node = instances[id]
	if not node then
		return
	end
	local target
	if parent == game then
		target = game:GetService(node.ClassName)
	else
		target = parent:FindFirstChild(node.Name)
		if target and target.ClassName ~= node.ClassName then
			target:Destroy()
			target = nil
		end
		if not target then
			target = Instance.new(node.ClassName)
			target.Name = node.Name
			target.Parent = parent
			table.insert(created, target:GetFullName())
		end
	end
	local source = node.Properties and node.Properties.Source
	if source and source.String and target:IsA("LuaSourceContainer") then
		if target.Source ~= source.String then
			target.Source = source.String
			table.insert(changed, target:GetFullName())
		end
	end
	for _, childId in node.Children do
		sync(childId, target)
	end
end

for _, childId in instances[info.rootInstanceId].Children do
	sync(childId, game)
end

return ("created: %s\nchanged: %s"):format(
	#created > 0 and table.concat(created, ", ") or "-",
	#changed > 0 and table.concat(changed, ", ") or "-"
)
