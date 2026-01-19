extends Node2D
## MainController - Gestisce la scena di gioco principale

func _ready() -> void:
	# Avvia il gioco quando la scena è pronta
	GameManager.start_game(1)
