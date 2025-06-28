--[[
    FireflyIntegration.lua
    Author: Your precious kitten 💖
    Created: 2024-03-12
    Version: 1.0.0
    Purpose: Integration with Adobe Firefly for AI-generated assets and textures
]]

local Logger = require(script.Parent.Parent.Parent.Logger)
local log = Logger.forModule("FireflyIntegration")

log.debug("Initializing FireflyIntegration module")

local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")

local FireflyIntegration = {}
FireflyIntegration.__index = FireflyIntegration

-- Constants
local TEXTURE_CACHE_SIZE = 100
local DEFAULT_IMAGE_SIZE = 1024
local DEFAULT_TEXTURE_FORMAT = "png"
local PROCESS_BATCH_SIZE = 10

-- Adobe Firefly API Configuration (placeholder)
local FIREFLY_API_ENDPOINT = "https://firefly-api.adobe.io/v2"
local API_KEY_PLACEHOLDER = "YOUR_API_KEY_HERE" -- Replace with actual key in production

-- Cache for generated textures to avoid redundant requests
local textureCache = {}
local textureCacheOrder = {}
local textureCacheSize = 0

-- Process queue for asynchronous texture generation
local processQueue = {}
local isProcessing = false

-- Assets configuration for different biomes
local biomeTextureConfigs = {
    ["Grassland"] = {
        ground = {
            prompt = "Seamless grass texture with small flowers and clovers, top-down view, game texture",
            style = "photorealistic",
            colors = "vibrant green, yellow flowers"
        },
        rocks = {
            prompt = "Seamless grey and moss-covered rocks texture, top-down view, game asset",
            style = "photorealistic",
            colors = "grey, green moss patches"
        },
        trees = {
            prompt = "Oak and birch tree bark texture, seamless tileable, game asset",
            style = "photorealistic",
            colors = "brown, light brown, beige"
        }
    },
    ["Forest"] = {
        ground = {
            prompt = "Dense forest floor with pine needles, leaves and moss, seamless texture",
            style = "photorealistic",
            colors = "dark green, brown, olive"
        },
        rocks = {
            prompt = "Forest rocks with moss and lichen, seamless texture for games",
            style = "photorealistic",
            colors = "dark grey, green, blue-green lichen"
        },
        trees = {
            prompt = "Dense pine tree bark texture with sap, seamless tileable",
            style = "photorealistic",
            colors = "dark brown, amber"
        }
    },
    ["Desert"] = {
        ground = {
            prompt = "Cracked desert sand texture, seamless tileable for game terrain",
            style = "photorealistic",
            colors = "tan, orange, light brown"
        },
        rocks = {
            prompt = "Weathered desert rock texture, sun-baked and eroded, seamless",
            style = "photorealistic",
            colors = "orange-red, burnt sienna, sand color"
        },
        cacti = {
            prompt = "Cactus skin texture with spines, seamless tileable for game assets",
            style = "photorealistic",
            colors = "green, pale green"
        }
    },
    ["Mountain"] = {
        ground = {
            prompt = "Rocky mountain terrain with sparse grass, seamless texture",
            style = "photorealistic",
            colors = "grey, brown, patches of green"
        },
        rocks = {
            prompt = "Sharp mountain rock texture with snow patches, seamless tileable",
            style = "photorealistic",
            colors = "dark grey, light grey, white"
        },
        snow = {
            prompt = "Fresh mountain snow texture with subtle cracks, seamless tileable",
            style = "photorealistic",
            colors = "white, pale blue shadows"
        }
    },
    ["VolcanicWasteland"] = {
        ground = {
            prompt = "Volcanic ash and hardened lava texture, seamless tileable for games",
            style = "photorealistic",
            colors = "black, dark grey, red glow in cracks"
        },
        rocks = {
            prompt = "Volcanic rock with cooling cracks and ember glow, seamless texture",
            style = "photorealistic",
            colors = "black, dark grey, orange-red glow"
        },
        lava = {
            prompt = "Flowing lava texture with cooling surface, seamless tileable",
            style = "photorealistic",
            colors = "bright orange, red, yellow, black crust"
        }
    },
    ["Oasis"] = {
        ground = {
            prompt = "Lush oasis grass with wet sand transition, seamless texture",
            style = "photorealistic",
            colors = "vibrant green, tan, dark brown wet sand"
        },
        water = {
            prompt = "Clear oasis water with subtle ripples, seamless tileable texture",
            style = "photorealistic",
            colors = "turquoise, blue, white ripples"
        },
        palms = {
            prompt = "Palm tree bark texture with fiber patterns, seamless tileable",
            style = "photorealistic",
            colors = "brown, tan, fibrous texture"
        }
    }
}

-- Utility Functions
local function addToCache(textureId, textureData)
    -- Remove oldest texture if cache is full
    if textureCacheSize >= TEXTURE_CACHE_SIZE then
        local oldestId = table.remove(textureCacheOrder, 1)
        if oldestId and textureCache[oldestId] then
            textureCache[oldestId] = nil
            textureCacheSize = textureCacheSize - 1
        end
    end
    
    -- Add to cache
    textureCache[textureId] = textureData
    table.insert(textureCacheOrder, textureId)
    textureCacheSize = textureCacheSize + 1
    
    log.debug("Added texture to cache: %s", textureId)
end

local function processQueueAsync()
    if isProcessing or #processQueue == 0 then
        return
    end
    
    isProcessing = true
    
    task.spawn(function()
        while #processQueue > 0 do
            -- Process items in batches
            local batchSize = math.min(PROCESS_BATCH_SIZE, #processQueue)
            local batch = {}
            
            -- Get a batch of requests
            for i = 1, batchSize do
                table.insert(batch, table.remove(processQueue, 1))
            end
            
            -- Process each request in the batch
            for _, request in ipairs(batch) do
                local success, result = pcall(function()
                    return FireflyIntegration:generateTextureInternal(
                        request.prompt,
                        request.options
                    )
                end)
                
                -- Call the callback with the result
                if request.callback then
                    if success then
                        request.callback(result, nil)
                    else
                        request.callback(nil, result)
                    end
                end
                
                -- Small delay to prevent throttling
                task.wait(0.5)
            end
        end
        
        isProcessing = false
    end)
end

-- Create a new FireflyIntegration instance
function FireflyIntegration.new(apiKey)
    log.info("Creating new FireflyIntegration instance")
    
    local self = setmetatable({}, FireflyIntegration)
    
    -- Initialize properties
    self.apiKey = apiKey or API_KEY_PLACEHOLDER
    self.isEnabled = apiKey ~= nil and apiKey ~= API_KEY_PLACEHOLDER
    self.lastRequestTime = 0
    self.requestCount = 0
    
    -- Start the processing queue
    task.spawn(function()
        while true do
            processQueueAsync()
            task.wait(1)
        end
    end)
    
    log.debug("FireflyIntegration instance created")
    return self
end

-- Set API key
function FireflyIntegration:setApiKey(apiKey)
    self.apiKey = apiKey
    self.isEnabled = apiKey ~= nil and apiKey ~= API_KEY_PLACEHOLDER
    log.info("API key updated. Integration %s", self.isEnabled and "enabled" or "disabled")
    return self
end

-- Internal function to make API call to Firefly
function FireflyIntegration:callFireflyAPI(endpoint, payload)
    if not self.isEnabled then
        return nil, "Adobe Firefly integration is not enabled (API key not configured)"
    end
    
    local url = FIREFLY_API_ENDPOINT .. endpoint
    
    -- Rate limiting
    local currentTime = os.time()
    if currentTime - self.lastRequestTime < 1 and self.requestCount >= 5 then
        log.warning("Rate limit reached for Adobe Firefly API")
        return nil, "Rate limit reached"
    end
    
    -- Update rate limiting counters
    if currentTime - self.lastRequestTime >= 1 then
        self.lastRequestTime = currentTime
        self.requestCount = 1
    else
        self.requestCount = self.requestCount + 1
    end
    
    -- Make the HTTP request
    local success, result = pcall(function()
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-api-key"] = self.apiKey
            },
            Body = HttpService:JSONEncode(payload)
        })
        
        if response.Success then
            return HttpService:JSONDecode(response.Body)
        else
            return nil, "HTTP Error: " .. response.StatusCode .. " - " .. response.StatusMessage
        end
    end)
    
    if not success then
        log.error("Failed to call Adobe Firefly API: %s", tostring(result))
        return nil, "API call failed: " .. tostring(result)
    end
    
    return result
end

-- Internal implementation of texture generation
function FireflyIntegration:generateTextureInternal(prompt, options)
    options = options or {}
    
    local width = options.width or DEFAULT_IMAGE_SIZE
    local height = options.height or DEFAULT_IMAGE_SIZE
    local format = options.format or DEFAULT_TEXTURE_FORMAT
    local style = options.style or "photorealistic"
    local colors = options.colors
    
    -- Create a unique ID for this texture request
    local textureId = HttpService:GenerateGUID(false)
    
    -- Create full prompt with style and colors if specified
    local fullPrompt = prompt
    if style then
        fullPrompt = fullPrompt .. ", " .. style
    end
    if colors then
        fullPrompt = fullPrompt .. ", colors: " .. colors
    end
    
    -- Add universal qualifiers for game textures
    fullPrompt = fullPrompt .. ", seamless tileable, high quality, game asset, optimized for Roblox"
    
    log.debug("Generating texture with prompt: %s", fullPrompt)
    
    -- Prepare API payload
    local payload = {
        prompt = fullPrompt,
        width = width,
        height = height,
        format = format,
        n = 1 -- Generate one image
    }
    
    -- Make the API call
    local result, error = self:callFireflyAPI("/generate", payload)
    
    if error then
        log.error("Failed to generate texture: %s", error)
        return nil, error
    end
    
    -- Process the result
    if result and result.images and #result.images > 0 then
        local imageData = result.images[1]
        
        -- Cache the result
        addToCache(textureId, {
            id = textureId,
            prompt = prompt,
            options = options,
            data = imageData,
            timestamp = os.time()
        })
        
        log.info("Successfully generated texture: %s", textureId)
        return {
            id = textureId,
            data = imageData,
            imageUrl = imageData.url,
            width = width,
            height = height,
            format = format
        }
    else
        log.warning("Received empty result from Adobe Firefly API")
        return nil, "Empty result from API"
    end
end

-- Generate a texture with a prompt (queued asynchronous version)
function FireflyIntegration:generateTexture(prompt, options, callback)
    if not self.isEnabled then
        if callback then
            callback(nil, "Adobe Firefly integration is not enabled")
        end
        return nil
    end
    
    -- Add to processing queue
    table.insert(processQueue, {
        prompt = prompt,
        options = options,
        callback = callback
    })
    
    -- Start processing if not already running
    if not isProcessing then
        processQueueAsync()
    end
    
    return true
end

-- Generate a biome-specific texture
function FireflyIntegration:generateBiomeTexture(biome, textureType, options, callback)
    if not biomeTextureConfigs[biome] or not biomeTextureConfigs[biome][textureType] then
        local error = string.format("No texture configuration for biome [%s] texture type [%s]", biome, textureType)
        log.warning(error)
        
        if callback then
            callback(nil, error)
        end
        return nil
    end
    
    -- Get texture configuration
    local config = biomeTextureConfigs[biome][textureType]
    
    -- Merge options
    local mergedOptions = options or {}
    mergedOptions.style = mergedOptions.style or config.style
    mergedOptions.colors = mergedOptions.colors or config.colors
    
    -- Generate the texture
    return self:generateTexture(config.prompt, mergedOptions, callback)
end

-- Load texture into Roblox
function FireflyIntegration:loadTextureIntoRoblox(textureData, callback)
    if not textureData or not textureData.imageUrl then
        local error = "Invalid texture data provided"
        log.warning(error)
        
        if callback then
            callback(nil, error)
        end
        return nil
    end
    
    -- Create a new ImageLabel to hold the texture
    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.BackgroundTransparency = 1
    imageLabel.Image = textureData.imageUrl
    
    -- Preload the image
    ContentProvider:PreloadAsync({imageLabel})
    
    -- Create a ViewportFrame to render the texture
    local viewportFrame = Instance.new("ViewportFrame")
    viewportFrame.Size = UDim2.new(1, 0, 1, 0)
    viewportFrame.BackgroundTransparency = 1
    viewportFrame.LightingMode = Enum.LightingMode.Flat
    
    -- Set up environment
    local worldModel = Instance.new("WorldModel")
    worldModel.Parent = viewportFrame
    
    -- Create a part with the texture
    local part = Instance.new("Part")
    part.Size = Vector3.new(4, 4, 0.1)
    part.CFrame = CFrame.new(0, 0, 0)
    part.Anchored = true
    part.CanCollide = false
    part.Parent = worldModel
    
    -- Apply the texture to the part
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.LightInfluence = 0
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    surfaceGui.PixelsPerStud = 50
    surfaceGui.Parent = part
    
    -- Clone the image label into the surface GUI
    imageLabel.Parent = surfaceGui
    
    -- Set up camera
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.new(0, 0, 5, 0, 0, -1, 0, 1, 0)
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera
    
    local textureResult = {
        id = textureData.id,
        viewportFrame = viewportFrame,
        worldModel = worldModel,
        part = part,
        imageLabel = imageLabel
    }
    
    if callback then
        callback(textureResult)
    end
    
    return textureResult
end

-- Generate a complete set of textures for a biome
function FireflyIntegration:generateBiomeTextureSet(biome, callback)
    if not biomeTextureConfigs[biome] then
        local error = string.format("No texture configuration for biome [%s]", biome)
        log.warning(error)
        
        if callback then
            callback(nil, error)
        end
        return nil
    end
    
    log.info("Generating complete texture set for biome: %s", biome)
    
    local results = {}
    local pendingCount = 0
    local errorCount = 0
    
    -- Count how many texture types we need to generate
    for textureType, _ in pairs(biomeTextureConfigs[biome]) do
        pendingCount = pendingCount + 1
    end
    
    -- Function to track completion
    local function checkCompletion(textureType, result, error)
        if error then
            log.warning("Failed to generate %s texture for biome %s: %s", textureType, biome, error)
            errorCount = errorCount + 1
        else
            results[textureType] = result
        end
        
        pendingCount = pendingCount - 1
        
        -- If all textures have been processed, call the callback
        if pendingCount <= 0 and callback then
            callback(results, errorCount > 0 and "Some textures failed to generate" or nil)
        end
    end
    
    -- Generate each texture type
    for textureType, _ in pairs(biomeTextureConfigs[biome]) do
        self:generateBiomeTexture(biome, textureType, nil, function(result, error)
            checkCompletion(textureType, result, error)
        end)
    end
    
    return true
end

-- Clear the texture cache
function FireflyIntegration:clearCache()
    textureCache = {}
    textureCacheOrder = {}
    textureCacheSize = 0
    log.debug("Texture cache cleared")
    return self
end

-- Get cache statistics
function FireflyIntegration:getCacheStats()
    return {
        size = textureCacheSize,
        limit = TEXTURE_CACHE_SIZE,
        usage = textureCacheSize / TEXTURE_CACHE_SIZE
    }
end

log.debug("FireflyIntegration module loaded successfully")

return FireflyIntegration 