--[[
    OptimizedWorldSystem.lua
    Author: Your favorite AI assistant 💖
    Created: 2024-03-12
    Version: 1.0.0
    Purpose: Main integration module for the optimized Petfinity 2.0 World Generation System
]]

local Logger = require(script.Parent.Logger)
local log = Logger.forModule("OptimizedWorldSystem")

log.info("Initializing OptimizedWorldSystem module")

-- Import optimized modules
local NoiseGenerator = require(script.Parent.NoiseGenerator)
local BiomeBlender = require(script.Parent.BiomeBlender)
local PersistenceManager = require(script.Parent.PersistenceManager)
local StructurePlacer = require(script.Parent.StructurePlacer)
local PerfMonitor = require(script.Parent.PerfMonitor)
local FireflyIntegration = require(script.Parent.ContentGenerator.FireflyIntegration)

-- Services
local RunService = game:GetService("RunService")

-- Constants
local DEFAULT_WORLD_SIZE = 1024
local DEFAULT_CHUNK_SIZE = 32
local DEFAULT_RENDER_DISTANCE = 5
local DEFAULT_DETAIL_LEVEL = 3 -- 1-5, higher is more detailed
local BENCHMARK_ITERATIONS = 5

-- The OptimizedWorldSystem class
local OptimizedWorldSystem = {}
OptimizedWorldSystem.__index = OptimizedWorldSystem

-- Generate a unique world ID
local function generateWorldId()
    local httpService = game:GetService("HttpService")
    return httpService:GenerateGUID(false)
end

-- Track memory usage changes
local function trackMemoryChange(func, label)
    local before = gcinfo()
    local result = func()
    local after = gcinfo()
    local change = after - before
    
    log.debug("%s memory change: %s KB", label, change)
    return result, change
end

-- Create a new OptimizedWorldSystem instance
function OptimizedWorldSystem.new(config)
    log.info("Creating new OptimizedWorldSystem instance")
    
    config = config or {}
    local worldId = config.worldId or generateWorldId()
    
    -- Register with performance monitor
    PerfMonitor.registerModule("WorldSystem")
    
    -- Initialize subsystems with performance monitoring
    local system = setmetatable({
        -- Configuration
        worldId = worldId,
        worldSize = config.worldSize or DEFAULT_WORLD_SIZE,
        chunkSize = config.chunkSize or DEFAULT_CHUNK_SIZE,
        renderDistance = config.renderDistance or DEFAULT_RENDER_DISTANCE,
        detailLevel = config.detailLevel or DEFAULT_DETAIL_LEVEL,
        seed = config.seed or os.time(),
        
        -- State tracking
        isInitialized = false,
        isGenerating = false,
        isLoading = false,
        activeChunks = {},
        chunkGenerationQueue = {},
        
        -- Performance metrics
        metrics = {
            generationTime = 0,
            loadingTime = 0,
            frameTimes = {},
            memoryUsage = 0,
            chunkCount = 0
        },
        
        -- API key for Firefly (if provided)
        firefly = {
            apiKey = config.fireflyApiKey,
            isEnabled = config.fireflyApiKey ~= nil
        }
    }, OptimizedWorldSystem)
    
    -- Initialize sub-systems
    PerfMonitor.startOperation("WorldSystem", "initialization")
    
    -- Initialize NoiseGenerator
    system.noise = NoiseGenerator.new(system.seed)
    log.debug("NoiseGenerator initialized with seed: %s", system.seed)
    
    -- Initialize BiomeBlender
    system.biomeBlender = BiomeBlender.new()
    system.biomeBlender:setCacheSize(500) -- Adjust based on world size
    log.debug("BiomeBlender initialized with cache size: 500")
    
    -- Initialize PersistenceManager
    system.persistence = PersistenceManager.new("Petfinity2_World_" .. worldId)
    system.persistence:setAutoSaveInterval(300) -- 5 minutes
    log.debug("PersistenceManager initialized for world: %s", worldId)
    
    -- Initialize StructurePlacer
    system.structurePlacer = StructurePlacer.new()
    log.debug("StructurePlacer initialized")
    
    -- Initialize Firefly Integration
    system.contentGenerator = FireflyIntegration.new(config.fireflyApiKey)
    if system.firefly.isEnabled then
        log.info("Firefly integration enabled")
    else
        log.info("Firefly integration disabled (no API key provided)")
    end
    
    -- Initialize the performance monitor connection
    system.perfUpdateConnection = RunService.Heartbeat:Connect(function(dt)
        PerfMonitor.trackFrameTime(dt)
        
        -- Update metrics once per second
        system.frameCounter = (system.frameCounter or 0) + 1
        if system.frameCounter >= 60 then
            system.frameCounter = 0
            system:updateMetrics()
        end
    end)
    
    PerfMonitor.endOperation("WorldSystem", "initialization")
    log.info("OptimizedWorldSystem initialized successfully")
    
    return system
end

-- Configure world generation parameters
function OptimizedWorldSystem:configure(config)
    if config.seed and config.seed ~= self.seed then
        self.seed = config.seed
        self.noise:setSeed(config.seed)
        log.info("Noise generator seed updated to: %s", config.seed)
    end
    
    if config.worldSize then self.worldSize = config.worldSize end
    if config.chunkSize then self.chunkSize = config.chunkSize end
    if config.renderDistance then self.renderDistance = config.renderDistance end
    if config.detailLevel then self.detailLevel = config.detailLevel end
    
    -- Update Firefly API key if provided
    if config.fireflyApiKey then
        self.firefly.apiKey = config.fireflyApiKey
        self.firefly.isEnabled = true
        self.contentGenerator:setApiKey(config.fireflyApiKey)
        log.info("Firefly API key updated")
    end
    
    -- Configure persistence
    if config.autoSaveInterval then
        self.persistence:setAutoSaveInterval(config.autoSaveInterval)
    end
    
    log.info("World system configured with: worldSize=%d, chunkSize=%d, renderDistance=%d, detailLevel=%d",
        self.worldSize, self.chunkSize, self.renderDistance, self.detailLevel)
    
    return self
end

-- Initialize the world system
function OptimizedWorldSystem:initialize()
    if self.isInitialized then
        log.warning("World system already initialized")
        return self
    end
    
    PerfMonitor.startOperation("WorldSystem", "full_initialization")
    
    -- Prepare the world container
    self.worldRoot = Instance.new("Folder")
    self.worldRoot.Name = "PetfinityWorld_" .. self.worldId
    self.worldRoot.Parent = workspace
    
    -- Create organization folders
    self.terrainFolder = Instance.new("Folder")
    self.terrainFolder.Name = "Terrain"
    self.terrainFolder.Parent = self.worldRoot
    
    self.structuresFolder = Instance.new("Folder")
    self.structuresFolder.Name = "Structures"
    self.structuresFolder.Parent = self.worldRoot
    
    self.entitiesFolder = Instance.new("Folder")
    self.entitiesFolder.Name = "Entities"
    self.entitiesFolder.Parent = self.worldRoot
    
    -- Load world data if exists
    local worldData, loadError = self:tryLoadWorldData()
    
    if worldData then
        log.info("Loaded existing world data for world: %s", self.worldId)
    else
        if loadError then
            log.warning("Could not load world data: %s", loadError)
        end
        log.info("Initializing new world with ID: %s", self.worldId)
    end
    
    -- Pre-calculate noise at a coarse level for fast biome boundary detection
    log.debug("Pre-calculating coarse noise for biome boundaries")
    self:preCalculateCoarseNoise()
    
    -- Pre-generate structures templates if Firefly is enabled
    if self.firefly.isEnabled then
        log.debug("Pre-loading texture assets from Firefly")
        self:preloadTextureAssets()
    end
    
    -- Initialize structure placer with the parent folder
    self.structurePlacer:setParentFolder(self.structuresFolder)
    
    self.isInitialized = true
    PerfMonitor.endOperation("WorldSystem", "full_initialization")
    
    log.info("World system fully initialized")
    return self
end

-- Try to load existing world data
function OptimizedWorldSystem:tryLoadWorldData()
    if not self.persistence then
        return nil, "Persistence manager not initialized"
    end
    
    PerfMonitor.startOperation("WorldSystem", "data_loading")
    
    local success, worldData = pcall(function()
        return self.persistence:loadWorldData()
    end)
    
    PerfMonitor.endOperation("WorldSystem", "data_loading")
    
    if not success then
        return nil, "Error loading world data: " .. tostring(worldData)
    end
    
    if not worldData then
        return nil, "No existing world data found"
    end
    
    -- Apply loaded world data
    if worldData.seed then
        self.seed = worldData.seed
        self.noise:setSeed(worldData.seed)
    end
    
    if worldData.parameters then
        self:configure(worldData.parameters)
    end
    
    return worldData
end

-- Pre-calculate coarse noise for fast biome detection
function OptimizedWorldSystem:preCalculateCoarseNoise()
    PerfMonitor.startOperation("WorldSystem", "coarse_noise_calculation")
    
    -- Calculate coarse noise at 1/16th resolution
    local coarseSize = math.ceil(self.worldSize / 16)
    local coarseNoise = {}
    
    -- Batch process the noise calculations
    for x = 1, coarseSize do
        coarseNoise[x] = {}
        for z = 1, coarseSize do
            local worldX = x * 16
            local worldZ = z * 16
            coarseNoise[x][z] = self.noise:perlin3D(worldX, 0, worldZ)
        end
    end
    
    self.coarseNoise = coarseNoise
    
    PerfMonitor.endOperation("WorldSystem", "coarse_noise_calculation")
    log.debug("Coarse noise pre-calculation complete: %dx%d grid", coarseSize, coarseSize)
    
    return self
end

-- Preload texture assets if Firefly is enabled
function OptimizedWorldSystem:preloadTextureAssets()
    if not self.firefly.isEnabled or not self.contentGenerator then
        return self
    end
    
    PerfMonitor.startOperation("WorldSystem", "texture_preloading")
    
    -- Get list of biomes from the biome blender
    local biomes = self.biomeBlender:getBiomeTypes()
    
    -- For each biome, preload its textures
    local preloadCount = 0
    for _, biome in ipairs(biomes) do
        self.contentGenerator:generateBiomeTextureSet(biome, function(results, error)
            if error then
                log.warning("Error preloading textures for biome %s: %s", biome, error)
            else
                preloadCount = preloadCount + 1
                log.debug("Preloaded textures for biome: %s", biome)
            end
        end)
    end
    
    PerfMonitor.endOperation("WorldSystem", "texture_preloading")
    log.info("Texture preloading initiated for %d biomes", #biomes)
    
    return self
end

-- Generate a chunk at the specified coordinates
function OptimizedWorldSystem:generateChunk(chunkX, chunkZ)
    if not self.isInitialized then
        log.warning("Cannot generate chunk: World system not initialized")
        return nil
    end
    
    local chunkId = chunkX .. "," .. chunkZ
    
    -- Check if chunk is already active
    if self.activeChunks[chunkId] then
        log.debug("Chunk %s already active, skipping generation", chunkId)
        return self.activeChunks[chunkId]
    end
    
    PerfMonitor.startOperation("WorldSystem", "chunk_generation_" .. chunkId)
    
    -- Create a new chunk container
    local chunk = {
        id = chunkId,
        x = chunkX,
        z = chunkZ,
        worldX = chunkX * self.chunkSize,
        worldZ = chunkZ * self.chunkSize,
        size = self.chunkSize,
        container = Instance.new("Folder")
    }
    
    chunk.container.Name = "Chunk_" .. chunkId
    chunk.container.Parent = self.terrainFolder
    
    -- Generate terrain for the chunk
    self:generateChunkTerrain(chunk)
    
    -- Place structures in the chunk
    self:placeChunkStructures(chunk)
    
    -- Add to active chunks
    self.activeChunks[chunkId] = chunk
    
    -- Update metrics
    self.metrics.chunkCount = self.metrics.chunkCount + 1
    
    PerfMonitor.endOperation("WorldSystem", "chunk_generation_" .. chunkId)
    log.debug("Generated chunk at (%d,%d)", chunkX, chunkZ)
    
    return chunk
end

-- Generate terrain for a chunk
function OptimizedWorldSystem:generateChunkTerrain(chunk)
    PerfMonitor.startOperation("WorldSystem", "terrain_generation_" .. chunk.id)
    
    -- Generate heightmap for the chunk
    local heightMap = {}
    
    -- Calculate terrain points
    for x = 0, chunk.size do
        heightMap[x] = {}
        for z = 0, chunk.size do
            local worldX = chunk.worldX + x
            local worldZ = chunk.worldZ + z
            
            -- Get height using fractal noise
            local height = self.noise:fractal(
                worldX / 100, 
                0, 
                worldZ / 100, 
                self.detailLevel + 2, -- More octaves for height
                0.5
            )
            
            -- Scale height to desired range (0-100)
            height = (height + 1) * 50
            heightMap[x][z] = height
        end
    end
    
    -- Determine biomes for the chunk
    local biomeMap = {}
    for x = 0, chunk.size do
        biomeMap[x] = {}
        for z = 0, chunk.size do
            local worldX = chunk.worldX + x
            local worldZ = chunk.worldZ + z
            
            -- Use noise to determine biome type
            local biomeNoise = self.noise:perlin3D(worldX / 200, 0, worldZ / 200)
            
            -- Get biome type based on noise and height
            local biomeType = self.biomeBlender:getBiomeType(biomeNoise, heightMap[x][z])
            biomeMap[x][z] = biomeType
        end
    end
    
    -- Blend biomes at boundaries
    local blendedBiomeMap = self.biomeBlender:blendBiomes(biomeMap, heightMap)
    
    -- Create terrain parts based on the blended biome map
    self:createTerrainParts(chunk, heightMap, blendedBiomeMap)
    
    -- Store heightmap and biome data with the chunk
    chunk.heightMap = heightMap
    chunk.biomeMap = blendedBiomeMap
    
    PerfMonitor.endOperation("WorldSystem", "terrain_generation_" .. chunk.id)
    return chunk
end

-- Create terrain parts based on heightmap and biome data
function OptimizedWorldSystem:createTerrainParts(chunk, heightMap, biomeMap)
    PerfMonitor.startOperation("WorldSystem", "terrain_creation_" .. chunk.id)
    
    -- Group terrain by biome type for batch creation
    local biomeGroups = {}
    
    -- Create a grid of terrain blocks
    local function createTerrainBlock(x, z, height, biome)
        if not biomeGroups[biome] then
            biomeGroups[biome] = {}
        end
        
        table.insert(biomeGroups[biome], {
            x = x,
            z = z,
            height = height
        })
    end
    
    -- Create terrain blocks for the entire chunk
    for x = 0, chunk.size - 1 do
        for z = 0, chunk.size - 1 do
            local height = math.floor(heightMap[x][z])
            local biome = biomeMap[x][z]
            
            createTerrainBlock(x, z, height, biome)
        end
    end
    
    -- Create parts in batches by biome type
    for biome, positions in pairs(biomeGroups) do
        local biomeFolder = Instance.new("Folder")
        biomeFolder.Name = biome
        biomeFolder.Parent = chunk.container
        
        -- Process in batches of 100 to avoid performance issues
        for i = 1, #positions, 100 do
            local endIdx = math.min(i + 99, #positions)
            local batch = {}
            
            for j = i, endIdx do
                table.insert(batch, positions[j])
            end
            
            self:createTerrainBatch(biomeFolder, batch, biome, chunk)
        end
    end
    
    PerfMonitor.endOperation("WorldSystem", "terrain_creation_" .. chunk.id)
    return chunk
end

-- Create a batch of terrain parts
function OptimizedWorldSystem:createTerrainBatch(parent, positions, biome, chunk)
    -- Create parts with matching properties for the biome
    for _, pos in ipairs(positions) do
        local block = Instance.new("Part")
        block.Size = Vector3.new(4, pos.height * 0.2, 4)
        block.Position = Vector3.new(
            chunk.worldX + pos.x * 4 + 2, 
            pos.height * 0.1, 
            chunk.worldZ + pos.z * 4 + 2
        )
        block.Anchored = true
        block.CanCollide = true
        block.Material = self:getBiomeMaterial(biome)
        block.Color = self:getBiomeColor(biome)
        block.Name = "Terrain_" .. pos.x .. "_" .. pos.z
        block.Parent = parent
        
        -- Apply texture if Firefly integration is enabled
        if self.firefly.isEnabled then
            self:applyBiomeTexture(block, biome)
        end
    end
end

-- Get the appropriate material for a biome
function OptimizedWorldSystem:getBiomeMaterial(biome)
    local materials = {
        ["Grassland"] = Enum.Material.Grass,
        ["Forest"] = Enum.Material.LeafyGrass,
        ["Desert"] = Enum.Material.Sand,
        ["Mountain"] = Enum.Material.Rock,
        ["VolcanicWasteland"] = Enum.Material.Slate,
        ["Oasis"] = Enum.Material.Sand,
        ["Tundra"] = Enum.Material.Snow,
        ["Beach"] = Enum.Material.Sand,
        ["Ocean"] = Enum.Material.Concrete
    }
    
    return materials[biome] or Enum.Material.Grass
end

-- Get the appropriate color for a biome
function OptimizedWorldSystem:getBiomeColor(biome)
    local colors = {
        ["Grassland"] = Color3.fromRGB(106, 194, 98),
        ["Forest"] = Color3.fromRGB(76, 148, 69),
        ["Desert"] = Color3.fromRGB(232, 198, 146),
        ["Mountain"] = Color3.fromRGB(138, 138, 138),
        ["VolcanicWasteland"] = Color3.fromRGB(99, 95, 98),
        ["Oasis"] = Color3.fromRGB(232, 198, 146),
        ["Tundra"] = Color3.fromRGB(230, 233, 235),
        ["Beach"] = Color3.fromRGB(232, 219, 176),
        ["Ocean"] = Color3.fromRGB(52, 152, 219)
    }
    
    return colors[biome] or Color3.fromRGB(106, 194, 98)
end

-- Apply textures to blocks if Firefly integration is enabled
function OptimizedWorldSystem:applyBiomeTexture(block, biome)
    if not self.firefly.isEnabled or not self.contentGenerator then
        return
    end
    
    -- Check if we have the ground texture for this biome
    self.contentGenerator:generateBiomeTexture(biome, "ground", nil, function(textureData, error)
        if error or not textureData then
            return
        end
        
        -- Apply texture to the block
        task.spawn(function()
            local textureResult = self.contentGenerator:loadTextureIntoRoblox(textureData)
            if textureResult and textureResult.imageLabel then
                -- Create surface GUIs for each face
                local faces = {"Top", "Bottom", "Left", "Right", "Front", "Back"}
                for _, face in ipairs(faces) do
                    local surfaceGui = Instance.new("SurfaceGui")
                    surfaceGui.Name = "Texture_" .. face
                    surfaceGui.Face = Enum.NormalId[face]
                    surfaceGui.LightInfluence = 0
                    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
                    surfaceGui.PixelsPerStud = 16
                    surfaceGui.Parent = block
                    
                    local imageClone = textureResult.imageLabel:Clone()
                    imageClone.Parent = surfaceGui
                end
            end
        end)
    end)
end

-- Place structures in a chunk
function OptimizedWorldSystem:placeChunkStructures(chunk)
    PerfMonitor.startOperation("WorldSystem", "structure_placement_" .. chunk.id)
    
    -- Get biome and height data from chunk
    local chunkBiomes = {}
    for x = 0, chunk.size do
        for z = 0, chunk.size do
            local biome = chunk.biomeMap[x][z]
            if biome then
                if not chunkBiomes[biome] then
                    chunkBiomes[biome] = 0
                end
                chunkBiomes[biome] = chunkBiomes[biome] + 1
            end
        end
    end
    
    -- Determine dominant biome
    local dominantBiome = "Grassland"
    local maxCount = 0
    for biome, count in pairs(chunkBiomes) do
        if count > maxCount then
            maxCount = count
            dominantBiome = biome
        end
    end
    
    -- Place structures based on dominant biome
    local structureCount = self.structurePlacer:getStructureCountForBiome(dominantBiome)
    
    -- For each potential structure
    for i = 1, structureCount do
        -- Find a suitable location
        local attempts = 0
        local maxAttempts = 10
        local placed = false
        
        while attempts < maxAttempts and not placed do
            attempts = attempts + 1
            
            -- Get random position within chunk
            local localX = math.random(0, chunk.size - 1)
            local localZ = math.random(0, chunk.size - 1)
            
            -- World position
            local worldX = chunk.worldX + localX * 4
            local worldZ = chunk.worldZ + localZ * 4
            
            -- Get height and biome at position
            local height = chunk.heightMap[localX][localZ] or 50
            local biome = chunk.biomeMap[localX][localZ] or dominantBiome
            
            -- Try to place structure
            local success = self.structurePlacer:placeStructureAt(
                worldX, 
                height, 
                worldZ, 
                biome,
                chunk.container
            )
            
            if success then
                placed = true
                log.debug("Placed structure at (%d,%d) in chunk %s", worldX, worldZ, chunk.id)
            end
        end
    end
    
    PerfMonitor.endOperation("WorldSystem", "structure_placement_" .. chunk.id)
    return chunk
end

-- Update chunks around a given position
function OptimizedWorldSystem:updateChunksAroundPosition(position)
    if not self.isInitialized then
        log.warning("Cannot update chunks: World system not initialized")
        return self
    end
    
    PerfMonitor.startOperation("WorldSystem", "chunk_update")
    
    -- Calculate current chunk coordinates
    local currentChunkX = math.floor(position.X / (self.chunkSize * 4))
    local currentChunkZ = math.floor(position.Z / (self.chunkSize * 4))
    
    -- Determine which chunks should be active
    local shouldBeActive = {}
    local renderDistance = self.renderDistance
    
    for x = currentChunkX - renderDistance, currentChunkX + renderDistance do
        for z = currentChunkZ - renderDistance, currentChunkZ + renderDistance do
            local chunkId = x .. "," .. z
            shouldBeActive[chunkId] = true
            
            -- Generate chunk if not already active
            if not self.activeChunks[chunkId] then
                -- Add to generation queue
                table.insert(self.chunkGenerationQueue, {x = x, z = z})
            end
        end
    end
    
    -- Process generation queue (up to 3 chunks per update)
    for i = 1, math.min(3, #self.chunkGenerationQueue) do
        local chunkInfo = table.remove(self.chunkGenerationQueue, 1)
        if chunkInfo then
            self:generateChunk(chunkInfo.x, chunkInfo.z)
        end
    end
    
    -- Unload chunks that are too far away
    for chunkId, chunk in pairs(self.activeChunks) do
        if not shouldBeActive[chunkId] then
            self:unloadChunk(chunkId)
        end
    end
    
    PerfMonitor.endOperation("WorldSystem", "chunk_update")
    return self
end

-- Unload a chunk
function OptimizedWorldSystem:unloadChunk(chunkId)
    local chunk = self.activeChunks[chunkId]
    if not chunk then
        return
    end
    
    log.debug("Unloading chunk: %s", chunkId)
    
    -- Save chunk data if needed
    -- self:saveChunkData(chunk)
    
    -- Remove chunk container
    if chunk.container and chunk.container:IsA("Instance") then
        chunk.container:Destroy()
    end
    
    -- Remove from active chunks
    self.activeChunks[chunkId] = nil
    
    -- Update metrics
    self.metrics.chunkCount = self.metrics.chunkCount - 1
    
    return self
end

-- Save the entire world
function OptimizedWorldSystem:saveWorld()
    if not self.isInitialized or not self.persistence then
        log.warning("Cannot save world: World system not initialized or persistence manager not available")
        return false
    end
    
    PerfMonitor.startOperation("WorldSystem", "world_saving")
    
    -- Prepare world data
    local worldData = {
        id = self.worldId,
        seed = self.seed,
        timestamp = os.time(),
        parameters = {
            worldSize = self.worldSize,
            chunkSize = self.chunkSize,
            renderDistance = self.renderDistance,
            detailLevel = self.detailLevel
        },
        chunks = {}
    }
    
    -- Add data for each active chunk
    for chunkId, chunk in pairs(self.activeChunks) do
        -- Only save essential data
        worldData.chunks[chunkId] = {
            id = chunk.id,
            x = chunk.x,
            z = chunk.z
        }
    end
    
    -- Save to persistence manager
    local success, error = pcall(function()
        return self.persistence:saveWorldData(worldData)
    end)
    
    PerfMonitor.endOperation("WorldSystem", "world_saving")
    
    if not success then
        log.error("Failed to save world: %s", error)
        return false
    end
    
    log.info("World saved successfully: %s", self.worldId)
    return true
end

-- Run world generation benchmarks
function OptimizedWorldSystem:runBenchmarks()
    if not PerfMonitor then
        log.warning("Cannot run benchmarks: Performance monitor not available")
        return nil
    end
    
    log.info("Running world generation benchmarks...")
    
    local benchmarks = {
        ["noise_generation"] = function()
            local result = 0
            for i = 1, 1000 do
                local x, y, z = math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)
                result = result + self.noise:perlin3D(x, y, z)
            end
            return result
        end,
        
        ["fractal_noise"] = function()
            local result = 0
            for i = 1, 100 do
                local x, y, z = math.random(-100, 100), math.random(-100, 100), math.random(-100, 100)
                result = result + self.noise:fractal(x, y, z, 4, 0.5)
            end
            return result
        end,
        
        ["biome_blending"] = function()
            -- Create sample biome and height maps
            local biomeMap = {}
            local heightMap = {}
            for x = 0, 32 do
                biomeMap[x] = {}
                heightMap[x] = {}
                for z = 0, 32 do
                    biomeMap[x][z] = (x + z) % 2 == 0 and "Grassland" or "Forest"
                    heightMap[x][z] = (math.sin(x/5) + math.cos(z/5)) * 25 + 50
                end
            end
            
            return self.biomeBlender:blendBiomes(biomeMap, heightMap)
        end,
        
        ["chunk_generation"] = function()
            -- Use a test position far from actual game world
            local testChunkX = 9999
            local testChunkZ = 9999
            local chunk = self:generateChunk(testChunkX, testChunkZ)
            
            -- Clean up test chunk right away
            self:unloadChunk(testChunkX .. "," .. testChunkZ)
            return chunk ~= nil
        end
    }
    
    -- Run each benchmark
    local results = {}
    for name, benchmarkFn in pairs(benchmarks) do
        log.debug("Running benchmark: %s", name)
        results[name] = PerfMonitor.runBenchmark(
            "WorldSystem", 
            name, 
            benchmarkFn, 
            BENCHMARK_ITERATIONS
        )
    end
    
    -- Log detailed results
    log.info("Benchmark results:")
    for name, result in pairs(results) do
        log.info("  %s: avg=%.2fms, min=%.2fms, max=%.2fms", 
            name, 
            result.average * 1000, 
            result.min * 1000, 
            result.max * 1000
        )
    end
    
    return results
end

-- Compare original vs optimized functions
function OptimizedWorldSystem:comparePerformance(original, optimized, iterations)
    if not PerfMonitor then
        return nil
    end
    
    iterations = iterations or BENCHMARK_ITERATIONS
    
    return PerfMonitor.compareFunctions(original, optimized, iterations)
end

-- Update metrics
function OptimizedWorldSystem:updateMetrics()
    if not self.isInitialized then
        return
    end
    
    -- Update memory usage
    self.metrics.memoryUsage = gcinfo()
    
    -- Update other metrics from performance monitor
    local perfData = PerfMonitor.getModuleStats("WorldSystem")
    if perfData then
        -- Update generation and loading metrics
        if perfData.operations then
            for name, data in pairs(perfData.operations) do
                if name:find("chunk_generation") then
                    self.metrics.generationTime = data.average
                elseif name == "data_loading" then
                    self.metrics.loadingTime = data.average
                end
            end
        end
        
        -- Update frame times
        if perfData.frameTimes then
            self.metrics.frameTimes = perfData.frameTimes
        end
    end
    
    log.debug("Metrics updated: memoryUsage=%dKB, activeChunks=%d", 
        self.metrics.memoryUsage, 
        self.metrics.chunkCount
    )
end

-- Get performance metrics
function OptimizedWorldSystem:getMetrics()
    self:updateMetrics()
    return self.metrics
end

-- Clean up resources when the world system is no longer needed
function OptimizedWorldSystem:destroy()
    log.info("Destroying world system")
    
    -- Save world before destroying
    self:saveWorld()
    
    -- Stop auto-save if active
    if self.persistence then
        self.persistence:disableAutoSave()
    end
    
    -- Disconnect performance monitor connection
    if self.perfUpdateConnection then
        self.perfUpdateConnection:Disconnect()
        self.perfUpdateConnection = nil
    end
    
    -- Unload all chunks
    for chunkId, _ in pairs(self.activeChunks) do
        self:unloadChunk(chunkId)
    end
    
    -- Clean up world container
    if self.worldRoot and self.worldRoot:IsA("Instance") then
        self.worldRoot:Destroy()
    end
    
    -- Clear references
    self.activeChunks = {}
    self.chunkGenerationQueue = {}
    self.isInitialized = false
    
    -- Remove from performance monitor
    PerfMonitor.unregisterModule("WorldSystem")
    
    log.info("World system destroyed")
end

log.debug("OptimizedWorldSystem module loaded successfully")

return OptimizedWorldSystem 