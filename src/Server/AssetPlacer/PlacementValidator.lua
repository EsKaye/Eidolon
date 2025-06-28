--[[
    AssetPlacer/PlacementValidator.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles spawn position validation
]]

-- Services
local Workspace = game:GetService("Workspace")
local Terrain = Workspace.Terrain

-- Constants
local SPAWN_CHECK_RADIUS = 5
local MAX_SPAWN_ATTEMPTS = 10
local MAX_SLOPE_ANGLE = math.rad(45)

-- Public functions
local PlacementValidator = {}

function PlacementValidator.findValidSpawnPosition(x, z, biomeName)
    -- Check multiple positions around the target point
    for i = 1, MAX_SPAWN_ATTEMPTS do
        local checkX = x + (math.random() - 0.5) * SPAWN_CHECK_RADIUS
        local checkZ = z + (math.random() - 0.5) * SPAWN_CHECK_RADIUS
        
        -- Get terrain height at this position
        local height = Terrain:GetHeight(Vector3.new(checkX, 0, checkZ))
        
        -- Check if position is valid (not too steep, not underwater, etc.)
        local normal = Terrain:GetNormal(Vector3.new(checkX, height, checkZ))
        local slope = math.acos(normal.Y)
        
        if slope < MAX_SLOPE_ANGLE then -- Less than 45-degree slope
            return Vector3.new(checkX, height, checkZ)
        end
    end
    
    return nil
end

function PlacementValidator.getRandomPositionInRadius(centerX, centerZ, radius)
    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius
    return centerX + math.cos(angle) * distance, centerZ + math.sin(angle) * distance
end

return PlacementValidator 