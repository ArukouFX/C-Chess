extends Control

@onready var challenge_list = $ScrollContainer/ChallengeList
@onready var back_button = $BackButton

# Nombres legibles por categoría, para no mostrarle el id técnico al jugador
const CATEGORY_LABELS = {
	"efficiency": "Eficiencia de RAM",
	"movement": "Movimiento",
	"escape": "Escape",
	"capture": "Captura",
	"checkmate": "Jaque Mate"
}

func _ready():
	_populate_list()
	back_button.pressed.connect(_on_back_pressed)

func _populate_list():
	for child in challenge_list.get_children():
		child.queue_free()

	var all_challenges = ChallengeDatabase.get_all()
	for i in range(all_challenges.size()):
		var ch = all_challenges[i]
		var button = Button.new()

		var category_label = CATEGORY_LABELS.get(ch.get("category", ""), ch.get("category", ""))
		button.text = "%d. %s  [%s]" % [i + 1, ch["title"], category_label]
		button.custom_minimum_size = Vector2(400, 50)

		# closure segura: capturamos el id por valor, no por índice mutable
		var challenge_id = ch["id"]
		button.pressed.connect(func(): _on_challenge_selected(challenge_id))

		challenge_list.add_child(button)

var _leaving: bool = false

func _on_challenge_selected(challenge_id: String):
	if _leaving:
		return
	_leaving = true
	GlobalConfig.selected_challenge_id = challenge_id
	GlobalConfig.challenge_mode = true
	get_tree().change_scene_to_file("res://src/challenge/challenge_scene.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://src/ui/menus/MainMenu.tscn")
