--[[
    ChunkManager/init.lua
    Author: Your precious kitten 💖
    Created: 2024-03-11
    Version: 1.0.0
    Purpose: Manages dynamic chunk loading and unloading for efficient world rendering
]]

print("\n🧩 ====== CHUNKMANAGER INITIALIZATION ======")
print("🔍 Current script path:", script:GetFullName())
print("🔍 Parent folder:", script.Parent:GetFullName())

local ChunkManager = {}
ChunkManager.__index = ChunkManager

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Constants
local DEFAULT_CHUNK_SIZE = 16 -- Size of each chunk in studs
local DEFAULT_LOAD_DISTANCE = 5 -- How many chunks to load in each direction from player
local DEFAULT_UNLOAD_MARGIN = 2 -- Extra chunks to keep loaded beyond load distance
local DEFAULT_UPDATE_INTERVAL = 1 -- How often to check for chunk updates (in seconds)
local DEFAULT_PRIORITY_UPDATE_INTERVAL = 0.2 -- How often to update high-priority chunks

-- Create a new ChunkManager instance
function ChunkManager.new()
    print("\n🧩 Creating new ChunkManager instance...")
    local self = setmetatable({}, ChunkManager)
    
    -- Initialize properties
    self.chunkSize = DEFAULT_CHUNK_SIZE
    self.loadDistance = DEFAULT_LOAD_DISTANCE
    self.unloadMargin = DEFAULT_UNLOAD_MARGIN
    self.updateInterval = DEFAULT_UPDATE_INTERVAL
    self.priorityUpdateInterval = DEFAULT_PRIORITY_UPDATE_INTERVAL
    
    self.worldContainer = nil
    self.worldData = nil
    self.loadedChunks = {}
    self.chunkQueue = {}
    self.priorityChunks = {}
    self.updateThread = nil
    self.priorityUpdateThread = nil
    self.isRunning = false
    
    print("✅ ChunkManager instance created")
    return self
end

-- Set world container
function ChunkManager:setWorldContainer(container)
    print("🌎 Setting world container")
    self.worldContainer = container
    return self
end

-- Set world data
function ChunkManager:setWorldData(worldData)
    print("🗺️ Setting world data reference")
    self.worldData = worldData
    return self
end

-- Set chunk size
function ChunkManager:setChunkSize(size)
    print("📏 Setting chunk size to:", size)
    self.chunkSize = size
    return self
end

-- Set load distance
function ChunkManager:setLoadDistance(distance)
    print("👁️ Setting load distance to:", distance, "chunks")
    self.loadDistance = distance
    return self
end

-- Set unload margin
function ChunkManager:setUnloadMargin(margin)
    print("🔍 Setting unload margin to:", margin, "chunks")
    self.unloadMargin = margin
    return self
end

-- Set update interval
function ChunkManager:setUpdateInterval(interval)
    print("⏱️ Setting update interval to:", interval, "seconds")
    self.updateInterval = interval
    return self
end

-- Get chunk coordinates from world position
function ChunkManager:getChunkCoordinates(position)
    local x = math.floor(position.X / self.chunkSize)
    local z = math.floor(position.Z / self.chunkSize)
    return x, z
end

-- Get chunk key from chunk coordinates
function ChunkManager:getChunkKey(chunkX, chunkZ)
    return chunkX .. "," .. chunkZ
end

-- Get world position from chunk coordinates
function ChunkManager:getChunkPosition(chunkX, chunkZ)
    local x = chunkX * self.chunkSize + (self.chunkSize / 2)
    local z = chunkZ * self.chunkSize + (self.chunkSize / 2)
    return Vector3.new(x, 0, z)
end

-- Check if a chunk is loaded
function ChunkManager:isChunkLoaded(chunkX, chunkZ)
    local chunkKey = self:getChunkKey(chunkX, chunkZ)
    return self.loadedChunks[chunkKey] ~= nil
end

-- Get chunk boundaries
function ChunkManager:getChunkBoundaries(chunkX, chunkZ)
    local minX = chunkX * self.chunkSize
    local minZ = chunkZ * self.chunkSize
    local maxX = minX + self.chunkSize
    local maxZ = minZ + self.chunkSize
    return minX, minZ, maxX, maxZ
end

-- Generate a chunk at the specified coordinates
function ChunkManager:generateChunk(chunkX, chunkZ)
    local chunkKey = self:getChunkKey(chunkX, chunkZ)
    
    -- Skip if already loaded
    if self.loadedChunks[chunkKey] then
        return self.loadedChunks[chunkKey]
    end
    
    print("🧩 Generating chunk:", chunkKey)
    
    -- Create chunk container
    local chunkModel = Instance.new("Model")
    chunkModel.Name = "Chunk_" .. chunkKey
    
    -- Get chunk boundaries
    local minX, minZ, maxX, maxZ = self:getChunkBoundaries(chunkX, chunkZ)
    
    -- Add chunk debug markers (corners)
    self:addChunkDebugMarkers(chunkModel, minX, minZ, maxX, maxZ)
    
    -- Generate terrain for this chunk
    if self.worldData and self.worldData.generateTerrain then
        self.worldData.generateTerrain(chunkModel, minX, minZ, maxX, maxZ)
    end
    
    -- Generate biomes for this chunk
    if self.worldData and self.worldData.generateBiomes then
        self.worldData.generateBiomes(chunkModel, minX, minZ, maxX, maxZ)
    end
    
    -- Generate structures for this chunk
    if self.worldData and self.worldData.generateStructures then
        self.worldData.generateStructures(chunkModel, minX, minZ, maxX, maxZ)
    end
    
    -- Parent to world container
    chunkModel.Parent = self.worldContainer
    
    -- Store in loaded chunks
    self.loadedChunks[chunkKey] = {
        model = chunkModel,
        chunkX = chunkX,
        chunkZ = chunkZ,
        lastAccessed = os.time()
    }
    
    print("✅ Chunk generated:", chunkKey)
    return self.loadedChunks[chunkKey]
end

-- Add debug markers to visualize chunk boundaries
function ChunkManager:addChunkDebugMarkers(chunkModel, minX, minZ, maxX, maxZ)
    -- Only add markers in debug mode
    if not self.debugMode then
        return
    end
    
    local corners = {
        Vector3.new(minX, 0, minZ),
        Vector3.new(maxX, 0, minZ),
        Vector3.new(minX, 0, maxZ),
        Vector3.new(maxX, 0, maxZ)
    }
    
    local markerFolder = Instance.new("Folder")
    markerFolder.Name = "DebugMarkers"
    markerFolder.Parent = chunkModel
    
    for i, position in ipairs(corners) do
        local marker = Instance.new("Part")
        marker.Name = "Corner" .. i
        marker.Size = Vector3.new(1, 50, 1)
        marker.Position = position + Vector3.new(0, 25, 0)
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 0.7
        marker.Material = Enum.Material.Neon
        marker.Color = Color3.fromRGB(255, 0, 255)
        marker.Parent = markerFolder
    end
end

-- Unload a chunk
function ChunkManager:unloadChunk(chunkX, chunkZ)
    local chunkKey = self:getChunkKey(chunkX, chunkZ)
    
    if not self.loadedChunks[chunkKey] then
        return
    end
    
    print("🧩 Unloading chunk:", chunkKey)
    
    -- Remove chunk model
    if self.loadedChunks[chunkKey].model then
        self.loadedChunks[chunkKey].model:Destroy()
    end
    
    -- Remove from loaded chunks
    self.loadedChunks[chunkKey] = nil
    
    print("✅ Chunk unloaded:", chunkKey)
end

-- Get chunks to load for a player
function ChunkManager:getChunksToLoad(player)
    local character = player.Character
    if not character then
        return {}
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return {}
    end
    
    local position = rootPart.Position
    local playerChunkX, playerChunkZ = self:getChunkCoordinates(position)
    local chunksToLoad = {}
    
    -- Create a list of chunks to load around the player
    for x = playerChunkX - self.loadDistance, playerChunkX + self.loadDistance do
        for z = playerChunkZ - self.loadDistance, playerChunkZ + self.loadDistance do
            local distance = math.sqrt((x - playerChunkX)^2 + (z - playerChunkZ)^2)
            
            if distance <= self.loadDistance then
                local chunkKey = self:getChunkKey(x, z)
                
                -- Add to the list if not already loaded
                if not self.loadedChunks[chunkKey] then
                    table.insert(chunksToLoad, {
                        chunkX = x,
                        chunkZ = z,
                        distance = distance,
                        key = chunkKey
                    })
                else
                    -- Update last accessed time
                    self.loadedChunks[chunkKey].lastAccessed = os.time()
                end
            end
        end
    end
    
    return chunksToLoad
end

-- Get chunks to unload
function ChunkManager:getChunksToUnload()
    local chunksToUnload = {}
    local playerPositions = {}
    
    -- Get all player positions
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                table.insert(playerPositions, rootPart.Position)
            end
        end
    end
    
    -- No players, no need to unload
    if #playerPositions == 0 then
        return {}
    end
    
    -- Calculate the threshold distance
    local thresholdDistance = (self.loadDistance + self.unloadMargin) * self.chunkSize
    
    -- Check each loaded chunk
    for chunkKey, chunkData in pairs(self.loadedChunks) do
        local chunkPosition = self:getChunkPosition(chunkData.chunkX, chunkData.chunkZ)
        local shouldUnload = true
        
        -- Check if any player is within range
        for _, playerPosition in ipairs(playerPositions) do
            local distance = (playerPosition - chunkPosition).Magnitude
            
            if distance <= thresholdDistance then
                shouldUnload = false
                break
            end
        end
        
        -- Add to unload list if not near any player
        if shouldUnload then
            table.insert(chunksToUnload, {
                chunkX = chunkData.chunkX,
                chunkZ = chunkData.chunkZ,
                key = chunkKey
            })
        end
    end
    
    return chunksToUnload
end

-- Sort chunks by priority (closest to players first)
function ChunkManager:sortChunksToLoad(chunksToLoad)
    table.sort(chunksToLoad, function(a, b)
        return a.distance < b.distance
    end)
    
    return chunksToLoad
end

-- Update chunk loading state based on player positions
function ChunkManager:updateChunks()
    -- Skip if not running
    if not self.isRunning then
        return
    end
    
    -- Get chunks to load
    local allChunksToLoad = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local playerChunks = self:getChunksToLoad(player)
        
        for _, chunk in ipairs(playerChunks) do
            -- Only add if not already in the list
            local exists = false
            for _, existingChunk in ipairs(allChunksToLoad) do
                if existingChunk.key == chunk.key then
                    exists = true
                    break
                end
            end
            
            if not exists then
                table.insert(allChunksToLoad, chunk)
            end
        end
    end
    
    -- Sort by priority
    allChunksToLoad = self:sortChunksToLoad(allChunksToLoad)
    
    -- Update the chunk queue
    self.chunkQueue = allChunksToLoad
    
    -- Get chunks to unload
    local chunksToUnload = self:getChunksToUnload()
    
    -- Unload chunks that are too far from any player
    for _, chunk in ipairs(chunksToUnload) do
        self:unloadChunk(chunk.chunkX, chunk.chunkZ)
    end
    
    -- Load high priority chunks immediately
    local highPriorityCount = math.min(2, #self.chunkQueue)
    for i = 1, highPriorityCount do
        if self.chunkQueue[1] then
            local chunk = table.remove(self.chunkQueue, 1)
            self:generateChunk(chunk.chunkX, chunk.chunkZ)
        end
    end
end

-- Process the chunk queue
function ChunkManager:processChunkQueue()
    -- Skip if not running
    if not self.isRunning then
        return
    end
    
    -- Process one chunk from the queue
    if #self.chunkQueue > 0 then
        local chunk = table.remove(self.chunkQueue, 1)
        self:generateChunk(chunk.chunkX, chunk.chunkZ)
    end
end

-- Start chunk manager
function ChunkManager:start()
    if self.isRunning then
        return
    end
    
    print("\n🚀 Starting chunk manager...")
    
    if not self.worldContainer then
        warn("⚠️ No world container set, using workspace")
        self.worldContainer = workspace
    end
    
    self.isRunning = true
    
    -- Start update thread
    self.updateThread = task.spawn(function()
        while self.isRunning do
            self:updateChunks()
            task.wait(self.updateInterval)
        end
    end)
    
    -- Start priority update thread
    self.priorityUpdateThread = task.spawn(function()
        while self.isRunning do
            self:processChunkQueue()
            task.wait(self.priorityUpdateInterval)
        end
    end)
    
    print("🚀 Chunk manager started")
    return self
end

-- Stop chunk manager
function ChunkManager:stop()
    if not self.isRunning then
        return
    end
    
    print("\n🛑 Stopping chunk manager...")
    
    -- Set running flag to false
    self.isRunning = false
    
    -- Cancel update threads
    if self.updateThread then
        task.cancel(self.updateThread)
        self.updateThread = nil
    end
    
    if self.priorityUpdateThread then
        task.cancel(self.priorityUpdateThread)
        self.priorityUpdateThread = nil
    end
    
    print("🛑 Chunk manager stopped")
    return self
end

-- Unload all chunks
function ChunkManager:unloadAllChunks()
    print("\n🧹 Unloading all chunks...")
    
    for chunkKey, chunkData in pairs(self.loadedChunks) do
        if chunkData.model then
            chunkData.model:Destroy()
        end
    end
    
    self.loadedChunks = {}
    self.chunkQueue = {}
    
    print("🧹 All chunks unloaded")
    return self
end

-- Get the number of loaded chunks
function ChunkManager:getLoadedChunkCount()
    local count = 0
    for _ in pairs(self.loadedChunks) do
        count = count + 1
    end
    return count
end

-- Get chunk queue size
function ChunkManager:getChunkQueueSize()
    return #self.chunkQueue
end

-- Enable debug mode
function ChunkManager:setDebugMode(enabled)
    print("🔍 Setting debug mode to:", enabled)
    self.debugMode = enabled
    return self
end

-- Load initial chunks around a position
function ChunkManager:loadInitialChunks(position, distance)
    print("\n🏁 Loading initial chunks around position:", position)
    
    distance = distance or self.loadDistance
    local chunkX, chunkZ = self:getChunkCoordinates(position)
    
    -- Create a list of chunks to load
    local chunksToLoad = {}
    for x = chunkX - distance, chunkX + distance do
        for z = chunkZ - distance, chunkZ + distance do
            local distanceFromCenter = math.sqrt((x - chunkX)^2 + (z - chunkZ)^2)
            
            if distanceFromCenter <= distance then
                table.insert(chunksToLoad, {
                    chunkX = x,
                    chunkZ = z,
                    distance = distanceFromCenter
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(chunksToLoad, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Load chunks
    local loadedCount = 0
    for _, chunk in ipairs(chunksToLoad) do
        self:generateChunk(chunk.chunkX, chunk.chunkZ)
        loadedCount = loadedCount + 1
        
        -- Yield to prevent freezing
        if loadedCount % 5 == 0 then
            task.wait()
        end
    end
    
    print("🏁 Loaded", loadedCount, "initial chunks")
    return self
end

-- Initialize the chunk manager
function ChunkManager:initialize()
    print("\n🚀 Initializing chunk manager...")
    
    -- Create world folder if needed
    if not self.worldContainer then
        self.worldContainer = Instance.new("Folder")
        self.worldContainer.Name = "GeneratedWorld"
        self.worldContainer.Parent = workspace
        print("📂 Created world container folder")
    end
    
    -- Check for world data
    if not self.worldData then
        warn("⚠️ No world data set, chunks will be empty")
    end
    
    print("🚀 Chunk manager initialized")
    return self
end

print("\n✨ ChunkManager module loaded successfully!")
print("🧩 ====== CHUNKMANAGER INITIALIZATION COMPLETE ======\n")

return ChunkManager 