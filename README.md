# ♟️ C-Chess: Ajedrez Programable / Programmable Chess

---
<div align="center">
    <h1>English Version</h1>
</div>


# ♟️ C-Chess: Programmable Chess

**C-Chess** is a turn-based strategy project developed in **Godot Engine 4.x** that combines classic chess mechanics with an innovative **programmable block system**.

The goal is to explore how **visual programming and modular logic** can be integrated to give each piece an autonomous and customizable behavior.

---

## 🧠 Block System (BlockSystem)

This is the project's central logic engine. It functions as an interpreter that:
* Defines and manages action blocks (move, capture, conditions, etc.).
* Assigns virtual resource limits (**"RAM"**) to each piece.
* Allows the creation of **visual scripts** (sequences of blocks) that pieces execute automatically on their turn.

This enables programmable chess where strategies are defined at a modular code level.

---

## 🧩 Project Structure

### 🎮 Main Scene (`Main.tscn`)

Contains the fundamental nodes that orchestrate the game:

* **`_GameManager`**: Core logic (turn management, victory conditions, etc.).
* **`_Table`**: Representation of the chessboard.
* **`_Pieces`**: Contains and manages all pieces in play.
* **`_Turn`**: Controls and displays the current turn.
* **`_BackGround`**: Visual background of the board.
* **`_CanvasLayer`**: Layer for the User Interface (UI).
* **`_Camera`**: Main scene camera.
* **`_Music`**: Background music controller.
* **`_Node (test_block.gd)`**: Auxiliary node used for testing the block system.

---

### 🧱 Secondary Scene (`Board.tscn`)

Defines the playing area and its interactions:

* **`_Board`**: Main board node.
    * `Sprite2D`: Graphical representation.
    * `Area2D`: Detects interactions and collisions.
    * `CollisionShape2D`: Defines the physical interaction area.

---

## ⚙️ Key Scripts

### `test_block.gd`

Testing script focused on verifying the functionality of the **BlockSystem**:

* **Testable Features:**
    * Get block information (`get_block_info`).
    * Filtering by categories (`get_blocks_by_category`).
    * Piece RAM capacity (`get_piece_ram_capacity`).
    * Script RAM usage calculation (`calculate_ram_usage`).
    * Script validation (`is_script_valid`).

* **Test Script Example:**
    ```gdscript
    var test_script = [
        {"type": "move_forward"},
        {"type": "if_enemy_front"}, 
        {"type": "capture"}
    ]
    ```

### `turn_display.gd`

Controls the visualization and animation of the current turn:

* Shows which player has the turn (**white** or **black**).
* Applies a cyclical visual animation to add dynamism to the turn indicator.

* **Update Function:**
    ```gdscript
    func update_turn(turn: String):
        if turn == "white":
            texture = load("res://Assets/turn-white.png")
        else:
            texture = load("res://Assets/turn-black.png")
    ```

---

## 🚀 How to Run the Project

1.  Open the project in **Godot Engine 4.x**.
2.  Load the main scene `Main.tscn`.
3.  Press the **Run** button (`▶️ Run`).
4.  Use the console to see the results of the `test_block.gd` tests.

---

## 📚 Project Goals

* Integrate modular logic (blocks) into a classic strategy game.
* Experiment with basic **Artificial Intelligence (AI)** by creating visual scripts for the pieces.
* Develop a scalable and maintainable architecture for future turn-based strategy games.

---

## 👨‍💻 Author

**Felipe Carballo**
Software Developer and Systems Analysis student.

* [GitHub](https://github.com/ArukouFX)
* [LinkedIn](https://www.linkedin.com/in/felipecarballolovato/)

---

## 🧾 License

This project is distributed under the **MIT License**. You are free to use, modify, and distribute the code, provided you retain attribution to the original author.

---
---
<div align="center">
    <h1>Versión en Español</h1>
</div>
---
---

# ♟️ C-Chess: Ajedrez Programable

**C-Chess** es un proyecto de estrategia por turnos desarrollado en **Godot Engine 4.x** que combina las mecánicas clásicas del ajedrez con un innovador **sistema de bloques programables**.

El objetivo es explorar cómo la **programación visual y la lógica modular** pueden integrarse para dar a cada pieza un comportamiento autónomo y personalizable.

---

## 🧠 Sistema de Bloques (BlockSystem)

Este es el motor lógico central del proyecto. Funciona como un intérprete que:
* Define y gestiona bloques de acción (mover, capturar, condiciones, etc.).
* Asigna límites de recursos virtuales (**"RAM"**) a cada pieza.
* Permite crear **scripts visuales** (secuencias de bloques) que las piezas ejecutan automáticamente en su turno.

Esto permite un ajedrez programable donde las estrategias se definen a nivel de código modular.

---

## 🧩 Estructura Principal del Proyecto

### 🎮 Escena Principal (`Main.tscn`)

Contiene los nodos fundamentales que orquestan el juego:

* **`_GameManager`**: Lógica principal (gestión de turnos, condiciones de victoria, etc.).
* **`_Table`**: Representación del tablero de ajedrez.
* **`_Pieces`**: Contiene y gestiona todas las piezas en juego.
* **`_Turn`**: Controla y muestra el turno actual.
* **`_BackGround`**: Fondo visual del tablero.
* **`_CanvasLayer`**: Capa para la interfaz de usuario (UI).
* **`_Camera`**: Cámara principal de la escena.
* **`_Music`**: Controlador de música de fondo.
* **`_Node (test_block.gd)`**: Nodo auxiliar utilizado para pruebas del sistema de bloques.

---

### 🧱 Escena Secundaria (`Board.tscn`)

Define el área de juego y sus interacciones:

* **`_Board`**: Nodo principal del tablero.
    * `Sprite2D`: Representación gráfica.
    * `Area2D`: Detecta interacciones y colisiones.
    * `CollisionShape2D`: Define el área física de interacción.

---

## ⚙️ Scripts Clave

### `test_block.gd`

Script de prueba enfocado en verificar la funcionalidad del **BlockSystem**:

* **Funcionalidades testeables:**
    * Obtener información de bloques (`get_block_info`).
    * Filtrado por categorías (`get_blocks_by_category`).
    * Capacidad de memoria RAM de las piezas (`get_piece_ram_capacity`).
    * Cálculo del uso de RAM en scripts (`calculate_ram_usage`).
    * Validación de scripts (`is_script_valid`).

* **Ejemplo de Script de Prueba:**
    ```gdscript
    var test_script = [
        {"type": "move_forward"},
        {"type": "if_enemy_front"}, 
        {"type": "capture"}
    ]
    ```

### `turn_display.gd`

Controla la visualización y animación del turno actual:

* Muestra qué jugador tiene el turno (**blanco** o **negro**).
* Aplica una animación visual cíclica para dar dinamismo al indicador de turno.

* **Función de Actualización:**
    ```gdscript
    func update_turn(turn: String):
        if turn == "white":
            texture = load("res://Assets/turn-white.png")
        else:
            texture = load("res://Assets/turn-black.png")
    ```

---

## 🚀 Cómo Ejecutar el Proyecto

1.  Abre el proyecto en **Godot Engine 4.x**.
2.  Carga la escena principal `Main.tscn`.
3.  Presiona el botón de **Ejecutar** (`▶️ Run`).
4.  Usa la consola para ver los resultados de las pruebas de `test_block.gd`.

---

## 📚 Objetivos del Proyecto

* Integrar lógica modular (bloques) en un juego clásico de estrategia.
* Experimentar con **Inteligencia Artificial (IA) básica** mediante la creación de scripts visuales para las piezas.
* Desarrollar una arquitectura escalable y mantenible para futuros juegos de estrategia por turnos.

---

## 👨‍💻 Autor

**Felipe Carballo**
Desarrollador de software y estudiante de Análisis de Sistemas.

* [GitHub](https://github.com/ArukouFX)
* [LinkedIn](https://www.linkedin.com/in/felipecarballolovato/)

---

## 🧾 Licencia

Este proyecto se distribuye bajo la **Licencia MIT**. Eres libre de usar, modificar y distribuir el código, siempre que mantengas la atribución al autor original.
