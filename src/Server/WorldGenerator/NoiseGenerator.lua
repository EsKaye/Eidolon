--[[
    WorldGenerator/NoiseGenerator.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles noise generation for terrain
]]

-- Services
local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain

-- Constants
local NOISE_SCALE = 0.01
local NOISE_OCTAVES = 4
local NOISE_PERSISTENCE = 0.5
local NOISE_LACUNARITY = 2
local DEBUG_VISUALIZATION = true
local DEBUG_HEIGHT = 50

-- Cache for noise values
local noiseCache = {}

-- Public functions
local NoiseGenerator = {}

function NoiseGenerator.generateNoise(x, z, scale, octaves, persistence, lacunarity)
    local cacheKey = string.format("%d,%d", x, z)
    if noiseCache[cacheKey] then
        return noiseCache[cacheKey]
    end
    
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0
    
    for i = 1, octaves do
        total = total + math.noise(x * scale * frequency, z * scale * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end
    
    local result = total / maxValue
    noiseCache[cacheKey] = result
    
    -- Debug visualization
    if DEBUG_VISUALIZATION then
        local height = math.floor(result * 10) -- Scale the noise value to a visible height
        Terrain:FillBlock(
            Vector3.new(x, DEBUG_HEIGHT, z),
            Vector3.new(1, height, 1),
            Enum.Material.Neon
        )
    end
    
    return result
end

function NoiseGenerator.clearCache()
    noiseCache = {}
    print("🧹 Cleared noise cache")
end

function NoiseGenerator.generateDebugVisualization(centerX, centerZ, radius)
    print("🎨 Generating noise visualization...")
    local startTime = tick()
    
    for x = centerX - radius, centerX + radius do
        for z = centerZ - radius, centerZ + radius do
            NoiseGenerator.generateNoise(x, z, NOISE_SCALE, NOISE_OCTAVES, NOISE_PERSISTENCE, NOISE_LACUNARITY)
        end
    end
    
    local endTime = tick()
    print(string.format("✅ Noise visualization complete! Time taken: %.2f seconds", endTime - startTime))
end

return NoiseGenerator 