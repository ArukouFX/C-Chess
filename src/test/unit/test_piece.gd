# test/unit/test_piece.gd
extends GutTest

var PieceScene = preload("res://src/entities/pieces/piece.tscn")
var textura = preload("res://assets/graphics/white/white-pawn.png")

func _nueva_pieza(tex: Texture2D, color: String, tipo: String, pos: Vector2) -> Node:
	var piece = autofree(PieceScene.instantiate())
	add_child_autofree(piece)
	piece.setup_piece(tex, color, tipo, pos)
	return piece

func test_setup_piece_asigna_ram_correcta():
	var piece = _nueva_pieza(null, "white", "queen", Vector2(3, 7))
	assert_eq(piece.available_ram, 32)
	assert_eq(piece.piece_id, "white_queen_3_7")

func test_get_programming_status_sin_programa():
	var piece = _nueva_pieza(null, "white", "horse", Vector2(1, 7))
	assert_eq(piece.get_programming_status(), "No program")

func test_escala_por_defecto_equivale_a_la_original():
	# Textura de 160 px en celda de 80 px: la misma escala 0.4375 de antes
	var piece = _nueva_pieza(textura, "white", "pawn", Vector2(0, 6))
	assert_almost_eq(piece.scale.x, 0.4375, 0.0001)

func test_escala_acompana_el_tamano_de_celda():
	var piece = _nueva_pieza(textura, "white", "pawn", Vector2(0, 6))
	piece.fit_to_cell(96.0)
	var lado_en_pantalla = textura.get_size().x * piece.scale.x
	assert_almost_eq(lado_en_pantalla, 96.0 * piece.CELL_FILL, 0.01)

func test_zona_de_clic_cubre_toda_la_pieza():
	# La forma hereda la escala del sprite; antes se escalaba dos veces y
	# quedaba de unos 30 px sobre una pieza de 70 px
	var piece = _nueva_pieza(textura, "white", "pawn", Vector2(0, 6))
	var forma: RectangleShape2D = piece.get_node("Area2D/CollisionShape2D").shape
	var lado_clic_en_pantalla = forma.size.x * piece.scale.x
	assert_almost_eq(lado_clic_en_pantalla, 80.0 * piece.CELL_FILL, 0.01)

func test_clic_izquierdo_emite_selected():
	var piece = _nueva_pieza(textura, "white", "pawn", Vector2(0, 6))
	watch_signals(piece)
	var clic = InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	piece._on_area_2d_input_event(null, clic, 0)
	assert_signal_emitted_with_parameters(piece, "selected", [piece])

func test_consumir_escape_lo_quita_salvo_si_es_permanente():
	var piece = _nueva_pieza(null, "white", "pawn", Vector2(0, 6))
	piece.defense_protocol = {"type": "white_escape_1"}
	piece.defense_protocol_active = true
	piece.consume_defense_protocol()
	assert_false(piece.defense_protocol_active)
	assert_null(piece.defense_protocol)

	piece.defense_protocol = {"type": "white_escape_1"}
	piece.defense_protocol_active = true
	piece.defense_protocol_permanent = true
	piece.consume_defense_protocol()
	assert_true(piece.defense_protocol_active, "Un escape permanente no se consume")

func test_seleccionar_y_deseleccionar():
	var piece = _nueva_pieza(textura, "white", "pawn", Vector2(0, 6))
	assert_false(piece.is_selected)
	piece.set_selected(true)
	assert_true(piece.is_selected)
	piece.set_selected(false)
	assert_false(piece.is_selected)
