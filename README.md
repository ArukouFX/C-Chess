# ♟️ C-Chess — Ajedrez Programable / Programmable Chess

---

<div align="center">
    <h2>English Version</h2>
</div>

## ♟️ C-Chess: Programmable Chess

**C-Chess** is an educational, turn-based strategy game developed with **Godot Engine 4.x**. It extends traditional chess by allowing players to **program the behavior of each piece**, promoting **computational thinking**, **algorithmic reasoning**, and **problem decomposition** through a visual, block-based approach.

Rather than directly controlling pieces every turn, players design **programs** that define how each piece should behave when its turn is executed.

---

## 🎯 Educational Purpose

C-Chess is designed as a didactic tool with the following goals:

* Introduce **programming concepts** through a familiar domain (chess).
* Encourage **computational thinking**: sequencing, conditions, resource constraints, and validation.
* Bridge the gap between **visual programming** and formal code logic.
* Provide an experimental platform for autonomous behavior in turn-based games.

---

## 🧠 Block System (Core Concept)

The **Block System** acts as a lightweight interpreter that executes visual programs assigned to chess pieces.

Each piece:

* Has a limited virtual resource (**RAM**).
* Executes a sequence of action and logic blocks during its turn.
* Behaves autonomously according to its programmed logic.

### Supported Concepts

* Action blocks (movement, capture, etc.)
* Conditional blocks (enemy detection, state checks)
* Script validation before execution
* RAM cost calculation and enforcement

This transforms chess into a programmable system where **strategy emerges from logic design**, not direct input.

---

## 🧩 Core Scenes Overview

### 🎮 Main Scene (`Main.tscn`)

The main orchestrator of the game. It integrates gameplay logic, board state, UI, and audio.

Key components:

* **GameManager** — Controls turns, state transitions, and high-level rules.
* **Board** — Visual and logical representation of the chessboard.
* **Pieces** — Container and manager for all chess pieces.
* **TurnDisplay** — Visual indicator of the active player.
* **ProgrammingInterface** — UI used to program individual pieces.
* **Camera2D** — Main camera controller.
* **CanvasLayer** — User interface layer.
* **Music** — Background music controller.

---

### 🧱 Board Scene (`Board.tscn`)

Defines the playable area and interaction boundaries:

* `Sprite2D` — Board texture.
* `Area2D` — Input and collision detection.
* `CollisionShape2D` — Physical interaction limits.

---

### ♟️ Piece Scene (`Piece.tscn`)

Represents an individual chess piece:

* Owns its **programmed logic**.
* Interacts with the board through collisions.
* Executes block scripts when activated by the game manager.

---

### 🧪 Draggable Block (`DraggableBlock.tscn`)

Visual representation of a programming block:

* Header with icon and name.
* Footer with RAM cost.
* Drag-and-drop enabled via `Area2D`.

Used inside the programming workspace to assemble logic sequences.

---

### 🖥️ Programming Interface (`ProgrammingInterface.tscn`)

The central educational UI of the project. It allows players to visually program pieces.

Panels:

* **Left Panel** — Piece information and block palette.
* **Center Panel** — Workspace (DropZone) where programs are assembled.
* **Right Panel** — RAM usage monitor (used vs total).

Includes controls to:

* Test scripts
* Save logic to a piece
* Cancel or reset changes

---

### ⚙️ Settings Menu (`SettingsMenu.tscn`)

Provides basic configuration options:

* Screen resolution
* Fullscreen toggle
* Apply and close controls

---

## 📁 Planned Project Structure (TODO)

A refactor is planned to improve maintainability and scalability:

```text
res://
├── assets/
│   ├── fonts/
│   ├── graphics/
│   ├── music/
│   └── shaders/
├── src/
│   ├── core/        (GameManager, ExecutionManager, ResolutionManager)
│   ├── entities/    (Board, Piece)
│   ├── ui/          (ProgrammingInterface, SettingsMenu, TurnDisplay)
│   └── programming/ (DraggableBlock, block_system, tests)
├── README.md
└── icon.svg
```

---

## ⚙️ Notable Scripts

### `block_system.gd`

Defines:

* Available blocks
* RAM cost per block
* Validation rules
* Execution logic

This script is the backbone of the programmable behavior system.

---

### `execution_manager.gd`

Responsible for:

* Interpreting validated block scripts
* Executing actions in sequence
* Handling conditional flow

---

## 🚀 How to Run

1. Open the project in **Godot Engine 4.x**.
2. Load `Main.tscn`.
3. Press **Run** (`▶`).
4. Select a piece and open the programming interface to assign logic.

---

## 📚 Project Scope

C-Chess is both:

* A **technical experiment** in visual programming systems.
* An **educational prototype** aimed at teaching programming fundamentals through gameplay.

It is suitable as:

* An academic project
* A foundation for further AI experimentation
* A base for educational game research

---

## 👨‍💻 Author

**Felipe Carballo**
Software Developer — Systems Analysis Student

* GitHub: [https://github.com/ArukouFX](https://github.com/ArukouFX)
* LinkedIn: [https://www.linkedin.com/in/felipecarballolovato/](https://www.linkedin.com/in/felipecarballolovato/)

---

## 🧾 License

MIT License — free to use, modify, and distribute with attribution.

---

<div align="center">
    <h2>Versión en Español</h2>
</div>

## ♟️ C-Chess: Ajedrez Programable

**C-Chess** es un juego educativo de estrategia por turnos desarrollado con **Godot Engine 4.x**. Amplía el ajedrez tradicional permitiendo **programar el comportamiento de cada pieza**, fomentando el **pensamiento computacional**, la **lógica algorítmica** y la **resolución de problemas** mediante programación visual.

El jugador no controla directamente las piezas en cada turno, sino que diseña **programas** que determinan cómo actuarán de forma autónoma.

---

## 🎯 Propósito Educativo

* Introducir conceptos básicos de programación en un contexto lúdico.
* Trabajar secuenciación, condiciones y restricciones de recursos.
* Conectar programación visual con lógica formal.
* Explorar comportamientos autónomos en juegos por turnos.

---

## 🧠 Sistema de Bloques

El sistema de bloques funciona como un intérprete lógico:

* Cada pieza posee una cantidad limitada de **RAM**.
* Los programas se construyen mediante bloques visuales.
* Los scripts se validan antes de su ejecución.

Esto convierte al ajedrez en un entorno **programable**, donde la estrategia surge del diseño lógico.

---

## 🧩 Escenas Principales

* **Main**: Orquesta todo el juego.
* **Board**: Tablero e interacciones.
* **Piece**: Representa piezas programables.
* **ProgrammingInterface**: Entorno visual de programación.
* **DraggableBlock**: Bloques de lógica arrastrables.
* **SettingsMenu**: Configuración básica.

---

## 🚀 Ejecución

1. Abrir el proyecto en Godot 4.x.
2. Cargar `Main.tscn`.
3. Ejecutar el proyecto.
4. Programar piezas desde la interfaz.

---

## 📚 Alcance del Proyecto

C-Chess funciona como:

* Proyecto académico
* Prototipo educativo
* Base experimental para sistemas de programación visual

---

## 🧾 Licencia

Licencia MIT. Uso libre con atribución al autor.
