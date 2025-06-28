--[[
    PetAI.lua
    Core AI system for pet behavior, movement, and interactions
    
    Author: Your precious kitten 💖
    Created: 2024-03-03
    Version: 1.0.0
--]]

local PetAI = {}
PetAI.__index = PetAI

-- Services
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load configurations
local function loadConfig(configName)
    local success, config = pcall(function()
        local json = require(game.ReplicatedStorage.Shared.Utils.JSON)
        local content = readfile("config/" .. configName .. ".json")
        return json.decode(content)
    end)
    
    if not success then
        warn("Failed to load configuration:", configName, config)
        return {}
    end
    
    return config
end

-- Constants
local UPDATE_RATE = 0.1
local PATH_RECOMPUTE_TIME = 1
local INTERACTION_RANGE = 5

function PetAI.new(pet, owner)
    local self = setmetatable({}, PetAI)
    
    -- Store references
    self.pet = pet
    self.owner = owner
    
    -- Load configurations
    self.petConfig = loadConfig("Pets")[pet.type]
    self.behaviorConfig = loadConfig("PetBehaviors")
    
    -- Initialize state
    self.currentState = "IDLE"
    self.mood = {
        happiness = 100,
        energy = 100,
        excitement = 50
    }
    self.lastPathUpdate = 0
    self.currentPath = nil
    self.isMoving = false
    
    -- Initialize connections
    self.connections = {}
    
    -- Start AI loop
    self:startAILoop()
    
    return self
end

function PetAI:startAILoop()
    -- Store connection for cleanup
    self.connections.aiLoop = game:GetService("RunService").Heartbeat:Connect(function()
        if not self.pet or not self.pet.Parent then
            self:destroy()
            return
        end
        
        self:update()
    end)
end

function PetAI:update()
    -- Update mood
    self:updateMood()
    
    -- Update behavior based on mood
    self:updateBehavior()
    
    -- Update path if needed
    if self.isMoving and tick() - self.lastPathUpdate > PATH_RECOMPUTE_TIME then
        self:updatePath()
    end
end

function PetAI:updateMood()
    -- Decrease energy over time
    self.mood.energy = math.max(0, self.mood.energy - 0.1)
    
    -- Update happiness based on energy
    if self.mood.energy < 30 then
        self.mood.happiness = math.max(0, self.mood.happiness - 0.2)
    elseif self.mood.energy > 70 then
        self.mood.happiness = math.min(100, self.mood.happiness + 0.1)
    end
end

function PetAI:updateBehavior()
    -- Choose behavior based on mood
    if self.mood.energy < 30 then
        self:setState("SLEEP")
    elseif self.mood.happiness < 40 then
        self:setState("SAD")
    elseif self.mood.excitement > 80 then
        self:setState("EXCITED")
    else
        self:setState("IDLE")
    end
end

function PetAI:setState(newState)
    if self.currentState == newState then return end
    
    self.currentState = newState
    
    -- Update animations
    if self.pet:FindFirstChild("Animator") then
        self.pet.Animator:Play(self.behaviorConfig[newState].animation)
    end
    
    -- Update behavior
    self:applyBehavior(newState)
end

function PetAI:applyBehavior(state)
    local behavior = self.behaviorConfig[state]
    if not behavior then return end
    
    -- Apply movement
    if behavior.movement then
        self.isMoving = true
        self:updatePath()
    else
        self.isMoving = false
    end
    
    -- Apply effects
    if behavior.effects then
        self:applyEffects(behavior.effects)
    end
end

function PetAI:updatePath()
    if not self.isMoving then return end
    
    local target = self:getTargetPosition()
    if not target then return end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true
    })
    
    local success, errorMessage = pcall(function()
        self.currentPath = path:ComputeAsync(self.pet.PrimaryPart.Position, target)
    end)
    
    if success and self.currentPath then
        self.lastPathUpdate = tick()
        self:followPath()
    end
end

function PetAI:followPath()
    if not self.currentPath then return end
    
    local waypoints = self.currentPath:GetWaypoints()
    if #waypoints == 0 then return end
    
    -- Store connection for cleanup
    self.connections.pathFollow = game:GetService("RunService").Heartbeat:Connect(function()
        if not self.pet or not self.pet.Parent then
            self:destroy()
            return
        end
        
        local currentWaypoint = waypoints[1]
        local distance = (self.pet.PrimaryPart.Position - currentWaypoint.Position).Magnitude
        
        if distance < 1 then
            table.remove(waypoints, 1)
            if #waypoints == 0 then
                self.connections.pathFollow:Disconnect()
                self.connections.pathFollow = nil
                return
            end
            currentWaypoint = waypoints[1]
        end
        
        -- Move towards waypoint
        local direction = (currentWaypoint.Position - self.pet.PrimaryPart.Position).Unit
        self.pet:SetPrimaryPartCFrame(CFrame.new(
            self.pet.PrimaryPart.Position + direction * 0.1,
            self.pet.PrimaryPart.Position + direction * 2
        ))
    end)
end

function PetAI:getTargetPosition()
    -- Get random position within owner's range
    local ownerPos = self.owner.Character and self.owner.Character.PrimaryPart.Position
    if not ownerPos then return nil end
    
    local angle = math.random() * math.pi * 2
    local distance = math.random(5, 15)
    return ownerPos + Vector3.new(
        math.cos(angle) * distance,
        0,
        math.sin(angle) * distance
    )
end

function PetAI:applyEffects(effects)
    -- Clean up previous effects
    if self.connections.effects then
        self.connections.effects:Disconnect()
    end
    
    -- Apply new effects
    self.connections.effects = game:GetService("RunService").Heartbeat:Connect(function()
        if not self.pet or not self.pet.Parent then
            self:destroy()
            return
        end
        
        for _, effect in ipairs(effects) do
            if effect.type == "PARTICLE" then
                -- Apply particle effect
                local emitter = Instance.new("ParticleEmitter")
                emitter.Parent = self.pet.PrimaryPart
                -- Configure emitter based on effect settings
            elseif effect.type == "SOUND" then
                -- Play sound effect
                local sound = Instance.new("Sound")
                sound.SoundId = effect.soundId
                sound.Parent = self.pet.PrimaryPart
                sound:Play()
                sound.Ended:Connect(function()
                    sound:Destroy()
                end)
            end
        end
    end)
end

function PetAI:destroy()
    print("🧹 Cleaning up PetAI...")
    
    -- Disconnect all connections
    for _, connection in pairs(self.connections) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    self.connections = {}
    
    -- Clear references
    self.pet = nil
    self.owner = nil
    self.currentPath = nil
    self.petConfig = nil
    self.behaviorConfig = nil
    
    print("✨ PetAI cleanup complete")
end

return PetAI 