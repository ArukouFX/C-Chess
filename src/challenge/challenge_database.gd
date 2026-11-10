extends Node
class_name ChallengeDatabase

# Formato de cada desafio
# -----------------------
# player_pieces / enemy_pieces: {"type", "coord", "role"} y opcionalmente:
#     "locked": true     -> la pieza no se puede programar
#     "escape": [bloques] -> protocolo de escape asignado al cargar el desafio.
#                           A diferencia de los del jugador, es permanente: no
#                           se consume al escapar.
#                           Se mantiene activo durante todo el desafio.
# enemy_script: un programa por turno enemigo -> {"piece_role", "blocks"}
# win_condition / lose_condition:
#     {"type": "piece_at_position", "role", "coord"}
#     {"type": "piece_captured", "role", "by_role" (opcional)}
#     {"type": "king_captured"}                 -> solo el rey negro
#     {"type": "survive_turns"} / {"type": "turns_exceeded"}  -> por conteo de turnos
#     {"type": "any", "conditions": [...]}     -> alcanza con que se cumpla una
#     {"type": "all", "conditions": [...]}     -> se tienen que cumplir todas
#
# Direcciones del guion enemigo (negras, vectores absolutos del tablero):
#     move_f = abajo, move_b = arriba, move_l = izquierda, move_r = derecha
#     move_fl = abajo-izquierda, move_fr = abajo-derecha
#
# Regla de RAM: cada bloque cuesta su valor base mas 1 por cada bloque que tenga
# antes en la cola. Total = suma de bases + n * (n - 1) / 2.

# Constante: en Godot 4 los arreglos y diccionarios constantes son de solo
# lectura. Cualquier intento de escribir estado de ejecucion aca da error en
# vez de ensuciar los datos para el resto de la sesion. El estado de cada
# intento vive en ChallengeManager.
const CHALLENGES: Array = [
	# 1. Loops y costo por posicion.
	# 7 "Adelante" cuestan 35. Con un solo loop el minimo es 26, hacen falta dos.
	# Soluciones: Loop(2)+Loop(2)+Loop(3) = 22, Loop(3)+Loop(3)+Adelante = 23,
	# Loop(4)+Loop(3) = 24.
	{
		"id": "ram_efficiency_2",
		"title": "Compresión de memoria",
		"instruction": "Capturá al peón de la esquina en un solo turno: \nla torre está a 7 pasos hacia adelante y tiene 24 de RAM. \nCada bloque cuesta su valor base más 1 por cada bloque \nque tenga antes en la cola: 7 'Adelante' cuestan 35. \nUn Loop ocupa un solo lugar en la cola. \nAgrupá el camino en loops para que entre.",
		"category": "efficiency",
		"player_pieces": [
			{"type": "white_tower", "coord": Vector2(0, 7), "role": "target"}
		],
		"enemy_pieces": [
			{"type": "black_pawn", "coord": Vector2(0, 0), "role": "victim"}
		],
		"enemy_script": [],
		"max_turns": 1,
		"win_condition": {"type": "piece_captured", "role": "victim", "by_role": "target"},
		"lose_condition": {"type": "turns_exceeded"}
	},
	# 2. El escape detiene al atacante.
	# Turno 1: solo un escape (no a los costados ni hacia atras). La torre se frena
	# en (3,6). Turno 2: el peon la captura con un bloque.
	{
		"id": "escape_2",
		"title": "El escudo",
		"instruction": "La torre enemiga va a bajar 5 casillas por la columna de tu peón. \nSi el peón se aparta, la torre sigue de largo y captura a tu rey. \nSi se queda sin protección, lo captura a él. \nUn atacante que choca contra un escape se frena en la casilla \nque atacó: usalo para detener la torre y capturala en el turno siguiente.",
		"category": "escape",
		"player_pieces": [
			{"type": "white_pawn", "coord": Vector2(3, 6), "role": "target"},
			{"type": "white_pawn", "coord": Vector2(2, 6), "role": "wall_left", "locked": true},
			{"type": "white_pawn", "coord": Vector2(4, 6), "role": "wall_right", "locked": true},
			{"type": "white_king", "coord": Vector2(3, 7), "role": "king", "locked": true}
		],
		"enemy_pieces": [
			{"type": "black_tower", "coord": Vector2(3, 2), "role": "threat"}
		],
		"enemy_script": [
			{"piece_role": "threat", "blocks": [
				{"type": "move_f"}, {"type": "move_f"}, {"type": "move_f"},
				{"type": "move_f"}, {"type": "move_f"}
			]}
		],
		"max_turns": 2,
		"win_condition": {"type": "piece_captured", "role": "threat", "by_role": "target"},
		"lose_condition": {"type": "any", "conditions": [
			{"type": "piece_captured", "role": "target"},
			{"type": "piece_captured", "role": "king"}
		]}
	},
	# 3. Salto del caballo con RAM exacta.
	# Distancia 4 hasta (3,3): 4 bloques con exactamente 2 diagonales = 16.
	# Ejemplo: Adelante, Diag. Adel. Der., Diag. Adel. Der., Adelante.
	{
		"id": "horse_1",
		"title": "Salto exacto",
		"instruction": "Al final del turno, el alfil enemigo va a bajar en diagonal \ny capturar tu peón de la izquierda. Capturalo antes con el caballo. \nTus peones bloquean la salida, pero el caballo puede atravesar aliados \nsi todavía le quedan instrucciones (no puede terminar sobre uno). \nTiene 16 de RAM: no le sobra nada.",
		"category": "movement",
		"player_pieces": [
			{"type": "white_horse", "coord": Vector2(1, 7), "role": "target"},
			{"type": "white_pawn", "coord": Vector2(0, 6), "role": "wall_a", "locked": true},
			{"type": "white_pawn", "coord": Vector2(1, 6), "role": "wall_b", "locked": true},
			{"type": "white_pawn", "coord": Vector2(2, 6), "role": "wall_c", "locked": true},
			{"type": "white_pawn", "coord": Vector2(3, 6), "role": "wall_d", "locked": true}
		],
		"enemy_pieces": [
			{"type": "black_bishop", "coord": Vector2(3, 3), "role": "threat"}
		],
		"enemy_script": [
			{"piece_role": "threat", "blocks": [
				{"type": "move_fl"}, {"type": "move_fl"}, {"type": "move_fl"}
			]}
		],
		"max_turns": 1,
		"win_condition": {"type": "piece_captured", "role": "threat", "by_role": "target"},
		"lose_condition": {"type": "piece_captured", "role": "wall_a"}
	},
	# 4. Prediccion de ruta y escape ofensivo.
	# Turno 1: Diag. Adel. Der. x2 hasta (5,5) + escape (13 o 15 de RAM). El alfil se
	# frena en (5,5). Turno 2: el caballo lo captura. El escape abajo-derecha choca
	# con el senuelo y falla.
	{
		"id": "ambush_1",
		"title": "Emboscada",
		"instruction": "El alfil enemigo baja en zigzag desde arriba a la derecha \n(abajo-izquierda, abajo-derecha, abajo-izquierda, abajo-derecha) \ny en este mismo turno captura tu peón. \nEl caballo no llega a capturarlo, pero sí a cortarle el camino. \nAcordate de lo que aprendiste en 'El escudo'.",
		"category": "capture",
		"player_pieces": [
			{"type": "white_horse", "coord": Vector2(3, 7), "role": "target"},
			{"type": "white_pawn", "coord": Vector2(6, 6), "role": "decoy", "locked": true}
		],
		"enemy_pieces": [
			{"type": "black_bishop", "coord": Vector2(6, 2), "role": "threat"}
		],
		"enemy_script": [
			{"piece_role": "threat", "blocks": [
				{"type": "move_fl"}, {"type": "move_fr"},
				{"type": "move_fl"}, {"type": "move_fr"}
			]},
			{"piece_role": "threat", "blocks": [
				{"type": "move_fr"}
			]}
		],
		"max_turns": 2,
		"win_condition": {"type": "piece_captured", "role": "threat", "by_role": "target"},
		"lose_condition": {"type": "any", "conditions": [
			{"type": "piece_captured", "role": "decoy"},
			{"type": "piece_captured", "role": "target"}
		]}
	},
	# 5. Final: loops + RAM ajustada + bloquear un escape.
	# Turno 1: rey Diag. Adel. Izq. x2 + Adelante hasta (1,0) (11/12).
	# Turno 2: torre con loops hasta (0,0) (22 a 24). El escape falla y el rey cae.
	# El rey enemigo muere por escape fallido. Ese caso tambien emite
	# piece_captured con el atacante, asi que se podria agregar
	# "by_role": "target" si se quiere exigir que lo capture la torre.
	{
		"id": "checkmate_2",
		"title": "Mate en el rincón",
		"instruction": "El rey enemigo está acorralado en la esquina, pero tiene \nun protocolo de escape: si lo atacan, salta a la derecha. \nUn escape falla si su casilla de destino está ocupada. \nTenés 2 turnos y una pieza por turno. Tu rey tiene 12 de RAM \ny tu torre está a 7 casillas del rincón.",
		"category": "checkmate",
		"player_pieces": [
			{"type": "white_king", "coord": Vector2(3, 3), "role": "support"},
			{"type": "white_tower", "coord": Vector2(0, 7), "role": "target"}
		],
		"enemy_pieces": [
			{"type": "black_king", "coord": Vector2(0, 0), "role": "enemy_king",
				"escape": [{"type": "move_r"}]}
		],
		"enemy_script": [],
		"max_turns": 2,
		"win_condition": {"type": "piece_captured", "role": "enemy_king"},
		"lose_condition": {"type": "turns_exceeded"}
	}
]

static func get_all() -> Array:
	return CHALLENGES

static func index_of(id: String) -> int:
	for i in range(CHALLENGES.size()):
		if CHALLENGES[i]["id"] == id:
			return i
	return -1
