--!strict
-- The build label (docs/SOFT_LAUNCH.md SL3): shown in a HUD corner so a bug
-- report can say which build it came from. Bump `version` when publishing.
-- `tag` is the channel; drop it when the beta ends.

local Build = {}

Build.tag = "BETA"
Build.version = "0.1.1" -- 2026-09-21: first published private beta build

function Build.label(): string
	return ("%s %s"):format(Build.tag, Build.version)
end

return Build
