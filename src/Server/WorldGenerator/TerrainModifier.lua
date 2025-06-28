--[[
    WorldGenerator/TerrainModifier.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles terrain modifications
]]

-- Services
local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain

-- Constants
local CHUNK_SIZE = 100
local MAX_HEIGHT = 100
local MIN_HEIGHT = 0

-- Public functions
local TerrainModifier = {}

function TerrainModifier.applyChunkToTerrain(chunk, chunkX, chunkZ)
    if not chunk then return end
    
    -- Batch terrain modifications
    local modifications = {}
    
    for x = 0, CHUNK_SIZE do
        for z = 0, CHUNK_SIZE do
            local worldX = chunkX * CHUNK_SIZE + x
            local worldZ = chunkZ * CHUNK_SIZE + z
            local data = chunk[x][z]
            
            table.insert(modifications, {
                position = CFrame.new(worldX, data.height/2, worldZ),
                size = Vector3.new(1, math.max(1, data.height), 1),
                material = data.material
            })
            
            table.insert(modifications, {
                position = CFrame.new(worldX, data.height, worldZ),
                size = Vector3.new(1, 1, 1),
                material = data.texture
            })
        end
    end
    
    -- Apply modifications in batches
    for _, mod in ipairs(modifications) do
        Terrain:FillBlock(mod.position, mod.size, mod.material)
    end
end

function TerrainModifier.clampHeight(height)
    return math.clamp(height, MIN_HEIGHT, MAX_HEIGHT)
end

return TerrainModifier 