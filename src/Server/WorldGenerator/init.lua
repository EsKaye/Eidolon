--[[
    WorldGenerator/init.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Main orchestrator for world generation
]]

local WorldGenerator = {}
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local BiomeHandler
local ChunkManager

-- Load dependencies
print("🌍 Loading WorldGenerator dependencies...")

local success, result = pcall(function()
    BiomeHandler = require(script.Parent.Parent.BiomeHandler.init)
    return BiomeHandler.init()
end)

if not success or not result then
    warn("❌ Failed to load BiomeHandler:", result)
    return nil
end

print("✅ BiomeHandler loaded successfully")

success, result = pcall(function()
    ChunkManager = require(script.Parent.ChunkManager)
    return ChunkManager.init()
end)

if not success or not result then
    warn("❌ Failed to load ChunkManager:", result)
    return nil
end

print("✅ ChunkManager loaded successfully")

-- Create new WorldGenerator instance
function WorldGenerator.new()
    print("🌍 Creating new WorldGenerator instance...")
    local self = {}
    setmetatable(self, {__index = WorldGenerator})
    
    -- Initialize instance variables
    self.chunks = {}
    self.center = Vector3.new(0, 0, 0)
    self.radius = 500
    
    print("✅ WorldGenerator instance created")
    return self
end

-- Generate world
function WorldGenerator:generateWorld(center, radius)
    print("🌍 Starting world generation...")
    self.center = center or self.center
    self.radius = radius or self.radius
    
    -- Generate chunks
    local chunkSize = 100
    local numChunks = math.ceil(self.radius * 2 / chunkSize)
    
    for x = -numChunks, numChunks do
        for z = -numChunks, numChunks do
            local chunkPos = Vector3.new(
                self.center.X + x * chunkSize,
                self.center.Y,
                self.center.Z + z * chunkSize
            )
            
            -- Get biome for chunk
            local biomeName, biome = BiomeHandler.getBiomeAtPosition(chunkPos.X, chunkPos.Z)
            print("🌿 Generating chunk at", chunkPos, "in biome:", biomeName)
            
            -- Generate chunk
            local success, chunk = pcall(function()
                return ChunkManager.generateChunk(chunkPos, chunkSize, biome)
            end)
            
            if not success then
                warn("❌ Failed to generate chunk at", chunkPos, ":", chunk)
                continue
            end
            
            -- Store chunk
            self.chunks[Vector3.new(x, 0, z)] = chunk
        end
    end
    
    print("✅ World generation complete!")
    return true
end

return WorldGenerator 