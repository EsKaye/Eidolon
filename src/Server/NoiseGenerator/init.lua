--[[
    NoiseGenerator/init.lua
    Author: Your precious kitten 💖
    Updated: 2024-03-12
    Version: 1.2.0
    Purpose: Generates procedural noise for terrain generation (Ultra-Optimized)
]]

local Logger = require(script.Parent.Parent.Logger)
local log = Logger.forModule("NoiseGenerator")

log.debug("Initializing NoiseGenerator module")

local NoiseGenerator = {}
NoiseGenerator.__index = NoiseGenerator

-- Constants for noise generation
local DEFAULT_SEED = os.time()
local DEFAULT_SCALE = 100
local DEFAULT_OCTAVES = 3
local DEFAULT_PERSISTENCE = 0.5
local DEFAULT_LACUNARITY = 2.0
local MIN_AMPLITUDE_THRESHOLD = 0.01 -- Early termination threshold
local CACHE_SIZE_LIMIT = 1000 -- Prevent memory leaks with bounded cache
local BATCH_PROCESS_LIMIT = 64 -- Max size for batch processing
local ADAPTIVE_OCTAVE_LIMIT = true -- Enable adaptive octave scaling

-- Performance monitoring
local perfStats = {
    noiseCallsTotal = 0,
    batchCallsTotal = 0,
    batchSizesSum = 0,
    generationTimeTotal = 0,
    operationsCount = 0
}

-- Cached permutation table
local perm = {}

-- Noise cache for memoization
local noiseCache = {}
local cacheHits = 0
local cacheMisses = 0
local cacheSize = 0

-- LRU cache implementation
local cacheQueue = {}
local cacheIndex = 1

-- Cache management
local function addToCache(key, value)
    if cacheSize >= CACHE_SIZE_LIMIT then
        -- Remove oldest entry using LRU
        local oldestKey = cacheQueue[cacheIndex]
        if oldestKey then
            noiseCache[oldestKey] = nil
            cacheSize = cacheSize - 1
        end
        cacheQueue[cacheIndex] = key
        cacheIndex = (cacheIndex % CACHE_SIZE_LIMIT) + 1
    else
        -- Add new entry to queue
        cacheSize = cacheSize + 1
        cacheQueue[cacheSize] = key
    end
    
    noiseCache[key] = value
end

local function clearCache()
    noiseCache = {}
    cacheQueue = {}
    cacheIndex = 1
    cacheSize = 0
    cacheHits = 0
    cacheMisses = 0
    log.debug("Noise cache cleared")
end

-- Initialize permutation table with seed
local function initPermTable(seed)
    log.debug("Initializing permutation table with seed: %d", seed)
    
    -- Create permutation array with values 0-255
    local p = {}
    for i = 0, 255 do
        p[i] = i
    end
    
    -- Fisher-Yates shuffle with seed as random source
    local rng = Random.new(seed)
    for i = 255, 1, -1 do
        local j = rng:NextInteger(0, i)
        p[i], p[j] = p[j], p[i]
    end
    
    -- Extend the permutation table to avoid overflow
    perm = {}
    for i = 0, 511 do
        perm[i] = p[i % 256]
    end
    
    log.debug("Permutation table initialized")
    
    -- Clear cache when seed changes
    clearCache()
    
    return perm
end

-- Fade function for Perlin noise to smooth interpolation (optimized polynomial)
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Linear interpolation between a and b by t
local function lerp(a, b, t)
    return a + t * (b - a)
end

-- Optimized gradient function for Perlin noise
local function grad(hash, x, y, z)
-- Use bit32 operations for compatibility with Lua 5.1/Luau
local h = bit32.band(hash, 15)
local u = h < 8 and x or y
local v = h < 4 and y or ((h == 12 or h == 14) and x or z)
return (bit32.band(h, 1) == 0 and u or -u) + (bit32.band(h, 2) == 0 and v or -v)
end

-- Create a new NoiseGenerator instance
function NoiseGenerator.new(seed)
    log.debug("Creating new NoiseGenerator instance")
    local self = setmetatable({}, NoiseGenerator)
    
    -- Initialize properties
    self.seed = seed or DEFAULT_SEED
    self.scale = DEFAULT_SCALE
    self.octaves = DEFAULT_OCTAVES
    self.persistence = DEFAULT_PERSISTENCE
    self.lacunarity = DEFAULT_LACUNARITY
    self.adaptiveOctaves = ADAPTIVE_OCTAVE_LIMIT
    
    -- Performance monitoring
    self.perfMonitoring = true
    
    -- Initialize permutation table with seed
    initPermTable(self.seed)
    
    log.debug("NoiseGenerator instance created with seed: %d", self.seed)
    return self
end

-- Set seed for noise generation
function NoiseGenerator:setSeed(seed)
    if seed == self.seed then
        return self -- No change needed
    end
    
    self.seed = seed
    initPermTable(seed)
    return self
end

-- Get current seed
function NoiseGenerator:getSeed()
    return self.seed
end

-- Set noise scale (higher = smoother)
function NoiseGenerator:setScale(scale)
    if scale == self.scale then
        return self -- No change needed
    end
    
    self.scale = scale
    clearCache() -- Scale changes affect all noise values
    return self
end

-- Set octaves (detail levels)
function NoiseGenerator:setOctaves(octaves)
    if octaves == self.octaves then
        return self -- No change needed
    end
    
    self.octaves = octaves
    clearCache() -- Octaves affect fractal calculations
    return self
end

-- Set persistence (how much each octave contributes)
function NoiseGenerator:setPersistence(persistence)
    if persistence == self.persistence then
        return self -- No change needed
    end
    
    self.persistence = persistence
    clearCache() -- Persistence affects fractal calculations
    return self
end

-- Set lacunarity (frequency multiplier between octaves)
function NoiseGenerator:setLacunarity(lacunarity)
    if lacunarity == self.lacunarity then
        return self -- No change needed
    end
    
    self.lacunarity = lacunarity
    clearCache() -- Lacunarity affects fractal calculations
    return self
end

-- Toggle adaptive octave scaling
function NoiseGenerator:setAdaptiveOctaves(enabled)
    self.adaptiveOctaves = enabled
    return self
end

-- Toggle performance monitoring
function NoiseGenerator:setPerformanceMonitoring(enabled)
    self.perfMonitoring = enabled
    return self
end

-- Generate 3D Perlin noise value at x,y,z with caching
function NoiseGenerator:perlin3D(x, y, z)
    if self.perfMonitoring then
        perfStats.noiseCallsTotal = perfStats.noiseCallsTotal + 1
    end
    
    -- Create cache key based on coordinates and scale
    local cacheKey = string.format("%.2f:%.2f:%.2f:%.2f", x, y, z, self.scale)
    
    -- Check cache first
    if noiseCache[cacheKey] then
        cacheHits = cacheHits + 1
        return noiseCache[cacheKey]
    end
    
    cacheMisses = cacheMisses + 1
    
    -- Scale coordinates
    x, y, z = x / self.scale, y / self.scale, z / self.scale
    
    -- Get unit cube containing the point
    local xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    
    -- Get relative coordinates within unit cube (0-1)
    x, y, z = x - xi, y - yi, z - zi
    
    -- Compute fade curves (optimization: only calculate once)
    local u, v, w = fade(x), fade(y), fade(z)
    
    -- Hash coordinates of cube corners (optimization: minimize table lookups)
    local perm_xi = perm[bit32.band(xi, 255)]
    local perm_xi_1 = perm[bit32.band(xi + 1, 255)]

    local perm_yi = perm[bit32.band(perm_xi + yi, 255)]
    local perm_yi_1 = perm[bit32.band(perm_xi + yi + 1, 255)]
    local perm_xi1_yi = perm[bit32.band(perm_xi_1 + yi, 255)]
    local perm_xi1_yi1 = perm[bit32.band(perm_xi_1 + yi + 1, 255)]

    local aaa = perm[bit32.band(perm_yi + zi, 255)]
    local aba = perm[bit32.band(perm_yi_1 + zi, 255)]
    local aab = perm[bit32.band(perm_yi + zi + 1, 255)]
    local abb = perm[bit32.band(perm_yi_1 + zi + 1, 255)]
    local baa = perm[bit32.band(perm_xi1_yi + zi, 255)]
    local bba = perm[bit32.band(perm_xi1_yi1 + zi, 255)]
    local bab = perm[bit32.band(perm_xi1_yi + zi + 1, 255)]
    local bbb = perm[bit32.band(perm_xi1_yi1 + zi + 1, 255)]
    
    -- Gradients at corners
    local x1 = lerp(grad(aaa, x, y, z), grad(baa, x-1, y, z), u)
    local x2 = lerp(grad(aba, x, y-1, z), grad(bba, x-1, y-1, z), u)
    local y1 = lerp(x1, x2, v)
    
    local x1 = lerp(grad(aab, x, y, z-1), grad(bab, x-1, y, z-1), u)
    local x2 = lerp(grad(abb, x, y-1, z-1), grad(bbb, x-1, y-1, z-1), u)
    local y2 = lerp(x1, x2, v)
    
    -- Final interpolation
    local result = lerp(y1, y2, w)
    
    -- Normalize to range [0, 1]
    result = (result + 1) / 2
    
    -- Cache the result
    addToCache(cacheKey, result)
    
    return result
end

-- NEW: Batch process multiple 3D noise points in one call (SIMD-style)
function NoiseGenerator:batchPerlin3D(pointsList)
    if self.perfMonitoring then
        perfStats.batchCallsTotal = perfStats.batchCallsTotal + 1
        perfStats.batchSizesSum = perfStats.batchSizesSum + #pointsList
    end
    
    local startTime = os.clock()
    local results = {}
    local pointsToProcess = {}
    
    -- First pass: check cache and collect points that need processing
    for i, point in ipairs(pointsList) do
        local x, y, z = point[1], point[2], point[3]
        local cacheKey = string.format("%.2f:%.2f:%.2f:%.2f", x, y, z, self.scale)
        
        if noiseCache[cacheKey] then
            results[i] = noiseCache[cacheKey]
            cacheHits = cacheHits + 1
        else
            cacheMisses = cacheMisses + 1
            results[i] = nil
            table.insert(pointsToProcess, {index = i, x = x, y = y, z = z, cacheKey = cacheKey})
        end
    end
    
    -- Process points that weren't in cache
    for _, point in ipairs(pointsToProcess) do
        local x, y, z = point.x / self.scale, point.y / self.scale, point.z / self.scale
        
        -- Get unit cube coordinates and process similarly to perlin3D
        local xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
        x, y, z = x - xi, y - yi, z - zi
        
        local u, v, w = fade(x), fade(y), fade(z)
        
        -- Compute all hash lookups
        local perm_xi = perm[bit32.band(xi, 255)]
        local perm_xi_1 = perm[bit32.band(xi + 1, 255)]

        local perm_yi = perm[bit32.band(perm_xi + yi, 255)]
        local perm_yi_1 = perm[bit32.band(perm_xi + yi + 1, 255)]
        local perm_xi1_yi = perm[bit32.band(perm_xi_1 + yi, 255)]
        local perm_xi1_yi1 = perm[bit32.band(perm_xi_1 + yi + 1, 255)]

        local aaa = perm[bit32.band(perm_yi + zi, 255)]
        local aba = perm[bit32.band(perm_yi_1 + zi, 255)]
        local aab = perm[bit32.band(perm_yi + zi + 1, 255)]
        local abb = perm[bit32.band(perm_yi_1 + zi + 1, 255)]
        local baa = perm[bit32.band(perm_xi1_yi + zi, 255)]
        local bba = perm[bit32.band(perm_xi1_yi1 + zi, 255)]
        local bab = perm[bit32.band(perm_xi1_yi + zi + 1, 255)]
        local bbb = perm[bit32.band(perm_xi1_yi1 + zi + 1, 255)]
        
        -- Calculate gradients and interpolate
        local x1 = lerp(grad(aaa, x, y, z), grad(baa, x-1, y, z), u)
        local x2 = lerp(grad(aba, x, y-1, z), grad(bba, x-1, y-1, z), u)
        local y1 = lerp(x1, x2, v)
        
        local x1 = lerp(grad(aab, x, y, z-1), grad(bab, x-1, y, z-1), u)
        local x2 = lerp(grad(abb, x, y-1, z-1), grad(bbb, x-1, y-1, z-1), u)
        local y2 = lerp(x1, x2, v)
        
        -- Final result
        local result = (lerp(y1, y2, w) + 1) / 2
        
        -- Store in results array and cache
        results[point.index] = result
        addToCache(point.cacheKey, result)
    end
    
    if self.perfMonitoring then
        local endTime = os.clock()
        perfStats.generationTimeTotal = perfStats.generationTimeTotal + (endTime - startTime)
        perfStats.operationsCount = perfStats.operationsCount + 1
    end
    
    return results
end

-- Generate 2D perlin noise (for heightmaps)
function NoiseGenerator:perlin2D(x, z)
    return self:perlin3D(x, 0, z)
end

-- Generate octaved perlin noise with adaptive octave count (fractal Brownian motion)
function NoiseGenerator:fractal(x, y, z)
    -- Create cache key for fractal noise
    local cacheKey = string.format("f:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%s", 
        x, y, z, self.scale, self.octaves, self.persistence, self.lacunarity, 
        self.adaptiveOctaves and "a" or "f")
    
    -- Check cache first
    if noiseCache[cacheKey] then
        cacheHits = cacheHits + 1
        return noiseCache[cacheKey]
    end
    
    cacheMisses = cacheMisses + 1
    
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0
    
    -- Calculate maximum possible value for normalization
    local effectiveOctaves = self.octaves
    
    if self.adaptiveOctaves then
        -- Calculate how many octaves we actually need based on scale and coordinates
        local detail = math.min(
            (self.scale / math.max(math.abs(x), math.abs(z), 1)), 
            self.scale
        ) / 10
        
        -- Limit octaves adaptively based on detail level needed
        effectiveOctaves = math.min(
            self.octaves, 
            math.max(1, math.ceil(2 + math.log(detail) / math.log(self.lacunarity)))
        )
    end
    
    -- Pre-calculate maximum normalization value
    for i = 1, effectiveOctaves do
        maxValue = maxValue + amplitude
        amplitude = amplitude * self.persistence
    end
    
    -- Reset for actual calculation
    amplitude = 1
    frequency = 1
    
    -- Generate fractal noise with early termination
    for i = 1, effectiveOctaves do
        -- Skip octaves with negligible contribution
        if amplitude / maxValue > MIN_AMPLITUDE_THRESHOLD then
            local noise = self:perlin3D(x * frequency, y * frequency, z * frequency)
            total = total + noise * amplitude
        end
        
        amplitude = amplitude * self.persistence
        frequency = frequency * self.lacunarity
    end
    
    -- Normalize to range [0, 1]
    local result = total / maxValue
    
    -- Cache the result
    addToCache(cacheKey, result)
    
    return result
end

-- NEW: Batch fractal noise generation - processes multiple points at once
function NoiseGenerator:batchFractal(pointsList)
    local results = {}
    local pointsToProcess = {}
    local effectiveOctaves = self.octaves
    
    -- Check cache and collect uncached points
    for i, point in ipairs(pointsList) do
        local x, y, z = point[1], point[2], point[3]
        
        local cacheKey = string.format("f:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%s", 
            x, y, z, self.scale, self.octaves, self.persistence, self.lacunarity,
            self.adaptiveOctaves and "a" or "f")
        
        if noiseCache[cacheKey] then
            results[i] = noiseCache[cacheKey]
            cacheHits = cacheHits + 1
        else
            cacheMisses = cacheMisses + 1
            
            if self.adaptiveOctaves then
                -- Calculate adaptive octaves for this specific point
                local detail = math.min(
                    (self.scale / math.max(math.abs(x), math.abs(z), 1)), 
                    self.scale
                ) / 10
                
                local adaptiveOctaves = math.min(
                    self.octaves, 
                    math.max(1, math.ceil(2 + math.log(detail) / math.log(self.lacunarity)))
                )
                
                table.insert(pointsToProcess, {
                    index = i, x = x, y = y, z = z, 
                    cacheKey = cacheKey,
                    octaves = adaptiveOctaves
                })
            else
                table.insert(pointsToProcess, {
                    index = i, x = x, y = y, z = z, 
                    cacheKey = cacheKey,
                    octaves = self.octaves
                })
            end
        end
    end
    
    -- Process points that need calculation - in batches per octave for efficiency
    if #pointsToProcess > 0 then
        -- Calculate maximum normalization values for different octave counts
        local maxValueByOctave = {}
        
        for _, point in ipairs(pointsToProcess) do
            if not maxValueByOctave[point.octaves] then
                local maxValue = 0
                local amplitude = 1
                
                for i = 1, point.octaves do
                    maxValue = maxValue + amplitude
                    amplitude = amplitude * self.persistence
                end
                
                maxValueByOctave[point.octaves] = maxValue
            end
        end
        
        -- Process each octave in batch for all points that need it
        local octaveResults = {}
        
        -- Group points by effective octave count
        local pointsByOctaveCount = {}
        for _, point in ipairs(pointsToProcess) do
            if not pointsByOctaveCount[point.octaves] then
                pointsByOctaveCount[point.octaves] = {}
            end
            table.insert(pointsByOctaveCount[point.octaves], point)
        end
        
        -- Process each group of points with the same octave count
        for octaveCount, pointGroup in pairs(pointsByOctaveCount) do
            local amplitude = 1
            local frequency = 1
            
            -- Initialize running total for each point
            for _, point in ipairs(pointGroup) do
                octaveResults[point.index] = 0
            end
            
            -- Process each octave with batch perlin noise
            for o = 1, octaveCount do
                -- Skip octaves with negligible contribution
                if amplitude / maxValueByOctave[octaveCount] > MIN_AMPLITUDE_THRESHOLD then
                    -- Prepare batch points for this octave
                    local batchPoints = {}
                    for i, point in ipairs(pointGroup) do
                        batchPoints[i] = {
                            point.x * frequency,
                            point.y * frequency,
                            point.z * frequency
                        }
                    end
                    
                    -- Get noise values for all points in this octave
                    local noiseValues = self:batchPerlin3D(batchPoints)
                    
                    -- Add weighted contribution to running totals
                    for i, point in ipairs(pointGroup) do
                        octaveResults[point.index] = octaveResults[point.index] + 
                                                      noiseValues[i] * amplitude
                    end
                end
                
                -- Prepare for next octave
                amplitude = amplitude * self.persistence
                frequency = frequency * self.lacunarity
            end
            
            -- Normalize and cache results
            for _, point in ipairs(pointGroup) do
                local normalizedValue = octaveResults[point.index] / maxValueByOctave[octaveCount]
                results[point.index] = normalizedValue
                addToCache(point.cacheKey, normalizedValue)
            end
        end
    end
    
    return results
end

-- Generate a heightmap using batched noise calculation for efficiency
function NoiseGenerator:generateHeightmap(centerX, centerZ, width, height, resolution)
    log.info("Generating heightmap: %dx%d at resolution %d", width, height, resolution or 1)
    local startTime = os.clock()
    
    local heightmap = {}
    resolution = resolution or 1
    
    -- Precompute constants
    local halfWidth = width / 2
    local halfHeight = height / 2
    local widthSteps = math.floor(width / resolution)
    local heightSteps = math.floor(height / resolution)
    
    -- Use table.create for pre-allocation where available
    for x = 0, widthSteps do
        heightmap[x] = {}
    end
    
    -- Prepare batches of points for noise generation
    local batchSize = BATCH_PROCESS_LIMIT
    local batchedPoints = {}
    local pointIndices = {}
    local currentBatch = {}
    
    -- Group all points into batches
    for x = 0, widthSteps do
        local worldX = centerX - halfWidth + x * resolution
        
        for z = 0, heightSteps do
            local worldZ = centerZ - halfHeight + z * resolution
            
            table.insert(currentBatch, {worldX, 0, worldZ})
            table.insert(pointIndices, {x = x, z = z})
            
            -- Process in batches to avoid huge arrays
            if #currentBatch >= batchSize then
                table.insert(batchedPoints, currentBatch)
                currentBatch = {}
            end
        end
    end
    
    -- Add any remaining points as final batch
    if #currentBatch > 0 then
        table.insert(batchedPoints, currentBatch)
    end
    
    -- Process each batch
    local pointIndex = 1
    for _, batch in ipairs(batchedPoints) do
        local batchResults = self:batchFractal(batch)
        
        -- Assign results to heightmap
        for i, value in ipairs(batchResults) do
            local indices = pointIndices[pointIndex]
            heightmap[indices.x][indices.z] = value
            pointIndex = pointIndex + 1
        end
        
        -- Yield to prevent script timeout during long operations
        task.wait()
    end
    
    local endTime = os.clock()
    log.info("Heightmap generated in %.3f seconds with %d cache hits, %d misses", 
        endTime - startTime, cacheHits, cacheMisses)
    
    return heightmap
end

-- Generate a 3D noise sample with efficient chunking and batch processing
function NoiseGenerator:generate3DNoise(centerX, centerY, centerZ, width, height, depth, resolution)
    log.info("Generating 3D noise volume: %dx%dx%d", width, height, depth)
    local startTime = os.clock()
    
    local noise = {}
    resolution = resolution or 1
    
    -- Precompute constants
    local halfWidth = width / 2
    local halfHeight = height / 2
    local halfDepth = depth / 2
    local widthSteps = math.floor(width / resolution)
    local heightSteps = math.floor(height / resolution)
    local depthSteps = math.floor(depth / resolution)
    
    -- Generate 3D noise in chunks to improve memory usage
    local CHUNK_SIZE = 16 -- Process in smaller chunks
    
    for xChunk = 0, math.ceil(widthSteps / CHUNK_SIZE) - 1 do
        local xStart = xChunk * CHUNK_SIZE
        local xEnd = math.min(xStart + CHUNK_SIZE, widthSteps)
        
        for x = xStart, xEnd do
            noise[x] = {}
            local worldX = centerX - halfWidth + x * resolution
            
            for yChunk = 0, math.ceil(heightSteps / CHUNK_SIZE) - 1 do
                local yStart = yChunk * CHUNK_SIZE
                local yEnd = math.min(yStart + CHUNK_SIZE, heightSteps)
                
                -- Prepare batch points for this x,y chunk
                local batchPoints = {}
                local pointIndices = {}
                
                for y = yStart, yEnd do
                    noise[x][y] = {}
                    local worldY = centerY - halfHeight + y * resolution
                    
                    for zChunk = 0, math.ceil(depthSteps / CHUNK_SIZE) - 1 do
                        local zStart = zChunk * CHUNK_SIZE
                        local zEnd = math.min(zStart + CHUNK_SIZE, depthSteps)
                        
                        -- Collect points for batch processing
                        for z = zStart, zEnd do
                            local worldZ = centerZ - halfDepth + z * resolution
                            table.insert(batchPoints, {worldX, worldY, worldZ})
                            table.insert(pointIndices, {x = x, y = y, z = z})
                        end
                    end
                end
                
                -- Process the batch of points for this chunk
                if #batchPoints > 0 then
                    local batchResults = self:batchFractal(batchPoints)
                    
                    -- Assign batch results to the 3D noise array
                    for i, value in ipairs(batchResults) do
                        local indices = pointIndices[i]
                        noise[indices.x][indices.y][indices.z] = value
                    end
                end
                
                -- Yield to prevent script timeout
                task.wait()
            end
        end
    end
    
    local endTime = os.clock()
    log.info("3D noise generated in %.3f seconds with %d cache hits, %d misses", 
        endTime - startTime, cacheHits, cacheMisses)
    
    return noise
end

-- Get cache statistics
function NoiseGenerator:getCacheStats()
    return {
        cacheSize = cacheSize,
        hits = cacheHits,
        misses = cacheMisses,
        hitRate = cacheHits / (cacheHits + cacheMisses + 0.0001) * 100
    }
end

-- Get performance statistics 
function NoiseGenerator:getPerfStats()
    if self.perfMonitoring then
        -- Calculate averages and rates
        local avgBatchSize = perfStats.batchSizesSum / math.max(1, perfStats.batchCallsTotal)
        local avgGenTime = perfStats.generationTimeTotal / math.max(1, perfStats.operationsCount)
        
        return {
            noiseCallsTotal = perfStats.noiseCallsTotal,
            batchCallsTotal = perfStats.batchCallsTotal,
            avgBatchSize = avgBatchSize,
            totalGenTime = perfStats.generationTimeTotal,
            avgGenTime = avgGenTime,
            callsPerSecond = perfStats.noiseCallsTotal / math.max(0.001, perfStats.generationTimeTotal)
        }
    else
        return {
            monitoring = "disabled"
        }
    end
end

-- Reset performance statistics
function NoiseGenerator:resetPerfStats()
    perfStats = {
        noiseCallsTotal = 0,
        batchCallsTotal = 0,
        batchSizesSum = 0,
        generationTimeTotal = 0,
        operationsCount = 0
    }
    return self
end

-- Clear the noise cache
function NoiseGenerator:clearCache()
    clearCache()
    return self
end

log.debug("NoiseGenerator module loaded successfully")

return NoiseGenerator 