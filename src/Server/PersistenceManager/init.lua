--[[
    PersistenceManager/init.lua
    Author: Your precious kitten 💖
    Updated: 2024-03-11
    Version: 1.1.0
    Purpose: Manages persistence of world and player data (Optimized)
]]

local Logger = require(script.Parent.Parent.Logger)
local log = Logger.forModule("PersistenceManager")

log.debug("Initializing PersistenceManager module")

-- Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Constants
local DEFAULT_AUTO_SAVE_INTERVAL = 300 -- 5 minutes
local MAX_RETRY_ATTEMPTS = 5
local RETRY_DELAY = 3
local THROTTLE_WINDOW = 6 -- Seconds between DataStore requests (to avoid hitting limits)
local CHUNK_SIZE = 4000000 -- ~4MB chunks for large data
local SAVE_DEBOUNCE_TIME = 10 -- Seconds to wait between save attempts for the same key
local KEY_EXPIRATION = 60*60*24*180 -- 180 days (in seconds)

-- Internal caching
local PersistenceManager = {}
PersistenceManager.__index = PersistenceManager

-- Queue for throttling DataStore requests
local requestQueue = {}
local lastRequestTime = 0
local isProcessingQueue = false

-- Metadata for each data type (compression settings, chunk settings)
local dataTypeSettings = {
    worldData = {
        useCompression = true,
        chunking = true,
        metadata = true
    },
    worldParams = {
        useCompression = false,
        chunking = false,
        metadata = true
    },
    playerData = {
        useCompression = true,
        chunking = true,
        metadata = true
    }
}

-- In-memory cache to avoid redundant datastore calls
local cache = {
    worldData = {},
    worldParams = {},
    playerData = {},
    lastSaveTime = {} -- Track when keys were last saved to implement debouncing
}

-- Stats for monitoring
local stats = {
    requests = 0,
    throttled = 0,
    errors = 0,
    cacheHits = 0,
    cacheMisses = 0,
    saveOperations = 0,
    loadOperations = 0,
    compressionRatio = 0,
    totalSaveSize = 0
}

-- Utility functions
local function compress(data)
    if not data then return nil end
    
    -- Convert to JSON
    local success, jsonData = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    if not success then
        log.error("Failed to encode data to JSON: %s", jsonData)
        return nil
    end
    
    -- Compress (simulation - in a real implementation, you would use a compression library)
    -- This is a placeholder for where actual compression would happen
    local compressed = {
        original_size = #jsonData,
        compressed_data = jsonData, -- In a real scenario, this would be compressed
        timestamp = os.time()
    }
    
    -- Update compression stats
    stats.compressionRatio = 1.0 -- Placeholder ratio
    stats.totalSaveSize = stats.totalSaveSize + #jsonData
    
    log.debug("Compressed data from %d bytes (compression placeholder)", #jsonData)
    return compressed
end

local function decompress(compressed)
    if not compressed or not compressed.compressed_data then 
        return nil 
    end
    
    -- Decompress (simulation)
    local jsonData = compressed.compressed_data
    
    -- Convert from JSON back to table
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonData)
    end)
    
    if not success then
        log.error("Failed to decode JSON data: %s", data)
        return nil
    end
    
    return data
end

-- Split large data into chunks
local function chunkData(data, keyBase)
    local compressed = compress(data)
    if not compressed then return nil end
    
    local jsonData = compressed.compressed_data
    local chunks = {}
    
    -- Create metadata chunk
    chunks[keyBase .. "_meta"] = {
        chunkCount = math.ceil(#jsonData / CHUNK_SIZE),
        totalSize = #jsonData,
        originalSize = compressed.original_size,
        timestamp = os.time()
    }
    
    -- Split data into chunks
    for i = 1, chunks[keyBase .. "_meta"].chunkCount do
        local startIndex = (i-1) * CHUNK_SIZE + 1
        local endIndex = math.min(i * CHUNK_SIZE, #jsonData)
        chunks[keyBase .. "_" .. i] = string.sub(jsonData, startIndex, endIndex)
    end
    
    log.debug("Split data into %d chunks for key %s", chunks[keyBase .. "_meta"].chunkCount, keyBase)
    return chunks
end

-- Combine chunks back into complete data
local function combineChunks(chunks, keyBase)
    if not chunks[keyBase .. "_meta"] then
        log.error("Missing metadata chunk for %s", keyBase)
        return nil
    end
    
    local meta = chunks[keyBase .. "_meta"]
    local jsonData = ""
    
    -- Combine all chunks
    for i = 1, meta.chunkCount do
        local chunkKey = keyBase .. "_" .. i
        if not chunks[chunkKey] then
            log.error("Missing chunk %d for %s", i, keyBase)
            return nil
        end
        jsonData = jsonData .. chunks[chunkKey]
    end
    
    -- Create compressed data structure to match what decompress expects
    local compressed = {
        compressed_data = jsonData,
        original_size = meta.originalSize,
        timestamp = meta.timestamp
    }
    
    -- Decompress and return
    return decompress(compressed)
end

-- Process the request queue (one operation at a time to throttle)
local function processRequestQueue()
    if isProcessingQueue or #requestQueue == 0 then
        return
    end
    
    isProcessingQueue = true
    
    -- Check if enough time has passed since last request
    local currentTime = os.clock()
    local timeToWait = math.max(0, THROTTLE_WINDOW - (currentTime - lastRequestTime))
    
    task.delay(timeToWait, function()
        if #requestQueue > 0 then
            local nextRequest = table.remove(requestQueue, 1)
            lastRequestTime = os.clock()
            
            -- Execute the request
            local success, result = pcall(nextRequest.callback)
            
            -- Handle the result
            task.spawn(function()
                if success then
                    if nextRequest.onSuccess then
                        nextRequest.onSuccess(result)
                    end
                else
                    stats.errors = stats.errors + 1
                    if nextRequest.onError then
                        nextRequest.onError(result)
                    end
                    log.error("DataStore operation failed: %s", result)
                end
                
                -- Process next request
                isProcessingQueue = false
                processRequestQueue()
            end)
        else
            isProcessingQueue = false
        end
    end)
end

-- Add a request to the queue
local function queueRequest(callback, onSuccess, onError)
    stats.requests = stats.requests + 1
    
    table.insert(requestQueue, {
        callback = callback,
        onSuccess = onSuccess,
        onError = onError,
        timestamp = os.clock()
    })
    
    -- If queue was empty, start processing
    if #requestQueue == 1 and not isProcessingQueue then
        processRequestQueue()
    else
        stats.throttled = stats.throttled + 1
    end
end

-- Create a new PersistenceManager instance
function PersistenceManager.new()
    log.info("Creating new PersistenceManager instance")
    
    local self = setmetatable({}, PersistenceManager)
    
    -- Initialize properties
    self.worldStore = nil
    self.playerStore = nil
    self.worldParamsStore = nil
    self.isAutoSaving = false
    self.autoSaveInterval = DEFAULT_AUTO_SAVE_INTERVAL
    self.autoSaveThread = nil
    self.isDataStoreAvailable = true
    self.pendingSaves = {}
    
    -- Attempt to set up DataStores
    self:setupDataStores()
    
    log.debug("PersistenceManager instance created")
    return self
end

-- Initialize DataStore access
function PersistenceManager:setupDataStores()
    -- Only access DataStores in a server environment
    if not RunService:IsServer() then
        log.warning("DataStores can only be accessed from server")
        self.isDataStoreAvailable = false
        return
    end
    
    local success, result = pcall(function()
        -- Get DataStore instances
        self.worldStore = DataStoreService:GetDataStore("WorldData")
        self.playerStore = DataStoreService:GetDataStore("PlayerData")
        self.worldParamsStore = DataStoreService:GetDataStore("WorldParams")
        return true
    end)
    
    if success and result then
        log.info("DataStores successfully initialized")
        self.isDataStoreAvailable = true
    else
        log.error("Failed to initialize DataStores: %s", result)
        self.isDataStoreAvailable = false
    end
end

-- Set world generation parameters
function PersistenceManager:setWorldParams(worldID, params)
    if not self.isDataStoreAvailable or not worldID or not params then
        return false
    end
    
    -- Update cache
    cache.worldParams[worldID] = params
    
    -- Implement save debouncing
    local lastSaveKey = "worldParams:" .. worldID
    local currentTime = os.time()
    
    if cache.lastSaveTime[lastSaveKey] and 
       currentTime - cache.lastSaveTime[lastSaveKey] < SAVE_DEBOUNCE_TIME then
        log.debug("Debouncing save for worldParams:%s", worldID)
        
        -- Mark as pending save
        self.pendingSaves[lastSaveKey] = true
        
        -- Schedule a save after the debounce period
        task.delay(SAVE_DEBOUNCE_TIME, function()
            if self.pendingSaves[lastSaveKey] then
                self:setWorldParams(worldID, cache.worldParams[worldID])
                self.pendingSaves[lastSaveKey] = nil
            end
        end)
        
        return true
    end
    
    -- Mark save time
    cache.lastSaveTime[lastSaveKey] = currentTime
    self.pendingSaves[lastSaveKey] = nil
    
    -- Queue the save operation
    local dataToSave = params
    if dataTypeSettings.worldParams.useCompression then
        dataToSave = compress(params)
    end
    
    queueRequest(
        function()
            stats.saveOperations = stats.saveOperations + 1
            return self.worldParamsStore:SetAsync(worldID, dataToSave, {
                metadata = {
                    version = "1.1.0",
                    timestamp = os.time()
                }
            })
        end,
        function()
            log.info("Successfully saved world parameters for world %s", worldID)
        end,
        function(err)
            log.error("Failed to save world parameters for world %s: %s", worldID, err)
            
            -- Retry save later
            task.delay(RETRY_DELAY, function()
                if not self.pendingSaves[lastSaveKey] then
                    self.pendingSaves[lastSaveKey] = true
                    self:setWorldParams(worldID, cache.worldParams[worldID])
                end
            end)
        end
    )
    
    return true
end

-- Get world generation parameters
function PersistenceManager:getWorldParams(worldID, callback)
    if not self.isDataStoreAvailable or not worldID then
        if callback then callback(nil) end
        return
    end
    
    -- Check cache first
    if cache.worldParams[worldID] then
        stats.cacheHits = stats.cacheHits + 1
        log.debug("Cache hit for worldParams:%s", worldID)
        if callback then callback(cache.worldParams[worldID]) end
        return
    end
    
    stats.cacheMisses = stats.cacheMisses + 1
    
    -- Queue the load operation
    queueRequest(
        function()
            stats.loadOperations = stats.loadOperations + 1
            return self.worldParamsStore:GetAsync(worldID)
        end,
        function(result)
            if result then
                local params = result
                if dataTypeSettings.worldParams.useCompression then
                    params = decompress(result)
                end
                
                -- Update cache
                cache.worldParams[worldID] = params
                
                log.info("Successfully loaded world parameters for world %s", worldID)
                if callback then callback(params) end
            else
                log.info("No world parameters found for world %s", worldID)
                if callback then callback(nil) end
            end
        end,
        function(err)
            log.error("Failed to load world parameters for world %s: %s", worldID, err)
            if callback then callback(nil) end
        end
    )
end

-- Save world data in chunks if needed
function PersistenceManager:setWorldData(worldID, data)
    if not self.isDataStoreAvailable or not worldID or not data then
        return false
    end
    
    -- Update cache
    cache.worldData[worldID] = data
    
    -- Implement save debouncing
    local lastSaveKey = "worldData:" .. worldID
    local currentTime = os.time()
    
    if cache.lastSaveTime[lastSaveKey] and 
       currentTime - cache.lastSaveTime[lastSaveKey] < SAVE_DEBOUNCE_TIME then
        log.debug("Debouncing save for worldData:%s", worldID)
        
        -- Mark as pending save
        self.pendingSaves[lastSaveKey] = true
        
        -- Schedule a save after the debounce period
        task.delay(SAVE_DEBOUNCE_TIME, function()
            if self.pendingSaves[lastSaveKey] then
                self:setWorldData(worldID, cache.worldData[worldID])
                self.pendingSaves[lastSaveKey] = nil
            end
        end)
        
        return true
    end
    
    -- Mark save time
    cache.lastSaveTime[lastSaveKey] = currentTime
    self.pendingSaves[lastSaveKey] = nil
    
    -- Check if we need to use chunking
    if dataTypeSettings.worldData.chunking then
        local chunks = chunkData(data, worldID)
        if not chunks then
            log.error("Failed to chunk world data for world %s", worldID)
            return false
        end
        
        -- Save each chunk
        for chunkKey, chunkData in pairs(chunks) do
            local finalChunkKey = chunkKey
            
            queueRequest(
                function()
                    stats.saveOperations = stats.saveOperations + 1
                    return self.worldStore:SetAsync(finalChunkKey, chunkData, {
                        metadata = {
                            version = "1.1.0",
                            timestamp = os.time(),
                            isChunk = true,
                            expiration = os.time() + KEY_EXPIRATION
                        }
                    })
                end,
                function()
                    log.debug("Saved chunk %s for world %s", finalChunkKey, worldID)
                end,
                function(err)
                    log.error("Failed to save chunk %s for world %s: %s", finalChunkKey, worldID, err)
                end
            )
        end
        
        log.info("Queued all chunks for saving for world %s", worldID)
        return true
    else
        -- Single operation save
        local dataToSave = data
        if dataTypeSettings.worldData.useCompression then
            dataToSave = compress(data)
        end
        
        queueRequest(
            function()
                stats.saveOperations = stats.saveOperations + 1
                return self.worldStore:SetAsync(worldID, dataToSave, {
                    metadata = {
                        version = "1.1.0",
                        timestamp = os.time(),
                        expiration = os.time() + KEY_EXPIRATION
                    }
                })
            end,
            function()
                log.info("Successfully saved world data for world %s", worldID)
            end,
            function(err)
                log.error("Failed to save world data for world %s: %s", worldID, err)
                
                -- Retry save later
                task.delay(RETRY_DELAY, function()
                    if not self.pendingSaves[lastSaveKey] then
                        self.pendingSaves[lastSaveKey] = true
                        self:setWorldData(worldID, cache.worldData[worldID])
                    end
                end)
            end
        )
        
        return true
    end
end

-- Load world data, handling chunked data if necessary
function PersistenceManager:getWorldData(worldID, callback)
    if not self.isDataStoreAvailable or not worldID then
        if callback then callback(nil) end
        return
    end
    
    -- Check cache first
    if cache.worldData[worldID] then
        stats.cacheHits = stats.cacheHits + 1
        log.debug("Cache hit for worldData:%s", worldID)
        if callback then callback(cache.worldData[worldID]) end
        return
    end
    
    stats.cacheMisses = stats.cacheMisses + 1
    
    -- First check if there's metadata to determine if data is chunked
    queueRequest(
        function()
            stats.loadOperations = stats.loadOperations + 1
            return self.worldStore:GetAsync(worldID .. "_meta")
        end,
        function(metadata)
            if metadata then
                -- Data is chunked, load all chunks
                log.debug("Found chunked data for world %s, loading %d chunks", worldID, metadata.chunkCount)
                
                local chunks = {
                    [worldID .. "_meta"] = metadata
                }
                local chunksLoaded = 0
                
                -- Function to check if all chunks are loaded
                local function checkComplete()
                    chunksLoaded = chunksLoaded + 1
                    if chunksLoaded >= metadata.chunkCount then
                        -- All chunks loaded, combine them
                        local worldData = combineChunks(chunks, worldID)
                        
                        if worldData then
                            log.info("Successfully loaded all chunked world data for world %s", worldID)
                            
                            -- Update cache
                            cache.worldData[worldID] = worldData
                            
                            if callback then callback(worldData) end
                        else
                            log.error("Failed to combine chunks for world %s", worldID)
                            if callback then callback(nil) end
                        end
                    end
                end
                
                -- Load each chunk
                for i = 1, metadata.chunkCount do
                    local chunkKey = worldID .. "_" .. i
                    
                    queueRequest(
                        function()
                            stats.loadOperations = stats.loadOperations + 1
                            return self.worldStore:GetAsync(chunkKey)
                        end,
                        function(chunkData)
                            if chunkData then
                                chunks[chunkKey] = chunkData
                                log.debug("Loaded chunk %d/%d for world %s", i, metadata.chunkCount, worldID)
                                checkComplete()
                            else
                                log.error("Failed to load chunk %s for world %s", chunkKey, worldID)
                                checkComplete()
                            end
                        end,
                        function(err)
                            log.error("Error loading chunk %s for world %s: %s", chunkKey, worldID, err)
                            checkComplete()
                        end
                    )
                end
            else
                -- No chunks, try loading as a single value
                queueRequest(
                    function()
                        stats.loadOperations = stats.loadOperations + 1
                        return self.worldStore:GetAsync(worldID)
                    end,
                    function(result)
                        if result then
                            local worldData = result
                            if dataTypeSettings.worldData.useCompression then
                                worldData = decompress(result)
                            end
                            
                            log.info("Successfully loaded world data for world %s", worldID)
                            
                            -- Update cache
                            cache.worldData[worldID] = worldData
                            
                            if callback then callback(worldData) end
                        else
                            log.info("No world data found for world %s", worldID)
                            if callback then callback(nil) end
                        end
                    end,
                    function(err)
                        log.error("Failed to load world data for world %s: %s", worldID, err)
                        if callback then callback(nil) end
                    end
                )
            end
        end,
        function(err)
            log.error("Failed to check metadata for world %s: %s", worldID, err)
            
            -- Try loading as a single value as fallback
            queueRequest(
                function()
                    return self.worldStore:GetAsync(worldID)
                end,
                function(result)
                    if result then
                        local worldData = result
                        if dataTypeSettings.worldData.useCompression then
                            worldData = decompress(result)
                        end
                        
                        log.info("Fallback: Successfully loaded world data for world %s", worldID)
                        
                        -- Update cache
                        cache.worldData[worldID] = worldData
                        
                        if callback then callback(worldData) end
                    else
                        log.info("No world data found for world %s", worldID)
                        if callback then callback(nil) end
                    end
                end,
                function(err)
                    log.error("Fallback: Failed to load world data for world %s: %s", worldID, err)
                    if callback then callback(nil) end
                end
            )
        end
    )
end

-- Save player data
function PersistenceManager:setPlayerData(playerID, data)
    -- Similar implementation to setWorldData, with player-specific logic
    -- (Implementation would follow the same pattern as setWorldData)
    if not self.isDataStoreAvailable or not playerID or not data then
        return false
    end
    
    -- Update cache
    cache.playerData[playerID] = data
    
    -- Queue the save operation with compression if needed
    local dataToSave = data
    if dataTypeSettings.playerData.useCompression then
        dataToSave = compress(data)
    end
    
    queueRequest(
        function()
            stats.saveOperations = stats.saveOperations + 1
            return self.playerStore:SetAsync(playerID, dataToSave, {
                metadata = {
                    version = "1.1.0",
                    timestamp = os.time(),
                    expiration = os.time() + KEY_EXPIRATION
                }
            })
        end,
        function()
            log.info("Successfully saved player data for player %s", playerID)
        end,
        function(err)
            log.error("Failed to save player data for player %s: %s", playerID, err)
        end
    )
    
    return true
end

-- Load player data
function PersistenceManager:getPlayerData(playerID, callback)
    -- Similar implementation to getWorldData, for player data
    -- (Implementation would follow the same pattern as getWorldData)
    if not self.isDataStoreAvailable or not playerID then
        if callback then callback(nil) end
        return
    end
    
    -- Check cache first
    if cache.playerData[playerID] then
        stats.cacheHits = stats.cacheHits + 1
        log.debug("Cache hit for playerData:%s", playerID)
        if callback then callback(cache.playerData[playerID]) end
        return
    end
    
    stats.cacheMisses = stats.cacheMisses + 1
    
    -- Queue the load operation
    queueRequest(
        function()
            stats.loadOperations = stats.loadOperations + 1
            return self.playerStore:GetAsync(playerID)
        end,
        function(result)
            if result then
                local playerData = result
                if dataTypeSettings.playerData.useCompression then
                    playerData = decompress(result)
                end
                
                -- Update cache
                cache.playerData[playerID] = playerData
                
                log.info("Successfully loaded player data for player %s", playerID)
                if callback then callback(playerData) end
            else
                log.info("No player data found for player %s", playerID)
                if callback then callback(nil) end
            end
        end,
        function(err)
            log.error("Failed to load player data for player %s: %s", playerID, err)
            if callback then callback(nil) end
        end
    )
end

-- Enable auto-saving
function PersistenceManager:enableAutoSave(interval)
    if self.isAutoSaving then
        return
    end
    
    self.autoSaveInterval = interval or DEFAULT_AUTO_SAVE_INTERVAL
    self.isAutoSaving = true
    
    -- Clear any existing thread
    if self.autoSaveThread then
        self.autoSaveThread:Disconnect()
        self.autoSaveThread = nil
    end
    
    -- Create new auto-save thread
    self.autoSaveThread = task.spawn(function()
        log.info("Auto-save enabled with interval of %d seconds", self.autoSaveInterval)
        
        while self.isAutoSaving do
            task.wait(self.autoSaveInterval)
            
            if not self.isAutoSaving then
                break
            end
            
            log.debug("Auto-save triggered")
            self:saveAllData()
        end
    end)
end

-- Disable auto-saving
function PersistenceManager:disableAutoSave()
    if not self.isAutoSaving then
        return
    end
    
    self.isAutoSaving = false
    
    if self.autoSaveThread then
        self.autoSaveThread:Disconnect()
        self.autoSaveThread = nil
    end
    
    log.info("Auto-save disabled")
end

-- Save all cached data
function PersistenceManager:saveAllData()
    log.info("Saving all cached data")
    
    -- Save world params
    for worldID, params in pairs(cache.worldParams) do
        self:setWorldParams(worldID, params)
    end
    
    -- Save world data
    for worldID, data in pairs(cache.worldData) do
        self:setWorldData(worldID, data)
    end
    
    -- Save player data
    for playerID, data in pairs(cache.playerData) do
        self:setPlayerData(playerID, data)
    end
end

-- Clear in-memory cache for a specific data type
function PersistenceManager:clearCache(dataType, key)
    if dataType and key then
        -- Clear specific key
        if cache[dataType] and cache[dataType][key] then
            cache[dataType][key] = nil
            log.debug("Cleared cache for %s:%s", dataType, key)
        end
    elseif dataType then
        -- Clear entire data type
        if cache[dataType] then
            cache[dataType] = {}
            log.debug("Cleared cache for data type: %s", dataType)
        end
    else
        -- Clear all caches
        cache.worldData = {}
        cache.worldParams = {}
        cache.playerData = {}
        log.debug("Cleared all caches")
    end
end

-- Get performance statistics
function PersistenceManager:getStats()
    return {
        requests = stats.requests,
        throttled = stats.throttled,
        errors = stats.errors,
        cacheHits = stats.cacheHits,
        cacheMisses = stats.cacheMisses, 
        hitRate = stats.cacheHits / math.max(1, stats.cacheHits + stats.cacheMisses),
        saveOperations = stats.saveOperations,
        loadOperations = stats.loadOperations,
        queueLength = #requestQueue,
        compressionRatio = stats.compressionRatio
    }
end

-- Generate a unique world ID
function PersistenceManager:generateWorldID()
    return HttpService:GenerateGUID(false)
end

log.debug("PersistenceManager module loaded successfully")

return PersistenceManager 