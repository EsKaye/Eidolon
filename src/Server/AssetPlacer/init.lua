--[[
    AssetPlacer/init.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Main orchestrator for asset placement
]]

-- Dependencies
print("📂 Loading AssetPlacer dependencies...")
local success, BiomeHandler = pcall(function()
    local path = script.Parent.Parent.BiomeHandler
    print("  Loading BiomeHandler from:", path:GetFullName())
    return require(path)
end)
if not success then
    warn("⚠️ Failed to load BiomeHandler:", BiomeHandler)
    return nil
end
print("✅ BiomeHandler loaded successfully!")

local AssetManager = require(script.Parent.AssetManager)
local PlacementValidator = require(script.Parent.PlacementValidator)
local BiomeAssetMapper = require(script.Parent.BiomeAssetMapper)
local StructurePlacer = require(script.Parent.StructurePlacer)

-- Verify BiomeHandler is properly initialized
if not BiomeHandler or not BiomeHandler.getBiomeData then
    warn("⚠️ BiomeHandler not properly initialized")
    return nil
end

-- Public functions
local AssetPlacer = {}

function AssetPlacer.placeAssets(centerX, centerZ, radius)
    print("🎨 Starting asset placement...")
    local startTime = tick()
    local biomeData = BiomeHandler.getBiomeData()
    
    -- Create placeholder assets for each biome
    BiomeAssetMapper.createBiomeAssets(biomeData)
    
    -- Place assets in the world
    for biomeName, biome in pairs(biomeData) do
        print("🌿 Placing assets for biome:", biomeName)
        local biomeAssets = BiomeAssetMapper.getBiomeAssets(biomeName, biomeData)
        if not biomeAssets then continue end
        
        -- Place trees
        for _, treeType in ipairs(biomeAssets.trees) do
            local count = math.random(biomeAssets.treeDensity.min, biomeAssets.treeDensity.max)
            for i = 1, count do
                local x, z = PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
                local biomeAtPos = BiomeHandler.getBiomeAtPosition(x, z)
                if biomeAtPos == biomeName then
                    local position = PlacementValidator.findValidSpawnPosition(x, z, biomeName)
                    if position then
                        AssetManager.placeAsset(treeType, position, math.random(0, 360))
                    end
                end
            end
        end
        
        -- Place rocks
        for _, rockType in ipairs(biomeAssets.rocks) do
            local count = math.random(biomeAssets.rockDensity.min, biomeAssets.rockDensity.max)
            for i = 1, count do
                local x, z = PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
                local biomeAtPos = BiomeHandler.getBiomeAtPosition(x, z)
                if biomeAtPos == biomeName then
                    local position = PlacementValidator.findValidSpawnPosition(x, z, biomeName)
                    if position then
                        AssetManager.placeAsset(rockType, position, math.random(0, 360))
                    end
                end
            end
        end
        
        -- Place structures
        for _, structure in ipairs(biomeAssets.structures) do
            local x, z = PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
            local biomeAtPos = BiomeHandler.getBiomeAtPosition(x, z)
            if biomeAtPos == biomeName then
                local position = PlacementValidator.findValidSpawnPosition(x, z, biomeName)
                if position then
                    StructurePlacer.placeStructure(structure.type, position, math.random(0, 360))
                end
            end
        end
        
        -- Place decorations
        for _, decoration in ipairs(biomeAssets.decorations) do
            local count = math.random(biomeAssets.decorationDensity.min, biomeAssets.decorationDensity.max)
            for i = 1, count do
                local x, z = PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
                local biomeAtPos = BiomeHandler.getBiomeAtPosition(x, z)
                if biomeAtPos == biomeName then
                    local position = PlacementValidator.findValidSpawnPosition(x, z, biomeName)
                    if position then
                        AssetManager.placeAsset(decoration, position, math.random(0, 360))
                    end
                end
            end
        end
    end
    
    local endTime = tick()
    print(string.format("✅ Asset placement complete! Time taken: %.2f seconds", endTime - startTime))
end

function AssetPlacer.placeGachaMachines(centerX, centerZ, radius)
    local biomeData = BiomeHandler.getBiomeData()
    StructurePlacer.placeGachaMachines(centerX, centerZ, radius, biomeData)
end

function AssetPlacer.placeEventAreas(centerX, centerZ, radius)
    local biomeData = BiomeHandler.getBiomeData()
    StructurePlacer.placeEventAreas(centerX, centerZ, radius, biomeData)
end

return AssetPlacer 