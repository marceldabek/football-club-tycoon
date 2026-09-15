--!strict
-- Boots the club for this server and keeps it saved.
--   Loading: wait for the first player (the owner) -> load their profile ->
--   restore every service -> build the world -> Manage.
-- Also owns the club-naming remote and the world prompt wiring, both of
-- which are owner-only. One club per server; other players are visitors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Config = require(ReplicatedStorage.Shared.Config)
local Profile = require(ReplicatedStorage.Shared.Profile)
local ClubState = require(script.Parent.ClubState)
local WorldBuilder = require(script.Parent.WorldBuilder)
local MatchService = require(script.Parent.MatchService)
local UpgradeService = require(script.Parent.UpgradeService)
local ClubService = require(script.Parent.ClubService)
local SeasonService = require(script.Parent.SeasonService)
local HistoryService = require(script.Parent.HistoryService)
local SaveService = require(script.Parent.SaveService)
local Scenery = require(script.Parent.Scenery)

local Session = {}

local saver: SaveService.Saver
local backendKind = "none"
local ownerId = 0
local loaded = false
local world: WorldBuilder.World? = nil
-- Stamps carried across snapshots (the saver bumps updatedAt / saveCount).
local createdAt = 0
local updatedAt = 0
local saveCount = 0

local function findOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function remote(name: string): RemoteEvent
	local remotes = findOrCreate(ReplicatedStorage, "Remotes", "Folder")
	return findOrCreate(remotes, name, "RemoteEvent") :: RemoteEvent
end

local function toast(player: Player, message: string, ok: boolean?)
	remote("Toast"):FireClient(player, message, ok)
end

local VISITOR_MESSAGE = "You're visiting this club. Only the owner can manage it."

-- ------------------------------------------------------------------ profile

function Session.ownerId(): number
	return ownerId
end

function Session.snapshot(): Profile.Profile
	local scalars = ClubState.serialize()
	local raw: any = {
		version = Profile.VERSION,
		clubName = scalars.clubName,
		named = scalars.named,
		cash = scalars.cash,
		stands = scalars.stands,
		amenityLevel = scalars.amenityLevel,
		matchesPlayed = scalars.matchesPlayed,
		wins = scalars.wins,
		draws = scalars.draws,
		losses = scalars.losses,
		club = ClubService.serialize(),
		season = SeasonService.serialize(),
		history = HistoryService.serialize(),
		createdAt = createdAt,
		updatedAt = updatedAt,
		saveCount = saveCount,
	}
	local profile = Profile.normalize(raw)
	return profile
end

-- Matchday starts from the world board or the HUD's PLAY MATCH button; both
-- go through here so the owner check and the phase lock are in one place.
local function requestMatch(player: Player)
	if not ClubState.isOwner(player) then
		toast(player, VISITOR_MESSAGE)
		return
	end
	if ClubState.get("Phase") ~= "Manage" then
		toast(player, "A match is already in progress")
		return
	end
	local started = MatchService.playMatch()
	if not started then
		toast(player, "A match is already in progress")
	end
end

local function wireWorld(w: WorldBuilder.World)
	w.matchdayPrompt.Triggered:Connect(requestMatch)

	for key, prompt in w.standPrompts do
		prompt.Triggered:Connect(function(player)
			if not ClubState.isOwner(player) then
				toast(player, VISITOR_MESSAGE)
				return
			end
			local ok, message = UpgradeService.tryExpandStand(key)
			if ok then
				remote("Toast"):FireAllClients(message or "Stand expanded!", true)
			else
				toast(player, message or "Cannot expand right now")
			end
		end)
	end

	w.amenityPrompt.Triggered:Connect(function(player)
		if not ClubState.isOwner(player) then
			toast(player, VISITOR_MESSAGE)
			return
		end
		local ok, message = UpgradeService.tryUpgradeAmenity()
		if ok then
			remote("Toast"):FireAllClients(message or "Amenity built!", true)
		else
			toast(player, message or "Cannot build right now")
		end
	end)
end

-- Everything from the profile into the services and the world. Used at
-- boot and by the Studio "reload" command.
function Session.restoreAll(p: Profile.Profile)
	createdAt = p.createdAt
	updatedAt = p.updatedAt
	saveCount = p.saveCount
	ClubState.restore(p)
	local w = WorldBuilder.build(p.stands, p.amenityLevel)
	world = w
	UpgradeService.init({ stands = w.standPrompts, amenity = w.amenityPrompt })
	wireWorld(w)
	ClubService.restore(p.club)
	SeasonService.restore(p.season)
	HistoryService.restore(p.history)
	Session.refreshPromptLock()
end

function Session.refreshPromptLock()
	local w = world
	if not w then
		return
	end
	local phase = ClubState.get("Phase")
	local managing = phase == "Manage"
	w.matchdayPrompt.Enabled = managing
	UpgradeService.refreshPrompt()
	Scenery.setMatchday(phase == "PreMatch" or phase == "Match")
end

-- Every save goes through here so the stamps the saver writes stay in step.
local function flush(force: boolean): boolean
	if not loaded then
		return false
	end
	local ok = saver:flush(ownerId, Session.snapshot, force)
	if ok then
		saveCount += 1
		updatedAt = os.time()
		print(("[FCT] saved (%s, #%d)"):format(backendKind, saveCount))
	end
	return ok
end

function Session.saveNow(): boolean
	return flush(true)
end

-- Studio: prove the round trip without leaving the session.
function Session.reload(): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Reload only between matches"
	end
	local snapshot = Session.snapshot()
	local HttpService = game:GetService("HttpService")
	local copy = HttpService:JSONDecode(HttpService:JSONEncode(snapshot))
	local profile = Profile.normalize(copy)
	Session.restoreAll(profile)
	return true, "reloaded from a JSON copy of the snapshot"
end

-- Studio: throw the club away and start again.
function Session.wipe(): (boolean, string?)
	if ClubState.get("Phase") ~= "Manage" then
		return false, "Wipe only between matches"
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	local name = (if owner then owner.DisplayName else "Your") .. Config.DefaultClubNameSuffix
	Session.restoreAll(Profile.new(name))
	Session.saveNow()
	return true, "fresh club"
end

-- ------------------------------------------------------------------- naming

local function applyName(player: Player, requested: unknown)
	if not ClubState.isOwner(player) then
		toast(player, VISITOR_MESSAGE)
		return
	end
	if not (ClubState.get("NeedsName") :: boolean) then
		toast(player, "The club already has its name")
		return
	end
	if type(requested) ~= "string" then
		return
	end
	local name = requested:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if #name < Config.ClubNameMinLength or #name > Config.ClubNameMaxLength then
		toast(player, ("Name must be %d to %d characters"):format(Config.ClubNameMinLength, Config.ClubNameMaxLength))
		return
	end
	if not name:match("^[%w%s'%-%.]+$") then
		toast(player, "Letters, numbers, spaces, ' - . only")
		return
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	local final: string
	if ok then
		final = filtered
	elseif RunService:IsStudio() then
		warn("[FCT] text filter unavailable in Studio; accepting the name unfiltered")
		final = name
	else
		warn("[FCT] text filter failed: " .. tostring(filtered))
		final = ClubState.get("ClubName") :: string
		toast(player, "Couldn't check that name right now. Keeping " .. final)
	end
	ClubState.set("ClubName", final)
	ClubState.set("NeedsName", false)
	SeasonService.renameClub(final)
	WorldBuilder.setClubName(final)
	Session.saveNow()
	toast(player, ("Welcome to %s!"):format(final), true)
end

-- --------------------------------------------------------------------- boot

local function waitForOwner(): Player
	local existing = Players:GetPlayers()[1]
	if existing then
		return existing
	end
	return Players.PlayerAdded:Wait()
end

function Session.start()
	ClubState.init()
	MatchService.init()
	ClubService.init()
	HistoryService.init()
	SeasonService.init()
	remote("ClubName").OnServerEvent:Connect(applyName)
	remote("PlayMatch").OnServerEvent:Connect(function(player: Player)
		if loaded then
			requestMatch(player)
		end
	end)
	Scenery.setup() -- lighting, horizon and floodlights exist while the club loads

	local backend, kind = SaveService.autoBackend(Config.Save.storeName)
	backendKind = kind
	saver = SaveService.new(backend, { retries = Config.Save.loadRetries, backoff = Config.Save.retryBackoffSeconds })

	local owner: Player
	local profile: Profile.Profile
	local isNew = false
	while true do
		owner = waitForOwner()
		local data, status = saver:load(owner.UserId)
		if owner.Parent ~= Players then
			continue -- left while we were loading; wait for the next one
		end
		if status == "error" then
			owner:Kick("Your club could not be loaded. Please rejoin.")
			while owner.Parent do
				task.wait(0.1)
			end
			continue
		end
		if status == "new" then
			isNew = true
			profile = Profile.new(owner.DisplayName .. Config.DefaultClubNameSuffix)
		else
			local changed
			profile, changed = Profile.normalize(data)
			if changed then
				warn("[FCT] profile needed repairs on load")
			end
		end
		break
	end

	ownerId = owner.UserId
	Session.restoreAll(profile)
	loaded = true
	ClubState.set("OwnerUserId", ownerId)
	ClubState.onDirty = function()
		saver:markDirty()
	end
	-- the prompts follow the phase; listen before the flip to Manage so the
	-- matchday board and upgrade signs come on at boot, not at the next change
	ClubState.Folder:GetAttributeChangedSignal("Phase"):Connect(Session.refreshPromptLock)
	ClubState.set("Phase", "Manage")
	Session.refreshPromptLock()
	print(("[FCT] %s profile for %s (%s): %s, %d matches played"):format(
		if isNew then "new" else "loaded", owner.Name, backendKind, profile.clubName, profile.matchesPlayed))

	-- a brand-new club exists in the store straight away
	if isNew then
		Session.saveNow()
	end
	task.spawn(function()
		while true do
			task.wait(Config.Save.autosaveSeconds)
			if saver:isDirty() then
				flush(false)
			end
		end
	end)
	MatchService.onSettled = function()
		Session.saveNow()
	end

	Players.PlayerRemoving:Connect(function(player)
		if player.UserId == ownerId then
			flush(true)
		end
	end)
	game:BindToClose(function()
		flush(true)
	end)
end

return Session
