--[[
    AssetPlacer/StructurePlacer.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles structure placement
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Dependencies
local AssetManager = require(script.Parent.AssetManager)
local PlacementValidator = require(script.Parent.PlacementValidator)

-- Public functions
local StructurePlacer = {}

function StructurePlacer.placeStructure(structureType, position, rotation)
    AssetManager.ensureAssetExists(structureType, "Structures")
    local structure = ReplicatedStorage.Assets.Structures[structureType]:Clone()
    structure:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0))
    structure.Parent = Workspace
    return structure
end

function StructurePlacer.placeGachaMachines(centerX, centerZ, radius, biomeData)
    print("🎮 Starting gacha machine placement...")
    local startTime = tick()
    
    for biomeName, biome in pairs(biomeData) do
        for _, gachaPoint in ipairs(biome.spawnPoints.gacha) do
            local x, z = PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
            local biomeAtPos = BiomeHandler.getBiomeAtPosition(x, z)
            if biomeAtPos == biomeName then
                local position = PlacementValidator.findValidSpawnPosition(x, z, biomeName)
                if position then
                    StructurePlacer.placeStructure("GachaMachine", position, math.random(0, 360))
                end
            end
        end
    end
    
    local endTime = tick()
    print(string.format("✅ Gacha machine placement complete! Time taken: %.2f seconds", endTime - startTime))
end

function StructurePlacer.placeEventAreas(centerX, centerZ, radius, biomeData)
    print("🎪 Starting event area placement...")
    local startTime = tick()
    
    for biomeName, biome in pairs(biomeData) do
        for _, eventPoint in ipairs(biome.spawnPoints.events) do
            local x, z = PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
            local biomeAtPos = BiomeHandler.getBiomeAtPosition(x, z)
            if biomeAtPos == biomeName then
                local position = PlacementValidator.findValidSpawnPosition(x, z, biomeName)
                if position then
                    StructurePlacer.placeStructure("EventArea", position, math.random(0, 360))
                end
            end
        end
    end
    
    local endTime = tick()
    print(string.format("✅ Event area placement complete! Time taken: %.2f seconds", endTime - startTime))
end

return StructurePlacer 