extends Node

# ══════════════════════════════════════════════════════════════════════════════
#  VOID SURGE – Equipment UI
#
#  Completamente autonomo:
#  • slot con bordi neon per elemento
#  • synergy flash spettacolare
#  • usa solo nodi Godot standard
# ══════════════════════════════════════════════════════════════════════════════

const ELEMENT_COLORS: Dictionary = {
	"fire"    : Color(1.00, 0.35, 0.05),
	"ice"     : Color(0.20, 0.70, 1.00),
	"void"    : Color(0.60, 0.10, 1.00),
	"plasma"  : Color(0.00, 1.00, 0.90),
	"default" : Color(0.55, 0.55, 0.85),
}

const SLOT_COUNT := 4
const SLOT_SIZE  := 54.0

# ── runtime ───────────────────────────────────────────────────────────────────
var _canvas:       CanvasLayer
var _flash_layer:  CanvasLayer
var _slots:        Array = []   # Array[Dictionary {panel, icon_lbl, count_lbl, border_sb}]
var _pickup_lbl:   Label
var _pickup_tween: Tween


# ══════════════════════════════════════════════
#  Avvio
# ══════════════════════════════════════════════

func _ready() -> void:
	# Rimuovi i vecchi nodi figli definiti nella scena (.tscn) per evitare sovrapposizioni
	for child in get_children():
		child.queue_free()

	_canvas = CanvasLayer.new()
	_canvas.layer = 21
	add_child(_canvas)

	_flash_layer = CanvasLayer.new()
	_flash_layer.layer   = 50
	_flash_layer.visible = false
	add_child(_flash_layer)

	_build_slots()
	_build_pickup_banner()
	_connect_signals()


# ══════════════════════════════════════════════
#  Build slot bar
# ══════════════════════════════════════════════

func _build_slots() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	# container orizzontale in alto a sinistra, sotto l'HUD strip (offset_top 48)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hbox.offset_left = 14
	hbox.offset_top  = 48
	hbox.add_theme_constant_override("separation", 6)
	root.add_child(hbox)

	for i in SLOT_COUNT:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.14, 0.92)
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.22, 0.22, 0.45, 0.45)
		pc.add_theme_stylebox_override("panel", sb)
		# vuoto di default: quasi invisibile
		pc.modulate.a = 0.25
		hbox.add_child(pc)

		var inner := Control.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		pc.add_child(inner)

		# icona centrata (vuoto = niente testo)
		var icon_lbl := Label.new()
		icon_lbl.text = ""
		icon_lbl.add_theme_font_size_override("font_size", 24)
		icon_lbl.add_theme_color_override("font_color", Color.WHITE)
		icon_lbl.add_theme_constant_override("outline_size", 3)
		icon_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
		icon_lbl.set_anchors_preset(Control.PRESET_CENTER)
		icon_lbl.offset_left   = -16
		icon_lbl.offset_right  = 16
		icon_lbl.offset_top    = -14
		icon_lbl.offset_bottom = 14
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		inner.add_child(icon_lbl)

		# count in basso a destra
		var count_lbl := Label.new()
		count_lbl.text = ""
		count_lbl.add_theme_font_size_override("font_size", 10)
		count_lbl.add_theme_color_override("font_color", Color.WHITE)
		count_lbl.add_theme_constant_override("outline_size", 2)
		count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_lbl.offset_left = -22
		count_lbl.offset_top  = -18
		inner.add_child(count_lbl)

		_slots.append({
			"panel"     : pc,
			"icon_lbl"  : icon_lbl,
			"count_lbl" : count_lbl,
			"border_sb" : sb,
		})

func _build_pickup_banner() -> void:
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root_ctrl)

	_pickup_lbl = Label.new()
	_pickup_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_pickup_lbl.offset_top    = 115
	_pickup_lbl.offset_bottom = 142
	_pickup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_lbl.add_theme_font_size_override("font_size", 17)
	_pickup_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_pickup_lbl.add_theme_constant_override("outline_size", 4)
	_pickup_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_pickup_lbl.modulate.a = 0.0
	root_ctrl.add_child(_pickup_lbl)


# ══════════════════════════════════════════════
#  Segnali (tutti opzionali)
# ══════════════════════════════════════════════

func _connect_signals() -> void:
	if EquipmentManager.has_signal("equipment_picked_up"):
		EquipmentManager.equipment_picked_up.connect(_on_pickup)
	if EquipmentManager.has_signal("synergy_activated"):
		EquipmentManager.synergy_activated.connect(_on_synergy)
	if EquipmentManager.has_signal("equipment_stats_changed"):
		EquipmentManager.equipment_stats_changed.connect(_refresh)
	if EquipmentManager.has_signal("inventory_changed"):
		EquipmentManager.inventory_changed.connect(_refresh)


# ══════════════════════════════════════════════
#  Aggiornamento slot
# ══════════════════════════════════════════════

func _refresh(_arg = null) -> void:
	if not EquipmentManager.has_method("get_inventory_display"):
		return
	var inv = EquipmentManager.get_inventory_display()
	if not inv is Array:
		return

	for i in SLOT_COUNT:
		var slot: Dictionary = _slots[i]
		var panel: PanelContainer = slot["panel"]
		if i < inv.size():
			var item = inv[i]
			if not item is Dictionary:
				continue
			var element: String = item.get("element", item.get("type", "default"))
			var col: Color = ELEMENT_COLORS.get(element, ELEMENT_COLORS["default"])
			var icon: String = _icon_for(item.get("type", item.get("category", "")))
			var stacks: int  = item.get("stacks", item.get("count", 1))

			slot["icon_lbl"].text = icon
			slot["icon_lbl"].add_theme_color_override("font_color",
				Color(col.r, col.g, col.b, 0.95))
			slot["border_sb"].border_color = Color(col.r, col.g, col.b, 0.80)
			slot["count_lbl"].text = "x%d" % stacks if stacks > 1 else ""

			# slot diventa completamente visibile
			create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)
			# flash bordo
			var tw := create_tween()
			tw.tween_property(slot["border_sb"], "border_color",
				col.lightened(0.5), 0.15)
			tw.tween_property(slot["border_sb"], "border_color", col, 0.4)
		else:
			slot["icon_lbl"].text = ""
			slot["border_sb"].border_color = Color(0.22, 0.22, 0.45, 0.45)
			slot["count_lbl"].text = ""
			# slot quasi invisibile
			create_tween().tween_property(panel, "modulate:a", 0.25, 0.3)

func _on_pickup(item_name: String = "", element: String = "default") -> void:
	_refresh()
	if item_name == "":
		return
	var col: Color = ELEMENT_COLORS.get(element, ELEMENT_COLORS["default"])
	_pickup_lbl.text = "✦  " + item_name.to_upper() + "  ✦"
	_pickup_lbl.add_theme_color_override("font_color", col.lightened(0.3))
	if _pickup_tween:
		_pickup_tween.kill()
	_pickup_tween = create_tween()
	_pickup_tween.tween_property(_pickup_lbl, "modulate:a", 1.0, 0.15)
	_pickup_tween.tween_property(_pickup_lbl, "modulate:a", 0.0, 0.60).set_delay(1.5)

func _icon_for(type_str: String) -> String:
	match type_str.to_lower():
		"weapon"    : return "⚔"
		"armor"     : return "🛡"
		"relic"     : return "💠"
		"consumable": return "💊"
		"augment"   : return "⚙"
		_            : return "✦"


# ══════════════════════════════════════════════
#  SYNERGY FLASH
# ══════════════════════════════════════════════

func _on_synergy(data = null) -> void:
	var name_str := "SYNERGY"
	var element  := "default"
	if data is Dictionary:
		name_str = data.get("name", name_str)
		element  = data.get("element", element)
	elif data is String:
		name_str = data
	var col: Color = ELEMENT_COLORS.get(element, ELEMENT_COLORS["default"])
	_play_flash(name_str, col)

func _play_flash(synergy_name: String, col: Color) -> void:
	for c in _flash_layer.get_children():
		c.queue_free()
	_flash_layer.visible = true

	# overlay colorato
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.0)
	_flash_layer.add_child(overlay)

	# testo principale
	var lbl := Label.new()
	lbl.text = "⚡  %s  ⚡" % synergy_name.to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", col.lightened(0.45))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	lbl.modulate.a  = 0.0
	lbl.scale       = Vector2(0.4, 0.4)
	lbl.pivot_offset = DisplayServer.window_get_size() / 2
	_flash_layer.add_child(lbl)

	# sub-label
	var sub := Label.new()
	sub.text = "SYNERGY  ACTIVATED"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub.offset_top  = -80
	sub.offset_left = -250
	sub.offset_right = 250
	sub.add_theme_font_size_override("font_size", 16)
	# FIX: alpha era 0.0 → testo invisibile, restava solo il contorno nero
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0, 1.0))
	sub.add_theme_constant_override("outline_size", 3)
	sub.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.15, 0.85))
	_flash_layer.add_child(sub)

	# animazione
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "color:a",   0.40, 0.18)
	tw.tween_property(lbl, "modulate:a",    1.00, 0.18)
	tw.tween_property(lbl, "scale", Vector2(1.20, 1.20), 0.18
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lbl, "scale", Vector2(1.00, 1.00), 0.15
	).set_delay(0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a",    1.00, 0.25).set_delay(0.22)
	tw.tween_property(overlay, "color:a",   0.20, 0.60).set_delay(0.35)
	tw.tween_property(overlay, "color:a",   0.00, 0.50).set_delay(1.55)
	tw.tween_property(lbl, "modulate:a",    0.00, 0.50).set_delay(1.55)
	tw.tween_property(sub, "modulate:a",    0.00, 0.40).set_delay(1.65)
	tw.set_parallel(false)
	tw.tween_callback(func():
		_flash_layer.visible = false
		for c in _flash_layer.get_children():
			c.queue_free()
	).set_delay(2.10)

	# bounce testo
	var bounce := create_tween().set_loops(3)
	bounce.tween_property(lbl, "scale", Vector2(1.08, 0.92), 0.10
	).set_ease(Tween.EASE_OUT).set_delay(0.33)
	bounce.tween_property(lbl, "scale", Vector2(1.00, 1.00), 0.10
	).set_ease(Tween.EASE_IN)
