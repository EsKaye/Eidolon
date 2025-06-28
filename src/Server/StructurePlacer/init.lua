--[[
    StructurePlacer/init.lua
    Author: Your precious kitten 💖
    Updated: 2024-03-11
    Version: 1.1.0
    Purpose: Places structures based on biome type, terrain height, and AI rules (Optimized)
]]

local Logger = require(script.Parent.Parent.Logger)
local log = Logger.forModule("StructurePlacer")

log.debug("Initializing StructurePlacer module")

-- Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")

-- Constants
local DEFAULT_STRUCTURE_DENSITY = 0.025 -- Default density of structures (0-1)
local MIN_STRUCTURE_DISTANCE = 20 -- Minimum distance between structures
local MAX_STRUCTURES_PER_CHUNK = 10 -- Maximum structures per chunk
local ASSET_VERIFICATION_BATCH_SIZE = 10 -- Number of assets to verify in each batch
local STRUCTURE_PLACEMENT_BATCH_SIZE = 5 -- Number of structures to place in each batch
local DEFAULT_BIOME_RULES = {
    ["Grassland"] = {
        structures = {
            "Tree_Oak", "Tree_Birch", "Bush_Small", "Rock_Small", "Flower_Patch"
        },
        weights = {
            ["Tree_Oak"] = 0.4,
            ["Tree_Birch"] = 0.3, 
            ["Bush_Small"] = 0.15,
            ["Rock_Small"] = 0.1,
            ["Flower_Patch"] = 0.05
        },
        density = 0.03
    },
    ["Forest"] = {
        structures = {
            "Tree_Oak", "Tree_Pine", "Tree_Birch", "Bush_Medium", "Mushroom_Cluster"
        },
        weights = {
            ["Tree_Oak"] = 0.35,
            ["Tree_Pine"] = 0.35,
            ["Tree_Birch"] = 0.15,
            ["Bush_Medium"] = 0.1,
            ["Mushroom_Cluster"] = 0.05
        },
        density = 0.05
    },
    ["Desert"] = {
        structures = {
            "Cactus_Tall", "Cactus_Small", "Rock_Desert", "DeadTree", "SandDune"
        },
        weights = {
            ["Cactus_Tall"] = 0.2,
            ["Cactus_Small"] = 0.3,
            ["Rock_Desert"] = 0.25,
            ["DeadTree"] = 0.15,
            ["SandDune"] = 0.1
        },
        density = 0.015
    },
    ["Mountain"] = {
        structures = {
            "Rock_Large", "Rock_Cluster", "Tree_Pine", "Mountain_Peak", "Cave_Entrance"
        },
        weights = {
            ["Rock_Large"] = 0.35,
            ["Rock_Cluster"] = 0.25,
            ["Tree_Pine"] = 0.2,
            ["Mountain_Peak"] = 0.15,
            ["Cave_Entrance"] = 0.05
        },
        density = 0.02
    },
    ["VolcanicWasteland"] = {
        structures = {
            "Volcano_Small", "LavaPool", "Rock_Volcanic", "SteamVent", "AshPile"
        },
        weights = {
            ["Rock_Volcanic"] = 0.4,
            ["SteamVent"] = 0.3,
            ["AshPile"] = 0.15,
            ["LavaPool"] = 0.1,
            ["Volcano_Small"] = 0.05
        },
        density = 0.01
    },
    ["Oasis"] = {
        structures = {
            "PalmTree", "WaterPool", "TropicalBush", "Reeds", "FruitBush"
        },
        weights = {
            ["PalmTree"] = 0.3,
            ["TropicalBush"] = 0.25,
            ["Reeds"] = 0.2,
            ["WaterPool"] = 0.15,
            ["FruitBush"] = 0.1
        },
        density = 0.04
    }
}

-- Main module
local StructurePlacer = {}
StructurePlacer.__index = StructurePlacer

-- Cache for asset verification results
local assetVerificationCache = {}

-- Spatial index to track structure placements for collision detection
local spatialIndex = {}
local spatialIndexCellSize = 50 -- Size of each cell in the spatial index

-- Structure loading cache to avoid duplicate loading
local structureCache = {}

-- Asset verification queue for background processing
local assetVerificationQueue = {}
local isAssetVerificationRunning = false

-- Helper Functions
local function getRandomValue(weightTable)
    local totalWeight = 0
    for _, weight in pairs(weightTable) do
        totalWeight = totalWeight + weight
    end
    
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    
    for item, weight in pairs(weightTable) do
        currentWeight = currentWeight + weight
        if randomValue <= currentWeight then
            return item
        end
    end
    
    -- Fallback - return first item
    for item, _ in pairs(weightTable) do
        return item
    end
end

-- Create spatial index key from world position
local function getSpatialIndexKey(position)
    local cellX = math.floor(position.X / spatialIndexCellSize)
    local cellZ = math.floor(position.Z / spatialIndexCellSize)
    return cellX .. ":" .. cellZ
end

-- Add structure to spatial index
local function addToSpatialIndex(position, structureType, structureId)
    local key = getSpatialIndexKey(position)
    
    if not spatialIndex[key] then
        spatialIndex[key] = {}
    end
    
    table.insert(spatialIndex[key], {
        position = position,
        structureType = structureType,
        structureId = structureId
    })
end

-- Check if position is too close to existing structures
local function isTooCloseToExistingStructures(position)
    -- Check the current cell and neighboring cells
    for xOffset = -1, 1 do
        for zOffset = -1, 1 do
            local cellX = math.floor(position.X / spatialIndexCellSize) + xOffset
            local cellZ = math.floor(position.Z / spatialIndexCellSize) + zOffset
            local key = cellX .. ":" .. cellZ
            
            if spatialIndex[key] then
                for _, structure in ipairs(spatialIndex[key]) do
                    local distance = (position - structure.position).Magnitude
                    if distance < MIN_STRUCTURE_DISTANCE then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Process asset verification queue in the background
local function processAssetVerificationQueue()
    if isAssetVerificationRunning or #assetVerificationQueue == 0 then
        return
    end
    
    isAssetVerificationRunning = true
    
    -- Process assets in batches
    task.spawn(function()
        while #assetVerificationQueue > 0 do
            local batchSize = math.min(ASSET_VERIFICATION_BATCH_SIZE, #assetVerificationQueue)
            local batch = {}
            
            -- Get a batch of assets to verify
            for i = 1, batchSize do
                table.insert(batch, table.remove(assetVerificationQueue, 1))
            end
            
            -- Verify the batch
            for _, assetInfo in ipairs(batch) do
                local assetId = assetInfo.assetId
                local callback = assetInfo.callback
                
                -- Check if already cached
                if assetVerificationCache[assetId] ~= nil then
                    if callback then
                        callback(assetVerificationCache[assetId])
                    end
                else
                    -- Verify the asset
                    local success = pcall(function()
                        ContentProvider:PreloadAsync({assetId})
                    end)
                    
                    assetVerificationCache[assetId] = success
                    
                    if callback then
                        callback(success)
                    end
                end
                
                -- Small delay to prevent throttling
                task.wait(0.1)
            end
        end
        
        isAssetVerificationRunning = false
    end)
end

-- Queue asset for verification
local function verifyAsset(assetId, callback)
    -- Check cache first
    if assetVerificationCache[assetId] ~= nil then
        if callback then
            callback(assetVerificationCache[assetId])
        end
        return
    end
    
    -- Add to queue
    table.insert(assetVerificationQueue, {
        assetId = assetId,
        callback = callback
    })
    
    -- Start processing if not already running
    if not isAssetVerificationRunning then
        processAssetVerificationQueue()
    end
end

-- Preload structure models for faster placement
local function preloadStructure(structureType)
    if structureCache[structureType] then
        return structureCache[structureType]
    end
    
    -- Try to load from Assets folder
    local structuresFolder = game.ServerStorage:FindFirstChild("Structures")
    if not structuresFolder then
        log.error("Structures folder not found in ServerStorage")
        return nil
    end
    
    local structure = structuresFolder:FindFirstChild(structureType)
    if not structure then
        log.error("Structure %s not found in Structures folder", structureType)
        return nil
    end
    
    -- Cache the structure
    structureCache[structureType] = structure:Clone()
    return structureCache[structureType]
end

-- Initialize StructurePlacer
function StructurePlacer.new()
    log.info("Creating new StructurePlacer instance")
    
    local self = setmetatable({}, StructurePlacer)
    
    -- Initialize properties
    self.structures = {}
    self.biomeRules = table.clone(DEFAULT_BIOME_RULES)
    self.structureDensity = DEFAULT_STRUCTURE_DENSITY
    self.structureFolder = nil
    self.placedStructures = {}
    self.placementQueue = {}
    self.isPlacing = false
    self.seed = os.time()
    
    -- Create a folder for structures if it doesn't exist
    self:createStructureFolder()
    
    -- Preload common structures
    self:preloadCommonStructures()
    
    log.debug("StructurePlacer instance created")
    return self
end

-- Create a folder to hold all placed structures
function StructurePlacer:createStructureFolder()
    local workspace = game:GetService("Workspace")
    local existingFolder = workspace:FindFirstChild("GeneratedStructures")
    
    if existingFolder then
        self.structureFolder = existingFolder
        log.debug("Using existing GeneratedStructures folder")
    else
        self.structureFolder = Instance.new("Folder")
        self.structureFolder.Name = "GeneratedStructures"
        self.structureFolder.Parent = workspace
        log.debug("Created new GeneratedStructures folder")
    end
end

-- Preload commonly used structures to improve placement performance
function StructurePlacer:preloadCommonStructures()
    log.debug("Preloading common structures")
    
    local commonStructures = {}
    
    -- Collect common structures from all biomes
    for _, biomeData in pairs(self.biomeRules) do
        for _, structureType in ipairs(biomeData.structures) do
            if not table.find(commonStructures, structureType) then
                table.insert(commonStructures, structureType)
            end
        end
    end
    
    -- Preload the most common structures
    for i, structureType in ipairs(commonStructures) do
        if i <= 10 then -- Limit to the first 10 to avoid initial lag
            task.spawn(function()
                preloadStructure(structureType)
            end)
        end
    end
    
    log.debug("Common structures queued for preloading")
end

-- Set seed for structure generation
function StructurePlacer:setSeed(seed)
    self.seed = seed
    log.debug("Structure placement seed set to %d", seed)
    return self
end

-- Set custom biome rules
function StructurePlacer:setBiomeRules(rules)
    if rules then
        self.biomeRules = rules
        log.debug("Custom biome rules set")
    end
    return self
end

-- Set overall structure density multiplier
function StructurePlacer:setStructureDensity(density)
    self.structureDensity = math.clamp(density, 0, 1)
    log.debug("Structure density set to %.3f", self.structureDensity)
    return self
end

-- Clear all placed structures
function StructurePlacer:clearStructures()
    log.info("Clearing all placed structures")
    
    if self.structureFolder then
        self.structureFolder:ClearAllChildren()
    end
    
    self.placedStructures = {}
    spatialIndex = {} -- Reset spatial index
    
    log.debug("All structures cleared")
    return self
end

-- Load structures from saved data
function StructurePlacer:loadStructures(structureData)
    if not structureData or not structureData.structures then
        log.warning("No structure data to load")
        return false
    end
    
    log.info("Loading %d saved structures", #structureData.structures)
    
    -- Clear existing structures
    self:clearStructures()
    
    -- Set the seed if provided
    if structureData.seed then
        self:setSeed(structureData.seed)
    end
    
    -- Process structures in batches
    local structuresToPlace = structureData.structures
    local processed = 0
    
    -- Function to process a batch
    local function processBatch()
        local batchSize = math.min(STRUCTURE_PLACEMENT_BATCH_SIZE, #structuresToPlace - processed)
        
        for i = 1, batchSize do
            local structureInfo = structuresToPlace[processed + i]
            
            if structureInfo then
                local position = Vector3.new(
                    structureInfo.position.X,
                    structureInfo.position.Y,
                    structureInfo.position.Z
                )
                
                self:placeStructure(
                    structureInfo.structureType,
                    position,
                    structureInfo.rotation,
                    structureInfo.scale,
                    structureInfo.biomeType
                )
            end
        end
        
        processed = processed + batchSize
        
        -- If more structures to process, schedule next batch
        if processed < #structuresToPlace then
            task.delay(0.05, processBatch)
        else
            log.info("All structures loaded successfully")
        end
    end
    
    -- Start processing
    processBatch()
    
    return true
end

-- Place a specific structure at the given position
function StructurePlacer:placeStructure(structureType, position, rotation, scale, biomeType)
    -- Check if position conflicts with existing structures
    if isTooCloseToExistingStructures(position) then
        log.debug("Structure placement at %s skipped due to proximity to existing structures", tostring(position))
        return nil
    end
    
    -- Generate unique ID for the structure
    local structureId = "struct_" .. HttpService:GenerateGUID(false)
    
    -- Load structure model
    local structureModel = preloadStructure(structureType)
    if not structureModel then
        log.error("Failed to load structure model %s", structureType)
        return nil
    end
    
    -- Clone and position the structure
    local placedStructure = structureModel:Clone()
    placedStructure.Name = structureType .. "_" .. structureId
    
    -- Set position, rotation, and scale
    placedStructure:SetPrimaryPartCFrame(
        CFrame.new(position) * 
        CFrame.Angles(0, rotation or math.rad(math.random(0, 359)), 0)
    )
    
    if scale then
        local primaryPart = placedStructure.PrimaryPart
        for _, part in ipairs(placedStructure:GetDescendants()) do
            if part:IsA("BasePart") then
                if part == primaryPart then
                    part.Size = part.Size * scale
                else
                    part.Size = part.Size * scale
                    local relativeCFrame = primaryPart.CFrame:ToObjectSpace(part.CFrame)
                    part.CFrame = primaryPart.CFrame * relativeCFrame
                end
            end
        end
    end
    
    -- Add to folder
    placedStructure.Parent = self.structureFolder
    
    -- Add to spatial index for collision detection
    addToSpatialIndex(position, structureType, structureId)
    
    -- Record placed structure
    table.insert(self.placedStructures, {
        structureId = structureId,
        structureType = structureType,
        position = position,
        rotation = rotation or math.rad(math.random(0, 359)),
        scale = scale or 1,
        biomeType = biomeType or "Unknown"
    })
    
    return placedStructure
end

-- Place structures based on biome map and terrain height
function StructurePlacer:placeStructures(biomeMap, terrainHeightMap, chunkBounds)
    if not biomeMap or not terrainHeightMap then
        log.error("Missing required biome map or terrain height map")
        return false
    end
    
    log.info("Placing structures based on biome map")
    
    -- Initialize with seed for reproducible results
    math.randomseed(self.seed)
    
    -- Define chunk bounds if not provided
    local startX = (chunkBounds and chunkBounds.startX) or 1
    local endX = (chunkBounds and chunkBounds.endX) or #biomeMap
    local startZ = (chunkBounds and chunkBounds.startZ) or 1
    local endZ = (chunkBounds and chunkBounds.endZ) or #biomeMap[1]
    
    -- Calculate number of structures to place based on density
    local chunkSize = ((endX - startX) * (endZ - startZ))
    local maxStructuresForChunk = math.min(
        math.ceil(chunkSize * self.structureDensity),
        MAX_STRUCTURES_PER_CHUNK
    )
    
    log.debug("Planning to place up to %d structures in chunk", maxStructuresForChunk)
    
    -- Candidate positions for structures
    local candidates = {}
    
    -- Add candidate positions based on biome weightings
    for x = startX, endX do
        for z = startZ, endZ do
            local biomeData = biomeMap[x][z]
            local primaryBiome = biomeData.primaryBiome
            
            if self.biomeRules[primaryBiome] then
                local biomeDensity = self.biomeRules[primaryBiome].density * self.structureDensity
                
                -- Use biome density to determine chance of adding candidate
                if math.random() < biomeDensity then
                    local heightY = terrainHeightMap[x][z] or 0
                    
                    table.insert(candidates, {
                        position = Vector3.new(x, heightY, z),
                        biomeType = primaryBiome
                    })
                end
            end
        end
    end
    
    -- Shuffle candidates
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    
    -- Limit to max structures
    if #candidates > maxStructuresForChunk then
        for i = #candidates, maxStructuresForChunk + 1, -1 do
            table.remove(candidates, i)
        end
    end
    
    log.debug("Selected %d candidate positions for structure placement", #candidates)
    
    -- Place structures in batches to avoid lag
    local function processBatch(index)
        local batchEnd = math.min(index + STRUCTURE_PLACEMENT_BATCH_SIZE - 1, #candidates)
        
        for i = index, batchEnd do
            local candidate = candidates[i]
            local biomeType = candidate.biomeType
            local position = candidate.position
            
            -- Skip if too close to existing structures
            if isTooCloseToExistingStructures(position) then
                continue
            end
            
            -- Select a random structure type based on biome weights
            local structureType = getRandomValue(self.biomeRules[biomeType].weights)
            
            -- Random rotation and scale variations
            local rotation = math.rad(math.random(0, 359))
            local scale = 0.8 + (math.random() * 0.4) -- 0.8 to 1.2
            
            -- Place the structure
            self:placeStructure(structureType, position, rotation, scale, biomeType)
        end
        
        -- If more to process, schedule next batch
        if batchEnd < #candidates then
            task.delay(0.05, function()
                processBatch(batchEnd + 1)
            end)
        else
            log.info("Completed structure placement - %d structures placed", #self.placedStructures)
        end
    end
    
    -- Start batch processing if we have candidates
    if #candidates > 0 then
        processBatch(1)
    else
        log.warning("No suitable locations found for structures in this chunk")
    end
    
    return true
end

-- Get serializable structure data for saving
function StructurePlacer:getStructureData()
    return {
        structures = self.placedStructures,
        seed = self.seed,
        count = #self.placedStructures
    }
end

-- Queue a structure to be placed with animation
function StructurePlacer:queueStructurePlacement(structureType, position, rotation, scale, biomeType)
    table.insert(self.placementQueue, {
        structureType = structureType,
        position = position,
        rotation = rotation,
        scale = scale,
        biomeType = biomeType
    })
    
    -- Start processing the queue if not already running
    if not self.isPlacing then
        self:processPlacementQueue()
    end
end

-- Process the structure placement queue with animations
function StructurePlacer:processPlacementQueue()
    if #self.placementQueue == 0 or self.isPlacing then
        return
    end
    
    self.isPlacing = true
    
    -- Process one structure at a time with animation
    local function processNext()
        if #self.placementQueue == 0 then
            self.isPlacing = false
            return
        end
        
        local next = table.remove(self.placementQueue, 1)
        
        -- Place with animation
        self:placeStructureWithAnimation(
            next.structureType,
            next.position,
            next.rotation,
            next.scale,
            next.biomeType,
            function()
                -- Process next after short delay
                task.delay(0.1, processNext)
            end
        )
    end
    
    processNext()
end

-- Place a structure with spawn animation
function StructurePlacer:placeStructureWithAnimation(structureType, position, rotation, scale, biomeType, callback)
    -- Place the structure
    local structure = self:placeStructure(structureType, position, rotation, scale, biomeType)
    
    if not structure then
        if callback then callback() end
        return nil
    end
    
    -- Apply animation
    for _, part in ipairs(structure:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Store original properties
            local originalPosition = part.Position
            local originalTransparency = part.Transparency
            
            -- Set initial state
            part.Transparency = 1
            
            -- Animate in
            local tweenInfo = TweenInfo.new(
                0.5, -- Time
                Enum.EasingStyle.Elastic, -- Style
                Enum.EasingDirection.Out -- Direction
            )
            
            local tween = TweenService:Create(part, tweenInfo, {
                Transparency = originalTransparency
            })
            
            tween:Play()
        end
    end
    
    -- Call callback after animation completes
    task.delay(0.6, function()
        if callback then callback() end
    end)
    
    return structure
end

log.debug("StructurePlacer module loaded successfully")

return StructurePlacer 