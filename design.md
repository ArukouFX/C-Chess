# Chess Game Architecture

## Overview
This document outlines the architecture of the chess game developed using Godot. The game is structured into several components, each responsible for specific functionalities.

## Main Components

### 1. Core
The core of the game is composed of several scripts that manage the game's state and logic.

- **game_manager.gd**: Manages the overall game state, including game initialization, turn management, and game end conditions.
- **turn_display.gd**: Handles the display and management of the turn indicator.
- **ResolutionManager.gd**: Manages the resolution and screen scaling.

### 2. Entities
Entities represent the game objects and their behaviors.

- **board/BoardManager.gd**: Manages the board state, including piece placement and movement.
- **pieces/piece.gd**: Manages the behavior of individual pieces, including movement rules and interactions.

### 3. Programming
The programming system allows players to create custom logic for their pieces.

- **block_system.gd**: Manages the block system, which is used to create custom logic.
- **draggable_block.gd**: Manages the draggable blocks used in the programming interface.

### 4. User Interface
The user interface (UI) is responsible for displaying the game to the player and handling user input.

- **menus/MianMenu.tscn**: The main menu scene.
- **menus/SettingsMenu.tscn**: The settings menu scene.
- **hud/back_ground.gd**: Manages the background of the HUD.
- **programming/programming_interface.tscn**: The programming interface scene.

### 5. Assets
Assets include all the visual and audio resources used in the game.

- **graphics/**: Contains all the visual assets, including sprites, backgrounds, and shaders.
- **music/**: Contains the game's music.

## File Structure
The project is organized into several directories, each containing related files.

- **assets/**: Contains all the assets used in the game.
- **src/**: Contains the source code of the game.
  - **IA/**: Contains the scripts for the AI system.
  - **core/**: Contains the core scripts that manage the game's state and logic.
  - **entities/**: Contains the scripts that manage game objects and their behaviors.
  - **programming/**: Contains the scripts that manage the programming system.
  - **ui/**: Contains the scripts and scenes that manage the user interface.
- **main.gd**: The main script that initializes the game.
- **main.tscn**: The main scene that loads the game.

## Dependencies
The game depends on several Godot modules and features, including:

- **GDScript**: The scripting language used for the game logic.
- **Scene Trees**: The scene management system used to organize the game's objects.
- **Shaders**: Custom shaders used for visual effects.

## Conclusion
This architecture provides a clear separation of concerns, making it easier to manage and extend the game. Each component is responsible for a specific aspect of the game, and changes can be made to individual components without affecting the rest of the game.

## Reglas de Desarrollo (IA)
1. **Solo GDScript:** Escribir código únicamente en archivos `.gd`.
2. **NUNCA tocar escenas:** No crear ni modificar archivos `.tscn`. La IA no debe intentar enlazar nodos, el desarrollador lo hará manualmente en el editor de Godot.
3. **Tipado Estático:** Usar tipado estricto en variables y retornos de funciones (ej. `var speed: float = 100.0`, `func move() -> void:`).
4. **Respetar Arquitectura:** Las nuevas piezas deben heredar e integrarse con `entities/pieces/piece.gd`.