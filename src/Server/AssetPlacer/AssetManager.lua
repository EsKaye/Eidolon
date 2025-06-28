--[[
    AssetPlacer/AssetManager.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Handles asset creation and caching
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cache for asset models
local assetCache = {}

-- Public functions
local AssetManager = {}

function AssetManager.createPlaceholderAsset(name, type)
    if assetCache[name] then
        return assetCache[name]
    end
    
    local model = Instance.new("Model")
    model.Name = name
    
    local part = Instance.new("Part")
    part.Name = "Main"
    part.Size = Vector3.new(5, 5, 5)
    part.Color = type == "Tree" and Color3.fromRGB(34, 139, 34) or
                 type == "Rock" and Color3.fromRGB(128, 128, 128) or
                 type == "Structure" and Color3.fromRGB(139, 69, 19) or
                 Color3.fromRGB(255, 255, 0)
    part.Material = Enum.Material.Plastic
    part.Anchored = true
    part.CanCollide = true
    part.Parent = model
    
    assetCache[name] = model
    return model
end

function AssetManager.ensureAssetExists(name, type)
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        assetsFolder = Instance.new("Folder")
        assetsFolder.Name = "Assets"
        assetsFolder.Parent = ReplicatedStorage
    end
    
    local typeFolder = assetsFolder:FindFirstChild(type)
    if not typeFolder then
        typeFolder = Instance.new("Folder")
        typeFolder.Name = type
        typeFolder.Parent = assetsFolder
    end
    
    if not typeFolder:FindFirstChild(name) then
        local model = AssetManager.createPlaceholderAsset(name, type)
        model.Parent = typeFolder
        print("✨ Created placeholder asset:", name, "of type:", type)
    end
end

function AssetManager.clearCache()
    assetCache = {}
end

return AssetManager 