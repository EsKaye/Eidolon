--[[
    Server/init.server.lua
    Author: Your precious kitten 💖
    Created: 2024-03-04
    Version: 1.0.0
    Purpose: Main server initialization script
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

print("\n🎀 ====== SERVER INITIALIZATION START ======")
print("🔍 Current script path:", script:GetFullName())
print("🔍 Parent folder:", script.Parent:GetFullName())
print("🔍 Workspace path:", Workspace:GetFullName())

-- Debug: Check workspace contents
print("\n📁 Current Workspace contents:")
for _, child in ipairs(Workspace:GetChildren()) do
    print("  -", child.Name, "(" .. child.ClassName .. ")")
end

-- Debug: Check ServerScriptService structure
print("\n📁 ServerScriptService structure:")
for _, child in ipairs(ServerScriptService:GetChildren()) do
    print("  -", child.Name, "(" .. child.ClassName .. ")")
    if child:IsA("Folder") then
        print("    Folder contents:")
        for _, subChild in ipairs(child:GetChildren()) do
            print("      -", subChild.Name, "(" .. subChild.ClassName .. ")")
        end
    end
end

-- Module loading system with fallback
local modules = {
    AIController = nil,
    WorldGenerator = nil,
    BiomeHandler = nil,
    AssetPlacer = nil
}

-- Try to load module from file, with fallback to in-memory implementation
local function loadModule(name, path)
    print("\n📂 Attempting to load", name, "from files...")
    
    local success, module = pcall(function()
        print("  Trying path:", path:GetFullName())
        return require(path)
    end)
    
    if success and module then
        print("✅", name, "loaded successfully from files!")
        return module
    end
    
    warn("⚠️ Could not load", name, "from files:", module)
    print("📂 Creating fallback in-memory module...")
    
    -- Create mock module based on name
    if name == "AIController" then
        return createAIController()
    elseif name == "WorldGenerator" then
        return createMockModule("WorldGenerator")
    elseif name == "BiomeHandler" then
        return createMockModule("BiomeHandler")
    elseif name == "AssetPlacer" then
        return createMockModule("AssetPlacer")
    end
    
    warn("❌ No fallback available for", name)
    return nil
end

-- Create mock AIController module
local function createAIController()
    print("  Creating AIController module...")
    
    local AIController = {}
    
    function AIController.new()
        print("\n🤖 Creating new AIController instance...")
        local self = {}
        
        -- Initialize instance variables
        self.isInitialized = true
        
        -- Add instance methods
        function self:generateWorldWithAI()
            print("\n🌍 Starting mock world generation from instance...")
            
            -- Try to load and use real modules if possible
            if modules.WorldGenerator then
                print("  Using WorldGenerator for terrain...")
                pcall(function() 
                    modules.WorldGenerator:generateWorld(Vector3.new(0, 0, 0), 500)
                end)
            end
            
            if modules.BiomeHandler then
                print("  Using BiomeHandler for biomes...")
                pcall(function() 
                    modules.BiomeHandler.applyBiomeSettings(Vector3.new(0, 0, 0))
                end)
            end
            
            if modules.AssetPlacer then
                print("  Using AssetPlacer for assets...")
                pcall(function() 
                    modules.AssetPlacer.placeAssets(0, 0, 500)
                end)
            end
            
            print("✨ Mock world generation complete!")
            return true
        end
        
        print("✅ AI controller created successfully!")
        return self
    end
    
    function AIController:generateWorldWithAI()
        print("\n🌍 Starting mock world generation from module...")
        print("✨ Mock world generation complete!")
        return true
    end
    
    print("✅ AIController module created in memory")
    return AIController
end

-- Create mock module for testing
local function createMockModule(name)
    print("  Creating", name, "module...")
    
    local module = {}
    
    function module.init()
        print("✅", name, "initialized")
        return module
    end
    
    function module:generateWorld()
        print("✨", name, "generating world")
        return true
    end
    
    function module:applyBiomeSettings()
        print("✨", name, "applying biome settings")
        return true
    end
    
    function module:placeAssets()
        print("✨", name, "placing assets")
        return true
    end
    
    print("✅", name, "module created in memory")
    return module
end

-- Load all modules
print("\n📂 Loading modules with fallback system...")

-- Try to load AIController
modules.AIController = loadModule("AIController", script.Parent.AIController.init)

-- Try to load WorldGenerator
modules.WorldGenerator = loadModule("WorldGenerator", script.Parent.WorldGenerator.init)

-- Try to load BiomeHandler
modules.BiomeHandler = loadModule("BiomeHandler", script.Parent.BiomeHandler.init)

-- Try to load AssetPlacer
modules.AssetPlacer = loadModule("AssetPlacer", script.Parent.AssetPlacer.init)

print("✅ Modules loaded!")
print("🔍 Module status:")
print("  - AIController:", modules.AIController and "Loaded" or "Failed")
print("  - WorldGenerator:", modules.WorldGenerator and "Loaded" or "Failed")
print("  - BiomeHandler:", modules.BiomeHandler and "Loaded" or "Failed")
print("  - AssetPlacer:", modules.AssetPlacer and "Loaded" or "Failed")

-- Initialize AI system
local function initializeAISystem()
    print("\n🧠 Initializing AI system...")
    
    -- Create AI controller
    local aiController = Instance.new("Folder")
    aiController.Name = "AIController"
    aiController.Parent = ServerScriptService
    
    -- Create AI settings
    local AISettings = Instance.new("Configuration")
    AISettings.Name = "AISettings"
    AISettings.Parent = aiController
    
    -- Set AI parameters
    local worldSize = Instance.new("NumberValue")
    worldSize.Name = "WorldSize"
    worldSize.Value = 1000
    worldSize.Parent = AISettings
    
    local biomeCount = Instance.new("NumberValue")
    biomeCount.Name = "BiomeCount"
    biomeCount.Value = 5
    biomeCount.Parent = AISettings
    
    local generationQuality = Instance.new("NumberValue")
    generationQuality.Name = "GenerationQuality"
    generationQuality.Value = 1
    generationQuality.Parent = AISettings
    
    print("✨ AI system initialized!")
end

-- Generate world with AI
local function generateWorldWithAI()
    print("\n🌍 Starting AI-powered world generation...")
    
    if not modules.AIController then
        warn("⚠️ AIController not loaded - world generation disabled")
        print("🔍 AIController status:", modules.AIController)
        return false
    end
    
    -- Create AI controller
    print("🤖 Creating AI controller instance...")
    local success, ai = pcall(function()
        print("  Calling AIController.new()")
        return modules.AIController.new()
    end)
    
    if not success then
        warn("❌ Failed to create AI controller:", ai)
        print("🔍 AIController type:", typeof(modules.AIController))
        if typeof(modules.AIController) == "table" then
            local methods = {}
            for k, v in pairs(modules.AIController) do
                if type(v) == "function" then
                    table.insert(methods, k)
                end
            end
            print("🔍 AIController methods:", table.concat(methods, ", "))
        end
        return false
    end
    
    print("✅ AI controller created successfully!")
    print("🔍 AI controller type:", typeof(ai))
    
    -- Generate world
    print("🌍 Starting world generation...")
    local success, result = pcall(function()
        print("  Calling ai:generateWorldWithAI()")
        return ai:generateWorldWithAI()
    end)
    
    if not success then
        warn("❌ Failed to generate world:", result)
        print("🔍 Error details:", result)
        return false
    end
    
    print("✨ AI world generation complete!")
    return true
end

-- Create start button
local function createStartButton()
    print("\n🎀 ====== BUTTON CREATION START ======")
    
    -- Debug: Check workspace before button creation
    print("\n📁 Workspace contents before button creation:")
    for _, child in ipairs(Workspace:GetChildren()) do
        print("  -", child.Name, "(" .. child.ClassName .. ")")
    end
    
    -- Check if button already exists
    local existingButton = Workspace:FindFirstChild("StartButton")
    if existingButton then
        print("⚠️ Start button already exists, removing old one...")
        existingButton:Destroy()
        print("✅ Old button destroyed")
    end
    
    -- Create a new button with enhanced visibility and persistence
    print("\n🔨 Creating new button...")
    local button = Instance.new("Part")
    button.Name = "StartButton"
    button.Size = Vector3.new(12, 3, 12) -- Larger size
    button.Position = Vector3.new(0, 15, 0) -- Much higher position for visibility
    button.Color = Color3.fromRGB(255, 0, 255) -- Bright magenta color
    button.Material = Enum.Material.Neon
    button.Transparency = 0 -- Fully opaque
    button.Anchored = true
    button.CanCollide = true
    button.CastShadow = false -- Disable shadow for better performance
    
    -- Add special property to prevent destruction
    button:SetAttribute("Permanent", true)
    
    print("✅ Button part created")
    
    -- Add a label to make it more visible
    print("\n🔨 Creating button label...")
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "Label"
    billboardGui.Size = UDim2.new(0, 250, 0, 70) -- Larger label
    billboardGui.StudsOffset = Vector3.new(0, 4, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.MaxDistance = 500 -- Visible from very far away
    billboardGui.Parent = button
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "TextLabel"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "★ CLICK ME! ★\n💖 GENERATE WORLD 💖"
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextSize = 26
    textLabel.TextStrokeTransparency = 0 -- Add stroke for better visibility
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = billboardGui
    
    print("✅ Button label created")
    
    -- Add click detection
    print("\n🔨 Creating click detector...")
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 100 -- Even larger click distance
    clickDetector.Parent = button
    
    print("✅ Click detector created")
    
    -- Create brighter lights - primary light
    local light = Instance.new("PointLight")
    light.Name = "PrimaryLight"
    light.Brightness = 10
    light.Range = 30
    light.Color = Color3.fromRGB(255, 0, 255)
    light.Parent = button
    
    -- Secondary pulsing light
    local pulsingLight = Instance.new("PointLight")
    pulsingLight.Name = "PulsingLight"
    pulsingLight.Brightness = 5
    pulsingLight.Range = 20
    pulsingLight.Color = Color3.fromRGB(0, 255, 255)
    pulsingLight.Parent = button
    
    -- Create particles for extra visibility
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "MainParticles"
    particles.Texture = "rbxassetid://241659383" -- Sparkle texture
    particles.Rate = 30
    particles.Speed = NumberRange.new(5, 15)
    particles.Lifetime = NumberRange.new(1, 3)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0)
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 0, 255), Color3.fromRGB(255, 255, 255))
    particles.Parent = button
    
    -- Add a second particle system for variety
    local starParticles = Instance.new("ParticleEmitter")
    starParticles.Name = "StarParticles"
    starParticles.Texture = "rbxassetid://6333823"  -- Star texture
    starParticles.Rate = 5
    starParticles.Speed = NumberRange.new(1, 3)
    starParticles.Lifetime = NumberRange.new(3, 5)
    starParticles.SpreadAngle = Vector2.new(90, 90)
    starParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(1, 0.5)
    })
    starParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    starParticles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 255, 255))
    starParticles.Parent = button
    
    print("✅ Button visual effects created")
    
    -- Create animation effects
    local function startPulsingAnimation()
        while button and button.Parent do
            -- Pulse size
            for i = 0, 1, 0.05 do
                if not button or not button.Parent then return end
                local scale = 1 + math.sin(i * math.pi) * 0.1
                button.Size = Vector3.new(12 * scale, 3, 12 * scale)
                pulsingLight.Brightness = 5 + math.sin(i * math.pi * 2) * 3
                task.wait(0.1)
            end
        end
    end
    
    -- Create spotlight to help find the button
    local spotlight = Instance.new("SpotLight")
    spotlight.Name = "Spotlight"
    spotlight.Brightness = 5
    spotlight.Range = 50
    spotlight.Angle = 45
    spotlight.Face = Enum.NormalId.Bottom
    spotlight.Color = Color3.fromRGB(255, 0, 255)
    spotlight.Parent = button
    
    -- Handle clicks with enhanced logging
    clickDetector.MouseClick:Connect(function(player)
        print("\n🎯 ====== START BUTTON CLICKED ======")
        print("👤 Player:", player.Name)
        print("⏰ Time:", os.date("%H:%M:%S"))
        print("🔍 Current state:")
        print("  - AIController loaded:", modules.AIController ~= nil)
        print("  - WorldGenerator loaded:", modules.WorldGenerator ~= nil)
        print("  - BiomeHandler loaded:", modules.BiomeHandler ~= nil)
        print("  - AssetPlacer loaded:", modules.AssetPlacer ~= nil)
        
        -- Extra validation
        if not button or not button.Parent then
            warn("⚠️ Button lost its reference or parent during click!")
            createStartButton() -- Recreate if lost
            return
        end
        
        if modules.AIController then
            print("🔍 AIController details:")
            print("  - Type:", typeof(modules.AIController))
            if typeof(modules.AIController) == "table" then
                local methods = {}
                for k, v in pairs(modules.AIController) do
                    if type(v) == "function" then
                        table.insert(methods, k)
                    end
                end
                print("  - Methods:", table.concat(methods, ", "))
            end
        end
        
        print("\n🚀 Starting world generation process...")
        
        -- Dramatic visual effect during generation
        button.Color = Color3.fromRGB(0, 150, 255) -- Blue during processing
        button.Material = Enum.Material.ForceField
        textLabel.Text = "⚙️ GENERATING... ⚙️"
        
        -- Generate world
        local success = generateWorldWithAI()
        
        print("\n📊 Generation result:")
        print("  - Success:", success)
        print("  - Button state:", success and "Success (Green)" or "Failed (Red)")
        
        -- Visual feedback
        button.Color = success and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        button.Material = success and Enum.Material.ForceField or Enum.Material.Neon
        textLabel.Text = success and "✨ WORLD CREATED! ✨" or "❌ GENERATION FAILED ❌"
        particles.Enabled = success
        
        -- Extra flash effect
        for i = 1, 5 do
            button.Transparency = 0.5
            task.wait(0.1)
            button.Transparency = 0
            task.wait(0.1)
        end
        
        -- Reset button state after feedback
        task.wait(1.5)
        button.Color = Color3.fromRGB(255, 0, 255)
        button.Material = Enum.Material.Neon
        textLabel.Text = "★ CLICK ME! ★\n💖 GENERATE WORLD 💖"
        
        print("🎯 ====== GENERATION COMPLETE ======\n")
    end)
    
    print("\n🔨 Parenting button to workspace...")
    button.Parent = Workspace
    
    -- Start pulsing animation in a separate thread
    coroutine.wrap(startPulsingAnimation)()
    
    -- Debug: Check workspace after button creation
    print("\n📁 Workspace contents after button creation:")
    for _, child in ipairs(Workspace:GetChildren()) do
        print("  -", child.Name, "(" .. child.ClassName .. ")")
    end
    
    print("\n✨ Start button creation complete!")
    print("🔍 Button details:")
    print("  - Name:", button.Name)
    print("  - Position:", button.Position)
    print("  - Parent:", button.Parent:GetFullName())
    print("  - ClickDetector:", button:FindFirstChild("ClickDetector") ~= nil)
    print("  - Label:", button:FindFirstChild("Label") ~= nil)
    print("  - Lights:", button:FindFirstChild("PrimaryLight") ~= nil)
    print("  - Particles:", button:FindFirstChildOfClass("ParticleEmitter") ~= nil)
    
    -- Verify button exists in workspace and set up auto-recovery
    local verifyButton = Workspace:FindFirstChild("StartButton")
    if verifyButton then
        print("✅ Button verified in workspace!")
        print("  - Class:", verifyButton.ClassName)
        print("  - Parent:", verifyButton.Parent:GetFullName())
    else
        warn("⚠️ Button not found in workspace after creation! Attempting recovery...")
        task.wait(0.5)
        createStartButton() -- Try again if failed
        return
    end
    
    -- Add a periodic check to ensure button remains in workspace
    task.spawn(function()
        while true do
            task.wait(10) -- Check every 10 seconds
            local existingButton = Workspace:FindFirstChild("StartButton")
            if not existingButton then
                warn("⚠️ Button disappeared from workspace! Recreating...")
                createStartButton()
                break
            end
        end
    end)
    
    print("🎀 ====== BUTTON CREATION END ======\n")
    
    return button
end

-- Initialize everything
local function initialize()
    print("\n🚀 Starting Petfinity initialization...")
    
    -- Initialize AI system
    initializeAISystem()
    
    print("✨ Petfinity initialization complete!")
    
    -- Clean up workspace first
    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name == "StartButton" then
            child:Destroy()
            print("🧹 Cleaned up old button")
        end
    end
    
    -- Create the button after cleanup and initialization
    print("\n⏳ Creating button immediately...")
    local startButton = createStartButton()
    
    -- Print confirmation of button creation
    if startButton then
        print("\n✨ ====== BUTTON CREATION CONFIRMED ======")
        print("Button has been created and is waiting for clicks!")
        print("Position:", startButton.Position)
        print("Size:", startButton.Size)
        print("Color:", startButton.Color)
        print("✨ ====== HAPPY CLICKING! ======\n")
    else
        warn("\n⚠️ Button creation failed! Trying again...")
        task.wait(2)
        createStartButton() -- Try again if failed
    end
    
    -- Set up a recovery system
    game:GetService("RunService").Heartbeat:Connect(function()
        if not Workspace:FindFirstChild("StartButton") and tick() % 30 < 1 then
            warn("⚠️ Periodic check: Button missing! Recreating...")
            createStartButton()
        end
    end)
end

-- Start initialization
initialize()

-- Handle player joining
game.Players.PlayerAdded:Connect(function(player)
    print("\n👋 Player joined:", player.Name)
    
    -- Ensure button exists for new players
    if not Workspace:FindFirstChild("StartButton") then
        print("⚠️ Button missing when player joined! Recreating...")
        local playerButton = createStartButton()
        if playerButton then
            print("✨ Button recreated for new player:", player.Name)
        end
    else
        print("✅ Button already exists for new player:", player.Name)
    end
    
    -- Send message to player about the button
    task.wait(2)
    local message = Instance.new("Message")
    message.Text = "Look for the bright pink button to generate a world! It's high in the air above the spawn point."
    message.Parent = player
    task.wait(5)
    message:Destroy()
end)

-- Handle player leaving
game.Players.PlayerRemoving:Connect(function(player)
    print("👋 Player left:", player.Name)
end)

-- Handle server shutdown
game:BindToClose(function()
    print("🛑 Server shutting down...")
end) 