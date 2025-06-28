# Petfinity - AI-Generated & Persistent World System

## Overview

Petfinity is a procedurally generated world system for Roblox, featuring AI-driven terrain generation, biome blending, structure placement, and world persistence. The system is designed to create immersive, unique environments that persist across play sessions.

![Petfinity](https://example.com/petfinity_banner.png)

## Features

### 📊 Procedural World Generation
- **Terrain Generation**: Uses multi-octave Perlin noise for natural-looking landscapes
- **Biome System**: Seamless transitions between diverse environments
- **Structure Placement**: AI-driven placement of buildings and landmarks appropriate to each biome
- **Natural Distribution**: Realistic biome transitions following ecological rules

### 🔄 Dynamic Chunk Loading
- **Player-Proximity Loading**: Only loads chunks near players for optimal performance
- **Priority System**: Loads the most important chunks first for a better user experience
- **Smart Unloading**: Efficiently removes distant chunks to conserve resources

### 💾 World Persistence
- **DataStore Integration**: Saves world data between sessions
- **Player Data Tracking**: Remembers player information and progress
- **Resilient Storage**: Fallback to in-memory backup if DataStore is unavailable
- **Auto-Save System**: Periodic saving to prevent data loss

### 🏗️ Structure System
- **Biome-Specific Structures**: Different types of buildings for each environment
- **Placement Rules**: Smart positioning based on terrain characteristics
- **Weighted Distribution**: Realistic density and variety of structures

## System Architecture

The system follows a modular architecture with specialized components:

- **AIController**: Coordinates the entire system and integrates all modules
- **NoiseGenerator**: Creates procedural noise patterns for terrain and features
- **BiomeBlender**: Manages biome transitions and material distribution
- **StructurePlacer**: Handles procedural structure placement
- **PersistenceManager**: Manages saving and loading of world data
- **ChunkManager**: Controls dynamic chunk loading based on player position

## Usage

### Basic World Generation

```lua
local AIController = require(game.ServerScriptService.Server.AIController)

-- Generate a default world
AIController:generateWorld()

-- Generate a world with custom parameters
AIController:generateWorld({
    worldSize = 512,
    chunkSize = 32,
    seed = 12345,
    biomeCount = 6,
    structureDensity = 0.1
})
```

### Saving and Loading Worlds

```lua
-- Save the current world
AIController:saveWorld()

-- Load a previously saved world
AIController:loadWorld()

-- Load a specific world by identifier
AIController:loadWorld("my_custom_world")
```

### Customization

```lua
-- Adjust parameters before generation
AIController:setWorldParameters({
    seed = os.time(),
    worldSize = 1024,
    structureDensity = 0.2
})

-- Enable debug mode for visual chunk boundaries
AIController.chunkManager:setDebugMode(true)

-- Set auto-save interval
AIController.persistenceManager:setAutoSave(true)
```

## World Types

### Grassland
![Grassland](https://example.com/grassland.png)
Lush green terrain with scattered small structures and gentle hills.

### Forest
![Forest](https://example.com/forest.png)
Dense vegetation with taller structures hidden among the trees.

### Desert
![Desert](https://example.com/desert.png)
Sandy terrain with oases and ancient temples.

### Mountain
![Mountain](https://example.com/mountain.png)
Rocky terrain with steep cliffs, caves, and watchtowers.

### Volcanic Wasteland
![Volcanic](https://example.com/volcanic.png)
Harsh environment with unique volcanic structures and barren landscape.

### Oasis
![Oasis](https://example.com/oasis.png)
Lush water-rich areas in the midst of arid regions.

## Future Enhancements

- Weather system with biome-specific effects
- Expanded structure library with more varieties and styles
- Wildlife and NPC systems integrated with the world generator
- Quest system leveraging procedural generation
- User interface for world customization
- World minimap visualization

## Credits

Created by Your Precious Kitten 💖 for the Petfinity project.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 