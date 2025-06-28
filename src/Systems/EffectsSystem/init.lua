--[[
    EffectsSystem.lua
    Handles visual and audio effects for game events
    
    Author: Cursor AI
    Created: 2024-03-03
    Version: 0.1.0
--]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectsSystem = {}
EffectsSystem.__index = EffectsSystem

-- Effect configurations for different rarities
local RARITY_EFFECTS = {
    COMMON = {
        PARTICLES = {
            Color = ColorSequence.new(Color3.fromRGB(200, 200, 200)),
            Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(0.5, 0.3),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Lifetime = NumberRange.new(0.5, 1),
            Rate = 20,
            Speed = NumberRange.new(3, 5)
        },
        SOUND = {
            ID = "rbxasset://sounds/impact_soft.mp3",
            Volume = 0.5,
            PlaybackSpeed = 1
        },
        SCREEN_SHAKE = {
            Intensity = 0.1,
            Duration = 0.2
        }
    },
    UNCOMMON = {
        PARTICLES = {
            Color = ColorSequence.new(Color3.fromRGB(100, 255, 100)),
            Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(0.5, 0.4),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Lifetime = NumberRange.new(0.8, 1.2),
            Rate = 30,
            Speed = NumberRange.new(4, 6)
        },
        SOUND = {
            ID = "rbxasset://sounds/impact_metal.mp3",
            Volume = 0.6,
            PlaybackSpeed = 1.1
        },
        SCREEN_SHAKE = {
            Intensity = 0.2,
            Duration = 0.3
        }
    },
    RARE = {
        PARTICLES = {
            Color = ColorSequence.new(Color3.fromRGB(100, 100, 255)),
            Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(0.5, 0.6),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Lifetime = NumberRange.new(1, 1.5),
            Rate = 40,
            Speed = NumberRange.new(5, 7)
        },
        SOUND = {
            ID = "rbxasset://sounds/victory.mp3",
            Volume = 0.7,
            PlaybackSpeed = 1.2
        },
        SCREEN_SHAKE = {
            Intensity = 0.3,
            Duration = 0.4
        }
    },
    EPIC = {
        PARTICLES = {
            Color = ColorSequence.new(Color3.fromRGB(200, 100, 255)),
            Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.4),
                NumberSequenceKeypoint.new(0.5, 0.8),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Lifetime = NumberRange.new(1.2, 1.8),
            Rate = 50,
            Speed = NumberRange.new(6, 8)
        },
        SOUND = {
            ID = "rbxasset://sounds/magic.mp3",
            Volume = 0.8,
            PlaybackSpeed = 1.3
        },
        SCREEN_SHAKE = {
            Intensity = 0.4,
            Duration = 0.5
        }
    },
    LEGENDARY = {
        PARTICLES = {
            Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)),
            Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(0.5, 1),
                NumberSequenceKeypoint.new(1, 0)
            }),
            Lifetime = NumberRange.new(1.5, 2),
            Rate = 60,
            Speed = NumberRange.new(7, 10)
        },
        SOUND = {
            ID = "rbxasset://sounds/victory_fanfare.mp3",
            Volume = 1,
            PlaybackSpeed = 1.4
        },
        SCREEN_SHAKE = {
            Intensity = 0.5,
            Duration = 0.6
        }
    }
}

function EffectsSystem.new(parent)
    local self = setmetatable({}, EffectsSystem)
    
    -- Create effects container
    self.container = Instance.new("Folder")
    self.container.Name = "EffectsContainer"
    self.container.Parent = parent
    
    -- Initialize particle emitters
    self.particleEmitters = {}
    for rarity, config in pairs(RARITY_EFFECTS) do
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = rarity .. "Emitter"
        
        -- Apply particle configuration
        emitter.Color = config.PARTICLES.Color
        emitter.Size = config.PARTICLES.Size
        emitter.Lifetime = config.PARTICLES.Lifetime
        emitter.Rate = config.PARTICLES.Rate
        emitter.Speed = config.PARTICLES.Speed
        emitter.Enabled = false
        
        emitter.Parent = self.container
        self.particleEmitters[rarity] = emitter
    end
    
    return self
end

-- Play effects for a specific rarity
function EffectsSystem:playEffects(rarity, position)
    local effects = RARITY_EFFECTS[rarity]
    if not effects then return end
    
    -- Play particle effect
    local emitter = self.particleEmitters[rarity]
    if emitter then
        emitter.Position = position
        emitter.Enabled = true
        
        -- Disable after duration
        task.delay(effects.PARTICLES.Lifetime.Max, function()
            if emitter and emitter.Parent then
                emitter.Enabled = false
            end
        end)
    end
    
    -- Play sound effect with proper cleanup
    local sound = Instance.new("Sound")
    sound.SoundId = effects.SOUND.ID
    sound.Volume = effects.SOUND.Volume
    sound.PlaybackSpeed = effects.SOUND.PlaybackSpeed
    sound.Parent = self.container
    
    -- Store sound for cleanup
    table.insert(self.activeSounds, sound)
    
    -- Clean up sound after playing
    sound.Ended:Connect(function()
        if sound and sound.Parent then
            sound:Destroy()
            local index = table.find(self.activeSounds, sound)
            if index then
                table.remove(self.activeSounds, index)
            end
        end
    end)
    
    sound:Play()
    
    -- Apply screen shake
    self:screenShake(effects.SCREEN_SHAKE.Intensity, effects.SCREEN_SHAKE.Duration)
end

-- Create screen shake effect with proper cleanup
function EffectsSystem:screenShake(intensity, duration)
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local startCFrame = camera.CFrame
    local elapsed = 0
    local connection
    
    -- Store previous connection
    if self.screenShakeConnection then
        self.screenShakeConnection:Disconnect()
    end
    
    self.screenShakeConnection = game:GetService("RunService").RenderStepped:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            camera.CFrame = startCFrame
            self.screenShakeConnection:Disconnect()
            self.screenShakeConnection = nil
            return
        end
        
        local shake = Vector3.new(
            math.random(-10, 10) * intensity,
            math.random(-10, 10) * intensity,
            0
        )
        
        camera.CFrame = startCFrame * CFrame.new(shake)
    end)
end

-- Clean up effects
function EffectsSystem:destroy()
    -- Clean up particle emitters
    for _, emitter in pairs(self.particleEmitters) do
        if emitter and emitter.Parent then
            emitter:Destroy()
        end
    end
    self.particleEmitters = {}
    
    -- Clean up active sounds
    for _, sound in pairs(self.activeSounds) do
        if sound and sound.Parent then
            sound:Destroy()
        end
    end
    self.activeSounds = {}
    
    -- Clean up screen shake
    if self.screenShakeConnection then
        self.screenShakeConnection:Disconnect()
        self.screenShakeConnection = nil
    end
    
    -- Clean up container
    if self.container and self.container.Parent then
        self.container:Destroy()
    end
end

return EffectsSystem 