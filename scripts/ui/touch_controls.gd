extends CanvasLayer
## TouchControls — Overlay touch per Android/iOS
## Si nasconde automaticamente quando viene connesso un controller fisico.
## Fornisce: joystick sinistro (movimento), joystick destro (mira + sparo),
##            pulsanti Q / E (poteri), pulsante PAUSE.
##
## Integrazione con InputManager:
##   InputManager.touch_move_vector   → movimento
##   InputManager.touch_aim_vector    → mira
##   InputManager.touch_shooting      → sparo continuo
##   Iniezione tramite Input.parse_input_event() per Q / E / pause

# ── Costanti dimensioni ──────────────────────────────────────────────────────
const JOY_OUTER_R    := 80.0   ## raggio cerchio esterno joystick
const JOY_INNER_R    := 32.0   ## raggio pallino joystick
const JOY_DEAD       := 10.0   ## dead-zone pixel
const BTN_SHOOT_R    := 64.0   ## raggio bottone sparo
const BTN_SM_R       := 44.0   ## raggio bottoni Q / E / pausa
const EDGE_PAD       := 24.0   ## margine bordo schermo
const BTN_ALPHA      := 0.55   ## opacità bottoni a riposo
const BTN_ALPHA_PRESS:= 0.90   ## opacità bottone premuto

# ── Colori ───────────────────────────────────────────────────────────────────
const C_JOY_OUTER  := Color(0.20, 0.80, 1.00, 0.30)
const C_JOY_INNER  := Color(0.20, 0.80, 1.00, 0.70)
const C_SHOOT      := Color(0.00, 1.00, 0.60, BTN_ALPHA)
const C_SHOOT_P    := Color(0.00, 1.00, 0.60, BTN_ALPHA_PRESS)
const C_Q          := Color(0.60, 0.20, 1.00, BTN_ALPHA)
const C_Q_P        := Color(0.60, 0.20, 1.00, BTN_ALPHA_PRESS)
const C_E          := Color(1.00, 0.60, 0.00, BTN_ALPHA)
const C_E_P        := Color(1.00, 0.60, 0.00, BTN_ALPHA_PRESS)
const C_PAUSE      := Color(1.00, 1.00, 1.00, 0.35)

# ── Stato joystick sinistro (movimento) ──────────────────────────────────────
var _lj_touch_id  : int     = -1
var _lj_origin    : Vector2 = Vector2.ZERO
var _lj_outer_node: Control = null
var _lj_inner_node: Control = null

# ── Stato joystick destro (mira + sparo) ─────────────────────────────────────
var _rj_touch_id  : int     = -1
var _rj_origin    : Vector2 = Vector2.ZERO
var _rj_outer_node: Control = null
var _rj_inner_node: Control = null

# ── Nodi bottoni ─────────────────────────────────────────────────────────────
var _btn_shoot  : Control = null
var _btn_q      : Control = null
var _btn_e      : Control = null
var _btn_pause  : Control = null

# ── Root container ───────────────────────────────────────────────────────────
var _root: Control = null

# ── Flag visibilità ──────────────────────────────────────────────────────────
var _controller_active: bool = false


# ════════════════════════════════════════════════════════════════════════════
#  INIT
# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 25          # sopra l'HUD (layer 20)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_ui()

	# Controller connect/disconnect
	InputManager.controller_connected.connect(_on_controller_connected)
	InputManager.controller_disconnected.connect(_on_controller_disconnected)

	# Nasconde su PC; mostra su mobile o quando non ci sono controller
	var is_mobile: bool = OS.get_name() in ["Android", "iOS"]
	var has_pad: bool   = not Input.get_connected_joypads().is_empty()

	if has_pad:
		_set_touch_visible(false)
		_controller_active = true
	else:
		_set_touch_visible(is_mobile)


# ════════════════════════════════════════════════════════════════════════════
#  BUILD UI
# ════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ── Joystick sinistro (base fissa) ───────────────────────────────────
	_lj_outer_node = _make_circle(JOY_OUTER_R, C_JOY_OUTER)
	_lj_inner_node = _make_circle(JOY_INNER_R, C_JOY_INNER)
	_root.add_child(_lj_outer_node)
	_root.add_child(_lj_inner_node)

	# ── Joystick destro (mira, segue il dito) ────────────────────────────
	_rj_outer_node = _make_circle(JOY_OUTER_R, C_JOY_OUTER)
	_rj_inner_node = _make_circle(JOY_INNER_R, C_JOY_INNER)
	_root.add_child(_rj_outer_node)
	_root.add_child(_rj_inner_node)

	# Joystick nascosti finché non si tocca lo schermo
	_lj_outer_node.visible = false
	_lj_inner_node.visible = false
	_rj_outer_node.visible = false
	_rj_inner_node.visible = false

	# ── Bottoni fissi (angolo in basso a destra) ─────────────────────────
	# Calcolati nel primo frame perché la viewport non è ancora pronta qui;
	# li posizioniamo in _notification(NOTIFICATION_WM_SIZE_CHANGED) e in _ready.
	_btn_shoot = _make_button(BTN_SHOOT_R, C_SHOOT, "FIRE")
	_btn_q     = _make_button(BTN_SM_R,   C_Q,     "Q")
	_btn_e     = _make_button(BTN_SM_R,   C_E,     "E")
	_btn_pause = _make_button(BTN_SM_R,   C_PAUSE, "II")
	_root.add_child(_btn_shoot)
	_root.add_child(_btn_q)
	_root.add_child(_btn_e)
	_root.add_child(_btn_pause)

	# Layout dopo il primo frame
	call_deferred("_layout_buttons")


func _layout_buttons() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var W: float = vp.get_visible_rect().size.x
	var H: float = vp.get_visible_rect().size.y

	# FIRE — centro-destra basso
	var shoot_x := W - EDGE_PAD - BTN_SHOOT_R
	var shoot_y := H - EDGE_PAD - BTN_SHOOT_R
	_place_circle(_btn_shoot, Vector2(shoot_x, shoot_y))

	# Q — sopra e a sinistra di FIRE
	_place_circle(_btn_q, Vector2(shoot_x - BTN_SHOOT_R - BTN_SM_R - 12.0,
								 shoot_y - BTN_SHOOT_R + BTN_SM_R))
	# E — sopra FIRE
	_place_circle(_btn_e, Vector2(shoot_x,
								 shoot_y - BTN_SHOOT_R - BTN_SM_R - 12.0))

	# PAUSE — angolo in alto a destra
	_place_circle(_btn_pause, Vector2(W - EDGE_PAD - BTN_SM_R,
									  EDGE_PAD + BTN_SM_R))


# ════════════════════════════════════════════════════════════════════════════
#  INPUT TOUCH
# ════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_on_touch_down(e.index, e.position)
		else:
			_on_touch_up(e.index, e.position)

	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_on_touch_drag(e.index, e.position)


func _on_touch_down(id: int, pos: Vector2) -> void:
	var vp_w: float = get_viewport().get_visible_rect().size.x

	# ── Bottoni (controlla prima, perché sovrapposti alla zona destra) ───
	if _hit_circle(_btn_shoot, BTN_SHOOT_R, pos):
		_press_button(_btn_shoot, C_SHOOT_P)
		InputManager.touch_shooting = true
		return
	if _hit_circle(_btn_q, BTN_SM_R, pos):
		_press_button(_btn_q, C_Q_P)
		_inject_action("activate_power_q", true)
		return
	if _hit_circle(_btn_e, BTN_SM_R, pos):
		_press_button(_btn_e, C_E_P)
		_inject_action("activate_power_e", true)
		return
	if _hit_circle(_btn_pause, BTN_SM_R, pos):
		_press_button(_btn_pause, Color(1, 1, 1, 0.80))
		_inject_action("pause", true)
		return

	# ── Joystick sinistro — metà sinistra dello schermo ──────────────────
	if pos.x < vp_w * 0.5 and _lj_touch_id == -1:
		_lj_touch_id = id
		_lj_origin   = pos
		_lj_outer_node.visible = true
		_lj_inner_node.visible = true
		_place_circle(_lj_outer_node, pos)
		_place_circle(_lj_inner_node, pos)
		return

	# ── Joystick destro — metà destra dello schermo (fuori dai bottoni) ──
	if pos.x >= vp_w * 0.5 and _rj_touch_id == -1:
		_rj_touch_id = id
		_rj_origin   = pos
		_rj_outer_node.visible = true
		_rj_inner_node.visible = true
		_place_circle(_rj_outer_node, pos)
		_place_circle(_rj_inner_node, pos)
		InputManager.touch_shooting = true
		return


func _on_touch_drag(id: int, pos: Vector2) -> void:
	# ── Joystick sinistro ────────────────────────────────────────────────
	if id == _lj_touch_id:
		var delta  := pos - _lj_origin
		var clamped:= delta.limit_length(JOY_OUTER_R)
		_place_circle(_lj_inner_node, _lj_origin + clamped)

		var raw_len := delta.length()
		if raw_len < JOY_DEAD:
			InputManager.touch_move_vector = Vector2.ZERO
		else:
			var norm := (raw_len - JOY_DEAD) / (JOY_OUTER_R - JOY_DEAD)
			InputManager.touch_move_vector = delta.normalized() * clampf(norm, 0.0, 1.0)
		return

	# ── Joystick destro (mira) ───────────────────────────────────────────
	if id == _rj_touch_id:
		var delta   := pos - _rj_origin
		var clamped := delta.limit_length(JOY_OUTER_R)
		_place_circle(_rj_inner_node, _rj_origin + clamped)

		if delta.length() > JOY_DEAD:
			InputManager.touch_aim_vector = delta.normalized()
		return


func _on_touch_up(id: int, _pos: Vector2) -> void:
	# ── Rilascio joystick sinistro ───────────────────────────────────────
	if id == _lj_touch_id:
		_lj_touch_id = -1
		InputManager.touch_move_vector = Vector2.ZERO
		_lj_outer_node.visible = false
		_lj_inner_node.visible = false
		return

	# ── Rilascio joystick destro ─────────────────────────────────────────
	if id == _rj_touch_id:
		_rj_touch_id = -1
		InputManager.touch_aim_vector  = Vector2.ZERO
		InputManager.touch_shooting    = false
		_rj_outer_node.visible = false
		_rj_inner_node.visible = false
		return

	# ── Rilascio bottoni ─────────────────────────────────────────────────
	if _hit_circle(_btn_shoot, BTN_SHOOT_R + 20.0, _pos) \
			or InputManager.touch_shooting:
		_release_button(_btn_shoot, C_SHOOT)
		InputManager.touch_shooting = false
		return
	if _hit_circle(_btn_q, BTN_SM_R + 20.0, _pos):
		_release_button(_btn_q, C_Q)
		_inject_action("activate_power_q", false)
		return
	if _hit_circle(_btn_e, BTN_SM_R + 20.0, _pos):
		_release_button(_btn_e, C_E)
		_inject_action("activate_power_e", false)
		return
	if _hit_circle(_btn_pause, BTN_SM_R + 20.0, _pos):
		_release_button(_btn_pause, C_PAUSE)
		_inject_action("pause", false)
		return


# ════════════════════════════════════════════════════════════════════════════
#  CONTROLLER DETECTION
# ════════════════════════════════════════════════════════════════════════════
func _on_controller_connected(_device_id: int) -> void:
	_controller_active = true
	_set_touch_visible(false)
	# Resetta stato touch per evitare input fantasma
	_reset_touch_state()


func _on_controller_disconnected(_device_id: int) -> void:
	# Mostra touch solo se non ci sono altri controller
	if Input.get_connected_joypads().is_empty():
		_controller_active = false
		var is_mobile: bool = OS.get_name() in ["Android", "iOS"]
		_set_touch_visible(is_mobile)


func _set_touch_visible(v: bool) -> void:
	visible = v
	if not v:
		_reset_touch_state()


func _reset_touch_state() -> void:
	InputManager.touch_move_vector = Vector2.ZERO
	InputManager.touch_aim_vector  = Vector2.ZERO
	InputManager.touch_shooting    = false
	_lj_touch_id = -1
	_rj_touch_id = -1
	if _lj_outer_node:
		_lj_outer_node.visible = false
		_lj_inner_node.visible = false
	if _rj_outer_node:
		_rj_outer_node.visible = false
		_rj_inner_node.visible = false
	_release_button(_btn_shoot, C_SHOOT)
	_release_button(_btn_q,     C_Q)
	_release_button(_btn_e,     C_E)


# ════════════════════════════════════════════════════════════════════════════
#  HELPERS — costruzione nodi
# ════════════════════════════════════════════════════════════════════════════
func _make_circle(radius: float, color: Color) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	c.size                = Vector2(radius * 2.0, radius * 2.0)
	c.mouse_filter        = Control.MOUSE_FILTER_IGNORE

	var draw_node := _CircleDraw.new()
	draw_node.draw_color = color
	draw_node.radius     = radius
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(draw_node)
	return c


func _make_button(radius: float, color: Color, label: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	c.size                = Vector2(radius * 2.0, radius * 2.0)
	c.mouse_filter        = Control.MOUSE_FILTER_IGNORE

	var draw_node := _CircleDraw.new()
	draw_node.draw_color  = color
	draw_node.radius      = radius
	draw_node.label_text  = label
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(draw_node)
	return c


func _place_circle(node: Control, center: Vector2) -> void:
	if node == null:
		return
	node.position = center - node.size * 0.5


func _hit_circle(node: Control, radius: float, pos: Vector2) -> bool:
	if node == null or not node.visible:
		return false
	var center := node.position + node.size * 0.5
	return pos.distance_to(center) <= radius


func _press_button(node: Control, color: Color) -> void:
	if node == null:
		return
	var d := node.get_child(0) as _CircleDraw
	if d:
		d.draw_color = color
		d.queue_redraw()


func _release_button(node: Control, color: Color) -> void:
	if node == null:
		return
	var d := node.get_child(0) as _CircleDraw
	if d:
		d.draw_color = color
		d.queue_redraw()


func _inject_action(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventAction.new()
	ev.action  = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


# ════════════════════════════════════════════════════════════════════════════
#  INNER CLASS — disegno cerchio + label
# ════════════════════════════════════════════════════════════════════════════
class _CircleDraw extends Control:
	var draw_color: Color = Color.WHITE
	var radius    : float = 40.0
	var label_text: String = ""

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, radius, draw_color)
		# Bordo
		var border_col := Color(draw_color.r, draw_color.g, draw_color.b,
								minf(draw_color.a + 0.30, 1.0))
		for i in range(3):
			draw_arc(center, radius - float(i), 0.0, TAU, 48, border_col, 1.0, true)

		# Label
		if label_text != "":
			var font     := ThemeDB.fallback_font
			var font_sz  := int(radius * 0.55)
			var txt_sz   := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER,
												  -1, font_sz)
			var txt_pos  := center - txt_sz * 0.5 + Vector2(0, txt_sz.y * 0.25)
			draw_string(font, txt_pos, label_text,
						HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz,
						Color(1, 1, 1, 0.95))
