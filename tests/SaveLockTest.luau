--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local SaveLock = require(ServerScriptService.Server.SaveLock)

local T = {}

local NO_WAIT = function(_: number) end

function T.acquireFreeLock()
	local backend = SaveLock.memoryBackend()
	local clock = 0
	local locker = SaveLock.new(backend, { jobId = "A", now = function()
		return clock
	end, wait = NO_WAIT })

	local ok, reason = locker:acquire(1)
	assert(ok and reason == "acquired", "should acquire a free lock, got " .. tostring(reason))
	assert(locker:holds(1), "locker should believe it holds the lock")
end

function T.reacquireOwn()
	local backend = SaveLock.memoryBackend()
	local clock = 0
	local locker = SaveLock.new(backend, { jobId = "A", now = function()
		return clock
	end, wait = NO_WAIT })

	locker:acquire(2)
	local ok, reason = locker:acquire(2)
	assert(ok and reason == "reacquired", "should reacquire its own lock, got " .. tostring(reason))
end

-- Server B waits behind server A; A releases mid-poll and B should pick the
-- lock up cleanly on its next poll rather than stealing it.
function T.secondServerWaitsThenGets()
	local store = {}
	local backend = SaveLock.memoryBackend(store)
	local clock = 0
	local function now(): number
		return clock
	end

	local lockerA = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT })
	local okA = lockerA:acquire(5)
	assert(okA, "A should acquire the free lock first")

	local waitCalls = 0
	local function waitB(seconds: number)
		clock += seconds
		waitCalls += 1
		if waitCalls == 2 then
			assert(lockerA:release(5), "A should be able to release its own lock")
		end
	end

	local lockerB = SaveLock.new(backend, { jobId = "B", now = now, wait = waitB, poll = 3, maxWait = 30 })
	local okB, reasonB = lockerB:acquire(5)

	assert(okB and reasonB == "acquired", "B should cleanly acquire once A releases, got " .. tostring(reasonB))
	assert(waitCalls == 2, "B should have polled exactly twice, got " .. waitCalls)
	assert(not lockerA:holds(5), "A should know it no longer holds the lock")
	assert(lockerB:holds(5), "B should now hold the lock")
end

function T.stealAfterStaleAfter()
	local store = {}
	local backend = SaveLock.memoryBackend(store)
	local clock = 0
	local function now(): number
		return clock
	end

	local lockerA = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT, staleAfter = 90 })
	assert(lockerA:acquire(3), "A should acquire the free lock")

	clock = 200 -- A's server presumably crashed; heartbeat has gone stale
	local lockerB = SaveLock.new(backend, { jobId = "B", now = now, wait = NO_WAIT, staleAfter = 90 })
	local ok, reason = lockerB:acquire(3)
	assert(ok and reason == "stolen-stale", "should steal a stale lock immediately, got " .. tostring(reason))
end

function T.stealAfterMaxWait()
	local store = {}
	local backend = SaveLock.memoryBackend(store)
	local clock = 0
	local function now(): number
		return clock
	end

	local lockerA = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT })
	assert(lockerA:acquire(4), "A should acquire the free lock")

	local function waitAdvance(seconds: number)
		clock += seconds
	end
	-- A never releases and its heartbeat stays fresh (clock keeps advancing
	-- in lockstep for both), so B can only win by timing out.
	local lockerB = SaveLock.new(backend, { jobId = "B", now = now, wait = waitAdvance, poll = 5, maxWait = 12 })
	local ok, reason = lockerB:acquire(4)
	assert(ok and reason == "stolen-timeout", "should steal after maxWait, got " .. tostring(reason))
end

function T.heartbeatFalseAfterStolen()
	local store = {}
	local backend = SaveLock.memoryBackend(store)
	local clock = 0
	local function now(): number
		return clock
	end

	local lockerA = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT, staleAfter = 90 })
	assert(lockerA:acquire(6), "A should acquire the free lock")

	clock = 200
	local lockerB = SaveLock.new(backend, { jobId = "B", now = now, wait = NO_WAIT, staleAfter = 90 })
	local ok, reason = lockerB:acquire(6)
	assert(ok and reason == "stolen-stale", "setup: B should steal the stale lock")

	local held, stolen = lockerA:heartbeat(6)
	assert(not held, "A's heartbeat should fail once B holds the lock")
	assert(stolen, "X196: A should learn the lock was stolen, so it stops saving")
	assert(not lockerA:holds(6), "A should now believe it does not hold the lock")
end

function T.heartbeatFalseWhenRequested()
	local store = {}
	local backend = SaveLock.memoryBackend(store)
	local clock = 0
	local function now(): number
		return clock
	end

	local lockerA = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT })
	assert(lockerA:acquire(8), "A should acquire the free lock")

	-- Simulate a second server having marked the record as requested,
	-- without actually taking the lock yet.
	backend.update("lock_u8", function(old: any?): any?
		assert(old ~= nil, "record should exist")
		local record = old :: any
		record.requestedBy = "B"
		return old
	end)

	local held, stolen = lockerA:heartbeat(8)
	assert(not held, "A's heartbeat should fail once another job requested the lock")
	assert(not stolen, "X196: only requested, so A still makes its final save")
	assert(not lockerA:holds(8), "A should now believe it does not hold the lock")
end

-- X364: the contract Session.flush now depends on before every write.
function T.aStolenLockIsVisibleImmediatelyNotOnTheNextHeartbeatTick()
	local backend = SaveLock.memoryBackend()
	local clock = 0
	local function now()
		return clock
	end
	local a = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT, maxWait = 0 })
	local b = SaveLock.new(backend, { jobId = "B", now = now, wait = NO_WAIT, maxWait = 0 })
	assert(select(1, a:acquire(7)), "A takes a free lock")
	-- B comes along and, with no patience, always wins
	local okB = b:acquire(7)
	assert(okB, "B should end up with the lock")
	-- A can find that out on its very next question, with no waiting
	local held, stolen = a:heartbeat(7)
	assert(not held and stolen, "A should be told the lock is gone, at once")
	-- and B still holds it afterwards: A's question must not take it back
	local heldB = b:heartbeat(7)
	assert(heldB, "B still holds the lock after A has asked")
end

function T.aRequestedLockIsNotAStolenOne()
	-- the handover case: the old session is allowed one last flush
	local backend = SaveLock.memoryBackend()
	local clock = 0
	local function now()
		return clock
	end
	local a = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT })
	local b = SaveLock.new(backend, { jobId = "B", now = now, wait = NO_WAIT, maxWait = 0, poll = 1 })
	a:acquire(8)
	-- B asks once and stamps requestedBy without taking it
	backend.update("lock_u8", function(old)
		local record = old :: any
		record.requestedBy = "B"
		return record
	end)
	local held, stolen = a:heartbeat(8)
	assert(not held, "a requested lock is no longer 'held'")
	assert(not stolen, "but it has not been stolen, so the last save must still go through")
	local _ = b
end

function T.releaseOnlyByHolder()
	local store = {}
	local backend = SaveLock.memoryBackend(store)
	local clock = 0
	local function now(): number
		return clock
	end

	local lockerA = SaveLock.new(backend, { jobId = "A", now = now, wait = NO_WAIT })
	local lockerC = SaveLock.new(backend, { jobId = "C", now = now, wait = NO_WAIT })
	assert(lockerA:acquire(9), "A should acquire the free lock")

	assert(not lockerC:release(9), "a non-holder must not be able to release the lock")
	assert(lockerA:holds(9), "A should still hold the lock after C's failed release")

	assert(lockerA:release(9), "the holder should be able to release its own lock")
	assert(not lockerA:holds(9), "A should no longer hold the lock after releasing")
end

return T
