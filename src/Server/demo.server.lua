--[[
    demo.server.lua
    Author: AI Assistant 💖
    Created: 2024-03-12
    Version: 1.0.0
    Purpose: Demonstrates the optimized Petfinity 2.0 World Generation System
]]

-- Import required modules
local Logger = require(script.Parent.Logger)
Logger.setLogLevel(Logger.LogLevel.DEBUG) -- Set to DEBUG level for demo

local log = Logger.forModule("Demo")
log.info("Starting Petfinity 2.0 World Generation Demo")

local PerfMonitor = require(script.Parent.PerfMonitor)
local OptimizedWorldSystem = require(script.Parent.OptimizedWorldSystem)

-- Create a demo UI
local function createDemoUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PetfinityDemo"
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 400)
    frame.Position = UDim2.new(1, -320, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Petfinity 2.0 Demo"
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    local statsContainer = Instance.new("ScrollingFrame")
    statsContainer.Size = UDim2.new(1, -20, 1, -100)
    statsContainer.Position = UDim2.new(0, 10, 0, 50)
    statsContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    statsContainer.BorderSizePixel = 0
    statsContainer.ScrollBarThickness = 6
    statsContainer.CanvasSize = UDim2.new(0, 0, 0, 500)
    statsContainer.Parent = frame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = statsContainer
    
    local generateButton = Instance.new("TextButton")
    generateButton.Size = UDim2.new(0.48, 0, 0, 40)
    generateButton.Position = UDim2.new(0, 10, 1, -45)
    generateButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    generateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    generateButton.Text = "Generate World"
    generateButton.TextSize = 14
    generateButton.Font = Enum.Font.GothamBold
    generateButton.Parent = frame
    
    local benchmarkButton = Instance.new("TextButton")
    benchmarkButton.Size = UDim2.new(0.48, 0, 0, 40)
    benchmarkButton.Position = UDim2.new(0.52, 0, 1, -45)
    benchmarkButton.BackgroundColor3 = Color3.fromRGB(0, 170, 125)
    benchmarkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    benchmarkButton.Text = "Run Benchmarks"
    benchmarkButton.TextSize = 14
    benchmarkButton.Font = Enum.Font.GothamBold
    benchmarkButton.Parent = frame
    
    -- Create UI elements for displaying stats
    local statLabels = {}
    local stats = {
        "World Seed",
        "Active Chunks",
        "Memory Usage",
        "Generation Time",
        "Loading Time",
        "FPS",
        "Cache Hits",
        "Cache Misses",
        "Cache Hit Rate"
    }
    
    for i, stat in ipairs(stats) do
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 30)
        container.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        container.BorderSizePixel = 0
        container.Parent = statsContainer
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.5, -5, 1, 0)
        label.Position = UDim2.new(0, 5, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Text = stat
        label.TextSize = 14
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container
        
        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(0.5, -5, 1, 0)
        value.Position = UDim2.new(0.5, 0, 0, 0)
        value.BackgroundTransparency = 1
        value.TextColor3 = Color3.fromRGB(255, 255, 255)
        value.Text = "-"
        value.TextSize = 14
        value.Font = Enum.Font.GothamBold
        value.TextXAlignment = Enum.TextXAlignment.Right
        value.Parent = container
        
        statLabels[stat] = value
    end
    
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    return {
        gui = screenGui,
        stats = statLabels,
        generateButton = generateButton,
        benchmarkButton = benchmarkButton
    }
end

-- Initialize world system with default settings
local worldSystem = OptimizedWorldSystem.new({
    seed = 12345,
    worldSize = 1024,
    chunkSize = 32,
    renderDistance = 5,
    detailLevel = 3,
    fireflyApiKey = nil -- Add your Firefly API key here if available
})

-- Flag to track if world is generated
local isWorldGenerated = false

-- Function to update UI with current stats
local function updateStats(ui, world)
    local metrics = world:getMetrics()
    local noiseStats = world.noise:getPerfStats()
    
    -- Update UI elements with current stats
    ui.stats["World Seed"].Text = tostring(world.seed)
    ui.stats["Active Chunks"].Text = tostring(metrics.chunkCount)
    ui.stats["Memory Usage"].Text = string.format("%.2f MB", metrics.memoryUsage / 1024)
    ui.stats["Generation Time"].Text = string.format("%.2f ms", metrics.generationTime * 1000)
    ui.stats["Loading Time"].Text = string.format("%.2f ms", metrics.loadingTime * 1000)
    
    -- Calculate FPS from frame times
    local fps = 0
    if metrics.frameTimes and #metrics.frameTimes > 0 then
        local sum = 0
        for _, time in ipairs(metrics.frameTimes) do
            sum = sum + time
        end
        fps = math.floor(1 / (sum / #metrics.frameTimes))
    end
    ui.stats["FPS"].Text = tostring(fps)
    
    -- Update cache stats
    local hits = noiseStats.cacheHits or 0
    local misses = noiseStats.cacheMisses or 0
    local total = hits + misses
    local hitRate = total > 0 and (hits / total * 100) or 0
    
    ui.stats["Cache Hits"].Text = tostring(hits)
    ui.stats["Cache Misses"].Text = tostring(misses)
    ui.stats["Cache Hit Rate"].Text = string.format("%.1f%%", hitRate)
end

-- Create a platform for the player to stand on
local function createPlayerPlatform()
    local platform = Instance.new("Part")
    platform.Size = Vector3.new(16, 1, 16)
    platform.Position = Vector3.new(0, 100, 0)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Material = Enum.Material.Metal
    platform.Color = Color3.fromRGB(200, 200, 200)
    platform.Parent = workspace
    
    -- Spawn the player on the platform
    local players = game:GetService("Players")
    players.CharacterAutoLoads = true
    
    players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            humanoidRootPart.CFrame = CFrame.new(0, 105, 0)
        end)
    end)
    
    for _, player in ipairs(players:GetPlayers()) do
        if player.Character then
            local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                humanoidRootPart.CFrame = CFrame.new(0, 105, 0)
            end
        end
    end
    
    return platform
end

-- Handle world generation around player
local function setupWorldGeneration(world)
    local runService = game:GetService("RunService")
    
    -- Update chunks based on player position
    runService:BindToRenderStep("UpdateWorldChunks", Enum.RenderPriority.Camera.Value + 1, function()
        local players = game:GetService("Players"):GetPlayers()
        for _, player in ipairs(players) do
            if player.Character then
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    world:updateChunksAroundPosition(rootPart.Position)
                end
            end
        end
    end)
end

-- Initialize the demo
local function initDemo()
    log.info("Initializing Petfinity 2.0 demo")
    
    -- Create player platform
    local platform = createPlayerPlatform()
    
    -- Create UI
    local demoUI = createDemoUI()
    
    -- Update stats periodically
    local runService = game:GetService("RunService")
    runService.Heartbeat:Connect(function()
        if isWorldGenerated then
            updateStats(demoUI, worldSystem)
        end
    end)
    
    -- Set up button events
    demoUI.generateButton.MouseButton1Click:Connect(function()
        if not isWorldGenerated then
            log.info("Generating world with seed: %s", worldSystem.seed)
            
            -- Initialize world system
            worldSystem:initialize()
            
            -- Setup world generation around player
            setupWorldGeneration(worldSystem)
            
            isWorldGenerated = true
            demoUI.generateButton.Text = "World Generated"
            demoUI.generateButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end
    end)
    
    demoUI.benchmarkButton.MouseButton1Click:Connect(function()
        log.info("Running benchmarks")
        
        -- Change button state
        demoUI.benchmarkButton.Text = "Running..."
        demoUI.benchmarkButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
        
        -- Run benchmarks on a separate thread
        task.spawn(function()
            -- Initialize if not already done
            if not isWorldGenerated then
                worldSystem:initialize()
                isWorldGenerated = true
                demoUI.generateButton.Text = "World Generated"
                demoUI.generateButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end
            
            -- Run benchmarks
            local results = worldSystem:runBenchmarks()
            
            -- Generate benchmark report UI
            local reportFrame = Instance.new("Frame")
            reportFrame.Size = UDim2.new(0, 400, 0, 300)
            reportFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
            reportFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            reportFrame.BorderSizePixel = 0
            reportFrame.Parent = demoUI.gui
            
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 40)
            title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.Text = "Benchmark Results"
            title.TextSize = 18
            title.Font = Enum.Font.GothamBold
            title.Parent = reportFrame
            
            local closeButton = Instance.new("TextButton")
            closeButton.Size = UDim2.new(0, 30, 0, 30)
            closeButton.Position = UDim2.new(1, -35, 0, 5)
            closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            closeButton.Text = "X"
            closeButton.TextSize = 16
            closeButton.Font = Enum.Font.GothamBold
            closeButton.Parent = reportFrame
            
            closeButton.MouseButton1Click:Connect(function()
                reportFrame:Destroy()
            end)
            
            local resultsContainer = Instance.new("ScrollingFrame")
            resultsContainer.Size = UDim2.new(1, -20, 1, -50)
            resultsContainer.Position = UDim2.new(0, 10, 0, 45)
            resultsContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            resultsContainer.BorderSizePixel = 0
            resultsContainer.ScrollBarThickness = 6
            resultsContainer.CanvasSize = UDim2.new(0, 0, 0, 500)
            resultsContainer.Parent = reportFrame
            
            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 5)
            layout.Parent = resultsContainer
            
            -- Add benchmark results to UI
            local y = 10
            for name, result in pairs(results) do
                local container = Instance.new("Frame")
                container.Size = UDim2.new(1, -10, 0, 80)
                container.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                container.BorderSizePixel = 0
                container.Parent = resultsContainer
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -10, 0, 30)
                nameLabel.Position = UDim2.new(0, 5, 0, 5)
                nameLabel.BackgroundTransparency = 1
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.Text = name
                nameLabel.TextSize = 16
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = container
                
                local avgLabel = Instance.new("TextLabel")
                avgLabel.Size = UDim2.new(0.33, -5, 0, 20)
                avgLabel.Position = UDim2.new(0, 5, 0, 35)
                avgLabel.BackgroundTransparency = 1
                avgLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                avgLabel.Text = string.format("Avg: %.2f ms", result.average * 1000)
                avgLabel.TextSize = 14
                avgLabel.Font = Enum.Font.Gotham
                avgLabel.TextXAlignment = Enum.TextXAlignment.Left
                avgLabel.Parent = container
                
                local minLabel = Instance.new("TextLabel")
                minLabel.Size = UDim2.new(0.33, -5, 0, 20)
                minLabel.Position = UDim2.new(0.33, 5, 0, 35)
                minLabel.BackgroundTransparency = 1
                minLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                minLabel.Text = string.format("Min: %.2f ms", result.min * 1000)
                minLabel.TextSize = 14
                minLabel.Font = Enum.Font.Gotham
                minLabel.TextXAlignment = Enum.TextXAlignment.Left
                minLabel.Parent = container
                
                local maxLabel = Instance.new("TextLabel")
                maxLabel.Size = UDim2.new(0.33, -5, 0, 20)
                maxLabel.Position = UDim2.new(0.66, 5, 0, 35)
                maxLabel.BackgroundTransparency = 1
                maxLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                maxLabel.Text = string.format("Max: %.2f ms", result.max * 1000)
                maxLabel.TextSize = 14
                maxLabel.Font = Enum.Font.Gotham
                maxLabel.TextXAlignment = Enum.TextXAlignment.Left
                maxLabel.Parent = container
                
                local iterLabel = Instance.new("TextLabel")
                iterLabel.Size = UDim2.new(1, -10, 0, 20)
                iterLabel.Position = UDim2.new(0, 5, 0, 55)
                iterLabel.BackgroundTransparency = 1
                iterLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                iterLabel.Text = string.format("Iterations: %d", result.iterations)
                iterLabel.TextSize = 12
                iterLabel.Font = Enum.Font.Gotham
                iterLabel.TextXAlignment = Enum.TextXAlignment.Left
                iterLabel.Parent = container
                
                y = y + 85
            end
            
            resultsContainer.CanvasSize = UDim2.new(0, 0, 0, y)
            
            -- Reset button state
            demoUI.benchmarkButton.Text = "Run Benchmarks"
            demoUI.benchmarkButton.BackgroundColor3 = Color3.fromRGB(0, 170, 125)
        end)
    end)
    
    log.info("Demo initialized successfully")
end

-- Start the demo
initDemo()

log.info("Demo script loaded successfully") 