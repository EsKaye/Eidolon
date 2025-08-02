--[[
    GhostMemoryTracker/init.lua
    Author: Your precious kitten 💖
    Created: 2024-03-15
    Version: 1.0.0
    Purpose: Tracks player ghost memories, dream journals, and projected soul logs.
]]
-- luacheck: globals script typeof

local Logger = require(script.Parent.Logger)
local log = Logger.forModule("GhostMemoryTracker")

local GhostMemoryTracker = {}
GhostMemoryTracker.__index = GhostMemoryTracker

-- Create a new tracker bound to a PersistenceManager instance
-- @param persistenceManager PersistenceManager that handles saving/loading
-- @param opts table Optional settings: {maxDreams, maxSoulLogs, autoSave}
function GhostMemoryTracker.new(persistenceManager, opts)
    log.debug("Creating GhostMemoryTracker")

    local self = setmetatable({}, GhostMemoryTracker)
    self.persistenceManager = persistenceManager
    self.memoryCache = {}

    opts = opts or {}
    self.maxDreams = opts.maxDreams or 100 -- keep a healthy backlog
    self.maxSoulLogs = opts.maxSoulLogs or 100
    self.autoSave = opts.autoSave == nil and true or opts.autoSave

    return self
end

-- Internal helper: initialize memory table for a player
local function ensureMemory(tableRef)
    tableRef.dreamJournal = tableRef.dreamJournal or {}
    tableRef.soulLogs = tableRef.soulLogs or {}
end

-- Load a player's ghost memory from PersistenceManager
function GhostMemoryTracker:load(player, callback)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    log.debug("Loading ghost memory for %s", playerId)

    self.persistenceManager:getPlayerData(playerId, function(data)
        data = data or {}
        local memory = data.ghostMemory or {}
        ensureMemory(memory)
        self.memoryCache[playerId] = memory
        if callback then callback(memory) end
    end)
end

-- Save a player's ghost memory back to PersistenceManager
function GhostMemoryTracker:save(player)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId]
    if not memory then return end

    self.persistenceManager:getPlayerData(playerId, function(data)
        data = data or {}
        data.ghostMemory = memory
        self.persistenceManager:setPlayerData(playerId, data)
    end)
end

-- Append a dream entry to the player's journal
-- @param text string The dream narrative
-- @param meta table Optional metadata {tags = {}, mood = "", lucidity = number}
function GhostMemoryTracker:addDream(player, text, meta)
    if not text or text == "" then return end
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId] or {}
    ensureMemory(memory)

    meta = meta or {}
    table.insert(memory.dreamJournal, {
        timestamp = os.time(),
        text = text,
        tags = meta.tags or {}, -- allow filtering by tags
        mood = meta.mood or "neutral",
        lucidity = meta.lucidity or 0
    })

    -- Trim oldest entries if exceeding maxDreams
    while #memory.dreamJournal > self.maxDreams do
        table.remove(memory.dreamJournal, 1)
    end

    self.memoryCache[playerId] = memory
    if self.autoSave then self:save(playerId) end
end

-- Append a soul projection log entry
-- @param data any A payload describing the soul projection
-- @param meta table Optional metadata {plane = "", intensity = number}
function GhostMemoryTracker:addSoulLog(player, data, meta)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId] or {}
    ensureMemory(memory)

    meta = meta or {}
    table.insert(memory.soulLogs, {
        timestamp = os.time(),
        data = data,
        plane = meta.plane or "astral",
        intensity = meta.intensity or 0
    })

    -- Trim oldest entries if exceeding maxSoulLogs
    while #memory.soulLogs > self.maxSoulLogs do
        table.remove(memory.soulLogs, 1)
    end

    self.memoryCache[playerId] = memory
    if self.autoSave then self:save(playerId) end
end

-- Retrieve dream entries with optional filtering
-- @param filter function|string optional filter: function(dream) -> bool or tag string
function GhostMemoryTracker:getDreams(player, filter)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId]
    if not memory then return {} end

    local dreams = memory.dreamJournal or {}
    if not filter then return dreams end

    local results = {}
    if type(filter) == "string" then
        -- filter by tag string
        for _, dream in ipairs(dreams) do
            for _, tag in ipairs(dream.tags or {}) do
                if tag == filter then
                    table.insert(results, dream)
                    break
                end
            end
        end
    elseif type(filter) == "function" then
        for _, dream in ipairs(dreams) do
            if filter(dream) then table.insert(results, dream) end
        end
    end
    return results
end

-- Retrieve soul logs with optional filter function
function GhostMemoryTracker:getSoulLogs(player, filter)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId]
    if not memory then return {} end

    local logs = memory.soulLogs or {}
    if not filter then return logs end

    local results = {}
    for _, logEntry in ipairs(logs) do
        if filter(logEntry) then table.insert(results, logEntry) end
    end
    return results
end

-- Get the most recent dream for a player
function GhostMemoryTracker:getLastDream(player)
    local dreams = self:getDreams(player)
    return dreams[#dreams]
end

-- Purge dream journal for a player
function GhostMemoryTracker:clearDreams(player)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId]
    if not memory then return end
    memory.dreamJournal = {}
    if self.autoSave then self:save(playerId) end
end

-- Purge soul logs for a player
function GhostMemoryTracker:clearSoulLogs(player)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId]
    if not memory then return end
    memory.soulLogs = {}
    if self.autoSave then self:save(playerId) end
end

-- Export a deep copy of a player's memory for analytics or backup
function GhostMemoryTracker:export(player)
    local playerId = typeof(player) == "Instance" and player.UserId or player
    local memory = self.memoryCache[playerId]
    if not memory then return nil end

    -- manual deep copy to avoid exposing internal table references
    local copy = {
        dreamJournal = {},
        soulLogs = {}
    }
    for _, dream in ipairs(memory.dreamJournal or {}) do
        local dreamCopy = {
            timestamp = dream.timestamp,
            text = dream.text,
            tags = {},
            mood = dream.mood,
            lucidity = dream.lucidity,
        }
        for i, tag in ipairs(dream.tags or {}) do
            dreamCopy.tags[i] = tag
        end
        table.insert(copy.dreamJournal, dreamCopy)
    end

    for _, logEntry in ipairs(memory.soulLogs or {}) do
        table.insert(copy.soulLogs, {
            timestamp = logEntry.timestamp,
            data = logEntry.data,
            plane = logEntry.plane,
            intensity = logEntry.intensity,
        })
    end
    return copy
end

return GhostMemoryTracker
