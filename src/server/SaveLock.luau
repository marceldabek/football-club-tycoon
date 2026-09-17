--!strict
-- Session locking for club saves (backlog B3.1).
--
-- Decided behaviour (CLAUDE.md s27, "Save lock"): "a new server waits for
-- the save lock, then loads, and the old session closes." Once a server
-- room has several players each with their own Saver, every save needs a
-- lock record so two servers never write the same club at once.
--
-- Protocol, stored at key "lock_u<userId>" as { jobId, lockedAt, heartbeat,
-- requestedBy?, released? }:
--   * acquire(): free (no record, or released = true), our own jobId, or a
--     heartbeat older than `staleAfter` -> take it immediately ("acquired" /
--     "reacquired" / "stolen-stale"). Otherwise stamp `requestedBy` on the
--     existing record (a note for the current holder) and poll every `poll`
--     seconds. The moment the holder frees it (nil or released) we take it
--     cleanly ("acquired"); if `maxWait` passes first we steal it anyway
--     ("stolen-timeout") -- the new server always wins in the end.
--   * heartbeat(): while we hold it, refresh our timestamp. Returns false
--     (and leaves the record untouched) the instant another jobId holds the
--     lock or has set `requestedBy` -- either way the caller should flush
--     and close this session.
--   * release(): only the current holder can mark the record released; we
--     never delete the key (a transform returning nil means "don't write",
--     mirroring DataStore:UpdateAsync, so it cannot be used to clear data).
--
-- Pure over a small backend so the whole thing is testable with a table
-- instead of a real DataStore. See tests/SaveLockTest.luau.

local SaveLock = {}

export type LockBackend = {
	update: (key: string, transform: (old: any?) -> any?) -> any?,
}

export type LockRecord = {
	jobId: string,
	lockedAt: number,
	heartbeat: number,
	requestedBy: string?,
	released: boolean?,
}

export type LockerOptions = {
	jobId: string,
	now: () -> number,
	wait: (number) -> (),
	staleAfter: number?,
	maxWait: number?,
	poll: number?,
}

export type Locker = {
	acquire: (self: Locker, userId: number) -> (boolean, string),
	heartbeat: (self: Locker, userId: number) -> (boolean, boolean),
	release: (self: Locker, userId: number) -> boolean,
	holds: (self: Locker, userId: number) -> boolean,
}

local function keyFor(userId: number): string
	return "lock_u" .. tostring(userId)
end

-- Same JSON-round-trip trick as SaveService.memoryBackend: no shared
-- references between caller and store, and non-JSON-safe values error here
-- instead of in production.
function SaveLock.memoryBackend(store: { [string]: any }?): LockBackend
	local HttpService = game:GetService("HttpService")
	local data: { [string]: any } = store or {}
	return {
		update = function(key: string, transform: (old: any?) -> any?): any?
			local raw = data[key]
			local old = if raw == nil then nil else HttpService:JSONDecode(raw)
			local new = transform(old)
			if new == nil then
				return nil
			end
			local encoded = HttpService:JSONEncode(new)
			data[key] = encoded
			return HttpService:JSONDecode(encoded)
		end,
	}
end

function SaveLock.dataStoreBackend(storeName: string): LockBackend
	local store: DataStore? = nil
	local function getStore(): DataStore
		if not store then
			store = game:GetService("DataStoreService"):GetDataStore(storeName)
		end
		return store :: DataStore
	end
	return {
		-- Real UpdateAsync calls can error (network, throttling); that is
		-- left to the caller to pcall, same as SaveService's backends.
		update = function(key: string, transform: (old: any?) -> any?): any?
			return getStore():UpdateAsync(key, transform)
		end,
	}
end

function SaveLock.new(backend: LockBackend, opts: LockerOptions): Locker
	local jobId = opts.jobId
	local now = opts.now
	local wait = opts.wait
	local staleAfter = opts.staleAfter or 90
	local maxWait = opts.maxWait or 30
	local poll = opts.poll or 3

	-- Last known local state only; never trusted over a fresh backend read.
	local held: { [number]: boolean } = {}

	-- One attempt to take the lock. Returns the outcome if we now hold it,
	-- or nil (having stamped `requestedBy`) if someone else still does.
	local function tryTake(userId: number): string?
		local key = keyFor(userId)
		local outcome: string? = nil
		backend.update(key, function(old: any?): any?
			local record = old :: LockRecord?
			if record == nil then
				outcome = "acquired"
				return { jobId = jobId, lockedAt = now(), heartbeat = now() }
			end
			if record.released == true then
				outcome = "acquired"
				return { jobId = jobId, lockedAt = now(), heartbeat = now() }
			end
			if record.jobId == jobId then
				outcome = "reacquired"
				return { jobId = jobId, lockedAt = now(), heartbeat = now() }
			end
			if (now() - record.heartbeat) >= staleAfter then
				outcome = "stolen-stale"
				return { jobId = jobId, lockedAt = now(), heartbeat = now() }
			end
			return {
				jobId = record.jobId,
				lockedAt = record.lockedAt,
				heartbeat = record.heartbeat,
				requestedBy = jobId,
			}
		end)
		return outcome
	end

	local self = {} :: any

	function self:acquire(userId: number): (boolean, string)
		local outcome = tryTake(userId)
		if outcome then
			held[userId] = true
			return true, outcome
		end

		local waited = 0
		while waited < maxWait do
			wait(poll)
			waited += poll
			outcome = tryTake(userId)
			if outcome then
				held[userId] = true
				return true, outcome
			end
		end

		-- Decided behaviour: the new server always wins.
		local key = keyFor(userId)
		backend.update(key, function(_old: any?): any?
			return { jobId = jobId, lockedAt = now(), heartbeat = now() }
		end)
		held[userId] = true
		return true, "stolen-timeout"
	end

	-- Second return (X196): true when another job now holds the lock, i.e. it
	-- was stolen and this server's data may already be older than the store's;
	-- false when merely requested (the new server waits for our last flush).
	function self:heartbeat(userId: number): (boolean, boolean)
		local key = keyFor(userId)
		local ok = false
		local stolen = false
		backend.update(key, function(old: any?): any?
			local record = old :: LockRecord?
			if record == nil then
				ok = false
				return nil
			end
			if record.jobId ~= jobId then
				ok = false
				stolen = true
				return nil
			end
			if record.requestedBy ~= nil then
				ok = false
				return nil
			end
			ok = true
			return { jobId = record.jobId, lockedAt = record.lockedAt, heartbeat = now() }
		end)
		held[userId] = ok
		return ok, stolen
	end

	function self:release(userId: number): boolean
		local key = keyFor(userId)
		local ok = false
		backend.update(key, function(old: any?): any?
			local record = old :: LockRecord?
			if record == nil then
				ok = false
				return nil
			end
			if record.jobId ~= jobId then
				ok = false
				return nil
			end
			ok = true
			return { jobId = record.jobId, lockedAt = record.lockedAt, heartbeat = now(), released = true }
		end)
		if ok then
			held[userId] = false
		end
		return ok
	end

	function self:holds(userId: number): boolean
		return held[userId] == true
	end

	return self :: Locker
end

return SaveLock
