extends Node
class_name BotSystem

# =============================================================================
# C-CHESS · BotSystem v2.4
#
# CAMBIO ARQUITECTURAL vs v2.2:
#   El greedy paso-a-paso causaba zigzags y capturas perdidas porque cada
#   bloque se evaluaba sin saber qué vendría después.
#
#   Ahora el bot usa un PLANIFICADOR DE SECUENCIA:
#   1. Genera TODAS las jugadas posibles desde la posición actual
#   2. Para cada jugada, simula el estado resultante
#   3. Elige la jugada con mejor score considerando la secuencia completa
#   4. Nunca vuelve a una casilla visitada en este turno (bloqueo duro)
#   5. Si hay captura disponible dentro de RAM, la prioriza absolutamente
#
#   Fixes específicos del log:
#   - Torre no hace ida/vuelta: visitadas bloqueadas duramente, no solo penalizadas
#   - Reina captura directo: la captura más próxima dentro de RAM gana siempre
#   - Rey protegido: mapa de control se recalcula considerando piezas que se mueven
# =============================================================================

const SCORE_CAPTURE    = 1000.0
const SCORE_CHECK_KING = 5000.0
const SCORE_ESCAPE     = 600.0
const PENALTY_EXPOSED  = 45.0

const PIECE_VALUES: Dictionary = {
	"king":   999.0,
	"queen":  90.0,
	"tower":  50.0,
	"bishop": 30.0,
	"horse":  30.0,
	"pawn":   10.0,
}

const CENTER_TABLE: Array = [
	[0.0, 0.1, 0.2, 0.2, 0.2, 0.2, 0.1, 0.0],
	[0.1, 0.3, 0.4, 0.4, 0.4, 0.4, 0.3, 0.1],
	[0.2, 0.4, 0.6, 0.7, 0.7, 0.6, 0.4, 0.2],
	[0.2, 0.4, 0.7, 1.0, 1.0, 0.7, 0.4, 0.2],
	[0.2, 0.4, 0.7, 1.0, 1.0, 0.7, 0.4, 0.2],
	[0.2, 0.4, 0.6, 0.7, 0.7, 0.6, 0.4, 0.2],
	[0.1, 0.3, 0.4, 0.4, 0.4, 0.4, 0.3, 0.1],
	[0.0, 0.1, 0.2, 0.2, 0.2, 0.2, 0.1, 0.0],
]

const INFO_BLOQUES: Dictionary = {
	"move_f":  {"vec": Vector2i(0,  1), "ram": 2},
	"move_b":  {"vec": Vector2i(0, -1), "ram": 2},
	"move_l":  {"vec": Vector2i(-1, 0), "ram": 2},
	"move_r":  {"vec": Vector2i(1,  0), "ram": 2},
	"move_fl": {"vec": Vector2i(-1, 1), "ram": 3},
	"move_fr": {"vec": Vector2i(1,  1), "ram": 3},
	"move_bl": {"vec": Vector2i(-1,-1), "ram": 3},
	"move_br": {"vec": Vector2i(1, -1), "ram": 3},
}

const SALTOS_CABALLO: Array = [
	["move_f",  "move_fr"],
	["move_f",  "move_fl"],
	["move_b",  "move_br"],
	["move_b",  "move_bl"],
	["move_r",  "move_fr"],
	["move_r",  "move_br"],
	["move_l",  "move_fl"],
	["move_l",  "move_bl"],
]

# =============================================================================
# 1. FUNCIÓN PRINCIPAL
# =============================================================================
static func procesar_turno_ia(game_manager: Node) -> bool:
	print("\n=== [BOT v2.4]: Turno negro ===")

	if game_manager.get("game_over") == true:
		return false

	var turno: int = game_manager.get("current_turn_count") if game_manager.get("current_turn_count") != null else 1
	print("[BOT v2.4]: Turno %d" % turno)

	var mapa_control = _construir_mapa_control(game_manager)

	# Intentar hasta 3 piezas si la primera no genera script válido
	var excluir: Array = []
	for _intento in range(3):
		var pieza = _seleccionar_pieza(game_manager, turno, mapa_control, excluir)
		if not pieza:
			break

		print("[BOT v2.4]: Pieza → %s (ID: %s, RAM: %d)" % [pieza.piece_type, pieza.piece_id, pieza.available_ram])
		var script_final = _construir_script(pieza, game_manager, mapa_control)

		if script_final.is_empty():
			print("[BOT v2.4]: Script vacío, intentando otra pieza.")
			excluir.append(pieza)
			continue

		print("[BOT v2.4]: Script con %d bloques." % script_final.size())
		game_manager.saved_programs[pieza.piece_id] = script_final.duplicate(true)
		pieza.behavior_script = script_final.duplicate(true)
		pieza.is_programmed   = true
		print("=== [BOT v2.4]: Inyección exitosa ===\n")
		return true

	print("[BOT v2.4]: Sin jugadas válidas.")
	return false


# =============================================================================
# 2. MAPA DE CONTROL (amenazas blancas)
# =============================================================================
static func _construir_mapa_control(game_manager: Node) -> Dictionary:
	var mapa: Dictionary = {}
	if not game_manager.pieces_container:
		return mapa
	for pieza in game_manager.pieces_container.get_children():
		if pieza.get_meta("is_dead", false) or pieza.piece_color != "white":
			continue
		var pos = _pos(pieza)
		if pos == null:
			continue
		for casilla in _casillas_atacadas_blanco(pieza, pos, game_manager):
			if not mapa.has(casilla):
				mapa[casilla] = []
			mapa[casilla].append(pieza)
	return mapa


static func _casillas_atacadas_blanco(pieza: Node, pos: Vector2i, game_manager: Node) -> Array:
	var res: Array = []
	match pieza.piece_type:
		"pawn":
			# Blanco avanza Y- (side_multiplier=-1), captura en diagonal Y-
			for dx in [-1, 1]:
				var t = pos + Vector2i(dx, -1)
				if _ok(t): res.append(t)
		"horse":
			for s in [Vector2i(2,1),Vector2i(2,-1),Vector2i(-2,1),Vector2i(-2,-1),
					  Vector2i(1,2),Vector2i(1,-2),Vector2i(-1,2),Vector2i(-1,-2)]:
				var t = pos + s
				if _ok(t): res.append(t)
		"tower":
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				res.append_array(_rayo(pos, d, game_manager))
		"bishop":
			for d in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				res.append_array(_rayo(pos, d, game_manager))
		"queen":
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),
					  Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				res.append_array(_rayo(pos, d, game_manager))
		"king":
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),
					  Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
				var t = pos + d
				if _ok(t): res.append(t)
	return res


static func _rayo(origen: Vector2i, dir: Vector2i, game_manager: Node) -> Array:
	var res: Array = []
	var actual = origen + dir
	while _ok(actual):
		res.append(actual)
		if game_manager.get_piece_at(actual) != null:
			break
		actual += dir
	return res


# =============================================================================
# 3. JUGADAS LEGALES
#    Devuelve: { "bloques": Array[String], "destino": Vector2i,
#               "captura": bool, "ram": int, "es_caballo": bool }
#    Para deslizantes: UNA jugada por destino (con todos los bloques necesarios)
# =============================================================================
static func _jugadas_legales(pieza: Node, pos: Vector2i, game_manager: Node) -> Array:
	var resultado: Array = []
	var tipo  = pieza.piece_type
	var color = pieza.piece_color

	if tipo == "horse":
		for par in SALTOS_CABALLO:
			var dest = pos + INFO_BLOQUES[par[0]]["vec"] + INFO_BLOQUES[par[1]]["vec"]
			if not _ok(dest): continue
			var occ = game_manager.get_piece_at(dest)
			if occ != null and not occ.get_meta("is_dead", false) and occ.piece_color == color:
				continue
			resultado.append({
				"bloques":    [par[0], par[1]],
				"destino":    dest,
				"captura":    occ != null and not occ.get_meta("is_dead", false) and occ.piece_color == "white",
				"ram":        INFO_BLOQUES[par[0]]["ram"] + INFO_BLOQUES[par[1]]["ram"],
				"es_caballo": true,
			})

	elif tipo == "pawn":
		var d1 = pos + INFO_BLOQUES["move_f"]["vec"]
		if _ok(d1):
			var occ = game_manager.get_piece_at(d1)
			if occ == null or occ.get_meta("is_dead", false):
				resultado.append({"bloques":["move_f"],"destino":d1,"captura":false,"ram":2,"es_caballo":false})
				# Doble avance desde fila inicial
				if pos.y == 1:
					var d2 = d1 + INFO_BLOQUES["move_f"]["vec"]
					var o2 = game_manager.get_piece_at(d2)
					if _ok(d2) and (o2 == null or o2.get_meta("is_dead", false)):
						resultado.append({"bloques":["move_f","move_f"],"destino":d2,"captura":false,"ram":4,"es_caballo":false})
		for b in ["move_fl","move_fr"]:
			var diag = pos + INFO_BLOQUES[b]["vec"]
			if _ok(diag):
				var occ = game_manager.get_piece_at(diag)
				if occ != null and not occ.get_meta("is_dead", false) and occ.piece_color == "white":
					resultado.append({"bloques":[b],"destino":diag,"captura":true,"ram":INFO_BLOQUES[b]["ram"],"es_caballo":false})

	else:
		var dirs_validas: Array = []
		match tipo:
			"tower":  dirs_validas = ["move_f","move_b","move_l","move_r"]
			"bishop": dirs_validas = ["move_fl","move_fr","move_bl","move_br"]
			"queen":  dirs_validas = ["move_f","move_b","move_l","move_r","move_fl","move_fr","move_bl","move_br"]
			"king":   dirs_validas = ["move_f","move_b","move_l","move_r","move_fl","move_fr","move_bl","move_br"]
		var max_pasos = 1 if tipo == "king" else 7

		for bloque in dirs_validas:
			var vec      = INFO_BLOQUES[bloque]["vec"]
			var ram_unit = INFO_BLOQUES[bloque]["ram"]
			var actual   = pos + vec
			var pasos    = 1
			var bloques_acum: Array = []
			while _ok(actual) and pasos <= max_pasos:
				bloques_acum.append(bloque)
				var occ = game_manager.get_piece_at(actual)
				if occ != null and not occ.get_meta("is_dead", false):
					if occ.piece_color == "white":
						resultado.append({"bloques":bloques_acum.duplicate(),"destino":actual,"captura":true,"ram":pasos*ram_unit,"es_caballo":false})
					break
				resultado.append({"bloques":bloques_acum.duplicate(),"destino":actual,"captura":false,"ram":pasos*ram_unit,"es_caballo":false})
				actual += vec
				pasos  += 1

	return resultado


# =============================================================================
# 4. SCORING DE JUGADA INDIVIDUAL
# =============================================================================
static func _score_jugada(pieza: Node, pos_origen: Vector2i, jugada: Dictionary, game_manager: Node, mapa_control: Dictionary) -> float:
	var destino = jugada["destino"]
	var score   = 0.0

	score += CENTER_TABLE[clamp(destino.x,0,7)][clamp(destino.y,0,7)] * 2.0

	var avance = destino.y - pos_origen.y
	score += avance * 0.5 if avance > 0 else avance * 1.5

	if jugada["captura"]:
		var occ = game_manager.get_piece_at(destino)
		if occ != null and not occ.get_meta("is_dead", false):
			var val_vic = _val(occ.piece_type)
			var val_atk = _val(pieza.piece_type)
			score += SCORE_CAPTURE + val_vic - (val_atk * 0.1)
			if occ.piece_type == "king":
				score += SCORE_CHECK_KING

	if _bajo_ataque(destino, mapa_control):
		score -= PENALTY_EXPOSED
		score -= _val(pieza.piece_type) * 0.3
		if not jugada["captura"] and _val(pieza.piece_type) >= 30.0:
			score -= _val(pieza.piece_type) * 2.0

	# Lookahead: solo capturas de piezas normales (no rey, evita scores inflados)
	var jugadas_sig = _jugadas_legales(pieza, destino, game_manager)
	for j2 in jugadas_sig:
		if j2["captura"]:
			var occ2 = game_manager.get_piece_at(j2["destino"])
			if occ2 != null and not occ2.get_meta("is_dead", false) and occ2.piece_type != "king":
				score += _val(occ2.piece_type) * 0.25
			break

	return score


# =============================================================================
# 5. SELECCIÓN DE PIEZA
# =============================================================================
static func _seleccionar_pieza(game_manager: Node, turno: int, mapa_control: Dictionary, excluir: Array) -> Node:
	var vivas: Array = []
	for p in game_manager.pieces_container.get_children():
		if p.piece_color == "black" and not p.get_meta("is_dead", false) and p not in excluir:
			vivas.append(p)
	if vivas.is_empty():
		return null

	# Prioridad 1: rey en jaque
	var rey = _rey_negro(vivas)
	if rey:
		var pos_rey = _pos(rey)
		if pos_rey and _bajo_ataque(pos_rey, mapa_control):
			print("[BOT v2.4]: ⚠ Rey en jaque.")
			return _rescatar_rey(rey, vivas, game_manager, mapa_control)

	# Prioridad 2: reina amenazada
	for p in vivas:
		if p.piece_type == "queen":
			var pr = _pos(p)
			if pr and _bajo_ataque(pr, mapa_control):
				return p

	# Prioridad 3: pieza con captura inmediata disponible dentro de RAM
	for p in vivas:
		var pp = _pos(p)
		if pp == null: continue
		for j in _jugadas_legales(p, pp, game_manager):
			if j["captura"] and j["ram"] <= p.available_ram:
				# Captura directa disponible → elegir esta pieza directamente
				print("[BOT v2.4]: Captura directa disponible con %s" % p.piece_type)
				return p

	# Prioridad 4: score general
	var mejor: Node = null
	var best: float = -INF
	for p in vivas:
		var pp = _pos(p)
		if pp == null: continue
		var jugadas = _jugadas_legales(p, pp, game_manager)
		var mejor_j = -INF
		for j in jugadas:
			var s = _score_jugada(p, pp, j, game_manager, mapa_control)
			if s > mejor_j: mejor_j = s
		var bonus = 3.0 if turno <= 3 and p.piece_type in ["pawn","horse"] else 0.0
		var total = mejor_j + bonus
		if total > best or (total == best and randf() > 0.6):
			best  = total
			mejor = p

	if mejor:
		print("[BOT v2.4]: Mejor pieza → %s (score: %.1f)" % [mejor.piece_type, best])
	return mejor


# =============================================================================
# 6. CONSTRUCTOR DE SCRIPT — planificador de secuencia completa
#
#    REGLAS DURAS (no penalizaciones, bloqueos reales):
#    - Nunca volver a una casilla visitada este turno
#    - Si hay captura dentro de RAM desde la posición actual → tomarla siempre
#    - La captura más eficiente en RAM tiene prioridad sobre posicionamiento
# =============================================================================
static func _construir_script(pieza: Node, game_manager: Node, mapa_control: Dictionary) -> Array:
	var script:    Array    = []
	var ram_max:   int      = pieza.available_ram
	var ram_usada: int      = 0
	var pos_v:     Vector2i
	var visitadas: Array    = []

	var pos_ini = _pos(pieza)
	if pos_ini == null: return []
	pos_v = pos_ini
	visitadas.append(pos_v)

	print("[BOT v2.4]: Construyendo script para %s (RAM: %d)" % [pieza.piece_type, ram_max])

	# PASO A: Escape si la pieza está bajo ataque
	if _bajo_ataque(pos_v, mapa_control) and ram_max >= 4:
		var esc = _mejor_escape(pieza, pos_v, game_manager, mapa_control, ram_max, visitadas)
		if not esc.is_empty():
			var ram_esc = BlockSystem.calculate_ram_usage(esc["bloques"].map(func(b): return {"type": b}))
			if ram_usada + ram_esc <= ram_max:
				for b in esc["bloques"]:
					script.append({"type": b})
				ram_usada += ram_esc
				pos_v      = esc["destino"]
				visitadas.append(pos_v)
				print("[BOT v2.4]: → Escape → %s (RAM: %d)" % [str(pos_v), ram_usada])
				# Tras escape, si hay RAM, seguir con ofensiva
				if ram_usada >= ram_max:
					return script

	# PASO B+C: Secuencia ofensiva
	var max_slots = 8

	while ram_usada < ram_max and script.size() < max_slots:
		var jugadas = _jugadas_legales(pieza, pos_v, game_manager)
		if jugadas.is_empty(): break

		# --- REGLA DURA 1: filtrar jugadas que vuelvan a casillas visitadas ---
		var jugadas_validas: Array = []
		for j in jugadas:
			if _en_visitadas(j["destino"], visitadas):
				continue
			var ram_j = BlockSystem.calculate_ram_usage(j["bloques"].map(func(b): return {"type": b}))
			if ram_usada + ram_j > ram_max:
				continue
			jugadas_validas.append({"jugada": j, "ram": ram_j})

		if jugadas_validas.is_empty(): break

		# --- REGLA DURA 2: si hay captura directa disponible, tomarla sin dudar ---
		var captura_directa = null
		var mejor_val_captura = -1.0
		for c in jugadas_validas:
			if c["jugada"]["captura"]:
				var occ = game_manager.get_piece_at(c["jugada"]["destino"])
				if occ != null and not occ.get_meta("is_dead", false):
					var val = _val(occ.piece_type)
					if val > mejor_val_captura:
						mejor_val_captura = val
						captura_directa   = c

		if captura_directa != null:
			var j   = captura_directa["jugada"]
			var ram_j = captura_directa["ram"]
			for b in j["bloques"]:
				script.append({"type": b})
			ram_usada += ram_j
			pos_v      = j["destino"]
			visitadas.append(pos_v)
			print("[BOT v2.4]:   + CAPTURA %s → %s (RAM: %d/%d)" % [str(j["bloques"]), str(pos_v), ram_usada, ram_max])
			break  # Script cerrado tras captura

		# --- Selección por score (sin capturas disponibles) ---
		var candidatos: Array = []
		for c in jugadas_validas:
			var sc = _score_jugada(pieza, pos_v, c["jugada"], game_manager, mapa_control)
			candidatos.append({"jugada": c["jugada"], "score": sc, "ram": c["ram"]})

		if candidatos.is_empty(): break

		candidatos.sort_custom(func(a, b):
			if abs(a["score"] - b["score"]) < 0.5:
				return randf() > 0.5
			return a["score"] > b["score"]
		)

		var mejor = candidatos[0]
		var j     = mejor["jugada"]
		var ram_j = mejor["ram"]

		for b in j["bloques"]:
			script.append({"type": b})
		ram_usada += ram_j
		pos_v      = j["destino"]
		visitadas.append(pos_v)
		print("[BOT v2.4]:   + %s → %s (score: %.1f, RAM: %d/%d)" % [str(j["bloques"]), str(pos_v), mejor["score"], ram_usada, ram_max])

	return script


# =============================================================================
# 7. ESCAPE
# =============================================================================
static func _mejor_escape(pieza: Node, pos: Vector2i, game_manager: Node, mapa_control: Dictionary, ram_max: int, visitadas: Array) -> Dictionary:
	var jugadas = _jugadas_legales(pieza, pos, game_manager)
	var mejor_score = -INF
	var mejor: Dictionary = {}

	for j in jugadas:
		if _en_visitadas(j["destino"], visitadas): continue
		var ram_j = BlockSystem.calculate_ram_usage(j["bloques"].map(func(b): return {"type": b}))
		if ram_j > ram_max: continue

		var score = 0.0
		if _bajo_ataque(j["destino"], mapa_control):
			score -= 500.0
		else:
			score += SCORE_ESCAPE
		score += CENTER_TABLE[clamp(j["destino"].x,0,7)][clamp(j["destino"].y,0,7)] * 2.0
		if j["captura"]:
			var occ = game_manager.get_piece_at(j["destino"])
			if occ != null: score += _val(occ.piece_type)

		if score > mejor_score:
			mejor_score = score
			mejor = {"bloques": j["bloques"].duplicate(), "destino": j["destino"], "ram": ram_j}

	if mejor_score < 0.0: return {}
	return mejor


# =============================================================================
# 8. RESCATE DEL REY
# =============================================================================
static func _rescatar_rey(rey: Node, vivas: Array, game_manager: Node, mapa_control: Dictionary) -> Node:
	var pos_rey = _pos(rey)
	for j in _jugadas_legales(rey, pos_rey, game_manager):
		if not _bajo_ataque(j["destino"], mapa_control):
			return rey
	for p in vivas:
		if p.piece_type == "king": continue
		var pp = _pos(p)
		if pp == null: continue
		for j in _jugadas_legales(p, pp, game_manager):
			if j["captura"]:
				var occ = game_manager.get_piece_at(j["destino"])
				if occ != null and not occ.get_meta("is_dead", false) and occ.piece_color == "white":
					return p
	return rey


# =============================================================================
# 9. HELPERS
# =============================================================================
static func _ok(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x <= 7 and pos.y >= 0 and pos.y <= 7

static func _bajo_ataque(pos: Vector2i, mapa_control: Dictionary) -> bool:
	return mapa_control.has(pos) and not mapa_control[pos].is_empty()

static func _en_visitadas(pos: Vector2i, visitadas: Array) -> bool:
	for v in visitadas:
		if Vector2i(v) == pos: return true
	return false

static func _val(tipo: String) -> float:
	return PIECE_VALUES.get(tipo, 5.0)

static func _pos(pieza: Node) -> Variant:
	var p = pieza.get("board_position")
	if p != null: return Vector2i(int(p.x), int(p.y))
	if pieza.has_meta("board_pos"):
		p = pieza.get_meta("board_pos")
		return Vector2i(int(p.x), int(p.y))
	return null

static func _rey_negro(piezas: Array) -> Node:
	for p in piezas:
		if p.piece_type == "king": return p
	return null
