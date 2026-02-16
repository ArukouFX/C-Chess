extends Sprite2D

# 0.15 significa que el sprite ocupará el 15% de la altura de la pantalla
@export var screen_height_ratio: float = 0.4 
@export var horizontal_offset: float = -480.0 

var base_scale: Vector2 = Vector2.ONE

func _ready():
	var res_manager = get_node_or_null("/root/ResolutionManager")
	if res_manager:
		# IMPORTANTE: Asegúrate de que el signal pase el Vector2i
		res_manager.resolution_changed.connect(_on_resolution_changed)
	
	update_turn("white")
	_adjust_layout.call_deferred()

func _on_resolution_changed(_new_res: Vector2i):
	_adjust_layout()

func _adjust_layout():
	if not texture:
		return
		
	var viewport_size = get_viewport_rect().size
	# Calculamos el factor de escala general del juego
	var game_scale_factor = viewport_size.y / 768.0
	
	# --- NUEVA LÓGICA DE ESCALADO ---
	# Calculamos cuánto mide la textura en píxeles y cuánto debería medir en pantalla
	var target_height = viewport_size.y * screen_height_ratio
	var texture_height = texture.get_height()
	
	# La escala base es la proporción entre el objetivo y el tamaño real del recurso
	var final_scale_value = target_height / texture_height
	base_scale = Vector2.ONE * final_scale_value
	self.scale = base_scale
	# --------------------------------
	
	# Posicionamiento
	var board = get_node_or_null("/root/Main/Board") 
	if board:
		# Mantenemos el offset relativo al factor de escala del juego
		global_position.x = board.global_position.x + (horizontal_offset * game_scale_factor)
		global_position.y = board.global_position.y
	else:
		global_position = Vector2(200 * game_scale_factor, viewport_size.y / 2)

func update_turn(turn: String):
	var texture_path = "res://assets/graphics/turn-white.png" if turn == "white" else "res://assets/graphics/turn-black.png"
	texture = load(texture_path)
	
	# Re-ajustamos el layout al cambiar textura por si tienen tamaños distintos
	_adjust_layout()
	animate_turn_change()

func animate_turn_change():
	# Matar tweens previos para evitar que la escala se quede "atascada" grande
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * 1.15, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", base_scale, 0.2).set_trans(Tween.TRANS_SINE)
