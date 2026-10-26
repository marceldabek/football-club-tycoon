--!strict
-- The build label (docs/SOFT_LAUNCH.md SL3): shown in a HUD corner so a bug
-- report can say which build it came from. Bump `version` when publishing.
-- `tag` is the channel; drop it when the beta ends.

local Build = {}

Build.tag = "BETA"
Build.version = "0.1.2" -- 2026-10-26: playtest 0.1.1 fixes and the ground plan's first steps

function Build.label(): string
	return ("%s %s"):format(Build.tag, Build.version)
end

return Build
