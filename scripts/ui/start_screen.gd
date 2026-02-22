extends CanvasLayer
class_name StartScreen
## StartScreen - Schermata iniziale con obiettivi e controlli
## Si nasconde quando il giocatore preme START e avvia il gioco

@onready var start_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/StartButton


func _ready() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_on_start_pressed)
	start_button.grab_focus()


func _input(event: InputEvent) -> void:
	# Consenti anche Enter/Space per avviare
	if visible and event.is_action_pressed("ui_accept"):
		_on_start_pressed()


func _on_start_pressed() -> void:
	visible = false
	# Avvia il gioco tramite MainController
	var main := get_node_or_null("/root/Main")
	if main and main.has_method("begin_game"):
		main.begin_game()
