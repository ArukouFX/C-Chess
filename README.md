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

* [GitHub]([https://github.com/tu-usuario](https://github.com/ArukouFX))
* [LinkedIn]([https://www.linkedin.com/in/tu-perfil](https://www.linkedin.com/in/felipecarballolovato/))

---

## 🧾 Licencia

Este proyecto se distribuye bajo la **Licencia MIT**. Eres libre de usar, modificar y distribuir el código, siempre que mantengas la atribución al autor original.
