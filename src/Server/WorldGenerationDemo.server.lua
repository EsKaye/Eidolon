--[[
    WorldGenerationDemo.server.lua
    Author: Your precious kitten 💖
    Created: 2024-03-11
    Version: 1.0.0
    Purpose: Demonstrates how to use the AI-driven world generation system
]]

print("\n🎮 ====== WORLD GENERATION DEMO ======")

-- Wait for game to fully load
local startTime = os.time()
print("⏱️ Waiting for game to fully load...")
wait(1)

-- Load AIController module
print("📦 Loading AIController module...")
local AIController = require(script.Parent.AIController)

if not AIController then
    warn("⚠️ Failed to load AIController module")
    return
end

print("✅ AIController module loaded successfully")

-- Create button for world generation
local function createWorldGenerationButton()
    print("🔘 Creating world generation demo button...")
    local button = Instance.new("Part")
    button.Name = "GenerateWorldButton"
    button.Size = Vector3.new(12, 3, 12)
    button.Position = Vector3.new(0, 15, 0)
    button.Anchored = true
    button.CanCollide = true
    button.Material = Enum.Material.Neon
    button.Color = Color3.fromRGB(0, 170, 255)
    button.Parent = workspace
    
    -- Add special property to prevent destruction
    button:SetAttribute("Permanent", true)
    
    -- Add text label
    local label = Instance.new("BillboardGui")
    label.Name = "ButtonLabel"
    label.Size = UDim2.new(0, 200, 0, 50)
    label.StudsOffset = Vector3.new(0, 2, 0)
    label.Adornee = button
    label.Parent = button
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Text = "GENERATE WORLD"
    textLabel.Parent = label
    
    -- Add click detector
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.Name = "ClickDetector"
    clickDetector.MaxActivationDistance = 100
    clickDetector.Parent = button
    
    -- Glowing effect
    local light = Instance.new("PointLight")
    light.Name = "ButtonLight"
    light.Brightness = 5
    light.Color = Color3.fromRGB(0, 170, 255)
    light.Range = 20
    light.Parent = button
    
    -- Sparkles effect
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = "Sparkles"
    sparkles.Texture = "rbxassetid://284205403"
    sparkles.Rate = 20
    sparkles.Speed = NumberRange.new(1, 3)
    sparkles.Lifetime = NumberRange.new(1, 2)
    sparkles.SpreadAngle = Vector2.new(180, 180)
    sparkles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 0)
    })
    sparkles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    sparkles.Parent = button
    
    -- Pulsing animation
    spawn(function()
        while button and button.Parent do
            for i = 0, 1, 0.05 do
                if not button or not button.Parent then break end
                button.Transparency = 0.2 + (i * 0.2)
                light.Brightness = 5 - (i * 2)
                wait(0.05)
            end
            for i = 1, 0, -0.05 do
                if not button or not button.Parent then break end
                button.Transparency = 0.2 + (i * 0.2)
                light.Brightness = 5 - (i * 2)
                wait(0.05)
            end
        end
    end)
    
    -- Create a spotlight
    local spotlight = Instance.new("SpotLight")
    spotlight.Name = "Spotlight"
    spotlight.Brightness = 5
    spotlight.Angle = 30
    spotlight.Range = 20
    spotlight.Face = Enum.NormalId.Bottom
    spotlight.Color = Color3.fromRGB(255, 255, 255)
    spotlight.Parent = button
    
    print("✅ World generation demo button created")
    return button, clickDetector
end

-- Create world generation demo
local function setupWorldGenerationDemo()
    print("\n🚀 Setting up world generation demo...")
    
    -- Create demonstration button
    local button, clickDetector = createWorldGenerationButton()
    
    -- Set up button click handler
    clickDetector.MouseClick:Connect(function(player)
        print("\n👆 Button clicked by player:", player.Name)
        
        -- Update button appearance
        button.Color = Color3.fromRGB(0, 100, 255)
        button.Material = Enum.Material.Neon
        button:FindFirstChild("ButtonLabel").Text.Text = "GENERATING..."
        
        -- Generate a custom world
        if AIController then
            print("🌎 Generating custom world...")
            
            -- Example of custom world parameters
            local worldParams = {
                worldSize = 256,
                chunkSize = 16,
                seed = math.random(1, 999999),
                biomeCount = 6,
                structureDensity = 0.05
            }
            
            -- Log the parameters being used
            for param, value in pairs(worldParams) do
                print("  - " .. param .. ": " .. tostring(value))
            end
            
            -- Start world generation
            local success = AIController:generateWorld(worldParams)
            
            if success then
                print("✅ World generation successful!")
                button.Color = Color3.fromRGB(0, 255, 100)
                button:FindFirstChild("ButtonLabel").Text.Text = "WORLD CREATED!"
                
                -- Change back after 5 seconds
                spawn(function()
                    wait(5)
                    if button and button.Parent then
                        button.Color = Color3.fromRGB(0, 170, 255)
                        button:FindFirstChild("ButtonLabel").Text.Text = "GENERATE WORLD"
                    end
                end)
            else
                print("❌ World generation failed")
                button.Color = Color3.fromRGB(255, 0, 0)
                button:FindFirstChild("ButtonLabel").Text.Text = "GENERATION FAILED"
                
                -- Change back after 5 seconds
                spawn(function()
                    wait(5)
                    if button and button.Parent then
                        button.Color = Color3.fromRGB(0, 170, 255)
                        button:FindFirstChild("ButtonLabel").Text.Text = "GENERATE WORLD"
                    end
                end)
            end
        else
            print("❌ AIController not available")
            button.Color = Color3.fromRGB(255, 0, 0)
            button:FindFirstChild("ButtonLabel").Text.Text = "ERROR: CONTROLLER NOT FOUND"
        end
    end)
    
    -- Set up automatic demo message for players
    local Players = game:GetService("Players")
    
    -- Welcome existing players
    for _, player in ipairs(Players:GetPlayers()) do
        print("👋 Welcoming existing player:", player.Name)
        -- Send message to player
        spawn(function()
            wait(2)
            game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
                "Welcome to the World Generation Demo! Click the floating button to generate a world.", "All"
            )
        end)
    end
    
    -- Welcome new players
    Players.PlayerAdded:Connect(function(player)
        print("👋 New player joined:", player.Name)
        -- Send message to player
        spawn(function()
            wait(2)
            game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(
                "Welcome " .. player.Name .. " to the World Generation Demo! Click the floating button to generate a world.", "All"
            )
        end)
    end)
    
    print("✅ World generation demo setup complete")
    return button
end

-- Run the demo setup
local demoButton = setupWorldGenerationDemo()

-- Set up button recovery system (in case it gets deleted)
spawn(function()
    while wait(10) do
        if not demoButton or not demoButton.Parent then
            print("🔄 Button not found, recreating...")
            demoButton = createWorldGenerationButton()
        end
    end
end)

-- Log total setup time
local endTime = os.time()
print("⏱️ Total setup time: " .. (endTime - startTime) .. " seconds")
print("🎮 ====== WORLD GENERATION DEMO READY ======\n") 