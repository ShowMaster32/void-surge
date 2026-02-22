extends Control
class_name EquipmentUI
## EquipmentUI - Barra inferiore: equipaggiamenti, sinergie attive, stat bonus

@onready var equipment_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/BottomRow/EquipmentContainer
@onready var synergy_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TopRow/SynergyContainer
@onready var stats_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopRow/StatsLabel

var equipment_icons: Dictionary = {}  # equipment_id -> Control node

const MAX_VISIBLE_ICONS := 12
const ICON_SIZE := Vector2(48, 48)

# Lettere per tipo equipaggiamento
const TYPE_LETTERS := {
	0: "W",  # WEAPON
	1: "A",  # ARMOR
	2: "U",  # UTILITY
	3: "S",  # SPECIAL
}

# Simboli per elemento
const ELEMENT_SYMBOLS := {
	0: "",    # NONE
	1: "F",   # FIRE
	2: "V",   # VOID
	3: "P",   # PLASMA
	4: "X",   # CHAOS
}


func _ready() -> void:
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
	for child in equipment_container.get_children():
		child.queue_free()
	equipment_icons.clear()

	var inventory := EquipmentManager.get_inventory_display()

	for i in mini(inventory.size(), MAX_VISIBLE_ICONS):
		var item: Dictionary = inventory[i]
		var equipment: EquipmentData = item["equipment"]
		var count: int = item["count"]
		var icon_node := _create_equipment_icon(equipment, count)
		equipment_container.add_child(icon_node)
		equipment_icons[equipment.equipment_id] = icon_node

	if inventory.size() > MAX_VISIBLE_ICONS:
		var more_label := Label.new()
		more_label.text = "+%d" % (inventory.size() - MAX_VISIBLE_ICONS)
		more_label.add_theme_font_size_override("font_size", 12)
		more_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		more_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		equipment_container.add_child(more_label)


func _create_equipment_icon(equipment: EquipmentData, count: int) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = ICON_SIZE

	# Sfondo scuro con bordo colore rarità
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.14, 0.95)
	style.border_color = equipment.get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	container.add_theme_stylebox_override("panel", style)

	# Layout interno
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	container.add_child(vbox)

	# Riga superiore: lettera tipo + simbolo elemento
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 2)
	vbox.add_child(top_row)

	var type_letter := Label.new()
	type_letter.text = TYPE_LETTERS.get(int(equipment.equipment_type), "?")
	type_letter.add_theme_font_size_override("font_size", 14)
	type_letter.add_theme_color_override("font_color", equipment.get_rarity_color())
	type_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(type_letter)

	# Simbolo elemento se presente
	var elem_sym: String = ELEMENT_SYMBOLS.get(int(equipment.element), "")
	if elem_sym != "":
		var elem_label := Label.new()
		elem_label.text = elem_sym
		elem_label.add_theme_font_size_override("font_size", 11)
		elem_label.add_theme_color_override("font_color", equipment.glow_color)
		top_row.add_child(elem_label)

	# Quadratino colore glow come indicatore visivo
	var glow_rect := ColorRect.new()
	glow_rect.custom_minimum_size = Vector2(20, 8)
	glow_rect.color = Color(equipment.glow_color.r, equipment.glow_color.g, equipment.glow_color.b, 0.7)
	glow_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(glow_rect)

	# Count badge se > 1
	if count > 1:
		var count_label := Label.new()
		count_label.text = "x%d" % count
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(count_label)

	# Tooltip completo al passaggio del mouse
	container.tooltip_text = _get_equipment_tooltip(equipment, count)

	return container


func _get_equipment_tooltip(equipment: EquipmentData, count: int) -> String:
	var tooltip := "[%s] %s" % [equipment.get_rarity_name().to_upper(), equipment.equipment_name]
	if count > 1:
		tooltip += " x%d" % count
	tooltip += "\n%s" % equipment.description
	tooltip += "\n\n%s" % equipment.get_stats_summary()
	if equipment.element != EquipmentData.ElementType.NONE:
		tooltip += "\nElement: %s" % equipment.get_element_name()
	return tooltip


func _update_synergy_display() -> void:
	for child in synergy_container.get_children():
		child.queue_free()

	for synergy_id in EquipmentManager.get_active_synergies():
		var synergy_info := EquipmentManager.get_synergy_info(synergy_id)
		if synergy_info.is_empty():
			continue

		# Pill orizzontale per ogni sinergia attiva
		var pill := PanelContainer.new()
		var pill_style := StyleBoxFlat.new()
		pill_style.bg_color = Color(0.2, 0.15, 0.05, 0.9)
		pill_style.border_color = Color(1, 0.8, 0.2, 0.8)
		pill_style.set_border_width_all(1)
		pill_style.set_corner_radius_all(10)
		pill_style.content_margin_left = 6.0
		pill_style.content_margin_right = 6.0
		pill_style.content_margin_top = 2.0
		pill_style.content_margin_bottom = 2.0
		pill.add_theme_stylebox_override("panel", pill_style)

		var synergy_label := Label.new()
		synergy_label.text = synergy_info["name"]
		synergy_label.add_theme_font_size_override("font_size", 11)
		synergy_label.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
		synergy_label.tooltip_text = synergy_info["description"]
		pill.add_child(synergy_label)
		synergy_container.add_child(pill)


func _update_stats_display(stats: Dictionary) -> void:
	if not stats_label:
		return

	var parts := []
	if stats.get("damage_bonus", 0.0) > 0:
		parts.append("DMG +%d%%" % int(stats["damage_bonus"] * 100))
	if stats.get("crit_chance_bonus", 0.0) > 0:
		parts.append("CRIT +%d%%" % int(stats["crit_chance_bonus"] * 100))
	if stats.get("crit_damage_bonus", 0.0) > 0:
		parts.append("CRIT DMG +%d%%" % int(stats["crit_damage_bonus"] * 100))
	if stats.get("fire_rate_bonus", 0.0) > 0:
		parts.append("RATE +%d%%" % int(stats["fire_rate_bonus"] * 100))
	if stats.get("pierce_bonus", 0) > 0:
		parts.append("PIERCE +%d" % stats["pierce_bonus"])
	if stats.get("move_speed_bonus", 0.0) > 0:
		parts.append("SPD +%d%%" % int(stats["move_speed_bonus"] * 100))
	if stats.get("health_regen", 0.0) > 0:
		parts.append("REGEN +%.1f/s" % stats["health_regen"])

	stats_label.text = "  |  ".join(parts)


func _show_collection_popup(equipment: EquipmentData) -> void:
	var popup := Label.new()
	popup.text = "+ %s" % equipment.equipment_name
	popup.add_theme_color_override("font_color", equipment.get_rarity_color())
	popup.add_theme_font_size_override("font_size", 18)
	# Posiziona sopra la barra inferiore, al centro dello schermo
	popup.position = Vector2(get_viewport_rect().size.x / 2.0 - 100.0, -60.0)
	popup.modulate.a = 0.0
	add_child(popup)

	var tween := create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.2)
	tween.tween_property(popup, "position:y", popup.position.y - 40.0, 0.6)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.tween_callback(popup.queue_free)


func _show_synergy_notification(synergy_name: String, activated: bool) -> void:
	var notification := Label.new()
	notification.text = "%s %s!" % [synergy_name, "ACTIVATED" if activated else "LOST"]
	var notif_color := Color(1, 0.8, 0.2) if activated else Color(0.7, 0.35, 0.35)
	notification.add_theme_color_override("font_color", notif_color)
	notification.add_theme_font_size_override("font_size", 22)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.position = Vector2(get_viewport_rect().size.x / 2.0 - 160.0, -100.0)
	notification.modulate.a = 0.0
	add_child(notification)

	var tween := create_tween()
	tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(1.08, 1.08), 0.1)
	tween.tween_property(notification, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(1.5)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(notification.queue_free)
