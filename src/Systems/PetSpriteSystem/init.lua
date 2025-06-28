--[[
    PetSpriteSystem.lua
    Handles 2D sprite-based pet animations and state management
    
    Author: Your precious kitten 💖
    Created: 2024-03-03
    Version: 1.0.0
--]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import required systems
local EffectsSystem = require(game.ReplicatedStorage.Systems.EffectsSystem)

local PetSpriteSystem = {}
PetSpriteSystem.__index = PetSpriteSystem

-- Animation configuration
local ANIMATION_CONFIG = {
    IDLE = {
        FRAMES = 4,
        DURATION = 1.2,
        BOUNCE_HEIGHT = 10,
        BLINK_INTERVAL = {MIN = 2, MAX = 4}
    },
    EXCITED = {
        FRAMES = 6,
        DURATION = 0.8,
        JUMP_HEIGHT = 20,
        SPIN_DURATION = 0.4
    },
    HATCHING = {
        FRAMES = 8,
        DURATION = 2,
        CRACK_FRAMES = 3,
        EMERGE_FRAMES = 5
    },
    HAPPY = {
        BOUNCE_SCALE = 1.1,
        SPARKLE_RATE = 2,
        GLOW_INTENSITY = 0.3
    },
    TIRED = {
        SWAY_ANGLE = 5,
        SWAY_DURATION = 2,
        BLINK_DURATION = 0.5
    }
}

-- Tween configuration
local TWEEN_CONFIG = {
    BOUNCE = {
        TIME = 0.6,
        STYLE = Enum.EasingStyle.Sine,
        DIRECTION = Enum.EasingDirection.InOut
    },
    SPIN = {
        TIME = 0.4,
        STYLE = Enum.EasingStyle.Quad,
        DIRECTION = Enum.EasingDirection.Out
    },
    STATE_TRANSITION = {
        TIME = 0.3,
        STYLE = Enum.EasingStyle.Quad,
        DIRECTION = Enum.EasingDirection.Out
    }
}

-- Sprite sheet configuration
local SPRITE_CONFIG = {
    DEFAULT_SIZE = UDim2.new(0, 150, 0, 150),
    SCALE_RANGE = {MIN = 0.8, MAX = 1.2},
    RENDER_PRIORITY = 2
}

function PetSpriteSystem.new(parent, petData)
    local self = setmetatable({}, PetSpriteSystem)
    
    -- Store references
    self.parent = parent
    self.petData = petData
    self.effectsSystem = EffectsSystem.new()
    
    -- Initialize state
    self.currentState = "IDLE"
    self.isAnimating = false
    self.currentFrame = 1
    
    -- Create UI components
    self:createSprite()
    
    -- Start idle animation
    self:playAnimation("IDLE")
    
    return self
end

function PetSpriteSystem:createSprite()
    -- Create container frame
    self.container = Instance.new("Frame")
    self.container.Name = "PetContainer"
    self.container.Size = SPRITE_CONFIG.DEFAULT_SIZE
    self.container.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.container.AnchorPoint = Vector2.new(0.5, 0.5)
    self.container.BackgroundTransparency = 1
    self.container.Parent = self.parent
    
    -- Create sprite image
    self.sprite = Instance.new("ImageLabel")
    self.sprite.Name = "PetSprite"
    self.sprite.Size = UDim2.new(1, 0, 1, 0)
    self.sprite.BackgroundTransparency = 1
    self.sprite.Image = self.petData.spriteSheet
    self.sprite.ImageRectSize = self.petData.frameSize
    self.sprite.ImageRectOffset = Vector2.new(0, 0)
    self.sprite.Parent = self.container
    
    -- Add UI constraints for proper scaling
    local aspect = Instance.new("UIAspectRatioConstraint")
    aspect.Parent = self.container
    
    -- Add UI scale for animations
    self.uiScale = Instance.new("UIScale")
    self.uiScale.Scale = 1
    self.uiScale.Parent = self.container
end

function PetSpriteSystem:playAnimation(animationType)
    if self.isAnimating and animationType ~= "IDLE" then return end
    
    self.isAnimating = true
    self.currentState = animationType
    
    local config = ANIMATION_CONFIG[animationType]
    local frameCount = config.FRAMES
    local duration = config.DURATION
    local frameTime = duration / frameCount
    
    -- Store previous connection
    if self.animationConnection then
        self.animationConnection:Disconnect()
    end
    
    -- Animation loop using RunService
    local startTime = tick()
    local currentFrame = 1
    
    self.animationConnection = game:GetService("RunService").Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        currentFrame = math.floor(elapsed / frameTime) % frameCount + 1
        
        -- Update sprite frame
        self.sprite.ImageRectOffset = Vector2.new(
            (currentFrame - 1) * self.petData.frameSize.X,
            0
        )
        
        -- Add special effects based on state
        if animationType == "HAPPY" then
            self:addHappyEffects()
        elseif animationType == "EXCITED" then
            self:addExcitedEffects(currentFrame)
        end
        
        -- Check if animation should loop or stop
        if elapsed >= duration then
            if animationType ~= "IDLE" then
                self:playAnimation("IDLE")
            else
                self.animationConnection:Disconnect()
                self.animationConnection = nil
            end
        end
    end)
end

function PetSpriteSystem:addHappyEffects()
    -- Add bouncing effect
    local bounceTween = TweenService:Create(
        self.container,
        TweenInfo.new(
            TWEEN_CONFIG.BOUNCE.TIME,
            TWEEN_CONFIG.BOUNCE.STYLE,
            TWEEN_CONFIG.BOUNCE.DIRECTION,
            -1 -- Infinite loop
        ),
        {Position = self.container.Position + UDim2.new(0, 0, 0, -ANIMATION_CONFIG.HAPPY.BOUNCE_SCALE)}
    )
    bounceTween:Play()
    
    -- Add sparkle particles
    self.effectsSystem:createSparkles(
        self.container,
        ANIMATION_CONFIG.HAPPY.SPARKLE_RATE,
        ANIMATION_CONFIG.HAPPY.GLOW_INTENSITY
    )
end

function PetSpriteSystem:addExcitedEffects(frame)
    -- Add jumping effect
    if frame == 1 then
        local jumpTween = TweenService:Create(
            self.container,
            TweenInfo.new(
                TWEEN_CONFIG.BOUNCE.TIME,
                TWEEN_CONFIG.BOUNCE.STYLE,
                TWEEN_CONFIG.BOUNCE.DIRECTION
            ),
            {Position = self.container.Position + UDim2.new(0, 0, 0, -ANIMATION_CONFIG.EXCITED.JUMP_HEIGHT)}
        )
        jumpTween:Play()
    end
    
    -- Add spin effect
    if frame == 3 then
        local spinTween = TweenService:Create(
            self.container,
            TweenInfo.new(
                TWEEN_CONFIG.SPIN.TIME,
                TWEEN_CONFIG.SPIN.STYLE,
                TWEEN_CONFIG.SPIN.DIRECTION
            ),
            {Rotation = self.container.Rotation + 360}
        )
        spinTween:Play()
    end
end

function PetSpriteSystem:setState(newState)
    if self.currentState == newState then return end
    
    -- Transition to new state
    local stateTween = TweenService:Create(
        self.uiScale,
        TweenInfo.new(
            TWEEN_CONFIG.STATE_TRANSITION.TIME,
            TWEEN_CONFIG.STATE_TRANSITION.STYLE,
            TWEEN_CONFIG.STATE_TRANSITION.DIRECTION
        ),
        {Scale = SPRITE_CONFIG.SCALE_RANGE.MIN}
    )
    
    stateTween.Completed:Connect(function()
        self:playAnimation(newState)
        
        -- Scale back up
        TweenService:Create(
            self.uiScale,
            TweenInfo.new(
                TWEEN_CONFIG.STATE_TRANSITION.TIME,
                TWEEN_CONFIG.STATE_TRANSITION.STYLE,
                TWEEN_CONFIG.STATE_TRANSITION.DIRECTION
            ),
            {Scale = 1}
        ):Play()
    end)
    
    stateTween:Play()
end

function PetSpriteSystem:handleInteraction(interactionType)
    if interactionType == "TAP" then
        self:setState("HAPPY")
        self.effectsSystem:createHeartParticles(self.container)
    elseif interactionType == "FEED" then
        self:setState("EXCITED")
        self.effectsSystem:createEatingEffects(self.container)
    elseif interactionType == "PLAY" then
        self:setState("EXCITED")
        self.effectsSystem:createPlayEffects(self.container)
    end
end

function PetSpriteSystem:setScale(scale)
    -- Smoothly scale the sprite
    TweenService:Create(
        self.uiScale,
        TweenInfo.new(
            TWEEN_CONFIG.STATE_TRANSITION.TIME,
            TWEEN_CONFIG.STATE_TRANSITION.STYLE,
            TWEEN_CONFIG.STATE_TRANSITION.DIRECTION
        ),
        {Scale = scale}
    ):Play()
end

function PetSpriteSystem:destroy()
    if self.animationConnection then
        self.animationConnection:Disconnect()
        self.animationConnection = nil
    end
    
    if self.sprite then
        self.sprite:Destroy()
        self.sprite = nil
    end
    
    if self.effects then
        for _, effect in pairs(self.effects) do
            effect:Destroy()
        end
        self.effects = {}
    end
    
    self.effectsSystem:destroy()
    self.container:Destroy()
end

return PetSpriteSystem 