extends Control
class_name EquipmentUI
## EquipmentUI - Mostra equipaggiamenti raccolti e sinergie attive

@onready var equipment_container: HBoxContainer = $MarginContainer/VBoxContainer/EquipmentContainer
@onready var synergy_container: VBoxContainer = $MarginContainer/VBoxContainer/SynergyContainer
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel

var equipment_icons: Dictionary = {}  # equipment_id -> Control node

const MAX_VISIBLE_ICONS := 10
const ICON_SIZE := Vector2(32, 32)


func _ready() -> void:
	# Connetti ai segnali di EquipmentManager
	EquipmentManager.equipment_collected.connect(_on_equipment_collected)
	EquipmentManager.equipment_stats_changed.connect(_on_stats_changed)
	EquipmentManager.synergy_activated.connect(_on_synergy_activated)
	EquipmentManager.synergy_deactivated.connect(_on_synergy_deactivated)


func _on_equipment_collected(equipment: EquipmentData) -> void:
	_update_equipment_display()
	_show_collection_popup(equipment)


func _on_stats_changed(stats: Dictionary) -> void:
	_update_stats_display(stats)


func _on_synergy_activated(synergy_name: String) -> void:
	_show_synergy_notification(synergy_name, true)
	_update_synergy_display()


func _on_synergy_deactivated(synergy_name: String) -> void:
	_show_synergy_notification(synergy_name, false)
	_update_synergy_display()


func _update_equipment_display() -> void:
	## Aggiorna la visualizzazione degli equipaggiamenti
	# Pulisci icone esistenti
	for child in equipment_container.get_children():
		child.queue_free()
	equipment_icons.clear()
	
	# Ottieni inventario
	var inventory := EquipmentManager.get_inventory_display()
	
	# Crea icone per ogni equipaggiamento
	for i in mini(inventory.size(), MAX_VISIBLE_ICONS):
		var item: Dictionary = inventory[i]
		var equipment: EquipmentData = item["equipment"]
		var count: int = item["count"]
		
		var icon_node := _create_equipment_icon(equipment, count)
		equipment_container.add_child(icon_node)
		equipment_icons[equipment.equipment_id] = icon_node
	
	# Mostra indicatore se ci sono più equipaggiamenti
	if inventory.size() > MAX_VISIBLE_ICONS:
		var more_label := Label.new()
		more_label.text = "+%d" % (inventory.size() - MAX_VISIBLE_ICONS)
		more_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		equipment_container.add_child(more_label)


func _create_equipment_icon(equipment: EquipmentData, count: int) -> Control:
	## Crea un'icona per l'equipaggiamento
	var container := PanelContainer.new()
	container.custom_minimum_size = ICON_SIZE
	
	# Style basato su rarità
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = equipment.get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	container.add_theme_stylebox_override("panel", style)
	
	# Contenuto
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(vbox)
	
	# Icona colorata (placeholder)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.color = equipment.glow_color
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	
	# Count se > 1
	if count > 1:
		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(count_label)
	
	# Tooltip
	container.tooltip_text = _get_equipment_tooltip(equipment, count)
	
	return container


func _get_equipment_tooltip(equipment: EquipmentData, count: int) -> String:
	var tooltip := "[%s] %s" % [equipment.get_rarity_name(), equipment.equipment_name]
	if count > 1:
		tooltip += " x%d" % count
	tooltip += "\n%s" % equipment.description
	tooltip += "\n\n%s" % equipment.get_stats_summary()
	if equipment.element != EquipmentData.ElementType.NONE:
		tooltip += "\nElement: %s" % equipment.get_element_name()
	return tooltip


func _update_synergy_display() -> void:
	## Aggiorna visualizzazione sinergie attive
	# Pulisci
	for child in synergy_container.get_children():
		child.queue_free()
	
	# Mostra sinergie attive
	for synergy_id in EquipmentManager.get_active_synergies():
		var synergy_info := EquipmentManager.get_synergy_info(synergy_id)
		if synergy_info.is_empty():
			continue
		
		var synergy_label := Label.new()
		synergy_label.text = "⚡ %s" % synergy_info["name"]
		synergy_label.add_theme_font_size_override("font_size", 12)
		synergy_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		synergy_label.tooltip_text = synergy_info["description"]
		synergy_container.add_child(synergy_label)


func _update_stats_display(stats: Dictionary) -> void:
	## Aggiorna label stats
	if not stats_label:
		return
	
	var text_parts := []
	
	if stats.get("damage_bonus", 0.0) > 0:
		text_parts.append("DMG +%d%%" % int(stats["damage_bonus"] * 100))
	if stats.get("crit_chance_bonus", 0.0) > 0:
		text_parts.append("CRIT +%d%%" % int(stats["crit_chance_bonus"] * 100))
	if stats.get("pierce_bonus", 0) > 0:
		text_parts.append("PIERCE +%d" % stats["pierce_bonus"])
	if stats.get("fire_rate_bonus", 0.0) > 0:
		text_parts.append("RATE +%d%%" % int(stats["fire_rate_bonus"] * 100))
	
	stats_label.text = " | ".join(text_parts) if text_parts.size() > 0 else ""


func _show_collection_popup(equipment: EquipmentData) -> void:
	## Mostra popup quando si raccoglie un equipaggiamento
	var popup := Label.new()
	popup.text = "+ %s" % equipment.equipment_name
	popup.add_theme_color_override("font_color", equipment.get_rarity_color())
	popup.add_theme_font_size_override("font_size", 16)
	popup.position = Vector2(get_viewport_rect().size.x / 2 - 100, 150)
	popup.modulate.a = 0
	add_child(popup)
	
	# Animazione
	var tween := create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.2)
	tween.tween_property(popup, "position:y", popup.position.y - 30, 0.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.tween_callback(popup.queue_free)


func _show_synergy_notification(synergy_name: String, activated: bool) -> void:
	## Mostra notifica sinergia
	var notification := Label.new()
	notification.text = "⚡ %s %s!" % [synergy_name, "ACTIVATED" if activated else "LOST"]
	notification.add_theme_color_override("font_color", Color(1, 0.8, 0.2) if activated else Color(0.6, 0.4, 0.4))
	notification.add_theme_font_size_override("font_size", 24)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.position = Vector2(get_viewport_rect().size.x / 2 - 150, 200)
	notification.modulate.a = 0
	add_child(notification)
	
	# Animazione
	var tween := create_tween()
	tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(notification, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(notification.queue_free)
