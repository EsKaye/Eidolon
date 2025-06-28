--[[
    BiomeBlender/init.lua
    Author: Your precious kitten 💖
    Updated: 2024-03-11
    Version: 1.1.0
    Purpose: Provides smooth blending between different biomes (Optimized)
]]

local Logger = require(script.Parent.Parent.Logger)
local log = Logger.forModule("BiomeBlender")

log.debug("Initializing BiomeBlender module")

local BiomeBlender = {}
BiomeBlender.__index = BiomeBlender

-- Constants for biome blending
local DEFAULT_BLEND_RADIUS = 10
local DEFAULT_BLEND_STRENGTH = 0.5
local DEFAULT_TRANSITION_NOISE_SCALE = 0.01
local BLEND_THRESHOLD = 0.05 -- Minimum blend factor to consider
local SPATIAL_GRID_CELL_SIZE = 16 -- Size of spatial partitioning grid cells

-- Pre-computed blend factors for common distances
local blendFactorCache = {}

-- Biome transition rules define which biomes can naturally border each other
local biomeTransitionRules = {
    -- Format: [biome1] = {biome2 = weight, biome3 = weight}
    -- Higher weight = more likely transition
    ["Grassland"] = {
        ["Forest"] = 1.0,
        ["Hills"] = 0.8,
        ["River"] = 0.5,
        ["Desert"] = 0.2
    },
    
    ["Forest"] = {
        ["Grassland"] = 0.8,
        ["Hills"] = 0.7,
        ["Mountain"] = 0.5,
        ["River"] = 0.4
    },
    
    ["Desert"] = {
        ["Oasis"] = 0.3,
        ["Grassland"] = 0.2,
        ["VolcanicWasteland"] = 0.4,
        ["DryRiver"] = 0.3
    },
    
    ["Mountain"] = {
        ["Hills"] = 0.9,
        ["Forest"] = 0.5,
        ["Snow"] = 0.7,
        ["River"] = 0.3
    },
    
    ["Oasis"] = {
        ["Desert"] = 1.0,
        ["VolcanicWasteland"] = 0.1
    },
    
    ["VolcanicWasteland"] = {
        ["Desert"] = 0.7,
        ["Mountain"] = 0.5,
        ["Oasis"] = 0.1
    },
    
    -- Default transitions for any biome not specifically defined
    ["Default"] = {
        ["Grassland"] = 0.3,
        ["Desert"] = 0.2,
        ["Forest"] = 0.3,
        ["Hills"] = 0.2
    }
}

-- Optimized lookup for transition weights
local precomputedTransitions = {}

-- Material distributions for different biomes
local biomeMaterials = {
    ["Grassland"] = {
        [Enum.Material.Grass] = 0.8,
        [Enum.Material.Mud] = 0.1,
        [Enum.Material.Rock] = 0.1
    },
    
    ["Forest"] = {
        [Enum.Material.Grass] = 0.6,
        [Enum.Material.LeafyGrass] = 0.3,
        [Enum.Material.Mud] = 0.1
    },
    
    ["Desert"] = {
        [Enum.Material.Sand] = 0.9,
        [Enum.Material.Sandstone] = 0.1
    },
    
    ["Mountain"] = {
        [Enum.Material.Rock] = 0.7,
        [Enum.Material.Slate] = 0.2,
        [Enum.Material.Snow] = 0.1
    },
    
    ["VolcanicWasteland"] = {
        [Enum.Material.Rock] = 0.5,
        [Enum.Material.Basalt] = 0.3,
        [Enum.Material.CrackedLava] = 0.2
    },
    
    ["Oasis"] = {
        [Enum.Material.Sand] = 0.5,
        [Enum.Material.Grass] = 0.3,
        [Enum.Material.Water] = 0.2
    },
    
    -- Default material distribution for unknown biomes
    ["Default"] = {
        [Enum.Material.Grass] = 0.5,
        [Enum.Material.Rock] = 0.3,
        [Enum.Material.Mud] = 0.2
    }
}

-- Pre-compute transition weights between all biomes
local function precomputeTransitionWeights()
    log.debug("Pre-computing biome transition weights")
    
    -- Get all biome names
    local biomeNames = {}
    for biome, _ in pairs(biomeTransitionRules) do
        if biome ~= "Default" then
            table.insert(biomeNames, biome)
        end
    end
    
    -- Compute all possible transitions
    for _, fromBiome in ipairs(biomeNames) do
        precomputedTransitions[fromBiome] = {}
        
        for _, toBiome in ipairs(biomeNames) do
            local weight = 0.1 -- Default low weight
            
            if fromBiome == toBiome then
                weight = 1.0 -- Same biome
            elseif biomeTransitionRules[fromBiome] and biomeTransitionRules[fromBiome][toBiome] then
                weight = biomeTransitionRules[fromBiome][toBiome]
            elseif biomeTransitionRules["Default"][toBiome] then
                weight = biomeTransitionRules["Default"][toBiome]
            end
            
            precomputedTransitions[fromBiome][toBiome] = weight
        end
    end
    
    log.debug("Transition weights pre-computed for %d biomes", #biomeNames)
end

-- Pre-compute common blend factors
local function precomputeBlendFactors(blendRadius, blendStrength)
    log.debug("Pre-computing blend factors")
    blendFactorCache = {}
    
    for d = 0, blendRadius, 0.5 do
        local distance = math.floor(d * 10) / 10 -- Round to 1 decimal place
        
        if distance >= blendRadius then
            blendFactorCache[distance] = 0
        else
            -- Smooth step function
            local t = 1 - (distance / blendRadius)
            blendFactorCache[distance] = t * t * (3 - 2 * t) * blendStrength
        end
    end
    
    log.debug("Blend factors pre-computed for radius %d", blendRadius)
end

-- Create a new BiomeBlender instance
function BiomeBlender.new(noiseGenerator)
    log.debug("Creating new BiomeBlender instance")
    local self = setmetatable({}, BiomeBlender)
    
    -- Initialize properties
    self.noiseGenerator = noiseGenerator
    self.blendRadius = DEFAULT_BLEND_RADIUS
    self.blendStrength = DEFAULT_BLEND_STRENGTH
    self.transitionNoiseScale = DEFAULT_TRANSITION_NOISE_SCALE
    
    -- Pre-compute lookup tables
    precomputeTransitionWeights()
    precomputeBlendFactors(self.blendRadius, self.blendStrength)
    
    log.debug("BiomeBlender instance created")
    return self
end

-- Set noise generator for blending transitions
function BiomeBlender:setNoiseGenerator(noiseGenerator)
    log.debug("Setting noise generator for biome blending")
    self.noiseGenerator = noiseGenerator
    return self
end

-- Set blend radius (how far blending extends)
function BiomeBlender:setBlendRadius(radius)
    if radius == self.blendRadius then
        return self -- No change needed
    end
    
    self.blendRadius = radius
    precomputeBlendFactors(radius, self.blendStrength)
    return self
end

-- Set blend strength (how smooth transitions are)
function BiomeBlender:setBlendStrength(strength)
    if strength == self.blendStrength then
        return self -- No change needed
    end
    
    self.blendStrength = math.clamp(strength, 0, 1)
    precomputeBlendFactors(self.blendRadius, self.blendStrength)
    return self
end

-- Get transition weight between two biomes (optimized)
function BiomeBlender:getTransitionWeight(fromBiome, toBiome)
    -- Use pre-computed transition weights
    if precomputedTransitions[fromBiome] and precomputedTransitions[fromBiome][toBiome] then
        return precomputedTransitions[fromBiome][toBiome]
    end
    
    -- Fallback for unknown biomes
    if biomeTransitionRules["Default"][toBiome] then
        return biomeTransitionRules["Default"][toBiome]
    end
    
    return 0.1 -- Default low weight
end

-- Calculate smooth transition factor between two points (optimized)
function BiomeBlender:calculateBlendFactor(distance)
    -- First check if distance exceeds radius
    if distance >= self.blendRadius then
        return 0
    end
    
    -- Round to one decimal place for cache lookup
    local roundedDistance = math.floor(distance * 10) / 10
    
    -- Try to get from cache
    if blendFactorCache[roundedDistance] then
        return blendFactorCache[roundedDistance]
    end
    
    -- Calculate and cache for future use
    local t = 1 - (distance / self.blendRadius)
    local factor = t * t * (3 - 2 * t) * self.blendStrength
    
    blendFactorCache[roundedDistance] = factor
    return factor
end

-- Add noise to blend boundaries for natural looking transitions
function BiomeBlender:addNoiseToBlend(position, factor)
    if not self.noiseGenerator or factor <= BLEND_THRESHOLD then
        return factor -- Skip noise calculation for insignificant factors
    end
    
    local noise = self.noiseGenerator:perlin2D(
        position.X * self.transitionNoiseScale, 
        position.Z * self.transitionNoiseScale
    )
    
    -- Map noise to range [-0.2, 0.2] for subtle variation
    local noiseInfluence = (noise - 0.5) * 0.4
    
    -- Apply noise to blend factor
    return math.clamp(factor + noiseInfluence, 0, 1)
end

-- Create a spatial partitioning grid for the biome map
local function createSpatialGrid(biomeMap)
    local grid = {}
    local mapWidth = #biomeMap
    local mapHeight = #biomeMap[1]
    
    -- Calculate grid dimensions
    local gridWidth = math.ceil(mapWidth / SPATIAL_GRID_CELL_SIZE)
    local gridHeight = math.ceil(mapHeight / SPATIAL_GRID_CELL_SIZE)
    
    -- Initialize grid cells
    for gx = 1, gridWidth do
        grid[gx] = {}
        for gz = 1, gridHeight do
            grid[gx][gz] = {}
        end
    end
    
    -- Populate grid with biome boundaries
    for x = 1, mapWidth do
        for z = 1, mapHeight do
            local currentBiome = biomeMap[x][z]
            local isBoundary = false
            
            -- Check if this is a boundary cell by examining neighbors
            for nx = math.max(1, x-1), math.min(mapWidth, x+1) do
                for nz = math.max(1, z-1), math.min(mapHeight, z+1) do
                    if biomeMap[nx][nz] ~= currentBiome then
                        isBoundary = true
                        break
                    end
                end
                if isBoundary then break end
            end
            
            -- If it's a boundary, add to the grid
            if isBoundary then
                local gx = math.ceil(x / SPATIAL_GRID_CELL_SIZE)
                local gz = math.ceil(z / SPATIAL_GRID_CELL_SIZE)
                
                table.insert(grid[gx][gz], {
                    x = x,
                    z = z,
                    biome = currentBiome
                })
            end
        end
    end
    
    return grid, gridWidth, gridHeight
end

-- Blend a biome map to create smooth transitions (optimized with spatial partitioning)
function BiomeBlender:blendBiomes(biomeMap)
    log.info("Blending biomes for smooth transitions")
    
    if not biomeMap or #biomeMap == 0 then
        log.warning("Empty biome map provided to blender")
        return biomeMap
    end
    
    local startTime = os.clock()
    local mapWidth = #biomeMap
    local mapHeight = #biomeMap[1]
    
    -- Create a spatial grid for efficient boundary detection
    local boundaryGrid, gridWidth, gridHeight = createSpatialGrid(biomeMap)
    log.debug("Created spatial partition grid: %dx%d", gridWidth, gridHeight)
    
    local blendedMap = {}
    
    -- Create base structure of blended map (more efficient table creation)
    for x = 1, mapWidth do
        blendedMap[x] = {}
        for z = 1, mapHeight do
            -- Each cell contains biome type and blend weights
            blendedMap[x][z] = {
                primaryBiome = biomeMap[x][z],
                blendWeights = { [biomeMap[x][z]] = 1 } -- Initially, 100% primary biome
            }
        end
    end
    
    -- Calculate blend weights - use spatial partitioning to only check near boundaries
    local cellsProcessed = 0
    local blendOperations = 0
    
    for x = 1, mapWidth do
        for z = 1, mapHeight do
            local currentBiome = biomeMap[x][z]
            local position = Vector3.new(x, 0, z)
            
            -- Determine which grid cells to check (only nearby cells within blend radius)
            local centerGx = math.ceil(x / SPATIAL_GRID_CELL_SIZE)
            local centerGz = math.ceil(z / SPATIAL_GRID_CELL_SIZE)
            local radiusInCells = math.ceil(self.blendRadius / SPATIAL_GRID_CELL_SIZE)
            
            -- Check only the grid cells that could contain relevant boundaries
            for gx = math.max(1, centerGx - radiusInCells), math.min(gridWidth, centerGx + radiusInCells) do
                for gz = math.max(1, centerGz - radiusInCells), math.min(gridHeight, centerGz + radiusInCells) do
                    -- Only process if this grid cell has boundaries
                    if boundaryGrid[gx][gz] and #boundaryGrid[gx][gz] > 0 then
                        for _, boundary in ipairs(boundaryGrid[gx][gz]) do
                            local neighborBiome = boundary.biome
                            
                            -- Skip if same biome
                            if neighborBiome ~= currentBiome then
                                local boundaryPos = Vector3.new(boundary.x, 0, boundary.z)
                                local distance = (boundaryPos - position).Magnitude
                                
                                -- Skip if distance exceeds blend radius
                                if distance < self.blendRadius then
                                    local transitionWeight = self:getTransitionWeight(currentBiome, neighborBiome)
                                    local blendFactor = self:calculateBlendFactor(distance) * transitionWeight
                                    
                                    -- Skip minimal blend factors
                                    if blendFactor > BLEND_THRESHOLD then
                                        -- Add noise variation for natural transitions
                                        blendFactor = self:addNoiseToBlend(position, blendFactor)
                                        
                                        -- Add blend weight
                                        blendedMap[x][z].blendWeights[neighborBiome] = 
                                            (blendedMap[x][z].blendWeights[neighborBiome] or 0) + blendFactor
                                        
                                        blendOperations = blendOperations + 1
                                    end
                                end
                            end
                        end
                    end
                    
                    cellsProcessed = cellsProcessed + 1
                end
            end
            
            -- Normalize weights
            local totalWeight = 0
            for _, weight in pairs(blendedMap[x][z].blendWeights) do
                totalWeight = totalWeight + weight
            end
            
            if totalWeight > 0 then
                for biome, weight in pairs(blendedMap[x][z].blendWeights) do
                    blendedMap[x][z].blendWeights[biome] = weight / totalWeight
                end
            end
        end
    end
    
    local endTime = os.clock()
    log.info("Biome blending completed in %.3f seconds", endTime - startTime)
    log.debug("Processed %d cells, performed %d blend operations", cellsProcessed, blendOperations)
    
    return blendedMap
end

-- Get material blend for a specific world position (optimized)
function BiomeBlender:getMaterialBlend(biomeData)
    -- Early return for single biome (common case)
    local biomeCount = 0
    local singleBiome
    
    for biome, weight in pairs(biomeData.blendWeights) do
        biomeCount = biomeCount + 1
        singleBiome = biome
        if biomeCount > 1 then break end
    end
    
    if biomeCount == 1 then
        -- Optimization for the common case of a single biome
        return biomeMaterials[singleBiome] or biomeMaterials["Default"]
    end
    
    -- Handle the more complex case of multiple biomes
    local materials = {}
    
    -- Apply material distribution for each biome based on blend weights
    for biome, weight in pairs(biomeData.blendWeights) do
        local biomeDistribution = biomeMaterials[biome] or biomeMaterials["Default"]
        
        for material, materialWeight in pairs(biomeDistribution) do
            materials[material] = (materials[material] or 0) + (materialWeight * weight)
        end
    end
    
    return materials
end

-- Visualize a blended biome map (for debugging)
function BiomeBlender:visualizeBlendMap(blendedMap, scale, height)
    print("🔍 Visualizing blended biome map...")
    scale = scale or 1
    height = height or 0.5
    
    -- Color map for different biomes
    local biomeColors = {
        ["Grassland"] = Color3.fromRGB(0, 255, 0),
        ["Forest"] = Color3.fromRGB(0, 128, 0),
        ["Desert"] = Color3.fromRGB(255, 240, 120),
        ["Mountain"] = Color3.fromRGB(128, 128, 128),
        ["VolcanicWasteland"] = Color3.fromRGB(128, 0, 0),
        ["Oasis"] = Color3.fromRGB(0, 255, 255),
        ["Default"] = Color3.fromRGB(200, 200, 200)
    }
    
    -- Create visualization model
    local visualization = Instance.new("Model")
    visualization.Name = "BiomeBlendMapVisualization"
    
    for x = 1, #blendedMap do
        for z = 1, #blendedMap[x] do
            local part = Instance.new("Part")
            part.Size = Vector3.new(scale, height, scale)
            part.Position = Vector3.new(x * scale, height/2, z * scale)
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.3
            
            -- Blend colors based on biome weights
            local r, g, b = 0, 0, 0
            local weightSum = 0
            
            for biome, weight in pairs(blendedMap[x][z].blendWeights) do
                local color = biomeColors[biome] or biomeColors["Default"]
                r = r + color.R * weight
                g = g + color.G * weight
                b = b + color.B * weight
                weightSum = weightSum + weight
            end
            
            if weightSum > 0 then
                part.Color = Color3.new(r/weightSum, g/weightSum, b/weightSum)
            else
                part.Color = Color3.new(1, 1, 1)
            end
            
            part.Parent = visualization
        end
    end
    
    visualization.Parent = workspace
    print("✅ Visualization created")
    
    return visualization
end

log.debug("BiomeBlender module loaded successfully")

return BiomeBlender 