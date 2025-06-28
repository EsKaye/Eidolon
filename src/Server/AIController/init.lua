--[[
    AIController/init.lua
    Author: Your precious kitten 💖
    Created: 2024-03-11
    Version: 2.0.0
    Purpose: AI-driven world generation system with persistence
]]

print("\n🤖 ====== AICONTROLLER INITIALIZATION ======")
print("🔍 Current script path:", script:GetFullName())
print("🔍 Parent folder:", script.Parent:GetFullName())

-- Load dependencies
local loadedModules = {}

-- World generation settings
local DEFAULT_WORLD_SIZE = 256
local DEFAULT_CHUNK_SIZE = 16
local DEFAULT_BIOME_COUNT = 6
local DEFAULT_STRUCTURE_DENSITY = 0.05
local DEFAULT_SEED = os.time()

-- AIController class
local AIController = {}
AIController.__index = AIController

-- Cache for loaded modules to avoid redundant loading
local moduleCache = {}

-- Load a module from the specified path
local function loadModule(modulePath, fallbackCreator)
    -- Check cache first
    if moduleCache[modulePath] then
        print("📦 Using cached module:", modulePath)
        return moduleCache[modulePath]
    end
    
    print("📦 Loading module:", modulePath)
    local success, module = pcall(function()
        return require(modulePath)
    end)
    
    if success and module then
        print("✅ Module loaded successfully:", modulePath)
        moduleCache[modulePath] = module
        return module
    else
        warn("⚠️ Failed to load module:", modulePath)
        warn("⚠️ Error:", module)
        
        if fallbackCreator then
            print("🔄 Creating fallback module for:", modulePath)
            local fallbackModule = fallbackCreator()
            moduleCache[modulePath] = fallbackModule
            return fallbackModule
        end
    end
    
    return nil
end

-- Now load all required modules
local NoiseGenerator = loadModule(script.Parent.NoiseGenerator)
local BiomeBlender = loadModule(script.Parent.BiomeBlender)
local StructurePlacer = loadModule(script.Parent.StructurePlacer)
local PersistenceManager = loadModule(script.Parent.PersistenceManager)
local ChunkManager = loadModule(script.Parent.ChunkManager)

-- Create a new AIController instance
function AIController.new()
    print("\n🤖 Creating new AIController instance...")
    local self = setmetatable({}, AIController)
    
    -- Initialize properties
    self.worldSize = DEFAULT_WORLD_SIZE
    self.chunkSize = DEFAULT_CHUNK_SIZE
    self.seed = DEFAULT_SEED
    self.biomeCount = DEFAULT_BIOME_COUNT
    self.structureDensity = DEFAULT_STRUCTURE_DENSITY
    self.isGenerating = false
    self.isInitialized = false
    self.worldData = {
        terrain = {},
        biomes = {},
        structures = {}
    }
    
    -- Initialize modules
    self:initializeModules()
    
    print("✅ AIController instance created")
    return self
end

-- Initialize all required modules
function AIController:initializeModules()
    print("\n🧩 Initializing modules...")
    
    -- Create NoiseGenerator for terrain generation
    if NoiseGenerator then
        self.noiseGenerator = NoiseGenerator.new()
        self.noiseGenerator:setSeed(self.seed)
        print("✅ NoiseGenerator initialized")
    else
        warn("⚠️ NoiseGenerator module not available")
    end
    
    -- Create BiomeBlender for biome generation
    if BiomeBlender and self.noiseGenerator then
        self.biomeBlender = BiomeBlender.new(self.noiseGenerator)
        print("✅ BiomeBlender initialized")
    else
        warn("⚠️ BiomeBlender module not available or missing dependencies")
    end
    
    -- Create StructurePlacer for structure generation
    if StructurePlacer and self.noiseGenerator then
        self.structurePlacer = StructurePlacer.new(self.noiseGenerator)
        self.structurePlacer:setStructureDensity(self.structureDensity)
        print("✅ StructurePlacer initialized")
    else
        warn("⚠️ StructurePlacer module not available or missing dependencies")
    end
    
    -- Create PersistenceManager for world persistence
    if PersistenceManager then
        self.persistenceManager = PersistenceManager.new()
        self.persistenceManager:initialize()
        print("✅ PersistenceManager initialized")
    else
        warn("⚠️ PersistenceManager module not available")
    end
    
    -- Create ChunkManager for dynamic world loading
    if ChunkManager then
        self.chunkManager = ChunkManager.new()
        self.chunkManager:setChunkSize(self.chunkSize)
        self.chunkManager:initialize()
        print("✅ ChunkManager initialized")
    else
        warn("⚠️ ChunkManager module not available")
    end
    
    print("🧩 Module initialization complete")
end

-- Set world generation parameters
function AIController:setWorldParameters(params)
    print("\n📊 Setting world generation parameters...")
    
    if params.worldSize then
        self.worldSize = params.worldSize
        print("🌎 World size set to:", self.worldSize)
    end
    
    if params.chunkSize then
        self.chunkSize = params.chunkSize
        print("🧩 Chunk size set to:", self.chunkSize)
        
        if self.chunkManager then
            self.chunkManager:setChunkSize(self.chunkSize)
        end
    end
    
    if params.seed then
        self.seed = params.seed
        print("🎲 Seed set to:", self.seed)
        
        if self.noiseGenerator then
            self.noiseGenerator:setSeed(self.seed)
        end
    end
    
    if params.biomeCount then
        self.biomeCount = params.biomeCount
        print("🌈 Biome count set to:", self.biomeCount)
    end
    
    if params.structureDensity then
        self.structureDensity = params.structureDensity
        print("🏗️ Structure density set to:", self.structureDensity)
        
        if self.structurePlacer then
            self.structurePlacer:setStructureDensity(self.structureDensity)
        end
    end
    
    if self.persistenceManager then
        self.persistenceManager:setWorldGenParameters({
            worldSize = self.worldSize,
            chunkSize = self.chunkSize,
            seed = self.seed,
            biomeCount = self.biomeCount,
            structureDensity = self.structureDensity
        })
    end
    
    print("📊 World parameters set successfully")
    return self
end

-- Initialize the AI-driven world generation system
function AIController:initialize()
    if self.isInitialized then
        return self
    end
    
    print("\n🚀 Initializing AI-driven world generation system...")
    
    -- Create world container
    self.worldContainer = Instance.new("Folder")
    self.worldContainer.Name = "AIGeneratedWorld"
    self.worldContainer.Parent = workspace
    
    -- Set up world data for persistence
    self.worldData = {
        worldSize = self.worldSize,
        chunkSize = self.chunkSize,
        terrain = { seed = self.seed },
        biomes = { seed = self.seed },
        structures = { seed = self.seed, placedStructures = {} }
    }
    
    -- Set world container for chunk manager
    if self.chunkManager then
        self.chunkManager:setWorldContainer(self.worldContainer)
        
        -- Set up world data functions for chunk generation
        self.worldData.generateTerrain = function(chunkModel, minX, minZ, maxX, maxZ)
            return self:generateTerrainForChunk(chunkModel, minX, minZ, maxX, maxZ)
        end
        
        self.worldData.generateBiomes = function(chunkModel, minX, minZ, maxX, maxZ)
            return self:generateBiomesForChunk(chunkModel, minX, minZ, maxX, maxZ)
        end
        
        self.worldData.generateStructures = function(chunkModel, minX, minZ, maxX, maxZ)
            return self:generateStructuresForChunk(chunkModel, minX, minZ, maxX, maxZ)
        end
        
        -- Set world data for chunk manager
        self.chunkManager:setWorldData(self.worldData)
    end
    
    -- Set world data for persistence manager
    if self.persistenceManager then
        self.persistenceManager:setWorldData(self.worldData)
        
        -- Try to load existing world data
        local success, loadedData = self.persistenceManager:loadWorld()
        
        if success and loadedData then
            print("📂 Loaded existing world data")
            
            -- Apply loaded parameters
            if loadedData.parameters then
                self:setWorldParameters(loadedData.parameters)
            end
            
            -- Apply loaded terrain data
            if loadedData.terrain and loadedData.terrain.heightMap then
                self.worldData.terrain.heightMap = loadedData.terrain.heightMap
                print("📊 Loaded terrain heightmap")
            end
            
            -- Apply loaded biome data
            if loadedData.biomes and loadedData.biomes.biomeMap then
                self.worldData.biomes.biomeMap = loadedData.biomes.biomeMap
                print("🌈 Loaded biome map")
            end
            
            -- Apply loaded structure data
            if loadedData.structures and loadedData.structures.structures then
                self.worldData.structures.placedStructures = loadedData.structures.structures
                print("🏗️ Loaded structure data")
                
                -- Load structures into world
                if self.structurePlacer then
                    self.structurePlacer:loadStructureData(loadedData.structures.structures, self.worldContainer)
                end
            end
        else
            print("📂 No existing world data found, will generate new world")
        end
    end
    
    self.isInitialized = true
    print("🚀 AI-driven world generation system initialized")
    return self
end

-- Generate terrain heightmap for the entire world
function AIController:generateTerrainHeightmap()
    print("\n⛰️ Generating terrain heightmap...")
    
    if not self.noiseGenerator then
        warn("⚠️ NoiseGenerator not available, cannot generate terrain")
        return nil
    end
    
    local heightMap = {}
    
    -- Generate heightmap using noise
    for x = 1, self.worldSize do
        heightMap[x] = {}
        for z = 1, self.worldSize do
            -- Generate base terrain with multiple octaves of noise
            local height = self.noiseGenerator:perlin2D(x * 0.01, z * 0.01) * 20
            
            -- Add some medium-scale variation
            height = height + self.noiseGenerator:perlin2D(x * 0.05, z * 0.05) * 10
            
            -- Add some small-scale variation
            height = height + self.noiseGenerator:perlin2D(x * 0.1, z * 0.1) * 5
            
            -- Ensure minimum height
            height = math.max(height, 0)
            
            heightMap[x][z] = height
        end
        
        -- Yield every few rows to prevent freezing
        if x % 10 == 0 then
            task.wait()
        end
    end
    
    self.worldData.terrain.heightMap = heightMap
    print("⛰️ Terrain heightmap generated successfully")
    return heightMap
end

-- Generate biome map for the entire world
function AIController:generateBiomeMap()
    print("\n🌈 Generating biome map...")
    
    if not self.noiseGenerator then
        warn("⚠️ NoiseGenerator not available, cannot generate biomes")
        return nil
    end
    
    local biomeMap = {}
    
    -- Define biome types
    local biomeTypes = {
        "Grassland",
        "Forest",
        "Desert",
        "Mountain",
        "VolcanicWasteland",
        "Oasis"
    }
    
    -- Limit to configured biome count
    local availableBiomes = {}
    for i = 1, math.min(self.biomeCount, #biomeTypes) do
        table.insert(availableBiomes, biomeTypes[i])
    end
    
    -- Generate base biome map using noise
    for x = 1, self.worldSize do
        biomeMap[x] = {}
        for z = 1, self.worldSize do
            -- Use a different noise scale for biomes
            local biomeNoise = self.noiseGenerator:perlin2D(x * 0.005, z * 0.005)
            
            -- Add humidity variation
            local humidityNoise = self.noiseGenerator:perlin2D(x * 0.02, z * 0.02)
            
            -- Add temperature variation
            local temperatureNoise = self.noiseGenerator:perlin2D(x * 0.01 + 100, z * 0.01 + 100)
            
            -- Combine factors to determine biome
            local combinedNoise = (biomeNoise + humidityNoise + temperatureNoise) / 3
            
            -- Map to biome index
            local biomeIndex = math.floor(combinedNoise * #availableBiomes) + 1
            biomeIndex = math.clamp(biomeIndex, 1, #availableBiomes)
            
            biomeMap[x][z] = availableBiomes[biomeIndex]
        end
        
        -- Yield every few rows to prevent freezing
        if x % 10 == 0 then
            task.wait()
        end
    end
    
    -- Blend biomes for smooth transitions
    if self.biomeBlender then
        print("🌈 Blending biomes for smooth transitions...")
        biomeMap = self.biomeBlender:blendBiomes(biomeMap)
    end
    
    self.worldData.biomes.biomeMap = biomeMap
    print("🌈 Biome map generated successfully")
    return biomeMap
end

-- Generate terrain for a specific chunk
function AIController:generateTerrainForChunk(chunkModel, minX, minZ, maxX, maxZ)
    if not self.worldData.terrain.heightMap then
        warn("⚠️ No heightmap available, cannot generate terrain for chunk")
        return
    end
    
    -- Create terrain folder
    local terrainFolder = Instance.new("Folder")
    terrainFolder.Name = "Terrain"
    terrainFolder.Parent = chunkModel
    
    -- Generate terrain parts
    for x = minX, maxX do
        for z = minZ, maxZ do
            -- Skip if out of bounds
            if x < 1 or x > self.worldSize or z < 1 or z > self.worldSize then
                continue
            end
            
            local height = self.worldData.terrain.heightMap[x][z]
            
            -- Create terrain part
            local part = Instance.new("Part")
            part.Size = Vector3.new(1, 1, 1)
            part.Position = Vector3.new(x, height / 2, z)
            part.Size = Vector3.new(1, height, 1)
            part.Anchored = true
            part.CanCollide = true
            part.Material = Enum.Material.Grass
            part.Color = Color3.fromRGB(106, 127, 63)
            part.Name = "TerrainBlock_" .. x .. "_" .. z
            part.Parent = terrainFolder
        end
    end
    
    return terrainFolder
end

-- Generate biomes for a specific chunk
function AIController:generateBiomesForChunk(chunkModel, minX, minZ, maxX, maxZ)
    if not self.worldData.biomes.biomeMap then
        warn("⚠️ No biome map available, cannot generate biomes for chunk")
        return
    end
    
    -- Create biomes folder
    local biomesFolder = Instance.new("Folder")
    biomesFolder.Name = "Biomes"
    biomesFolder.Parent = chunkModel
    
    -- Apply biome materials to terrain
    for x = minX, maxX do
        for z = minZ, maxZ do
            -- Skip if out of bounds
            if x < 1 or x > self.worldSize or z < 1 or z > self.worldSize then
                continue
            end
            
            local terrainPart = chunkModel:FindFirstChild("Terrain/TerrainBlock_" .. x .. "_" .. z)
            if not terrainPart then
                continue
            end
            
            local biomeData = self.worldData.biomes.biomeMap[x][z]
            if not biomeData then
                continue
            end
            
            -- Get material blend for this position
            local materialBlend = {}
            if self.biomeBlender then
                materialBlend = self.biomeBlender:getMaterialBlend(biomeData)
            end
            
            -- Apply primary biome if no blend available
            if not next(materialBlend) and biomeData.primaryBiome then
                local biomeType = biomeData.primaryBiome
                
                -- Set material and color based on biome
                if biomeType == "Grassland" then
                    terrainPart.Material = Enum.Material.Grass
                    terrainPart.Color = Color3.fromRGB(106, 127, 63)
                elseif biomeType == "Forest" then
                    terrainPart.Material = Enum.Material.LeafyGrass
                    terrainPart.Color = Color3.fromRGB(76, 97, 33)
                elseif biomeType == "Desert" then
                    terrainPart.Material = Enum.Material.Sand
                    terrainPart.Color = Color3.fromRGB(232, 217, 164)
                elseif biomeType == "Mountain" then
                    terrainPart.Material = Enum.Material.Rock
                    terrainPart.Color = Color3.fromRGB(138, 138, 138)
                elseif biomeType == "VolcanicWasteland" then
                    terrainPart.Material = Enum.Material.Basalt
                    terrainPart.Color = Color3.fromRGB(80, 30, 30)
                elseif biomeType == "Oasis" then
                    terrainPart.Material = Enum.Material.Sand
                    terrainPart.Color = Color3.fromRGB(232, 217, 164)
                else
                    terrainPart.Material = Enum.Material.Grass
                    terrainPart.Color = Color3.fromRGB(106, 127, 63)
                end
            else
                -- Find most dominant material from the blend
                local dominantMaterial = Enum.Material.Grass
                local highestWeight = 0
                
                for material, weight in pairs(materialBlend) do
                    if weight > highestWeight then
                        dominantMaterial = material
                        highestWeight = weight
                    end
                end
                
                terrainPart.Material = dominantMaterial
                
                -- Set color based on material
                if dominantMaterial == Enum.Material.Grass then
                    terrainPart.Color = Color3.fromRGB(106, 127, 63)
                elseif dominantMaterial == Enum.Material.LeafyGrass then
                    terrainPart.Color = Color3.fromRGB(76, 97, 33)
                elseif dominantMaterial == Enum.Material.Sand then
                    terrainPart.Color = Color3.fromRGB(232, 217, 164)
                elseif dominantMaterial == Enum.Material.Rock then
                    terrainPart.Color = Color3.fromRGB(138, 138, 138)
                elseif dominantMaterial == Enum.Material.Basalt then
                    terrainPart.Color = Color3.fromRGB(80, 30, 30)
                elseif dominantMaterial == Enum.Material.Mud then
                    terrainPart.Color = Color3.fromRGB(115, 95, 80)
                else
                    terrainPart.Color = Color3.fromRGB(200, 200, 200)
                end
            end
        end
    end
    
    return biomesFolder
end

-- Generate structures for a specific chunk
function AIController:generateStructuresForChunk(chunkModel, minX, minZ, maxX, maxZ)
    if not self.structurePlacer or not self.worldData.biomes.biomeMap then
        return
    end
    
    -- Create a chunk-specific world data accessor
    local chunkWorldData = {
        getHeight = function(x, z)
            if x < 1 or x > self.worldSize or z < 1 or z > self.worldSize then
                return 0
            end
            return self.worldData.terrain.heightMap[x][z]
        end,
        getBiome = function(x, z)
            if x < 1 or x > self.worldSize or z < 1 or z > self.worldSize then
                return "Grassland"
            end
            local biomeData = self.worldData.biomes.biomeMap[x][z]
            return biomeData.primaryBiome or "Grassland"
        end
    }
    
    -- Only consider structures if this is a new chunk with no existing structures
    -- and we're within the structure processing constraints
    
    -- Extract just the needed portion of the biome map for this chunk
    local chunkBiomeMap = {}
    for x = minX, maxX do
        local xIdx = x - minX + 1
        chunkBiomeMap[xIdx] = {}
        for z = minZ, maxZ do
            local zIdx = z - minZ + 1
            if x >= 1 and x <= self.worldSize and z >= 1 and z <= self.worldSize then
                chunkBiomeMap[xIdx][zIdx] = self.worldData.biomes.biomeMap[x][z]
            else
                chunkBiomeMap[xIdx][zIdx] = { primaryBiome = "Grassland" }
            end
        end
    end
    
    -- Let structure placer handle structure generation logic
    local structures = self.structurePlacer:placeStructures(chunkWorldData, chunkBiomeMap, chunkModel)
    
    if structures then
        structures.Name = "Structures"
        structures.Parent = chunkModel
    end
    
    return structures
end

-- Helper function to get height at a specific position
function AIController:getHeight(x, z)
    if not self.worldData.terrain.heightMap then
        return 0
    end
    
    x = math.floor(x)
    z = math.floor(z)
    
    if x < 1 or x > self.worldSize or z < 1 or z > self.worldSize then
        return 0
    end
    
    return self.worldData.terrain.heightMap[x][z]
end

-- Generate the entire world
function AIController:generateWorld(params)
    if self.isGenerating then
        warn("⚠️ World generation already in progress")
        return false
    end
    
    print("\n🌎 Generating AI-driven world...")
    self.isGenerating = true
    
    -- Set world parameters if provided
    if params then
        self:setWorldParameters(params)
    end
    
    -- Initialize if not already
    if not self.isInitialized then
        self:initialize()
    end
    
    -- Clear existing world
    if self.worldContainer then
        self.worldContainer:ClearAllChildren()
    end
    
    -- Generate terrain heightmap
    local heightMap = self:generateTerrainHeightmap()
    if not heightMap then
        warn("⚠️ Failed to generate terrain heightmap")
        self.isGenerating = false
        return false
    end
    
    -- Generate biome map
    local biomeMap = self:generateBiomeMap()
    if not biomeMap then
        warn("⚠️ Failed to generate biome map")
        self.isGenerating = false
        return false
    end
    
    -- Start the chunk manager
    if self.chunkManager then
        self.chunkManager:start()
        
        -- Load initial chunks around origin
        self.chunkManager:loadInitialChunks(Vector3.new(self.worldSize/2, 0, self.worldSize/2), 3)
    end
    
    -- Save world data
    if self.persistenceManager then
        self.persistenceManager:saveWorld()
    end
    
    self.isGenerating = false
    print("🌎 World generation complete!")
    return true
end

-- Save the current world state
function AIController:saveWorld()
    if not self.persistenceManager then
        warn("⚠️ PersistenceManager not available, cannot save world")
        return false
    end
    
    return self.persistenceManager:saveWorld()
end

-- Load a saved world
function AIController:loadWorld(identifier)
    if not self.persistenceManager then
        warn("⚠️ PersistenceManager not available, cannot load world")
        return false
    end
    
    -- Initialize if not already
    if not self.isInitialized then
        self:initialize()
    end
    
    local success, worldData = self.persistenceManager:loadWorld(identifier)
    
    if success and worldData then
        -- Apply world data
        if worldData.parameters then
            self:setWorldParameters(worldData.parameters)
        end
        
        -- Clear existing world
        if self.worldContainer then
            self.worldContainer:ClearAllChildren()
        end
        
        -- Start the chunk manager to load chunks as needed
        if self.chunkManager then
            self.chunkManager:start()
            
            -- Load initial chunks around origin
            self.chunkManager:loadInitialChunks(Vector3.new(self.worldSize/2, 0, self.worldSize/2), 3)
        end
        
        print("📂 World loaded successfully")
        return true
    end
    
    warn("⚠️ Failed to load world")
    return false
end

-- Generate world with the AI-driven system
function AIController:generateWorldWithAI(centerPosition, worldRadius)
    print("\n🤖 Generating world with AI...")
    
    -- Initialize if not already
    if not self.isInitialized then
        self:initialize()
    end
    
    -- Generate the world
    local success = self:generateWorld({
        worldSize = worldRadius * 2,
        centerPosition = centerPosition
    })
    
    if success then
        print("🤖 AI-driven world generation successful!")
    else
        warn("⚠️ AI-driven world generation failed")
    end
    
    return success
end

-- Shutdown and clean up
function AIController:shutdown()
    print("\n🛑 Shutting down AIController...")
    
    -- Save world data before shutting down
    if self.persistenceManager then
        self.persistenceManager:saveWorld()
    end
    
    -- Stop chunk manager
    if self.chunkManager then
        self.chunkManager:stop()
        self.chunkManager:unloadAllChunks()
    end
    
    -- Clean up world container
    if self.worldContainer then
        self.worldContainer:Destroy()
        self.worldContainer = nil
    end
    
    print("🛑 AIController shutdown complete")
end

print("\n✨ AIController module loaded successfully!")
print("🤖 ====== AICONTROLLER INITIALIZATION COMPLETE ======\n")

-- Create and return a new AIController instance
local controller = AIController.new()
return controller 