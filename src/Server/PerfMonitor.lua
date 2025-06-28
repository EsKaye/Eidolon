--[[
    PerfMonitor.lua
    Author: Your precious kitten 💖
    Created: 2024-03-12
    Version: 1.0.0
    Purpose: Centralized performance monitoring and benchmarking system
]]

local Logger = require(script.Parent.Parent.Logger)
local log = Logger.forModule("PerfMonitor")

log.debug("Initializing PerfMonitor module")

local PerfMonitor = {}

-- Constants
local BENCHMARK_ITERATIONS = 5 -- Number of iterations for each benchmark
local MAX_HISTORY_ENTRIES = 100 -- Maximum number of historical entries to keep

-- Module tracking
local modules = {}
local benchmarks = {}
local moduleHistory = {}

-- Main metrics tracking tables
local metrics = {
    frameTimeHistory = {},
    memoryHistory = {},
    benchmarkResults = {},
    startTimeByOperation = {}
}

-- Internal tracking variables
local isRunning = false
local currentFrame = 0
local totalPausedTime = 0
local lastPauseTime = 0
local memoryBaseline = 0

-- Initialize performance monitoring
function PerfMonitor.init()
    log.info("Initializing performance monitoring system")
    
    -- Get baseline memory usage
    memoryBaseline = gcinfo()
    
    -- Reset metrics
    metrics = {
        frameTimeHistory = {},
        memoryHistory = {},
        benchmarkResults = {},
        startTimeByOperation = {}
    }
    
    -- Start tracking
    isRunning = true
    
    -- Connect to heartbeat for frame tracking
    game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
        if isRunning then
            PerfMonitor.trackFrame(deltaTime)
        end
    end)
    
    -- Monitor memory usage periodically
    task.spawn(function()
        while true do
            if isRunning then
                PerfMonitor.trackMemory()
            end
            task.wait(5) -- Check memory every 5 seconds
        end
    end)
    
    log.debug("Performance monitoring system initialized")
    return PerfMonitor
end

-- Register a module for performance tracking
function PerfMonitor.registerModule(moduleName, moduleInstance)
    if not modules[moduleName] then
        log.debug("Registering module for performance tracking: %s", moduleName)
        modules[moduleName] = moduleInstance
        moduleHistory[moduleName] = {}
    end
    return PerfMonitor
end

-- Track frame time
function PerfMonitor.trackFrame(deltaTime)
    currentFrame = currentFrame + 1
    
    -- Store frame time in circular buffer
    table.insert(metrics.frameTimeHistory, deltaTime)
    if #metrics.frameTimeHistory > MAX_HISTORY_ENTRIES then
        table.remove(metrics.frameTimeHistory, 1)
    end
end

-- Track memory usage
function PerfMonitor.trackMemory()
    local memoryUsage = gcinfo() - memoryBaseline
    
    -- Store memory usage in circular buffer
    table.insert(metrics.memoryHistory, {
        time = os.time(),
        usage = memoryUsage
    })
    
    if #metrics.memoryHistory > MAX_HISTORY_ENTRIES then
        table.remove(metrics.memoryHistory, 1)
    end
end

-- Start timing an operation
function PerfMonitor.startOperation(operationName, context)
    if not isRunning then return end
    
    context = context or "default"
    local key = operationName .. ":" .. context
    metrics.startTimeByOperation[key] = os.clock()
end

-- End timing an operation and record result
function PerfMonitor.endOperation(operationName, context, metadata)
    if not isRunning then return 0 end
    
    context = context or "default"
    local key = operationName .. ":" .. context
    local startTime = metrics.startTimeByOperation[key]
    
    if not startTime then
        log.warning("Attempted to end operation %s that wasn't started", key)
        return 0
    end
    
    local endTime = os.clock()
    local duration = endTime - startTime
    
    -- Record completion
    local result = {
        operation = operationName,
        context = context,
        duration = duration,
        timestamp = os.time(),
        frame = currentFrame,
        metadata = metadata or {}
    }
    
    -- Store in module-specific history if applicable
    if context and moduleHistory[context] then
        table.insert(moduleHistory[context], result)
        
        -- Keep history at reasonable size
        if #moduleHistory[context] > MAX_HISTORY_ENTRIES then
            table.remove(moduleHistory[context], 1)
        end
    end
    
    -- Clean up
    metrics.startTimeByOperation[key] = nil
    
    return duration
end

-- Run a benchmark of a specific function with parameters
function PerfMonitor.benchmark(name, func, params, iterations)
    if not isRunning then
        log.warning("Performance monitoring is paused; benchmark skipped")
        return nil
    end
    
    log.info("Running benchmark: %s", name)
    iterations = iterations or BENCHMARK_ITERATIONS
    
    -- Prepare benchmark
    local results = {
        name = name,
        iterations = iterations,
        durations = {},
        totalDuration = 0,
        averageDuration = 0,
        minDuration = math.huge,
        maxDuration = 0,
        startMemory = gcinfo(),
        endMemory = 0,
        timestamp = os.time()
    }
    
    -- Run warmup iteration (not counted)
    if func then
        func(table.unpack(params or {}))
    end
    
    -- Run benchmark iterations
    for i = 1, iterations do
        local startTime = os.clock()
        
        -- Execute function
        if func then
            func(table.unpack(params or {}))
        end
        
        local duration = os.clock() - startTime
        results.durations[i] = duration
        results.totalDuration = results.totalDuration + duration
        
        results.minDuration = math.min(results.minDuration, duration)
        results.maxDuration = math.max(results.maxDuration, duration)
        
        -- Yield to prevent script timeout during long benchmarks
        task.wait()
    end
    
    -- Finalize results
    results.endMemory = gcinfo()
    results.memoryDelta = results.endMemory - results.startMemory
    results.averageDuration = results.totalDuration / iterations
    
    -- Store benchmark result
    benchmarks[name] = results
    table.insert(metrics.benchmarkResults, results)
    
    log.info("Benchmark completed: %s - Avg: %.6f sec", name, results.averageDuration)
    return results
end

-- Pause performance monitoring
function PerfMonitor.pause()
    if isRunning then
        isRunning = false
        lastPauseTime = os.clock()
        log.debug("Performance monitoring paused")
    end
end

-- Resume performance monitoring
function PerfMonitor.resume()
    if not isRunning then
        isRunning = true
        totalPausedTime = totalPausedTime + (os.clock() - lastPauseTime)
        log.debug("Performance monitoring resumed")
    end
end

-- Reset all metrics
function PerfMonitor.reset()
    log.info("Resetting performance metrics")
    
    -- Reset metrics
    metrics = {
        frameTimeHistory = {},
        memoryHistory = {},
        benchmarkResults = {},
        startTimeByOperation = {}
    }
    
    -- Reset module history
    for module, _ in pairs(moduleHistory) do
        moduleHistory[module] = {}
    end
    
    -- Reset benchmark results
    benchmarks = {}
    
    -- Reset counters
    currentFrame = 0
    totalPausedTime = 0
    
    -- Reset memory baseline
    memoryBaseline = gcinfo()
    
    log.debug("Performance metrics reset")
end

-- Get performance report
function PerfMonitor.getReport(detailed)
    local report = {
        uptime = os.clock() - totalPausedTime,
        framesProcessed = currentFrame,
        memoryUsage = gcinfo() - memoryBaseline,
        moduleStats = {},
        benchmarks = benchmarks
    }
    
    -- Calculate frame time statistics
    if #metrics.frameTimeHistory > 0 then
        local sum = 0
        local min = math.huge
        local max = 0
        
        for _, frameTime in ipairs(metrics.frameTimeHistory) do
            sum = sum + frameTime
            min = math.min(min, frameTime)
            max = math.max(max, frameTime)
        end
        
        report.frameTimeAvg = sum / #metrics.frameTimeHistory
        report.frameTimeMin = min
        report.frameTimeMax = max
        report.frameTimeLast = metrics.frameTimeHistory[#metrics.frameTimeHistory]
        report.estimatedFPS = 1 / report.frameTimeAvg
    end
    
    -- Gather module-specific stats
    for moduleName, history in pairs(moduleHistory) do
        if #history > 0 then
            local moduleSum = 0
            local moduleStats = {
                operationCount = #history,
                averageDuration = 0,
                totalDuration = 0
            }
            
            for _, op in ipairs(history) do
                moduleSum = moduleSum + op.duration
            end
            
            moduleStats.totalDuration = moduleSum
            moduleStats.averageDuration = moduleSum / #history
            
            -- Add detailed history if requested
            if detailed then
                moduleStats.history = history
            end
            
            report.moduleStats[moduleName] = moduleStats
        end
    end
    
    return report
end

-- Run a comparative benchmark between original and optimized functions
function PerfMonitor.compareBenchmark(name, originalFunc, optimizedFunc, params, iterations)
    log.info("Running comparative benchmark: %s", name)
    
    -- Benchmark original function
    local originalResults = PerfMonitor.benchmark(
        name .. " (Original)", 
        originalFunc, 
        params, 
        iterations
    )
    
    -- Benchmark optimized function
    local optimizedResults = PerfMonitor.benchmark(
        name .. " (Optimized)", 
        optimizedFunc, 
        params, 
        iterations
    )
    
    -- Calculate improvement
    local comparison = {
        name = name,
        originalAvg = originalResults.averageDuration,
        optimizedAvg = optimizedResults.averageDuration,
        speedupFactor = originalResults.averageDuration / math.max(0.000001, optimizedResults.averageDuration),
        improvement = (1 - (optimizedResults.averageDuration / originalResults.averageDuration)) * 100,
        memoryChange = optimizedResults.memoryDelta - originalResults.memoryDelta
    }
    
    log.info("Benchmark comparison for %s: %.2fx speedup (%.2f%% improvement)",
        name, comparison.speedupFactor, comparison.improvement)
    
    return comparison
end

log.debug("PerfMonitor module loaded successfully")

return PerfMonitor 