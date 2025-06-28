--[[
    WorldGenerator/ChunkManager.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles chunk loading and management
]]

-- Constants
local CHUNK_SIZE = 100

-- Dependencies
local BiomeBlender = require(script.Parent.BiomeBlender)
local TerrainModifier = require(script.Parent.TerrainModifier)

-- Public functions
local ChunkManager = {}

function ChunkManager.new()
    local self = {
        chunks = {},
        generatedChunks = {}
    }
    return setmetatable(self, {__index = ChunkManager})
end

function ChunkManager:generateChunk(chunkX, chunkZ, biomeData)
    local chunkKey = chunkX .. "," .. chunkZ
    if self.generatedChunks[chunkKey] then
        return self.chunks[chunkKey]
    end
    
    local chunk = {}
    
    -- Pre-calculate biome assignments for the chunk
    local biomeAssignments = {}
    for x = 0, CHUNK_SIZE do
        biomeAssignments[x] = {}
        for z = 0, CHUNK_SIZE do
            local worldX = chunkX * CHUNK_SIZE + x
            local worldZ = chunkZ * CHUNK_SIZE + z
            biomeAssignments[x][z] = BiomeBlender.getBiomeAtPosition(worldX, worldZ, biomeData)
        end
    end
    
    -- Generate terrain data
    for x = 0, CHUNK_SIZE do
        chunk[x] = {}
        for z = 0, CHUNK_SIZE do
            local worldX = chunkX * CHUNK_SIZE + x
            local worldZ = chunkZ * CHUNK_SIZE + z
            
            local terrainData = BiomeBlender.getTerrainData(worldX, worldZ, biomeData)
            chunk[x][z] = {
                height = TerrainModifier.clampHeight(terrainData.height),
                texture = terrainData.texture,
                material = terrainData.material
            }
        end
    end
    
    self.chunks[chunkKey] = chunk
    self.generatedChunks[chunkKey] = true
    
    return chunk
end

function ChunkManager:applyChunk(chunkX, chunkZ)
    local chunk = self.chunks[chunkX .. "," .. chunkZ]
    if chunk then
        TerrainModifier.applyChunkToTerrain(chunk, chunkX, chunkZ)
    end
end

function ChunkManager:clearChunks()
    self.chunks = {}
    self.generatedChunks = {}
end

return ChunkManager 