--[[
    BiomeHandler/init.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Manages biome data and settings for world generation
]]

local BiomeHandler = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local BIOME_CONFIG_PATH = "Config/Biomes"
local DEFAULT_BIOME = "MYSTIC_MEADOWS"

-- Cache for biome data
local biomeData = {}

-- Load biome configuration
local function loadBiomeConfig()
    print("🌍 Loading biome configuration...")
    local success, result = pcall(function()
        return require(ReplicatedStorage:WaitForChild(BIOME_CONFIG_PATH))
    end)
    
    if not success then
        warn("❌ Failed to load biome config:", result)
        return nil
    end
    
    print("✅ Biome configuration loaded successfully")
    return result
end

-- Initialize biome data
function BiomeHandler.init()
    print("🌍 Initializing BiomeHandler...")
    local config = loadBiomeConfig()
    if not config then
        warn("❌ BiomeHandler initialization failed: Could not load config")
        return nil
    end
    
    biomeData = config
    print("✅ BiomeHandler initialized successfully")
    return BiomeHandler
end

-- Get biome info at position
function BiomeHandler.getBiomeAtPosition(x, z)
    for biomeName, biome in pairs(biomeData) do
        local distance = math.sqrt((x - biome.centerX)^2 + (z - biome.centerZ)^2)
        if distance <= biome.radius then
            return biomeName, biome
        end
    end
    return DEFAULT_BIOME, biomeData[DEFAULT_BIOME]
end

-- Apply biome settings to terrain
function BiomeHandler.applyBiomeSettings(position)
    local biomeName, biome = BiomeHandler.getBiomeAtPosition(position.X, position.Z)
    print("🌍 Applying biome settings for:", biomeName)
    
    -- Apply terrain settings
    local terrain = workspace.Terrain
    terrain.Material = biome.terrainMaterial
    terrain.WaterColor = biome.terrainMaterial == Enum.Material.Water and Color3.fromRGB(0, 100, 255) or Color3.fromRGB(0, 0, 0)
    
    -- Apply lighting settings
    local lighting = game:GetService("Lighting")
    lighting.Ambient = biome.lighting.ambient
    lighting.OutdoorAmbient = biome.lighting.outdoorAmbient
    lighting.Brightness = biome.lighting.brightness
    lighting.GlobalShadows = biome.lighting.globalShadows
    
    -- Apply weather settings
    if biome.weather then
        -- Weather system will be implemented later
        print("🌤️ Weather system pending implementation")
    end
    
    return biome
end

-- Get biome data
function BiomeHandler.getBiomeData(biomeName)
    return biomeData[biomeName]
end

-- Get all biome names
function BiomeHandler.getBiomeNames()
    local names = {}
    for name, _ in pairs(biomeData) do
        table.insert(names, name)
    end
    return names
end

return BiomeHandler 