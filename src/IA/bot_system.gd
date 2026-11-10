extends Node
class_name BotSystem

# IA de las negras. Planifica con loops (ver "Tramos y loops").
#
# Cada turno:
#   1. Construye un mapa de amenazas: a que casillas puede llegar cada pieza
#      blanca con su RAM (DFS con costo incremental y poda por mejor costo).
#   2. Si el rey negro esta amenazado, busca una jugada que lo saque de la
#      amenaza y la verifica con el mapa hipotetico posterior.
#   3. Si no, puntua todas las jugadas de todas las piezas negras y aplica una
#      mirada de una jugada (look-ahead) con poda por cota: la mirada solo
#      resta puntaje, asi que el puntaje previo es un techo. La mirada revisa
#      la pieza movida, el rey (ataques descubiertos) y el resto de piezas.
#   4. Si la pieza queda en riesgo y le sobra RAM, le instala un escape,
#      calculado sobre el tablero posterior a la jugada.
#
# Una captura contra una pieza blanca con escape valido no captura: la victima
# huye y el atacante solo ocupa la casilla. El bot la puntua como tal.
#
# Las piezas negras se mueven con los mismos bloques que el jugador; el
# caballo puede atravesar aliados siempre que no termine sobre uno.

const SCORE_ESCAPE = 600.0
# Capturar al rey blanco termina la partida
const SCORE_VICTORIA = 10000.0
# Jugada que deja al rey negro recien amenazado
const PENAL_REY_EXPUESTO = 3000.0
# Volver a la casilla del turno anterior (evita el vaiven)
const PENAL_VAIVEN = 25.0
const META_CELDA_PREVIA := "bot_celda_previa"

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

const MAX_RESCATE := 24

# --- Dificultad ---
# rayo_propio: largo maximo de los rayos en sus jugadas (1 = sin loops).
# rayo_amenaza: idem al prever las jugadas blancas.
# mirada: maximo de mapas hipoteticos por turno (0 = sin mirada adelante).
# ruido: error aleatorio, +-ruido sobre el puntaje de cada jugada.
# escape: si se instala escapes.
const PERFILES := {
	"easy":   {"rayo_propio": 1, "rayo_amenaza": 1, "mirada": 0,  "ruido": 60.0, "escape": false},
	"normal": {"rayo_propio": 1, "rayo_amenaza": 7, "mirada": 8,  "ruido": 15.0, "escape": true},
	"hard":   {"rayo_propio": 7, "rayo_amenaza": 7, "mirada": 16, "ruido": 0.0,  "escape": true},
}

static func _perfil() -> Dictionary:
	var nivel: String = GlobalConfig.bot_difficulty if GlobalConfig else "normal"
	return PERFILES.get(nivel, PERFILES["normal"])

# --- Turno ---

static func procesar_turno_ia(game_manager: Node) -> bool:
	if GlobalConfig and GlobalConfig.bot_disabled:
		return false

	var mapa_control = _construir_mapa_control(game_manager)
	await game_manager.get_tree().process_frame

	var plan: Dictionary = {}
	var rey = _rey_negro(_piezas_negras(game_manager))
	if rey and _bajo_ataque(_pos(rey), mapa_control):
		print("[BOT]: Rey en jaque, buscando rescate.")
		plan = await _plan_rescate(rey, game_manager, mapa_control)
	if plan.is_empty():
		plan = await _elegir_jugada(game_manager, mapa_control)
	if plan.is_empty():
		print("[BOT]: Sin jugadas validas.")
		return false

	var pieza: Node = plan["pieza"]
	var jugada: Dictionary = plan["jugada"]
	var mapa_futuro: Dictionary = plan.get("mapa_futuro", {})
	if mapa_futuro.is_empty():
		mapa_futuro = _mapa_control_hipotetico(pieza, jugada["destino"], game_manager)
	var script_final: Array = _materializar(jugada["bloques"], pieza.piece_color)

	print("[BOT]: %s %s -> %s (bloques: %s, score: %.1f)" % [pieza.piece_type, pieza.piece_id, str(jugada["destino"]), str(jugada["bloques"]), plan.get("score", 0.0)])
	game_manager.saved_programs[pieza.piece_id] = script_final.duplicate(true)
	pieza.behavior_script = script_final.duplicate(true)
	pieza.is_programmed = true
	pieza.set_meta(META_CELDA_PREVIA, _pos(pieza))

	var ram_restante = pieza.available_ram - BlockSystem.calculate_ram_usage(script_final)
	_decidir_defensa(pieza, jugada["destino"], ram_restante, game_manager, mapa_futuro)
	return true

static func _piezas_negras(game_manager: Node) -> Array:
	var vivas: Array = []
	for p in game_manager.pieces_container.get_children():
		if p.piece_color == "black" and not p.get_meta("is_dead", false):
			vivas.append(p)
	return vivas

# --- Tramos y loops ---
#
# Una jugada es una secuencia de tramos. Un tramo es un bloque simple
# ("move_f") o un rayo de m casillas en linea recta ("move_f*3"). El rayo se
# ejecuta como un loop, anidado si conviene, con el menor costo de RAM que
# permiten las reglas. Asi el bot preve los loops del jugador (mapa de
# amenazas) y los usa en sus propias jugadas.
#
# Costo de una secuencia: suma de los costos base mas la posicion en la cola.
# El costo de un loop es el de su contenido calculado desde cero, y dentro del
# programa ocupa un solo lugar. Por eso conviene agrupar.

const MAX_RAYO := 7         # el tablero tiene 8 casillas por lado
const MAX_TRAMOS := 8

# base -> {"costo": [costo por m], "plan": [tamanos de los subtramos por m]}
static var _tabla_rayos: Dictionary = {}

# Costo minimo de RAM de un loop que avanza m casillas con un bloque de ese
# costo base. m = 1 es el bloque simple.
static func _costo_rayo(base: int, m: int) -> int:
	return _tabla_rayo(base)["costo"][m]

static func _tabla_rayo(base: int) -> Dictionary:
	if _tabla_rayos.has(base):
		return _tabla_rayos[base]
	var costo: Array = [0, base]
	var plan: Array = [[], [1]]
	for m in range(2, MAX_RAYO + 1):
		# dp[k][s]: menor suma de costos con k subtramos que suman s casillas.
		# Los subtramos son rayos menores que m, ya calculados.
		var INF := 1 << 30
		var dp: Array = []
		var padre: Array = []
		for kk in range(m + 1):
			dp.append([]); padre.append([])
			for ss in range(m + 1):
				dp[kk].append(INF); padre[kk].append(0)
		dp[0][0] = 0
		for kk in range(m):
			for ss in range(m + 1):
				if dp[kk][ss] >= INF:
					continue
				for t in range(1, m):
					if ss + t > m:
						break
					var v: int = dp[kk][ss] + costo[t]
					if v < dp[kk + 1][ss + t]:
						dp[kk + 1][ss + t] = v
						padre[kk + 1][ss + t] = t
		var mejor := INF
		var mejor_k := 0
		for kk in range(2, m + 1):
			if dp[kk][m] >= INF:
				continue
			var total: int = dp[kk][m] + kk * (kk - 1) / 2
			if total < mejor:
				mejor = total
				mejor_k = kk
		var partes: Array = []
		var resto := m
		for kk in range(mejor_k, 0, -1):
			var t: int = padre[kk][resto]
			partes.append(t)
			resto -= t
		partes.sort()
		partes.reverse()  # el orden no cambia el costo; los grandes primero
		costo.append(mejor)
		plan.append(partes)
	_tabla_rayos[base] = {"costo": costo, "plan": plan}
	return _tabla_rayos[base]

static func _es_rayo(tramo: String) -> bool:
	return tramo.contains("*")

static func _bloque_de(tramo: String) -> String:
	return tramo.get_slice("*", 0)

static func _largo_de(tramo: String) -> int:
	return int(tramo.get_slice("*", 1)) if _es_rayo(tramo) else 1

static func _costo_tramo(tramo: String) -> int:
	return _costo_rayo(INFO_BLOQUES[_bloque_de(tramo)]["ram"], _largo_de(tramo))

# Casilla -> pieza viva, armada una vez por busqueda (get_piece_at recorre
# todas las piezas en cada consulta). Igual que get_piece_at, registra la
# posicion virtual y, si difiere, la real.
static func _grilla(game_manager: Node) -> Dictionary:
	var grilla: Dictionary = {}
	for p in game_manager.pieces_container.get_children():
		if p.get_meta("is_dead", false):
			continue
		if not p.has_method("is_valid_piece") or not p.is_valid_piece():
			continue
		var v := Vector2i(p.virtual_board_position)
		if not grilla.has(v):
			grilla[v] = p
		var b := Vector2i(p.board_position)
		if b != v and not grilla.has(b):
			grilla[b] = p
	return grilla

# Todas las casillas que la pieza alcanza en un turno, con la jugada mas
# barata para cada una: {destino: {"bloques", "destino", "captura", "ram"}}.
static func _alcance(pieza: Node, origen: Vector2i, ram_max: int, grilla: Dictionary, max_rayo: int = MAX_RAYO) -> Dictionary:
	var resultado: Dictionary = {}
	_explorar(pieza, origen, 0, [], {origen: true}, ram_max, grilla, resultado, {}, max_rayo)
	return resultado

static func _explorar(pieza: Node, pos: Vector2i, ram_usada: int, camino: Array, visitadas: Dictionary,
		ram_max: int, grilla: Dictionary, resultado: Dictionary, mejor: Dictionary, max_rayo: int) -> void:
	var n := camino.size()
	if n >= MAX_TRAMOS:
		return
	var es_caballo: bool = pieza.piece_type == "horse"
	for bloque in INFO_BLOQUES:
		var vec: Vector2i = INFO_BLOQUES[bloque]["vec"]
		var base: int = INFO_BLOQUES[bloque]["ram"]
		var anterior: Node = null
		for m in range(1, max_rayo + 1):
			# Un rayo no atraviesa piezas: solo la ultima casilla puede estar ocupada
			if anterior != null:
				break
			var ram_acumulado := ram_usada + _costo_rayo(base, m) + n
			if ram_acumulado > ram_max:
				break  # el costo crece con m
			var destino: Vector2i = pos + vec * m
			if not _ok(destino):
				break
			var occ: Node = grilla.get(destino)
			if occ == pieza:
				occ = null
			anterior = occ
			var es_aliado: bool = occ != null and occ.piece_color == pieza.piece_color
			# El caballo atraviesa un aliado solo con un bloque simple y sin
			# terminar sobre el
			if es_aliado and not (es_caballo and m == 1):
				continue
			if visitadas.has(destino):
				continue
			var clave := Vector3i(destino.x, destino.y, n + 1)
			if mejor.get(clave, 1 << 30) <= ram_acumulado:
				continue
			mejor[clave] = ram_acumulado

			camino.append(bloque if m == 1 else "%s*%d" % [bloque, m])
			var es_captura: bool = occ != null and not es_aliado
			if not es_aliado:
				var previo: Dictionary = resultado.get(destino, {})
				if previo.is_empty() or ram_acumulado < previo["ram"]:
					resultado[destino] = {
						"bloques": camino.duplicate(),
						"destino": destino,
						"captura": es_captura,
						"ram": ram_acumulado,
					}
			# Una captura termina el programa
			if not es_captura:
				visitadas[destino] = true
				_explorar(pieza, destino, ram_acumulado, camino, visitadas, ram_max, grilla, resultado, mejor, max_rayo)
				visitadas.erase(destino)
			camino.pop_back()

# --- Mapa de amenazas ---

# Casilla -> {"costo_min", "piezas"}: donde puede llegar cada pieza blanca en
# su proximo turno, contando loops.
static func _construir_mapa_control(game_manager: Node) -> Dictionary:
	var mapa: Dictionary = {}
	if not game_manager.pieces_container:
		return mapa
	var grilla := _grilla(game_manager)
	for pieza in game_manager.pieces_container.get_children():
		if pieza.get_meta("is_dead", false) or pieza.piece_color != "white":
			continue
		var pos = _pos(pieza)
		if pos == null:
			continue
		var alcance := _alcance(pieza, pos, pieza.available_ram, grilla, _perfil()["rayo_amenaza"])
		for destino in alcance:
			var costo: int = alcance[destino]["ram"]
			if not mapa.has(destino):
				mapa[destino] = {"costo_min": costo, "piezas": [pieza]}
			else:
				mapa[destino]["costo_min"] = mini(mapa[destino]["costo_min"], costo)
				mapa[destino]["piezas"].append(pieza)
	return mapa

# --- Jugadas propias ---

# La jugada mas barata a cada casilla alcanzable. El limite es la RAM de la
# pieza, igual que para el jugador.
static func _jugadas_legales(pieza: Node, pos: Vector2i, game_manager: Node) -> Array:
	return _alcance(pieza, pos, pieza.available_ram, _grilla(game_manager), _perfil()["rayo_propio"]).values()

static func _costo_incremental(bloques: Array, offset: int = 0) -> int:
	var total = 0
	for i in range(bloques.size()):
		total += _costo_tramo(bloques[i]) + offset + i
	return total

# Convierte los tramos en el programa real: un rayo pasa a ser un loop del bot
static func _materializar(bloques: Array, color: String) -> Array:
	var script: Array = []
	for tramo in bloques:
		if _es_rayo(tramo):
			script.append({"type": _obtener_loop(_bloque_de(tramo), _largo_de(tramo), color)})
		else:
			script.append({"type": tramo})
	return script

# Loops del bot, reutilizados como los escapes: uno por direccion y largo
static var _loops_por_rayo: Dictionary = {}

static func _obtener_loop(bloque: String, m: int, color: String) -> String:
	var clave := "%s:%s:%d" % [color, bloque, m]
	var loop_id: String = _loops_por_rayo.get(clave, "")
	if loop_id != "" and not BlockSystem.get_block_info(loop_id).is_empty():
		return loop_id
	var contenido: Array = []
	for t in _tabla_rayo(INFO_BLOQUES[bloque]["ram"])["plan"][m]:
		contenido.append({"type": bloque if t == 1 else _obtener_loop(bloque, t, color)})
	loop_id = BlockSystem.create_loop_block(
		contenido,
		BlockSystem.calculate_ram_usage(contenido),
		"Loop auto (%s x%d)" % [bloque, m],
		color
	)
	# Marca interna: no se muestra en la paleta ni se guarda
	BlockSystem.block_definitions[loop_id]["bot_only"] = true
	_loops_por_rayo[clave] = loop_id
	return loop_id

# --- Eleccion de la jugada ---

# Puntaje previo (sin mirada adelante) de todas las jugadas de una pieza
static func _puntuar_jugadas(pieza: Node, game_manager: Node, mapa_control: Dictionary) -> Array:
	var pos_ini = _pos(pieza)
	if pos_ini == null: return []
	var jugadas_legales = _jugadas_legales(pieza, pos_ini, game_manager)
	if jugadas_legales.is_empty(): return []
	var ram_max: int = pieza.available_ram
	var riesgo_origen = _factor_riesgo(_costo_amenaza(pos_ini, mapa_control))
	var valor_pieza = _val(pieza.piece_type)
	var reina_sale_temprano = _reina_prematura(pieza, game_manager)

	var celda_previa = pieza.get_meta(META_CELDA_PREVIA) if pieza.has_meta(META_CELDA_PREVIA) else null

	var candidatas: Array = []
	for j in jugadas_legales:
		var ram_j = _costo_incremental(j["bloques"])
		if ram_j > ram_max:
			continue
		var destino: Vector2i = j["destino"]
		var score = 0.0
		var riesgo_destino = _factor_riesgo(_costo_amenaza(destino, mapa_control))
		var destino_seguro = riesgo_destino < 0.40

		# Supervivencia: salir de una casilla amenazada
		if riesgo_origen > 0.5:
			score += 250.0 * (riesgo_origen - riesgo_destino)

		var victima = game_manager.get_piece_at(destino) if j["captura"] else null
		if victima != null and victima.get_meta("is_dead", false):
			victima = null
		# Si la victima tiene un escape valido, la captura no ocurre
		var victima_escapa = victima != null and _tiene_escape_valido(victima, game_manager)

		if victima != null and not victima_escapa:
			score += _puntaje_captura(victima, valor_pieza, riesgo_destino, destino_seguro)
		else:
			score += _puntaje_posicional(pieza, pos_ini, destino, valor_pieza, riesgo_destino, destino_seguro, riesgo_origen, reina_sale_temprano)
			if victima_escapa:
				# Obligar a gastar un escape de un solo uso tiene algo de valor
				score += _val(victima.piece_type) * 0.5
			if celda_previa != null and destino == celda_previa:
				score -= PENAL_VAIVEN

		candidatas.append({"pieza": pieza, "jugada": j, "score": score})

	return candidatas

static func _puntaje_captura(victima: Node, valor_pieza: float, riesgo_destino: float, destino_seguro: bool) -> float:
	var val_victima = _val(victima.piece_type)
	if victima.piece_type == "king":
		return SCORE_VICTORIA
	var score = val_victima * 4.0 + 200.0
	if destino_seguro:
		score += 100.0
	elif val_victima >= valor_pieza:
		# Cambio igual o favorable: vale la pena aunque la casilla sea insegura
		score += (val_victima - valor_pieza) * 3.0 + 80.0
	elif riesgo_destino > 0.7:
		score -= (valor_pieza - val_victima) * riesgo_destino * 12.0
	elif riesgo_destino > 0.4:
		score -= (valor_pieza - val_victima) * riesgo_destino * 5.0
	else:
		score += 30.0
	if victima.piece_type == "queen":
		score += 500.0
	elif victima.piece_type in ["tower", "bishop", "horse"]:
		score += 80.0
	return score

static func _puntaje_posicional(pieza: Node, pos_ini: Vector2i, destino: Vector2i, valor_pieza: float, riesgo_destino: float, destino_seguro: bool, riesgo_origen: float, reina_sale_temprano: bool) -> float:
	var score = 0.0
	if not destino_seguro:
		score -= valor_pieza * riesgo_destino * 20.0
	score += CENTER_TABLE[clamp(destino.x, 0, 7)][clamp(destino.y, 0, 7)] * 10.0
	if pieza.piece_type == "pawn":
		var dir_avance = 1 if pieza.piece_color == "black" else -1
		if (destino.y - pos_ini.y) * dir_avance > 0:
			score += 20.0
			if destino_seguro:
				score += 15.0
	if pieza.piece_type in ["bishop", "horse"] and destino_seguro:
		score += 12.0
	if reina_sale_temprano and riesgo_origen <= 0.5 and pieza.piece_type == "queen":
		score -= 400.0
	return score

# Cuanto empeora una jugada al mirar la respuesta blanca. Siempre >= 0, asi
# el puntaje previo sigue siendo una cota superior.
# Devuelve {"penal": float, "mapa": mapa de amenazas posterior}.
static func _penalizacion_lookahead(pieza: Node, jugada: Dictionary, game_manager: Node, mapa_control: Dictionary) -> Dictionary:
	var destino: Vector2i = jugada["destino"]
	var valor_pieza = _val(pieza.piece_type)
	var mapa_futuro = _mapa_control_hipotetico(pieza, destino, game_manager)
	var penal := 0.0

	# Captura definitiva y favorable: perder la pieza despues es aceptable
	var cambio_favorable := false
	if jugada["captura"]:
		var occ = game_manager.get_piece_at(destino)
		if occ != null and _val(occ.piece_type) >= valor_pieza and not _tiene_escape_valido(occ, game_manager):
			if occ.piece_type == "king":
				return {"penal": 0.0, "mapa": mapa_futuro}
			cambio_favorable = true

	# La pieza movida
	if not cambio_favorable and _bajo_ataque(destino, mapa_futuro) and not _bajo_ataque(destino, mapa_control):
		penal += valor_pieza * _factor_riesgo(_costo_amenaza(destino, mapa_futuro)) * 40.0

	# El resto de las piezas negras: ataques descubiertos al irse esta pieza.
	# Las blancas solo capturan una vez por turno, asi que cuenta la peor.
	var peor := 0.0
	for p in _piezas_negras(game_manager):
		if p == pieza:
			continue
		var pp = _pos(p)
		if pp == null or not _bajo_ataque(pp, mapa_futuro) or _bajo_ataque(pp, mapa_control):
			continue
		if p.piece_type == "king":
			penal += PENAL_REY_EXPUESTO
			continue
		var perdida = _val(p.piece_type) * _factor_riesgo(_costo_amenaza(pp, mapa_futuro)) * 20.0
		if p.get("defense_protocol_active"):
			perdida *= 0.5
		peor = max(peor, perdida)
	penal += peor
	return {"penal": penal, "mapa": mapa_futuro}

# Mejor jugada entre todas las piezas negras. Poda por cota: se recorren las
# jugadas de mayor a menor puntaje previo y se corta cuando la siguiente ya
# no puede superar a la mejor verificada.
static func _elegir_jugada(game_manager: Node, mapa_control: Dictionary) -> Dictionary:
	var candidatas: Array = []
	for p in _piezas_negras(game_manager):
		candidatas.append_array(_puntuar_jugadas(p, game_manager, mapa_control))
	if candidatas.is_empty():
		return {}
	var perfil := _perfil()
	# Error aleatorio de los niveles bajos. Se suma antes de ordenar, asi la
	# poda por cota sigue siendo valida.
	var ruido: float = perfil["ruido"]
	if ruido > 0.0:
		for c in candidatas:
			c["score"] += randf_range(-ruido, ruido)
	candidatas.sort_custom(func(a, b): return a["score"] > b["score"])
	if perfil["mirada"] == 0:
		return candidatas[0]

	var mejor: Dictionary = {}
	var mapas_calculados := 0
	for c in candidatas:
		if not mejor.is_empty() and c["score"] <= mejor["score"]:
			break
		if mapas_calculados >= perfil["mirada"]:
			break
		var mirada = _penalizacion_lookahead(c["pieza"], c["jugada"], game_manager, mapa_control)
		mapas_calculados += 1
		var ajustado: float = c["score"] - mirada["penal"]
		if mejor.is_empty() or ajustado > mejor["score"]:
			mejor = {"pieza": c["pieza"], "jugada": c["jugada"], "score": ajustado, "mapa_futuro": mirada["mapa"]}
		await game_manager.get_tree().process_frame

	print("[BOT]: %d jugadas evaluadas, %d con mirada adelante." % [candidatas.size(), mapas_calculados])
	return mejor

# --- Rescate del rey ---

# Busca una jugada que deje al rey fuera del mapa de amenazas: mover el rey,
# capturar a quien lo amenaza o interponer una pieza. Cada candidata se
# verifica con el mapa posterior a la jugada.
# Si ninguna lo logra, devuelve la menos mala: un movimiento del rey que le
# deje RAM para un escape valido o, si no, el que mas reduzca el riesgo.
static func _plan_rescate(rey: Node, game_manager: Node, mapa_control: Dictionary) -> Dictionary:
	var pos_rey: Vector2i = _pos(rey)
	var atacantes: Array = mapa_control[pos_rey]["piezas"]
	var casillas_atacantes := {}
	for a in atacantes:
		casillas_atacantes[_pos(a)] = a

	# Candidatas en orden de preferencia: capturas de atacantes, movimientos
	# del rey y luego interposiciones (de menor RAM primero)
	var capturas: Array = []
	var del_rey: Array = []
	var bloqueos: Array = []
	for p in _piezas_negras(game_manager):
		var pp = _pos(p)
		if pp == null: continue
		for j in _jugadas_legales(p, pp, game_manager):
			var c = {"pieza": p, "jugada": j}
			if j["captura"] and casillas_atacantes.has(j["destino"]):
				capturas.append(c)
			elif p == rey:
				del_rey.append(c)
			elif mapa_control.has(j["destino"]) and not j["captura"]:
				bloqueos.append(c)
	capturas.sort_custom(func(a, b): return _val(a["pieza"].piece_type) < _val(b["pieza"].piece_type))
	bloqueos.sort_custom(func(a, b): return a["jugada"]["ram"] < b["jugada"]["ram"])

	var mejor: Dictionary = {}
	var respaldo: Dictionary = {}
	var riesgo_actual = _factor_riesgo(_costo_amenaza(pos_rey, mapa_control))
	var evaluadas := 0
	for c in capturas + del_rey + bloqueos:
		if evaluadas >= MAX_RESCATE:
			break
		var p: Node = c["pieza"]
		var j: Dictionary = c["jugada"]
		var mapa_futuro = _mapa_control_hipotetico(p, j["destino"], game_manager)
		evaluadas += 1
		var rey_despues: Vector2i = j["destino"] if p == rey else pos_rey
		if _bajo_ataque(rey_despues, mapa_futuro):
			var riesgo = _factor_riesgo(_costo_amenaza(rey_despues, mapa_futuro))
			if p == rey and _rey_puede_escapar(rey, j, game_manager, mapa_futuro):
				riesgo *= 0.25
			if riesgo < riesgo_actual and (respaldo.is_empty() or riesgo < respaldo["riesgo"]):
				respaldo = {"pieza": p, "jugada": j, "score": -riesgo * 100.0, "riesgo": riesgo, "mapa_futuro": mapa_futuro}
			continue

		# Verificada: puntuar entre las que salvan al rey
		var score := 0.0
		if j["captura"]:
			var occ = game_manager.get_piece_at(j["destino"])
			if occ: score += _val(occ.piece_type) * 4.0
		score -= _val(p.piece_type) * _factor_riesgo(_costo_amenaza(j["destino"], mapa_futuro)) * 10.0
		score -= j["ram"] * 0.5
		if mejor.is_empty() or score > mejor["score"]:
			mejor = {"pieza": p, "jugada": j, "score": score, "mapa_futuro": mapa_futuro}
		await game_manager.get_tree().process_frame

	if mejor.is_empty():
		print("[BOT]: Ninguna jugada saca al rey de la amenaza (%d probadas)." % evaluadas)
		if not respaldo.is_empty():
			print("[BOT]: Se usa la jugada menos riesgosa para el rey.")
			respaldo.erase("riesgo")
		return respaldo
	else:
		print("[BOT]: Rescate verificado con %s (%d probadas)." % [mejor["pieza"].piece_type, evaluadas])
	return mejor

# El rey, tras la jugada, conserva RAM para un escape hacia una casilla segura
static func _rey_puede_escapar(rey: Node, jugada: Dictionary, game_manager: Node, mapa_futuro: Dictionary) -> bool:
	var ram_restante = rey.available_ram - _costo_incremental(jugada["bloques"])
	if ram_restante < 2:
		return false
	return not _escape_desde(rey, jugada["destino"], ram_restante, game_manager, mapa_futuro).is_empty()

# Calcula el escape como si la pieza ya estuviera en el destino: asi su casilla
# de origen cuenta como libre y no como ocupada por ella misma.
static func _escape_desde(pieza: Node, destino: Vector2i, ram_max: int, game_manager: Node, mapa: Dictionary) -> Dictionary:
	var bp = pieza.board_position
	var vp = pieza.virtual_board_position
	pieza.board_position = Vector2(destino)
	pieza.virtual_board_position = Vector2(destino)
	var escape = _mejor_escape(pieza, destino, game_manager, mapa, ram_max, [destino])
	pieza.board_position = bp
	pieza.virtual_board_position = vp
	return escape

# --- Escape propio ---
static func _mejor_escape(pieza: Node, pos: Vector2i, game_manager: Node, mapa_control: Dictionary, ram_max: int, visitadas: Array) -> Dictionary:
	var jugadas = _jugadas_legales(pieza, pos, game_manager)
	var mejor_score: float = -INF
	var mejor: Dictionary = {}

	for j in jugadas:
		if j["bloques"].size() != 1 or _es_rayo(j["bloques"][0]):
			continue  # el escape es un unico bloque simple
		if _en_visitadas(j["destino"], visitadas): continue
		var ram_j = _costo_incremental(j["bloques"])
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

# --- Auxiliares ---
static func _ok(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x <= 7 and pos.y >= 0 and pos.y <= 7

static func _bajo_ataque(pos: Vector2i, mapa_control: Dictionary) -> bool:
	return mapa_control.has(pos)

static func _costo_amenaza(pos: Vector2i, mapa_control: Dictionary) -> int:
	if mapa_control.has(pos):
		return mapa_control[pos]["costo_min"]
	return -1

static func _factor_riesgo(costo_min: int) -> float:
	if costo_min < 0:
		return 0.0
	return clamp(1.15 - (float(costo_min) / 18.0), 0.0, 1.0)

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

# --- Escape de una pieza blanca ---
static func _tiene_escape_valido(pieza_objetivo: Node, game_manager: Node) -> bool:
	return _destino_escape(pieza_objetivo, game_manager) != null

# Casilla a la que huiria la pieza si la capturan, o null si no tiene un
# escape instalado o este fallaria. Replica GameManager.execute_defense_protocol.
static func _destino_escape(pieza_objetivo: Node, game_manager: Node) -> Variant:
	if not pieza_objetivo.get("defense_protocol_active"):
		return null
	var proto = pieza_objetivo.get("defense_protocol")
	if not proto is Dictionary or proto.is_empty():
		return null
	# El contenido del escape vive en BlockSystem (el programa guarda solo el id)
	var bloques = BlockSystem.get_block_info(proto.get("type", "")).get("contained_blocks", [])
	if bloques.is_empty():
		return null
	var info = BlockSystem.get_block_info(bloques[0].get("type", ""))
	if info.is_empty() or not info.has("vector"):
		return null
	var vec = Vector2i(info["vector"])
	var side_multiplier = -1 if pieza_objetivo.piece_color == "white" else 1
	var destino_escape = Vector2i(
		int(pieza_objetivo.virtual_board_position.x) + vec.x,
		int(pieza_objetivo.virtual_board_position.y) + vec.y * side_multiplier
	)
	if not _ok(destino_escape):
		return null
	if game_manager.get_piece_at(destino_escape, true, pieza_objetivo) != null:
		return null
	return destino_escape

# Protocolos de escape del bot, reutilizados: uno por direccion de movimiento.
# Como maximo existen 8 (uno por bloque de INFO_BLOQUES) en vez de uno nuevo
# por turno.
static var _escapes_por_bloque: Dictionary = {}

# Se llama al restaurar bloques desde un guardado: los ids en cache podrian
# apuntar a bloques que ya no existen o que ahora son del jugador
static func reset_escape_cache() -> void:
	_escapes_por_bloque.clear()
	_loops_por_rayo.clear()

static func _decidir_defensa(pieza: Node, destino_final: Vector2i, ram_restante: int, game_manager: Node, mapa_control: Dictionary) -> void:
	if not _perfil()["escape"]:
		_quitar_defensa(pieza)
		return
	if ram_restante < 2:
		_quitar_defensa(pieza)
		return

	var riesgo = _factor_riesgo(_costo_amenaza(destino_final, mapa_control))
	if riesgo < 0.25:
		_quitar_defensa(pieza)
		return

	var escape = _escape_desde(pieza, destino_final, ram_restante, game_manager, mapa_control)
	if escape.is_empty():
		_quitar_defensa(pieza)
		return

	var primer_bloque: String = escape["bloques"][0]
	var protocol_id = _obtener_escape_para_bloque(primer_bloque, pieza.piece_color)
	_instalar_defensa(pieza, protocol_id)
	print("[BOT]: Escape asignado a ", pieza.piece_id, " -> ", primer_bloque, " (", protocol_id, ")")

# Devuelve el protocolo existente para esa direccion o lo crea una sola vez.
static func _obtener_escape_para_bloque(bloque: String, color: String) -> String:
	var clave = color + ":" + bloque
	var protocol_id: String = _escapes_por_bloque.get(clave, "")
	# Se recrea si el bloque fue eliminado de BlockSystem
	if protocol_id != "" and not BlockSystem.get_block_info(protocol_id).is_empty():
		return protocol_id

	protocol_id = BlockSystem.create_escape_protocol(
		[{"type": bloque}],
		INFO_BLOQUES[bloque]["ram"],
		"Escape auto (%s)" % bloque,
		color
	)
	# Marca interna: no se muestra en la paleta de un jugador humano
	BlockSystem.block_definitions[protocol_id]["bot_only"] = true
	_escapes_por_bloque[clave] = protocol_id
	return protocol_id

# Deja la pieza con el mismo estado que instala la interfaz de programacion,
# que es lo que revisa GameManager.capture_piece.
static func _instalar_defensa(pieza: Node, protocol_id: String) -> void:
	pieza.defense_protocol = {"type": protocol_id}
	pieza.defense_protocol_id = protocol_id
	pieza.defense_protocol_active = true
	pieza.defense_protocol_owner_turn = pieza.piece_color
	pieza.defense_protocol_permanent = false

static func _quitar_defensa(pieza: Node) -> void:
	pieza.clear_defense_protocol()

# Mapa de amenazas despues de mover la pieza a destino. Si hay una victima,
# muere, salvo que tenga un escape valido: entonces se ubica en la casilla de
# huida, igual que en la partida real.
static func _mapa_control_hipotetico(pieza: Node, destino: Vector2i, game_manager: Node) -> Dictionary:
	var bp_original = pieza.board_position
	var vp_original = pieza.virtual_board_position
	var victima = game_manager.get_piece_at(destino)
	if victima != null and victima.piece_color == pieza.piece_color:
		victima = null
	var huida = _destino_escape(victima, game_manager) if victima != null else null
	var victima_bp = victima.board_position if victima else Vector2.ZERO
	var victima_vp = victima.virtual_board_position if victima else Vector2.ZERO
	var victima_muerta = victima.get_meta("is_dead", false) if victima else false

	pieza.board_position = Vector2(destino)
	pieza.virtual_board_position = Vector2(destino)
	if victima != null:
		if huida != null:
			victima.board_position = Vector2(huida)
			victima.virtual_board_position = Vector2(huida)
		else:
			victima.set_meta("is_dead", true)

	var mapa_simulado = _construir_mapa_control(game_manager)

	pieza.board_position = bp_original
	pieza.virtual_board_position = vp_original
	if victima != null:
		victima.board_position = victima_bp
		victima.virtual_board_position = victima_vp
		victima.set_meta("is_dead", victima_muerta)
	return mapa_simulado

# Penalizacion por sacar la reina antes de desarrollar las piezas menores
static func _reina_prematura(pieza: Node, game_manager: Node) -> bool:
	if pieza.piece_type != "queen":
		return false
	var piezas_menores_sin_mover := 0
	for p in game_manager.pieces_container.get_children():
		if p.piece_color != pieza.piece_color or p.get_meta("is_dead", false):
			continue
		if p.piece_type in ["horse", "bishop"]:
			var fila_original = 0 if p.piece_color == "black" else 7
			if int(_pos(p).y) == fila_original:
				piezas_menores_sin_mover += 1
	return piezas_menores_sin_mover >= 2  # al menos 2 piezas menores sin desarrollar
