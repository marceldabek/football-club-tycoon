--!strict
-- Storage for club profiles. A Saver wraps a backend (DataStore in a live
-- game, a table in an unpublished Studio place and in tests) with retries, a
-- dirty flag and an autosave loop. It never confuses "no data yet" with
-- "the store is broken", and refuses to save until a load has succeeded so a
-- failed load can never be overwritten by a fresh club.

local RunService = game:GetService("RunService")

local SaveService = {}

export type Backend = {
	get: (key: string) -> any?,
	set: (key: string, value: any) -> (),
}

export type LoadStatus = "ok" | "new" | "error"

export type Options = {
	retries: number?,
	backoff: number?,
	wait: ((number) -> ())?,
	now: (() -> number)?,
}

export type Saver = {
	load: (self: Saver, userId: number) -> (any?, LoadStatus),
	save: (self: Saver, userId: number, profile: any) -> boolean,
	markDirty: (self: Saver) -> (),
	isDirty: (self: Saver) -> boolean,
	flush: (self: Saver, userId: number, snapshot: () -> any, force: boolean?) -> boolean,
	startAutosave: (self: Saver, userId: number, snapshot: () -> any, seconds: number) -> (),
	stopAutosave: (self: Saver) -> (),
}

local function keyFor(userId: number): string
	return "u" .. tostring(userId)
end

-- Values go through JSON so the memory backend behaves like a DataStore:
-- no shared references, and anything that is not JSON-safe (sparse arrays,
-- userdata) errors here in Studio instead of in production.
function SaveService.memoryBackend(store: { [string]: any }?): Backend
	local HttpService = game:GetService("HttpService")
	local data: { [string]: any } = store or {}
	return {
		get = function(key: string): any?
			local raw = data[key]
			return if raw == nil then nil else HttpService:JSONDecode(raw)
		end,
		set = function(key: string, value: any)
			data[key] = HttpService:JSONEncode(value)
		end,
	}
end

function SaveService.dataStoreBackend(storeName: string): Backend
	local store: DataStore? = nil
	local function getStore(): DataStore
		if not store then
			store = game:GetService("DataStoreService"):GetDataStore(storeName)
		end
		return store :: DataStore
	end
	return {
		get = function(key: string): any?
			return getStore():GetAsync(key)
		end,
		set = function(key: string, value: any)
			getStore():UpdateAsync(key, function()
				return value
			end)
		end,
	}
end

-- Pure: the DataStore name for this server. Studio sessions add the suffix so
-- playtests keep their own saves (and save locks) apart from live players'.
function SaveService.storeNameFor(base: string, isStudio: boolean, studioSuffix: string?): string
	if isStudio and studioSuffix and studioSuffix ~= "" then
		return base .. studioSuffix
	end
	return base
end

-- DataStores need a published place. In Studio with an unpublished place we
-- fall back to memory (no persistence across Play sessions) and say so once.
function SaveService.autoBackend(storeName: string): (Backend, string)
	if RunService:IsStudio() then
		local ok, err = pcall(function()
			game:GetService("DataStoreService"):GetDataStore(storeName):GetAsync("__probe")
		end)
		if not ok then
			warn(("[FCT] DataStore unavailable in Studio (%s). Saving to memory for this session only."):format(tostring(err)))
			return SaveService.memoryBackend(), "memory"
		end
	end
	return SaveService.dataStoreBackend(storeName), "datastore"
end

function SaveService.new(backend: Backend, opts: Options?): Saver
	local options: Options = opts or {}
	local retries = options.retries or 3
	local backoff = options.backoff or 1
	local wait = options.wait or task.wait
	local now = options.now or os.time

	local loaded: { [number]: boolean } = {}
	local dirty = false
	local autosaveToken = 0

	local function attempt(fn: () -> any): (boolean, any)
		local lastErr: any = nil
		for i = 1, retries do
			local ok, result = pcall(fn)
			if ok then
				return true, result
			end
			lastErr = result
			if i < retries then
				wait(backoff * i)
			end
		end
		return false, lastErr
	end

	local self = {} :: any

	function self:load(userId: number): (any?, LoadStatus)
		local ok, result = attempt(function()
			return backend.get(keyFor(userId))
		end)
		if not ok then
			warn(("[FCT] load failed for %d: %s"):format(userId, tostring(result)))
			return nil, "error"
		end
		loaded[userId] = true
		if result == nil then
			return nil, "new"
		end
		return result, "ok"
	end

	function self:save(userId: number, profile: any): boolean
		if not loaded[userId] then
			warn(("[FCT] refusing to save %d before a successful load"):format(userId))
			return false
		end
		if type(profile) ~= "table" then
			return false
		end
		profile.updatedAt = now()
		profile.saveCount = (tonumber(profile.saveCount) or 0) + 1
		local ok, err = attempt(function()
			backend.set(keyFor(userId), profile)
		end)
		if not ok then
			profile.saveCount -= 1
			warn(("[FCT] save failed for %d: %s"):format(userId, tostring(err)))
			return false
		end
		return true
	end

	function self:markDirty()
		dirty = true
	end

	function self:isDirty(): boolean
		return dirty
	end

	function self:flush(userId: number, snapshot: () -> any, force: boolean?): boolean
		if not dirty and not force then
			return false
		end
		local ok = self:save(userId, snapshot())
		if ok then
			dirty = false
		end
		return ok
	end

	function self:startAutosave(userId: number, snapshot: () -> any, seconds: number)
		autosaveToken += 1
		local token = autosaveToken
		task.spawn(function()
			while token == autosaveToken do
				task.wait(seconds)
				if token ~= autosaveToken then
					break
				end
				if dirty then
					self:flush(userId, snapshot)
				end
			end
		end)
	end

	function self:stopAutosave()
		autosaveToken += 1
	end

	return self :: Saver
end

return SaveService
