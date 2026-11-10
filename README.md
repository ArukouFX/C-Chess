# C-Chess: Ajedrez Programable / Programmable Chess

[English](#english-version) | [Español](#versión-en-español)

---

## English Version

**C-Chess** is an educational, turn-based strategy game built with **Godot Engine 4.3** (Blazium 4.3.2). Instead of moving pieces directly, players **program** each piece with visual blocks, similar to Scratch. Every piece has a limited amount of memory (**RAM**), so players must plan, sequence and compress their programs.

The project was developed as a final degree project (TCC). Its goal is to practice **computational thinking**: sequencing, abstraction (loops), resource management and debugging, inside a familiar game.

### Game modes

- **Play against the bot**, with three difficulty levels (Easy, Normal, Hard).
- **Local multiplayer**: two players on the same computer.
- **Tutorial**: 9 guided levels that introduce each rule.
- **Challenges**: 5 puzzles, from RAM compression to checkmate.

### How to play

1. Click one of your pieces to open the programming interface.
2. Drag movement blocks into the workspace. The board shows a **preview** of the path: each step is numbered, captures are marked in red and invalid moves with a cross.
3. Press **Execute**. The piece runs its program and the turn passes to the opponent.
4. Capture the enemy king to win.

### Rules

**RAM per piece.** Every piece uses the same eight movement blocks. They differ only in memory:

| Piece | Pawn | King | Knight | Bishop | Rook | Queen |
|---|---|---|---|---|---|---|
| RAM | 8 | 12 | 16 | 20 | 24 | 32 |

**Incremental cost.** A block costs its base value (2 for straight moves, 3 for diagonals) plus 1 for each block placed before it. Three "Forward" blocks cost 2 + 3 + 4 = 9.

**Loops.** A loop groups a sequence into a single block. It costs what its contents cost and takes only one place in the queue, so long sequences become cheaper. Loops can be nested.

**Escape protocol.** A one-use protection. When the piece is about to be captured, it moves one block away. The escape fails if the destination is occupied or outside the board.

**Execution.** Leaving the board or running into an ally stops the program. A capture ends it. The knight is the only piece that can pass over allies, but it cannot end its move on one.

### Running the project

1. Install **Godot 4.3** or **Blazium 4.3.2**.
2. Clone the repository and open `project.godot`.
3. Press **Run**. The game starts at the main menu (`src/ui/menus/MainMenu.tscn`).

### Tests

The project includes 188 automated tests written with [GUT](https://github.com/bitwes/Gut), located in `src/test/unit/`. They cover the block system, the bot, challenges, menus and full simulated games. One test also checks that the path preview always matches the real execution.

Run them from the GUT panel in the editor, or from the command line:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://src/test/unit -gexit
```

### Project structure

```
src/
  core/          Game manager, global configuration, saving, music, resolution
  entities/      Board, pieces and the path preview
  programming/   Block system, draggable blocks, program simulation
  IA/            Bot (threat map, look-ahead, loops, difficulty levels)
  challenge/     Challenge database and challenge mode
  tutorial/      Tutorial levels
  ui/            Menus, programming interface and HUD
  scenes/        Base game scene (inherited by tutorial and challenges)
  test/          Automated tests
assets/          Graphics, fonts, music and shaders
addons/gut/      Testing framework
```

### Author

**Felipe Carballo**
Software developer and Systems Analysis student.

- [GitHub](https://github.com/ArukouFX)
- [LinkedIn](https://www.linkedin.com/in/felipecarballolovato/)

### License

Distributed under the **MIT License**. See the `LICENSE` file for details.

---

## Versión en Español

**C-Chess** es un juego educativo de estrategia por turnos desarrollado con **Godot Engine 4.3** (Blazium 4.3.2). En lugar de mover las piezas directamente, los jugadores **programan** cada pieza con bloques visuales, de forma similar a Scratch. Cada pieza tiene una cantidad limitada de memoria (**RAM**), por lo que hay que planificar, ordenar y comprimir los programas.

El proyecto se desarrolló como Trabajo de Conclusión de Curso (TCC). Su objetivo es ejercitar el **pensamiento computacional** dentro de un juego conocido: secuenciación, abstracción (loops), gestión de recursos y depuración.

### Modos de juego

- **Partida contra el bot**, con tres niveles de dificultad (Fácil, Normal, Difícil).
- **Multijugador local**: dos jugadores en la misma computadora.
- **Tutorial**: 9 niveles guiados que presentan cada regla.
- **Desafíos**: 5 problemas, desde la compresión de RAM hasta el jaque mate.

### Cómo se juega

1. Haz clic en una de tus piezas para abrir la interfaz de programación.
2. Arrastra bloques de movimiento al área de trabajo. El tablero muestra una **vista previa** del recorrido: cada paso aparece numerado, las capturas se marcan en rojo y los movimientos inválidos con una cruz.
3. Pulsa **Ejecutar**. La pieza ejecuta su programa y el turno pasa al rival.
4. Captura al rey enemigo para ganar.

### Reglas

**RAM por pieza.** Todas las piezas usan los mismos ocho bloques de movimiento. Solo se diferencian en la memoria:

| Pieza | Peón | Rey | Caballo | Alfil | Torre | Reina |
|---|---|---|---|---|---|---|
| RAM | 8 | 12 | 16 | 20 | 24 | 32 |

**Costo incremental.** Un bloque cuesta su valor base (2 en línea recta, 3 en diagonal) más 1 por cada bloque que tenga antes en la cola. Tres bloques "Adelante" cuestan 2 + 3 + 4 = 9.

**Loops.** Un loop agrupa una secuencia en un solo bloque. Cuesta lo mismo que su contenido y ocupa un solo lugar en la cola, así que las secuencias largas salen más baratas. Los loops se pueden anidar.

**Protocolo de escape.** Una protección de un solo uso: cuando la pieza va a ser capturada, se mueve un bloque. El escape falla si la casilla de destino está ocupada o fuera del tablero.

**Ejecución.** Salir del tablero o chocar con un aliado detiene el programa, y una captura lo termina. El caballo es la única pieza que puede atravesar aliados, pero no puede terminar su movimiento sobre uno.

### Cómo ejecutar el proyecto

1. Instala **Godot 4.3** o **Blazium 4.3.2**.
2. Clona el repositorio y abre `project.godot`.
3. Pulsa **Ejecutar**. El juego empieza en el menú principal (`src/ui/menus/MainMenu.tscn`).

### Tests

El proyecto incluye 188 tests automáticos escritos con [GUT](https://github.com/bitwes/Gut), ubicados en `src/test/unit/`. Cubren el sistema de bloques, el bot, los desafíos, los menús y partidas simuladas completas. Uno de ellos comprueba además que la vista previa del recorrido coincide siempre con la ejecución real.

Se ejecutan desde el panel de GUT en el editor o desde la terminal:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://src/test/unit -gexit
```

### Estructura del proyecto

```
src/
  core/          Gestor de partida, configuración global, guardado, música, resolución
  entities/      Tablero, piezas y vista previa del recorrido
  programming/   Sistema de bloques, bloques arrastrables, simulación de programas
  IA/            Bot (mapa de amenazas, mirada adelante, loops, niveles de dificultad)
  challenge/     Base de desafíos y modo desafío
  tutorial/      Niveles del tutorial
  ui/            Menús, interfaz de programación y HUD
  scenes/        Escena base de la partida (la heredan el tutorial y los desafíos)
  test/          Tests automáticos
assets/          Gráficos, fuentes, música y shaders
addons/gut/      Framework de tests
```

### Autor

**Felipe Carballo**
Desarrollador de software y estudiante de Análisis de Sistemas.

- [GitHub](https://github.com/ArukouFX)
- [LinkedIn](https://www.linkedin.com/in/felipecarballolovato/)

### Licencia

Se distribuye bajo la **Licencia MIT**. Consulta el archivo `LICENSE` para más detalles.
