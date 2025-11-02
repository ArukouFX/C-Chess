extends Sprite2D

func _ready():
	#initialize Turn
	update_turn("white")

func update_turn(turn: String):
	if turn == "white":
		texture = load("res://Assets/turn-white.png")
	else:
		texture = load("res://Assets/turn-black.png")
	
	print("🔄 Turn display updated to: ", turn)
	
	animate_turn_change()

func animate_turn_change():
	var tween = create_tween()
	tween.set_loops()  # Loop infinito
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.4)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.4)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
