--[[
    AssetPlacer/BiomeAssetMapper.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles biome-specific asset mapping
]]

-- Dependencies
local AssetManager = require(script.Parent.AssetManager)

-- Public functions
local BiomeAssetMapper = {}

function BiomeAssetMapper.createBiomeAssets(biomeData)
    for biomeName, biome in pairs(biomeData) do
        print("🌿 Creating assets for biome:", biomeName)
        
        -- Create tree assets
        for _, treeType in ipairs(biome.assets.trees) do
            AssetManager.ensureAssetExists(treeType, "Models")
        end
        
        -- Create rock assets
        for _, rockType in ipairs(biome.assets.rocks) do
            AssetManager.ensureAssetExists(rockType, "Models")
        end
        
        -- Create structure assets
        for _, structure in ipairs(biome.assets.structures) do
            AssetManager.ensureAssetExists(structure.type, "Structures")
        end
        
        -- Create decoration assets
        for _, decoration in ipairs(biome.assets.decorations) do
            AssetManager.ensureAssetExists(decoration, "Models")
        end
    end
end

function BiomeAssetMapper.getBiomeAssets(biomeName, biomeData)
    local biome = biomeData[biomeName]
    if not biome then return nil end
    
    return {
        trees = biome.assets.trees,
        rocks = biome.assets.rocks,
        structures = biome.assets.structures,
        decorations = biome.assets.decorations,
        treeDensity = biome.assets.treeDensity,
        rockDensity = biome.assets.rockDensity,
        decorationDensity = biome.assets.decorationDensity
    }
end

return BiomeAssetMapper 