extends Sprite2D

@export var screen_height_ratio: float = 0.2
# Posición en el panel derecho: fracción del ancho de pantalla donde empieza
@export var panel_right_start: float = 0.4  # fraccion del ancho del diseno
@export var vertical_position: float = 0.10  # fraccion del alto desde arriba

var base_scale: Vector2 = Vector2.ONE

func _ready():
	update_turn("white")
	_adjust_layout.call_deferred()

func _adjust_layout():
	if not texture:
		return
	
	# Coordenadas del diseno de 1360x768 (la camara lo centra en pantalla)
	var viewport_size = Vector2(ResolutionManager.BASE_SIZE)
	
	# Escala basada en altura objetivo
	var target_height = viewport_size.y * screen_height_ratio
	var texture_height = float(texture.get_height())
	if texture_height <= 0:
		return
	
	var final_scale_value = target_height / texture_height
	base_scale = Vector2.ONE * final_scale_value
	self.scale = base_scale
	
	# Posición en el panel derecho, en coordenadas globales
	var panel_center_x = viewport_size.x * panel_right_start + (viewport_size.x * (1.0 - panel_right_start)) / 2.0
	var target_y = viewport_size.y * vertical_position
	
	global_position = Vector2(panel_center_x, target_y)

func update_turn(turn: String):
	var texture_path = "res://assets/graphics/turn-white.png" if turn == "white" else "res://assets/graphics/turn-black.png"
	texture = load(texture_path)
	_adjust_layout()
	animate_turn_change()

func animate_turn_change():
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * 1.15, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", base_scale, 0.2).set_trans(Tween.TRANS_SINE)
