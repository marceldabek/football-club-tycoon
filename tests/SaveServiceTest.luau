--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local SaveService = require(ServerScriptService.Server.SaveService)

local T = {}

local NO_WAIT = function(_: number) end

-- A backend that errors for the first `failures` calls, then delegates.
local function flaky(inner, failures: number)
	local remaining = failures
	local function gate()
		if remaining > 0 then
			remaining -= 1
			error("simulated outage")
		end
	end
	return {
		get = function(key: string)
			gate()
			return inner.get(key)
		end,
		set = function(key: string, value: any)
			gate()
			inner.set(key, value)
		end,
	}
end

local function newSaver(backend, retries: number?)
	return SaveService.new(backend, { retries = retries or 3, backoff = 0, wait = NO_WAIT, now = function()
		return 42
	end })
end

function T.newThenSaveThenLoad()
	local store = {}
	local saver = newSaver(SaveService.memoryBackend(store))
	local data, status = saver:load(7)
	assert(data == nil and status == "new", "fresh user should be new")
	assert(saver:save(7, { cash = 5, saveCount = 0 }), "save should succeed")
	local back, status2 = saver:load(7)
	assert(status2 == "ok" and back.cash == 5, "load should return saved data")
	assert(back.saveCount == 1 and back.updatedAt == 42, "save should stamp the profile")
	assert(store["u7"] ~= nil, "key should be u<userId>")
end

function T.memoryBackendCopies()
	local saver = newSaver(SaveService.memoryBackend())
	saver:load(2)
	local original = { nested = { value = 1 } }
	saver:save(2, original)
	original.nested.value = 99
	local back = saver:load(2)
	assert(back.nested.value == 1, "stored data must not share references with the caller")
end

function T.flakyBackendRecovers()
	local saver = newSaver(flaky(SaveService.memoryBackend(), 2), 3)
	local _, status = saver:load(1)
	assert(status == "new", "should recover after two failures, got " .. status)
	assert(saver:save(1, {}), "save should recover too")
end

function T.alwaysFailingIsError()
	local saver = newSaver(flaky(SaveService.memoryBackend(), 100), 3)
	local data, status = saver:load(1)
	assert(data == nil and status == "error", "should be error, got " .. status)
	assert(not saver:save(1, {}), "save must be refused after a failed load")
end

function T.saveRefusedBeforeLoad()
	local saver = newSaver(SaveService.memoryBackend())
	assert(not saver:save(9, {}), "save before load should be refused")
end

function T.flushOnlyWhenDirty()
	local store = {}
	local saver = newSaver(SaveService.memoryBackend(store))
	saver:load(3)
	local snapshots = 0
	local function snapshot()
		snapshots += 1
		return { saveCount = 0 }
	end
	assert(not saver:flush(3, snapshot), "clean saver should not flush")
	assert(snapshots == 0, "snapshot should not be taken when clean")
	saver:markDirty()
	assert(saver:isDirty(), "should be dirty")
	assert(saver:flush(3, snapshot), "dirty saver should flush")
	assert(not saver:isDirty(), "flush should clear dirty")
	local stored = game:GetService("HttpService"):JSONDecode(store["u3"])
	assert(stored.saveCount == 1, "stored profile should be stamped")
	assert(saver:flush(3, snapshot, true), "force should save even when clean")
end

function T.studioUsesItsOwnStore()
	assert(SaveService.storeNameFor("ClubProfiles", true, "_Studio") == "ClubProfiles_Studio", "Studio gets the suffix")
	assert(SaveService.storeNameFor("ClubProfiles", false, "_Studio") == "ClubProfiles", "live servers keep the real store")
	assert(SaveService.storeNameFor("ClubProfiles", true, "") == "ClubProfiles", "empty suffix opts back into the real store")
	assert(SaveService.storeNameFor("ClubProfiles", true, nil) == "ClubProfiles", "no suffix configured")
end

return T
