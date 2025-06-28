--[[
    Config/Biomes.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Biome configuration data
]]

return {
    MYSTIC_MEADOWS = {
        centerX = 0,
        centerZ = 0,
        radius = 500,
        baseHeight = 10,
        heightVariation = 20,
        terrainTexture = Enum.Material.Grass,
        terrainMaterial = Enum.Material.Grass,
        weather = {
            type = "Clear",
            intensity = 1,
            frequency = 0.5
        },
        lighting = {
            ambient = Color3.fromRGB(200, 200, 200),
            outdoorAmbient = Color3.fromRGB(200, 200, 200),
            brightness = 1,
            globalShadows = true
        },
        assets = {
            trees = {
                density = {min = 0.1, max = 0.3},
                models = {"rbxassetid://1234567"} -- Placeholder ID
            },
            rocks = {
                density = {min = 0.05, max = 0.15},
                models = {"rbxassetid://1234568"} -- Placeholder ID
            },
            decorations = {
                density = {min = 0.2, max = 0.4},
                models = {"rbxassetid://1234569"} -- Placeholder ID
            }
        },
        ambientSounds = {},
        spawnPoints = {}
    },
    
    CRYSTAL_CAVERNS = {
        centerX = 1000,
        centerZ = 1000,
        radius = 400,
        baseHeight = 5,
        heightVariation = 15,
        terrainTexture = Enum.Material.Slate,
        terrainMaterial = Enum.Material.Slate,
        weather = {
            type = "Clear",
            intensity = 1,
            frequency = 0.5
        },
        lighting = {
            ambient = Color3.fromRGB(150, 150, 200),
            outdoorAmbient = Color3.fromRGB(150, 150, 200),
            brightness = 0.8,
            globalShadows = true
        },
        assets = {
            trees = {
                density = {min = 0.05, max = 0.15},
                models = {"rbxassetid://1234570"} -- Placeholder ID
            },
            rocks = {
                density = {min = 0.2, max = 0.4},
                models = {"rbxassetid://1234571"} -- Placeholder ID
            },
            decorations = {
                density = {min = 0.1, max = 0.2},
                models = {"rbxassetid://1234572"} -- Placeholder ID
            }
        },
        ambientSounds = {},
        spawnPoints = {}
    }
} 