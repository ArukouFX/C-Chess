extends Node

# ============================================================
# SaveManager — Autoload Singleton
# Añadilo en Project > Project Settings > Autoload
# con el nombre "SaveManager"
# ============================================================

const DEFAULT_SAVE_PATH := "user://savegame.json"

# Ruta activa. Los tests la cambian para no tocar la partida real.
var SAVE_PATH: String = DEFAULT_SAVE_PATH

# Devuelve true si existe una partida guardada
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Borra la partida guardada (útil al terminar el juego)
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print("[SaveManager] Partida borrada.")

# ----------------------------------------------------------
# GUARDAR
# Recibe el estado del juego ya serializado como Dictionary
# ----------------------------------------------------------
func save_game(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] No se pudo abrir el archivo para escritura: " + SAVE_PATH)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[SaveManager] Partida guardada en: " + SAVE_PATH)
	return true

# ----------------------------------------------------------
# CARGAR
# Devuelve el Dictionary con los datos, o {} si no existe
# ----------------------------------------------------------
func load_game() -> Dictionary:
	if not has_save():
		print("[SaveManager] No hay partida guardada.")
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] No se pudo abrir el archivo para lectura.")
		return {}

	var raw := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if parsed == null or not parsed is Dictionary:
		push_error("[SaveManager] Archivo de guardado corrupto.")
		return {}

	print("[SaveManager] Partida cargada correctamente.")
	return parsed
