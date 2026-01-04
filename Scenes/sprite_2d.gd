extends Sprite2D

@onready var resolution_manager = get_node_or_null("/root/ResolutionManager")

func _ready():
	# Configurar para que cubra toda la pantalla
	centered = false
	
	if resolution_manager:
		if resolution_manager.has_signal("resolution_changed"):
			resolution_manager.resolution_changed.connect(_on_resolution_changed)
		
		# Aplicar escala inicial
		apply_background_scale()
	else:
		# Sin ResolutionManager, estirar manualmente
		var viewport_size = get_viewport_rect().size
		self.scale = Vector2(
			viewport_size.x / texture.get_width(),
			viewport_size.y / texture.get_height()
		)

func _on_resolution_changed(new_size: Vector2, scale_factor: float):
	apply_background_scale()

func apply_background_scale():
	if not resolution_manager:
		return
	
	var viewport_size = get_viewport_rect().size
	
	# Estirar background para cubrir toda la pantalla
	self.scale = Vector2(
		viewport_size.x / texture.get_width(),
		viewport_size.y / texture.get_height()
	)
	
	# Posicionar en (0,0)
	self.position = Vector2.ZERO
	
	print("Background escalado a: ", self.scale)
