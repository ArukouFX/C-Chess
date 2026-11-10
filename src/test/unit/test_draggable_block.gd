extends GutTest

var BlockScene = preload("res://src/programming/draggable_block.tscn")
var zona: VBoxContainer

func _nuevo_bloque(tipo: String) -> DraggableBlock:
	var b: DraggableBlock = BlockScene.instantiate()
	b.block_id = tipo
	return b

# Workspace de prueba con tres bloques ya ubicados: move_f, move_b, move_l
func before_each():
	zona = VBoxContainer.new()
	zona.position = Vector2(100, 100)
	zona.size = Vector2(200, 400)
	add_child_autofree(zona)
	for tipo in ["move_f", "move_b", "move_l"]:
		var b = _nuevo_bloque(tipo)
		zona.add_child(b)
		b.setup_block(BlockSystem.get_block_info(tipo).duplicate(true))
		b.is_in_workspace = true
	# Esperar a que el contenedor acomode los bloques
	await get_tree().process_frame
	await get_tree().process_frame

func _tipos() -> Array:
	var r := []
	for c in zona.get_children():
		if c is DraggableBlock:
			r.append(c.block_id)
	return r

func _centro_y(i: int) -> float:
	var rect: Rect2 = zona.get_child(i).get_global_rect()
	return rect.position.y + rect.size.y / 2.0

func test_valor_por_defecto_de_block_id_es_vacio():
	var b = autofree(BlockScene.instantiate())
	assert_eq(b.block_id, "", "No debe apuntar a un bloque inexistente")

func test_la_escena_no_tiene_nodos_sobrantes():
	var b = autofree(BlockScene.instantiate())
	assert_null(b.get_node_or_null("Area2D"))
	assert_null(b.get_node_or_null("ColorRect/MarginContainer/VBoxContainer/footer/BlockName"))
	assert_not_null(b.get_node_or_null("ColorRect/MarginContainer/VBoxContainer/Header/BlockName"))

func test_posicion_de_insercion_segun_la_altura():
	var nuevo = _nuevo_bloque("move_r")
	add_child_autofree(nuevo)
	assert_eq(nuevo.get_insertion_slot(zona, _centro_y(0) - 10), 0, "Arriba del primero")
	assert_eq(nuevo.get_insertion_slot(zona, _centro_y(0) + 10), 1, "Entre el primero y el segundo")
	assert_eq(nuevo.get_insertion_slot(zona, _centro_y(2) + 10), 3, "Debajo del ultimo")

func test_insertar_en_el_medio_respeta_el_orden():
	var nuevo = _nuevo_bloque("move_r")
	add_child_autofree(nuevo)
	nuevo.move_to_workspace(zona, 1)
	assert_eq(_tipos(), ["move_f", "move_r", "move_b", "move_l"])
	assert_true(nuevo.is_in_workspace)

func test_insertar_al_principio_y_al_final():
	var primero = _nuevo_bloque("move_r")
	add_child_autofree(primero)
	primero.move_to_workspace(zona, 0)
	var ultimo = _nuevo_bloque("move_fl")
	add_child_autofree(ultimo)
	ultimo.move_to_workspace(zona, 99)
	assert_eq(_tipos(), ["move_r", "move_f", "move_b", "move_l", "move_fl"])

func test_reordenar_un_bloque_del_workspace():
	# Mover el ultimo (move_l) al principio: no se cuenta a si mismo
	var bloque = zona.get_child(2)
	bloque.move_to_workspace(zona, 0)
	assert_eq(_tipos(), ["move_l", "move_f", "move_b"])

func test_el_orden_no_cambia_la_ram_total():
	# Cada bloque paga su base + su posicion, pero el total es siempre
	# suma de bases + n*(n-1)/2: insertar en el medio cambia el orden de
	# ejecucion, no la RAM necesaria
	var diagonal_primero = BlockSystem.calculate_ram_usage([{"type": "move_fl"}, {"type": "move_f"}])
	var diagonal_segundo = BlockSystem.calculate_ram_usage([{"type": "move_f"}, {"type": "move_fl"}])
	assert_eq(diagonal_primero, 3 + (2 + 1))
	assert_eq(diagonal_segundo, 2 + (3 + 1))
	assert_eq(diagonal_primero, diagonal_segundo)
