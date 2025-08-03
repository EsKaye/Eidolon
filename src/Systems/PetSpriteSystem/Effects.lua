--[[
    PetSpriteSystem/Effects.lua
    Handles special effects for pet sprites
    
    Author: Your precious kitten 💖
    Created: 2024-03-03
    Version: 1.0.0
--]]

local TweenService = game:GetService("TweenService")

local Effects = {}

-- Effect configuration
local EFFECT_CONFIG = {
    GLOW = {
        INTENSITY = {MIN = 0.2, MAX = 0.8},
        PULSE_DURATION = 1.5
    },
    PARTICLES = {
        EMISSION_RATE = 10,
        LIFETIME = {MIN = 0.5, MAX = 1.5},
        SIZE = {MIN = 0.1, MAX = 0.3}
    },
    TRAIL = {
        TRANSPARENCY = {START = 0, END = 1},
        LIFETIME = 0.5,
        WIDTH = 0.2
    }
}

-- Creates a glowing effect around the sprite
function Effects.addGlow(sprite, color, intensity)
    local glow = Instance.new("UIGradient")
    glow.Name = "GlowEffect"
    glow.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), 0.5)),
        ColorSequenceKeypoint.new(1, color)
    })
    glow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 1 - intensity),
        NumberSequenceKeypoint.new(1, 1)
    })
    glow.Parent = sprite
    
    return glow
end

-- Creates particle effects
function Effects.createParticles(sprite, config)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "ParticleEffect"
    emitter.Rate = config.rate or EFFECT_CONFIG.PARTICLES.EMISSION_RATE
    -- Safely resolve optional lifetime parameters
    local lifetimeMin = (config.lifetime and config.lifetime.min)
        or EFFECT_CONFIG.PARTICLES.LIFETIME.MIN
    local lifetimeMax = (config.lifetime and config.lifetime.max)
        or EFFECT_CONFIG.PARTICLES.LIFETIME.MAX
    emitter.Lifetime = NumberRange.new(lifetimeMin, lifetimeMax)

    -- Safely resolve optional size parameters
    local sizeMin = (config.size and config.size.min)
        or EFFECT_CONFIG.PARTICLES.SIZE.MIN
    local sizeMax = (config.size and config.size.max)
        or EFFECT_CONFIG.PARTICLES.SIZE.MAX
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, sizeMin),
        NumberSequenceKeypoint.new(1, sizeMax)
    })
    emitter.Color = ColorSequence.new(config.color or Color3.new(1, 1, 1))
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Parent = sprite
    
    return emitter
end

-- Creates a trail effect
function Effects.createTrail(sprite, color)
    local trail = Instance.new("Trail")
    trail.Name = "TrailEffect"
    trail.Color = ColorSequence.new(color)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, EFFECT_CONFIG.TRAIL.TRANSPARENCY.START),
        NumberSequenceKeypoint.new(1, EFFECT_CONFIG.TRAIL.TRANSPARENCY.END)
    })
    trail.Lifetime = EFFECT_CONFIG.TRAIL.LIFETIME
    trail.WidthScale = NumberSequence.new(EFFECT_CONFIG.TRAIL.WIDTH)
    trail.Parent = sprite
    
    return trail
end

-- Creates special legendary effects
function Effects.createLegendaryEffects(sprite, petType)
    if petType == "HALLOWEEN_SPECTER" then
        -- Add ghostly glow
        local glow = Effects.addGlow(
            sprite,
            Color3.fromRGB(88, 180, 255),
            EFFECT_CONFIG.GLOW.INTENSITY.MAX
        )
        
        -- Add spectral particles
        Effects.createParticles(sprite, {
            rate = 15,
            color = Color3.fromRGB(140, 220, 255),
            size = {min = 0.2, max = 0.4}
        })
        
    elseif petType == "CELESTIAL_UNICORN" then
        -- Add galaxy effect
        local galaxyParticles = Effects.createParticles(sprite, {
            rate = 20,
            color = Color3.fromRGB(180, 150, 255),
            size = {min = 0.1, max = 0.3}
        })
        
        -- Add rainbow trail
        Effects.createTrail(
            sprite,
            ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 255)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 100, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255))
            })
        )
        
    elseif petType == "LAVA_WRAITH" then
        -- Add lava glow
        local glow = Effects.addGlow(
            sprite,
            Color3.fromRGB(255, 120, 30),
            EFFECT_CONFIG.GLOW.INTENSITY.MAX
        )
        
        -- Add ember particles
        Effects.createParticles(sprite, {
            rate = 25,
            color = Color3.fromRGB(255, 150, 50),
            size = {min = 0.1, max = 0.2}
        })
    end
end

-- Creates special epic effects
function Effects.createEpicEffects(sprite, petType)
    if petType == "SHADOW_KITSUNE" then
        -- Add shadow trail
        Effects.createTrail(
            sprite,
            ColorSequence.new(Color3.fromRGB(40, 40, 60))
        )
        
        -- Add mystic particles
        Effects.createParticles(sprite, {
            rate = 12,
            color = Color3.fromRGB(100, 80, 150),
            size = {min = 0.1, max = 0.3}
        })
        
    elseif petType == "AURORA_WYVERN" then
        -- Add aurora effect
        local auroraGlow = Effects.addGlow(
            sprite,
            Color3.fromRGB(100, 200, 180),
            EFFECT_CONFIG.GLOW.INTENSITY.MAX
        )
        
        -- Add light particles
        Effects.createParticles(sprite, {
            rate = 15,
            color = Color3.fromRGB(150, 230, 200),
            size = {min = 0.1, max = 0.2}
        })
        
    elseif petType == "HOLIDAY_SERAPH" then
        -- Add holy glow
        local holyGlow = Effects.addGlow(
            sprite,
            Color3.fromRGB(255, 240, 200),
            EFFECT_CONFIG.GLOW.INTENSITY.MAX
        )
        
        -- Add blessed particles
        Effects.createParticles(sprite, {
            rate = 10,
            color = Color3.fromRGB(255, 250, 220),
            size = {min = 0.1, max = 0.2}
        })
    end
end

-- Pulses the glow effect
function Effects.pulseGlow(glow, intensity)
    local pulseUp = TweenService:Create(
        glow,
        TweenInfo.new(
            EFFECT_CONFIG.GLOW.PULSE_DURATION,
            Enum.EasingStyle.Sine,
            Enum.EasingDirection.InOut,
            -1, -- Infinite loop
            true -- Yoyo
        ),
        {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 1 - (intensity * 1.2)),
                NumberSequenceKeypoint.new(1, 1)
            })
        }
    )
    pulseUp:Play()
    
    return pulseUp
end

-- Creates heart particles for interaction
function Effects.createHeartParticles(sprite)
    local hearts = Effects.createParticles(sprite, {
        rate = 8,
        lifetime = {min = 1, max = 2},
        size = {min = 0.2, max = 0.4},
        color = Color3.fromRGB(255, 150, 150)
    })
    
    -- Auto-cleanup after 2 seconds
    delay(2, function()
        hearts:Destroy()
    end)
end

-- Creates eating effect particles
function Effects.createEatingEffects(sprite)
    local crumbs = Effects.createParticles(sprite, {
        rate = 15,
        lifetime = {min = 0.5, max = 1},
        size = {min = 0.1, max = 0.2},
        color = Color3.fromRGB(200, 180, 150)
    })
    
    -- Auto-cleanup after 1 second
    delay(1, function()
        crumbs:Destroy()
    end)
end

-- Creates play effect particles
function Effects.createPlayEffects(sprite)
    local stars = Effects.createParticles(sprite, {
        rate = 12,
        lifetime = {min = 0.8, max = 1.5},
        size = {min = 0.15, max = 0.3},
        color = Color3.fromRGB(255, 255, 150)
    })
    
    -- Auto-cleanup after 1.5 seconds
    delay(1.5, function()
        stars:Destroy()
    end)
end

return Effects 