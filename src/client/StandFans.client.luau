--!strict
-- Starts the stand crowd (#6c): every ground's fans are client-built avatars
-- now, see StandCrowd. MatchPresenter requires the same module to make them
-- react.

local StandCrowd = require(script.Parent:WaitForChild("StandCrowd"))

StandCrowd.start()
