--!strict
-- Boots one club and keeps it saved.
--   Loading: PlotService hands over the owner -> load their profile ->
--   restore every service -> build the world -> Manage.
-- Also owns the club-naming remote and the world prompt wiring, both of
-- which are owner-only. There is one copy of this module per claimed plot
-- (docs/PLOTS.md); other players on the plot are visitors.

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
local SaveLock = require(script.Parent.SaveLock)
local Scenery = require(script.Parent.Scenery)
local PlotContext = require(script.Parent.PlotContext)
local PlotGrounds = require(script.Parent.PlotGrounds)

local Session = {}

local saver: SaveService.Saver
local locker: SaveLock.Locker? = nil
local haveLock = false
-- X196: another server stole the lock; it may already have saved newer data,
-- so this server must never write the club again
local lockStolen = false
local backendKind = "none"
local ownerId = 0
local loaded = false
local stopped = false
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
		finance = ClubState.financeSnapshot(), -- X299
		settings = {
			music = ClubState.get("SettingMusic") ~= false,
			quality = ClubState.get("SettingQuality") or "",
		},
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
	if ClubState.get("NeedsName") == true then
		toast(player, "Name your club first.")
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
				toast(player, message or "Stand expanded!", true)
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
			toast(player, message or "Amenity built!", true)
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
	if PlotContext.index then
		Scenery.buildClubFloodlights(w.model)
		PlotGrounds.build(w.model)
	end
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
	-- X250: the HUD's PLAY MATCH hides until the club is named; the board must
	-- agree, or match 1 can start with the placeholder name still on the card
	local named = ClubState.get("NeedsName") ~= true
	w.matchdayPrompt.Enabled = managing and named
	-- X249: the office computer prompt is part of matchday lock-out too. The
	-- client's panel refuses to open outside Manage, so an enabled prompt that
	-- does nothing was the only thing that still looked usable.
	local clubPrompt = w.model:FindFirstChild("ClubPrompt", true)
	if clubPrompt and clubPrompt:IsA("ProximityPrompt") then
		-- X339: and not before the club has a name, like the matchday board
		clubPrompt.Enabled = managing and named
		clubPrompt.ObjectText = if managing then "Manage squad, scouting & staff" else "Locked during matchday"
	end
	-- the scout's report on the desk: a pack lands after every match, scout or
	-- not, and the folder is lit while the latest one is unopened
	local scoutPrompt = w.model:FindFirstChild("ScoutPrompt", true)
	if scoutPrompt and scoutPrompt:IsA("ProximityPrompt") then
		local played = ((ClubState.get("MatchesPlayed") :: number?) or 0) > 0
		scoutPrompt.Enabled = managing and named and played
		local glow = scoutPrompt.Parent and scoutPrompt.Parent:FindFirstChild("NewGlow")
		if glow and glow:IsA("Highlight") then
			glow.Enabled = scoutPrompt.Enabled and ClubState.get("ScoutReportNew") == true
		end
	end
	UpgradeService.refreshPrompt()
	Scenery.setMatchday(phase == "PreMatch" or phase == "Match", ClubState.get("Evening") == true)
end

-- X274: a store that refuses every write used to be invisible. After this many
-- flushes in a row fail, the owner is told rather than finding out on rejoin.
local FAILED_SAVES_BEFORE_WARNING = 2
local failedSaves = 0

-- X364: `lockStolen` is only set inside the heartbeat loop, which ticks every
-- `Config.Save.heartbeatSeconds`, so for up to ten seconds after another server
-- took this owner's lock this session would still write - and
-- `MatchService.onSettled` saves unconditionally the moment a match settles, so
-- a match that finished a second after the new server loaded could overwrite
-- the new session's profile with this one's. SaveLock's own header promises
-- that cannot happen, so every write asks the lock record first.
--
-- A lock that is merely *requested* is not refused: handing over with one last
-- flush is the decided behaviour (CLAUDE.md s27, "the old session closes").
local function lockTaken(): boolean
	if not haveLock or locker == nil then
		return false -- no locking backend (the Studio memory fallback)
	end
	local ok, held, stolen = pcall(function()
		return (locker :: SaveLock.Locker):heartbeat(ownerId)
	end)
	if not ok then
		return false -- a backend error is not proof; the heartbeat loop decides
	end
	if stolen then
		lockStolen = true
		return true
	end
	return false
end

-- Every save goes through here so the stamps the saver writes stay in step.
local function flush(force: boolean): boolean
	if not loaded or stopped or lockStolen then
		return false
	end
	-- only worth a lock read when there is actually something to write
	if (force or saver:isDirty()) and lockTaken() then
		warn("[FCT] save refused: another server holds this club's lock")
		return false
	end
	local ok = saver:flush(ownerId, Session.snapshot, force)
	if ok then
		saveCount += 1
		updatedAt = os.time()
		print(("[FCT] saved (%s, #%d)"):format(backendKind, saveCount))
		if failedSaves >= FAILED_SAVES_BEFORE_WARNING then
			local owner = Players:GetPlayerByUserId(ownerId)
			if owner then
				toast(owner, "Saving again. Your club is safe.", true)
			end
		end
		failedSaves = 0
	elseif saver:isDirty() then
		-- isDirty means there was something to write, so this really failed
		-- rather than "nothing to do"
		failedSaves += 1
		if failedSaves == FAILED_SAVES_BEFORE_WARNING then
			local owner = Players:GetPlayerByUserId(ownerId)
			if owner then
				toast(owner, "Your club isn't saving right now. Recent progress may be lost.")
			end
			warn(("[FCT] %d saves in a row failed for %d"):format(failedSaves, ownerId))
		end
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
	local length = utf8.len(name) or #name -- X190: letters, not bytes
	if length < Config.ClubNameMinLength or length > Config.ClubNameMaxLength then
		toast(player, ("Name must be %d to %d characters"):format(Config.ClubNameMinLength, Config.ClubNameMaxLength))
		return
	end
	if not name:match("^[%w%s'%-%.]+$") then
		toast(player, "Letters, numbers, spaces, ' - . only")
		return
	end
	-- X213: not the name of a league club (duplicate table rows and crests)
	local lower = string.lower(name)
	for _, division in Config.Clubs do
		for _, club in division do
			if string.lower(club.name) == lower then
				toast(player, "There's already a club called that in the league. Try another name.")
				return
			end
		end
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	local final: string
	if ok then
		-- X198: a name the filter changed (hashes) is refused, not kept for good
		if filtered ~= name then
			toast(player, "That name isn't allowed. Try another one.")
			return
		end
		final = filtered
	elseif RunService:IsStudio() then
		warn("[FCT] text filter unavailable in Studio; accepting the name unfiltered")
		final = name
	else
		-- X197: a filter outage must not use up the only naming chance
		warn("[FCT] text filter failed: " .. tostring(filtered))
		toast(player, "Couldn't check that name right now. Try again in a moment.")
		return
	end
	ClubState.set("ClubName", final)
	ClubState.set("NeedsName", false)
	SeasonService.renameClub(final)
	WorldBuilder.setClubName(final)
	Session.saveNow()
	toast(player, ("Welcome to %s!"):format(final), true)
end

-- --------------------------------------------------------------------- boot

-- Loads `owner`'s club into this plot and runs it until stop(). Yields while
-- the save loads. Returns false when the owner left during the load or the
-- load failed (they are kicked so a broken store never gets overwritten).
function Session.start(owner: Player): boolean
	ClubState.init()
	MatchService.init()
	ClubService.init()
	HistoryService.init()
	SeasonService.init()
	PlotContext.onRemote(remote("ClubName"), applyName)
	-- X223: the owner's music and quality choices, saved with the club
	PlotContext.onRemote(remote("SaveSettings"), function(player: Player, rawMusic: unknown, rawQuality: unknown)
		if not loaded or not ClubState.isOwner(player) then
			return
		end
		if type(rawMusic) == "boolean" then
			ClubState.set("SettingMusic", rawMusic)
		end
		if rawQuality == "High" or rawQuality == "Low" then
			ClubState.set("SettingQuality", rawQuality)
		end
	end)
	PlotContext.onRemote(remote("PlayMatch"), function(player: Player)
		if loaded then
			requestMatch(player)
		end
	end)
	if not PlotContext.index then
		Scenery.setup() -- single-club place: the old scenery around the origin
	end

	local storeName = SaveService.storeNameFor(Config.Save.storeName, RunService:IsStudio(), Config.Save.studioStoreSuffix)
	local backend, kind = SaveService.autoBackend(storeName)
	backendKind = kind
	saver = SaveService.new(backend, { retries = Config.Save.loadRetries, backoff = Config.Save.retryBackoffSeconds })

	-- Decided behaviour (CLAUDE.md s27, "Save lock"): a new server always
	-- acquires the lock and loads; a previous session holding it notices via
	-- heartbeat (below) and closes itself rather than us waiting on it. The
	-- lock backend mirrors the save backend so Studio's memory fallback never
	-- touches a real DataStore. Acquiring is best-effort: a broken lock store
	-- must never strand the player at a loading screen forever, so an error
	-- here just logs and continues without a lock instead of blocking.
	local lockBackend = if backendKind == "datastore"
		then SaveLock.dataStoreBackend(storeName)
		else SaveLock.memoryBackend()
	-- one id per session, not per server: a stopped session on this server must not
	-- release a lock that a newer session for the same owner now holds
	local sessionGuid = game:GetService("HttpService"):GenerateGUID(false)
	local jobId = (if game.JobId ~= "" then game.JobId else "studio") .. ":" .. sessionGuid
	locker = SaveLock.new(lockBackend, {
		jobId = jobId,
		now = os.time,
		wait = task.wait,
		staleAfter = Config.Save.lockStaleSeconds,
		maxWait = Config.Save.lockMaxWaitSeconds,
		poll = Config.Save.lockPollSeconds,
	})
	local lockOk, lockErr = pcall(function()
		(locker :: SaveLock.Locker):acquire(owner.UserId)
	end)
	haveLock = lockOk
	if not lockOk then
		warn(("[FCT] save lock acquire failed for %d: %s (continuing without a lock)"):format(owner.UserId, tostring(lockErr)))
	end
	-- X207: leaving while the lock or save was loading must still free the lock
	-- (stop() ran before haveLock was set), or the next join waits the full maxWait
	local function releaseEarly()
		if haveLock then
			pcall(function()
				(locker :: SaveLock.Locker):release(owner.UserId)
			end)
			haveLock = false
		end
	end
	if owner.Parent ~= Players or stopped then
		releaseEarly()
		return false -- left while we were waiting for the lock
	end

	local data, status = saver:load(owner.UserId)
	if owner.Parent ~= Players or stopped then
		releaseEarly()
		return false -- left while we were loading
	end
	if status == "error" then
		releaseEarly()
		owner:Kick("Your club could not be loaded. Please rejoin.")
		return false
	end
	local profile: Profile.Profile
	local isNew = status == "new"
	if isNew then
		profile = Profile.new(owner.DisplayName .. Config.DefaultClubNameSuffix)
	else
		local changed
		profile, changed = Profile.normalize(data)
		if changed then
			warn("[FCT] profile needed repairs on load")
		end
	end

	ownerId = owner.UserId
	ClubState.set("OwnerUserId", ownerId)
	Session.restoreAll(profile)
	loaded = true
	ClubState.onDirty = function()
		saver:markDirty()
	end
	-- the prompts follow the phase; listen before the flip to Manage so the
	-- matchday board and upgrade signs come on at boot, not at the next change
	ClubState.Folder:GetAttributeChangedSignal("Phase"):Connect(Session.refreshPromptLock)
	ClubState.Folder:GetAttributeChangedSignal("NeedsName"):Connect(Session.refreshPromptLock)
	ClubState.Folder:GetAttributeChangedSignal("ScoutLevel"):Connect(Session.refreshPromptLock)
	-- the desk folder opens on the first match, not on hiring a scout
	ClubState.Folder:GetAttributeChangedSignal("MatchesPlayed"):Connect(Session.refreshPromptLock)
	ClubState.Folder:GetAttributeChangedSignal("ScoutReportNew"):Connect(Session.refreshPromptLock)
	ClubState.set("Phase", "Manage")
	Session.refreshPromptLock()
	print(("[FCT] %s %s profile for %s (%s): %s, %d matches played"):format(
		PlotContext.name(), if isNew then "new" else "loaded", owner.Name, backendKind, profile.clubName, profile.matchesPlayed))

	-- a brand-new club exists in the store straight away
	if isNew then
		Session.saveNow()
	end
	task.spawn(function()
		local lastAutosave = os.clock()
		-- X275: the loop body is pcall'd. It used to call Session.snapshot outside
		-- any pcall, so one serialize error killed the thread for the rest of the
		-- session: no autosave and, worse, no lock heartbeat, so another server
		-- took the stale lock and quietly won.
		local function tick(): boolean
			if haveLock then
				-- Another server took (or is requesting) this owner's lock:
				-- decided behaviour is the new server always wins, so this one
				-- flushes what it has and closes rather than fighting for it.
				local hbOk, hbHeld, hbStolen = pcall(function()
					return (locker :: SaveLock.Locker):heartbeat(ownerId)
				end)
				if hbOk and not hbHeld then
					if hbStolen then
						-- X196: the new server already holds the lock (and may have
						-- saved); flushing now could overwrite newer data
						lockStolen = true
						warn("[FCT] save lock was taken by another server; not saving this session again")
					else
						-- only requested: the new server waits for this final save
						flush(true)
					end
					local ownerPlayer = Players:GetPlayerByUserId(ownerId)
					if ownerPlayer then
						ownerPlayer:Kick("Your club was opened on another server.")
					end
					Session.stop()
					return false
				end
			end
			if not stopped and saver:isDirty() and os.clock() - lastAutosave >= Config.Save.autosaveSeconds then
				lastAutosave = os.clock()
				flush(false)
			end
			return true
		end
		while not stopped do
			task.wait(Config.Save.heartbeatSeconds)
			if stopped then
				break
			end
			local ok, result = pcall(tick)
			if not ok then
				warn("[FCT] autosave/heartbeat tick failed (continuing): " .. tostring(result))
			elseif result == false then
				break -- the tick asked us to stop (the lock went to another server)
			end
		end
	end)
	MatchService.onSettled = function()
		Session.saveNow()
	end
	return true
end

-- The owner left (or the server is closing): save one last time, then take
-- the club out of the world. Safe to call twice.
function Session.stop()
	if stopped then
		return
	end
	flush(true)
	if haveLock and not lockStolen then
		local ok = pcall(function()
			(locker :: SaveLock.Locker):release(ownerId)
		end)
		if not ok then
			warn("[FCT] save lock release failed (harmless; it will go stale and a new server can steal it)")
		end
		haveLock = false
	end
	stopped = true
	loaded = false
	local w = world
	world = nil
	if w and w.model.Parent then
		w.model:Destroy()
	end
	ClubState.Folder:Destroy()
end

return Session
