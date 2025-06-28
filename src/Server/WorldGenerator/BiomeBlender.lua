--[[
    WorldGenerator/BiomeBlender.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles biome blending and transitions
]]

-- Constants
local BIOME_BLEND_DISTANCE = 20

-- Dependencies
local NoiseGenerator = require(script.Parent.NoiseGenerator)

-- Public functions
local BiomeBlender = {}

function BiomeBlender.getBiomeAtPosition(x, z, biomeData)
    local closestBiome = nil
    local minDistance = math.huge
    
    for biomeName, biome in pairs(biomeData) do
        local distance = (Vector2.new(x, z) - Vector2.new(biome.centerX, biome.centerZ)).Magnitude
        if distance < minDistance then
            minDistance = distance
            closestBiome = biomeName
        end
    end
    
    return closestBiome
end

function BiomeBlender.blendBiomes(x, z, biome1, biome2, biomeData)
    local blendFactor = math.clamp(
        (Vector2.new(x, z) - Vector2.new(biomeData[biome1].centerX, biomeData[biome1].centerZ)).Magnitude / BIOME_BLEND_DISTANCE,
        0,
        1
    )
    
    local biome1Data = biomeData[biome1]
    local biome2Data = biomeData[biome2]
    
    return {
        height = biome1Data.baseHeight * (1 - blendFactor) + biome2Data.baseHeight * blendFactor,
        texture = blendFactor < 0.5 and biome1Data.terrainTexture or biome2Data.terrainTexture,
        material = blendFactor < 0.5 and biome1Data.terrainMaterial or biome2Data.terrainMaterial
    }
end

function BiomeBlender.getTerrainData(x, z, biomeData)
    local biome1 = BiomeBlender.getBiomeAtPosition(x, z, biomeData)
    local biome2 = BiomeBlender.getBiomeAtPosition(x + 1, z + 1, biomeData)
    
    if biome1 == biome2 then
        local biome = biomeData[biome1]
        return {
            height = biome.baseHeight + NoiseGenerator.generateNoise(x, z) * biome.heightVariation,
            texture = biome.terrainTexture,
            material = biome.terrainMaterial
        }
    else
        return BiomeBlender.blendBiomes(x, z, biome1, biome2, biomeData)
    end
end

return BiomeBlender 