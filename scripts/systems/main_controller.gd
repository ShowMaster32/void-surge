extends Node2D
## MainController - Gestisce la scena di gioco principale

@onready var zone_generator: ZoneGenerator = $ZoneGenerator
@onready var zone_indicator: ZoneIndicator = $ZoneIndicator


func _ready() -> void:
	# Connetti segnali
	if zone_generator:
		zone_generator.zone_changed.connect(_on_zone_changed)
	
	# Avvia il gioco quando la scena è pronta
	GameManager.start_game(1)


func _on_zone_changed(zone_data: ZoneData) -> void:
	if zone_indicator:
		zone_indicator.show_zone(zone_data)
