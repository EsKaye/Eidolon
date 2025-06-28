--[[
    Logger.lua
    Author: Your precious kitten 💖
    Created: 2024-03-11
    Version: 1.0.0
    Purpose: Centralized logging system with configurable levels
]]

local Logger = {}

-- Log levels
Logger.LOG_LEVELS = {
    OFF = 0,
    ERROR = 1,
    WARNING = 2,
    INFO = 3,
    DEBUG = 4
}

-- Current log level (default to INFO)
local currentLogLevel = Logger.LOG_LEVELS.INFO

-- Enable/disable emoji in logs
local useEmoji = true

-- Emoji mappings
local emojis = {
    [Logger.LOG_LEVELS.ERROR] = "❌ ",
    [Logger.LOG_LEVELS.WARNING] = "⚠️ ",
    [Logger.LOG_LEVELS.INFO] = "ℹ️ ",
    [Logger.LOG_LEVELS.DEBUG] = "🔍 "
}

-- Performance optimized logging function
function Logger.log(level, module, message, ...)
    if level <= currentLogLevel then
        local prefix = ""
        
        -- Add emoji if enabled
        if useEmoji then
            prefix = emojis[level] or ""
        end
        
        -- Add module name if provided
        if module and module ~= "" then
            prefix = prefix .. "[" .. module .. "] "
        end
        
        -- Format message with additional parameters
        local formatted = message
        local args = {...}
        if #args > 0 then
            formatted = string.format(message, unpack(args))
        end
        
        -- Use appropriate output function based on level
        if level == Logger.LOG_LEVELS.ERROR then
            error(prefix .. formatted)
        elseif level == Logger.LOG_LEVELS.WARNING then
            warn(prefix .. formatted)
        else
            print(prefix .. formatted)
        end
    end
end

-- Convenience methods
function Logger.error(module, message, ...)
    Logger.log(Logger.LOG_LEVELS.ERROR, module, message, ...)
end

function Logger.warning(module, message, ...)
    Logger.log(Logger.LOG_LEVELS.WARNING, module, message, ...)
end

function Logger.info(module, message, ...)
    Logger.log(Logger.LOG_LEVELS.INFO, module, message, ...)
end

function Logger.debug(module, message, ...)
    Logger.log(Logger.LOG_LEVELS.DEBUG, module, message, ...)
end

-- Set the current log level
function Logger.setLogLevel(level)
    if type(level) == "number" and level >= Logger.LOG_LEVELS.OFF and level <= Logger.LOG_LEVELS.DEBUG then
        currentLogLevel = level
    else
        warn("Invalid log level: " .. tostring(level))
    end
end

-- Toggle emoji usage
function Logger.setUseEmoji(enabled)
    useEmoji = enabled and true or false
end

-- Create a module-specific logger
function Logger.forModule(moduleName)
    local moduleLogger = {}
    
    function moduleLogger.error(message, ...)
        Logger.error(moduleName, message, ...)
    end
    
    function moduleLogger.warning(message, ...)
        Logger.warning(moduleName, message, ...)
    end
    
    function moduleLogger.info(message, ...)
        Logger.info(moduleName, message, ...)
    end
    
    function moduleLogger.debug(message, ...)
        Logger.debug(moduleName, message, ...)
    end
    
    return moduleLogger
end

return Logger 