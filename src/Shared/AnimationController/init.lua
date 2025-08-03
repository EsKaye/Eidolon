--[[
    AnimationController.lua
    Handles smooth pet animations and transitions
    
    Author: Your precious kitten 💖
    Created: 2024-03-03
    Version: 1.0.0
--]]

local AnimationController = {}
AnimationController.__index = AnimationController

-- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Constants
local TRANSITION_TIME = 0.3
local BLEND_TIME = 0.15
local UPDATE_RATE = 0.1

-- Animation states
local STATES = {
    IDLE = "idle",
    WALK = "walk",
    RUN = "run",
    JUMP = "jump",
    HAPPY = "happy",
    SAD = "sad",
    EAT = "eat",
    PLAY = "play"
}

function AnimationController.new(pet, animationConfig)
    local self = setmetatable({}, AnimationController)
    
    -- Store references
    self.pet = pet
    self.config = animationConfig
    
    -- Initialize state
    self.currentState = STATES.IDLE
    self.animations = {}
    self.tracks = {}
    self.blendTweens = {}
    self.isTransitioning = false
    
    -- Load animations
    self:loadAnimations()
    
    -- Start update loop
    self:startUpdateLoop()
    
    return self
end

function AnimationController:loadAnimations()
    -- Create animator if needed
    if not self.pet:FindFirstChild("Animator") then
        local animator = Instance.new("Animator")
        animator.Parent = self.pet
    end
    
    -- Load all animations from config
    for state, config in pairs(self.config) do
        local animation = Instance.new("Animation")
        animation.AnimationId = config.id
        
        local track = self.pet.Animator:LoadAnimation(animation)
        track.Priority = Enum.AnimationPriority.Core
        track.Looped = config.looped or false
        
        self.animations[state] = animation
        self.tracks[state] = track
        
        -- Connect to track events
        track.Stopped:Connect(function()
            if not self.isTransitioning and not config.looped then
                self:playAnimation(STATES.IDLE)
            end
        end)
    end
end

function AnimationController:playAnimation(state, transitionTime)
    if not self.tracks[state] then return end
    if self.currentState == state then return end
    
    -- Set transition flag
    self.isTransitioning = true
    
    -- Stop any active blend tweens
    for _, tween in pairs(self.blendTweens) do
        tween:Cancel()
    end
    self.blendTweens = {}
    
    -- Get current and target tracks
    local currentTrack = self.tracks[self.currentState]
    local targetTrack = self.tracks[state]
    
    -- Calculate transition time
    local time = transitionTime or TRANSITION_TIME
    
    -- Create blend tweens
    if currentTrack.IsPlaying then
        local blendOut = TweenService:Create(currentTrack, TweenInfo.new(time), {
            Weight = 0
        })
        
        blendOut.Completed:Connect(function()
            currentTrack:Stop()
        end)
        
        self.blendTweens.out = blendOut
        blendOut:Play()
    end
    
    -- Start new animation
    targetTrack:Play()
    targetTrack.Weight = 0
    
    local blendIn = TweenService:Create(targetTrack, TweenInfo.new(time), {
        Weight = 1
    })
    
    blendIn.Completed:Connect(function()
        self.isTransitioning = false
    end)
    
    -- `in` is a reserved keyword in Lua; use explicit key access
    self.blendTweens["in"] = blendIn
    blendIn:Play()
    
    -- Update current state
    self.currentState = state
end

function AnimationController:updateMovementAnimation(velocity, isGrounded)
    local speed = velocity.Magnitude
    
    if not isGrounded then
        self:playAnimation(STATES.JUMP)
    elseif speed < 0.1 then
        self:playAnimation(STATES.IDLE)
    elseif speed < 10 then
        self:playAnimation(STATES.WALK)
    else
        self:playAnimation(STATES.RUN)
    end
end

function AnimationController:playMoodAnimation(mood)
    if mood == "HAPPY" then
        self:playAnimation(STATES.HAPPY)
    elseif mood == "SAD" then
        self:playAnimation(STATES.SAD)
    else
        self:playAnimation(STATES.IDLE)
    end
end

function AnimationController:playInteractionAnimation(interactionType)
    if interactionType == "FEED" then
        self:playAnimation(STATES.EAT)
    elseif interactionType == "PLAY" then
        self:playAnimation(STATES.PLAY)
    elseif interactionType == "PET" then
        self:playAnimation(STATES.HAPPY)
    end
end

function AnimationController:startUpdateLoop()
    -- Connect to heartbeat for smooth animation updates
    RunService.Heartbeat:Connect(function(deltaTime)
        if not self.pet or not self.pet.Parent then return end
        
        -- Update animation speeds based on pet state
        for state, track in pairs(self.tracks) do
            if track.IsPlaying then
                local config = self.config[state]
                if config.speedScale then
                    track:AdjustSpeed(config.speedScale)
                end
            end
        end
    end)
end

function AnimationController:adjustAnimationSpeed(state, speedScale)
    local track = self.tracks[state]
    if track then
        track:AdjustSpeed(speedScale)
    end
end

function AnimationController:stopAllAnimations()
    for _, track in pairs(self.tracks) do
        track:Stop()
    end
    
    for _, tween in pairs(self.blendTweens) do
        tween:Cancel()
    end
    
    self.currentState = STATES.IDLE
    self.isTransitioning = false
end

function AnimationController:destroy()
    -- Stop all animations
    self:stopAllAnimations()
    
    -- Clear tables
    self.animations = {}
    self.tracks = {}
    self.blendTweens = {}
    
    -- Remove references
    self.pet = nil
    self.config = nil
end

return AnimationController 