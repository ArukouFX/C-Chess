extends Node2D

var dance_tween: Tween
var is_animating = false

func _ready():
	start_dance_animation()

func start_dance_animation():
	if dance_tween:
		dance_tween.kill()
	
	dance_tween = create_tween()
	dance_tween.set_loops()

	var pulse_duration = 0.6
	
	dance_tween.tween_property(self, "scale", Vector2(1.02, 1.02), pulse_duration)
	dance_tween.tween_property(self, "scale", Vector2(1.0, 1.0), pulse_duration)
	
	is_animating = true

func stop_dance_animation():
	if dance_tween:
		dance_tween.kill()
		dance_tween = null

	var reset_tween = create_tween()
	reset_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	is_animating = false

func on_piece_dragged():
	if is_animating:
		stop_dance_animation()

func on_piece_released():
	if not is_animating:
		await get_tree().create_timer(0.5).timeout
		start_dance_animation()
