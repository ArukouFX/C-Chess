extends Node

class_name ExecutionManager

signal execution_started
signal execution_completed
signal move_executed(piece, from_pos, to_pos)

var move_queue: Array = []
var is_executing: bool = false

func queue_move(piece: Node, command: Dictionary):
	move_queue.append({"piece": piece, "command": command})

func execute_all():
	if is_executing or move_queue.is_empty():
		return
	
	is_executing = true
	emit_signal("execution_started")
	_execute_next()

func _execute_next():
	if move_queue.is_empty():
		is_executing = false
		emit_signal("execution_completed")
		return
	
	var move_data = move_queue.pop_front()
	var piece = move_data["piece"]
	var command = move_data["command"]
	
	_process_command(piece, command)
	
	# Esperar y ejecutar siguiente
	await get_tree().create_timer(0.5).timeout
	_execute_next()

func _process_command(piece: Node, command: Dictionary):
	match command.get("action"):
		"move":
			var from_pos = piece.board_position
			var to_pos = command["target"]
			piece.board_position = to_pos
			
			# Animación
			var tween = create_tween()
			tween.tween_property(piece, "position", 
				board.get_nearest_cell_pos(board_position_to_world(to_pos)), 0.3)
			
			emit_signal("move_executed", piece, from_pos, to_pos)
