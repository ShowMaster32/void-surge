extends Control
class_name ZoneIndicator
## ZoneIndicator - Mostra la zona corrente con animazione

@onready var zone_name_label: Label = $PanelContainer/VBoxContainer/ZoneNameLabel
@onready var zone_desc_label: Label = $PanelContainer/VBoxContainer/ZoneDescLabel
@onready var panel: PanelContainer = $PanelContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var current_zone: ZoneData
var hide_timer: Timer


func _ready() -> void:
	# Nascondi inizialmente
	modulate.a = 0
	
	# Timer per nascondere dopo un po'
	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)


func show_zone(zone_data: ZoneData) -> void:
	current_zone = zone_data
	
	if not zone_data:
		return
	
	# Aggiorna testo
	zone_name_label.text = zone_data.zone_name.to_upper()
	zone_desc_label.text = zone_data.description
	
	# Colore basato sulla zona
	var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style:
		style.border_color = zone_data.glow_color
		panel.add_theme_stylebox_override("panel", style)
	
	zone_name_label.add_theme_color_override("font_color", zone_data.glow_color)
	
	# Animazione entrata
	_animate_in()
	
	# Nascondi dopo 4 secondi
	hide_timer.start(4.0)


func _animate_in() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Fade in + slide
	position.y = -50
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(self, "position:y", 0.0, 0.5)


func _animate_out() -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(self, "modulate:a", 0.0, 0.3)


func _on_hide_timer_timeout() -> void:
	_animate_out()
