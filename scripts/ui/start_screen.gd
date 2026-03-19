extends CanvasLayer
class_name StartScreen
## StartScreen v2 — Schermata iniziale completamente procedurale
## Layout: Logo animato + 3 colonne (Obiettivo / Tastiera / Controller) + START

# ── Palette ────────────────────────────────────────────────────────────────────
const C_BG    := Color(0.01, 0.00, 0.06, 0.98)
const C_PANEL := Color(0.05, 0.02, 0.13, 0.97)
const C_ACC   := Color(0.20, 0.88, 1.00)
const C_ACC2  := Color(0.65, 0.22, 1.00)
const C_GOLD  := Color(1.00, 0.82, 0.10)
const C_Q     := Color(0.20, 0.88, 1.00)
const C_E     := Color(1.00, 0.55, 0.12)
const C_DIM   := Color(0.44, 0.44, 0.60)
const C_HI    := Color(0.88, 0.88, 1.00)
const C_GREEN := Color(0.22, 1.00, 0.50)

var _title_lbl:     Label  = null
var _start_btn:     Button = null   # bottone Standard
var _hardcore_btn:  Button = null   # bottone Hardcore
var _started:       bool   = false  ## guard anti-doppio avvio
var _selected_mode: String = "standard"


# ══════════════════════════════════════════════
#  Avvio
# ══════════════════════════════════════════════

func _ready() -> void:
	layer        = 100
	visible      = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	await get_tree().process_frame
	_animate_title()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Enter / Space / A → avvia nella modalità selezionata dal focus
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_trigger_focused_mode()
		return
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed and jb.button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_trigger_focused_mode()


## Avvia nella modalità del bottone attualmente in focus (Standard o Hardcore)
func _trigger_focused_mode() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == _hardcore_btn:
		_on_hardcore_pressed()
	else:
		_on_start_pressed()


func _on_start_pressed() -> void:
	if _started:
		return   # evita doppio avvio (button.pressed + _input entrambi possono scattare)
	_started = true
	GameManager.game_mode = _selected_mode
	visible = false
	var main := get_node_or_null("/root/Main")
	if main and main.has_method("begin_game"):
		main.begin_game()


func _on_hardcore_pressed() -> void:
	if _started:
		return
	if not MetaManager.is_hardcore_unlocked():
		# Non sbloccato: lampeggia il tasto per feedback
		var tw := create_tween()
		tw.tween_property(_hardcore_btn, "modulate", Color(1.2, 0.3, 0.3), 0.1)
		tw.tween_property(_hardcore_btn, "modulate", Color.WHITE, 0.2)
		return
	_started = true
	GameManager.game_mode = "hardcore"
	visible = false
	var main := get_node_or_null("/root/Main")
	if main and main.has_method("begin_game"):
		main.begin_game()


# ══════════════════════════════════════════════
#  Build UI
# ══════════════════════════════════════════════

func _build_ui() -> void:
	# ── Nebula animata in background ─────────────────────────────────────────
	_add_nebula_background()

	# Sfondo scuro semi-trasparente sopra la nebula
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0.01, 0.00, 0.06, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_add_stars(bg)

	# Panel centrale
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 0)
	var ps := _mk_style(C_PANEL, C_ACC2, 16, 2)
	ps.shadow_color = Color(0.55, 0.22, 1.00, 0.20)
	ps.shadow_size  = 14
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   44)
	margin.add_theme_constant_override("margin_right",  44)
	margin.add_theme_constant_override("margin_top",    34)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(root_vbox)

	_build_title(root_vbox)
	_hline(root_vbox, C_ACC2, 0.45)
	_build_columns(root_vbox)
	_hline(root_vbox, C_ACC2, 0.20)
	_build_tips(root_vbox)
	_build_start(root_vbox)

	var ver := _lbl("Void Surge  •  Alpha 0.3  •  2025", 13, C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(ver)


# ── Titolo ─────────────────────────────────────────────────────────────────────

func _build_title(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	parent.add_child(hbox)

	hbox.add_child(_lbl("◈", 64, C_ACC, 4, Color(0.10, 0.70, 1.00, 0.8)))

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(tv)

	_title_lbl = _lbl("VOID SURGE", 72, C_ACC, 6, Color(0.05, 0.50, 0.90, 0.90))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(_title_lbl)

	var tag := _lbl("Roguelite  •  Bullet-hell  •  Sopravvivenza infinita", 18, C_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(tag)

	hbox.add_child(_lbl("◈", 64, C_ACC, 4, Color(0.10, 0.70, 1.00, 0.8)))


# ── Tre colonne ────────────────────────────────────────────────────────────────

func _build_columns(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)

	# Obiettivo
	var obj := _make_section(hbox, "🎯  OBIETTIVO", C_ACC)
	var obj_rows: Array = [
		["Sopravvivi il più a lungo possibile",                  C_HI],
		["Uccidi nemici → guadagni ψ Souls",                    C_GOLD],
		["Ogni wave i nemici aumentano di numero e forza",       C_HI],
		["Ogni 3 wave cambi zona e scenario",                    C_HI],
		["Nello shop compri poteri, boost e upgrade permanenti", C_GREEN],
		["I Souls sbloccano talenti e skin nel MetaHub",         Color(0.75, 0.55, 1.00)],
	]
	for r: Array in obj_rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		obj.add_child(row)
		var dot := _lbl("▸", 15, r[1] as Color)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(dot)
		var lbl := _lbl(r[0] as String, 15, r[1] as Color)
		lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

	_vline(hbox)

	# Tastiera
	var kb := _make_section(hbox, "⌨  TASTIERA", C_ACC)
	_ctrl_grid(kb, [
		["Muovi",        "W  A  S  D"],
		["Mira",         "Mouse"],
		["Spara",        "Click sinistro (hold)"],
		["Potere Q",     "Q"],
		["Potere E",     "E"],
		["Pausa",        "ESC"],
		["Shop (debug)", "F2"],
	])
	var kb_badges := HBoxContainer.new()
	kb_badges.add_theme_constant_override("separation", 8)
	kb.add_child(kb_badges)
	kb_badges.add_child(_key_badge("Q", C_Q))
	kb_badges.add_child(_lbl("Potere Ciano", 15, C_Q))
	var sp := Control.new(); sp.custom_minimum_size = Vector2(12, 0)
	kb_badges.add_child(sp)
	kb_badges.add_child(_key_badge("E", C_E))
	kb_badges.add_child(_lbl("Potere Arancio", 15, C_E))

	_vline(hbox)

	# Controller
	var ctrl := _make_section(hbox, "🎮  CONTROLLER", C_ACC)
	_ctrl_grid(ctrl, [
		["Muovi",          "Stick sinistro"],
		["Mira",           "Stick destro"],
		["Spara",          "R2 / RT  (grilletto dx, hold)"],
		["Potere Q",       "L1 / LB  (spalla sinistra)"],
		["Potere E",       "R1 / RB  (spalla destra)"],
		["Sprint Boost",   "L2 / LT  (grilletto sx)"],
		["Shop",           "Select / Share / Back"],
		["Conferma",       "A / ×  (Croce)"],
		["Annulla/Chiudi", "B / ○  (Cerchio)"],
		["Pausa",          "Start / Options"],
	])


# ── Tips ───────────────────────────────────────────────────────────────────────

func _build_tips(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(hbox)

	var tips: Array = [
		["⚡", "I nemici droppano equipaggiamento — raccoglilo per migliorare le stats"],
		["ψ",  "Le Souls sono permanenti: si accumulano tra le run e non si perdono"],
		["◈",  "Compra i Poteri Q/E nello shop: Shield Burst, Plasma Bomb, Void Dash…"],
		["🛡️", "Lo Shield Burst ti rende invincibile 1.5s — usalo prima degli impatti"],
	]
	for t: Array in tips:
		var tip_hbox := HBoxContainer.new()
		tip_hbox.add_theme_constant_override("separation", 6)
		tip_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(tip_hbox)
		tip_hbox.add_child(_lbl(t[0] as String, 22, C_GOLD))
		var tl := _lbl(t[1] as String, 14, C_DIM)
		tl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip_hbox.add_child(tl)


# ── Bottone START ──────────────────────────────────────────────────────────────

func _build_start(parent: VBoxContainer) -> void:
	var cc := CenterContainer.new()
	parent.add_child(cc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(vb)

	# ── Selezione modalità ────────────────────────────────────────────────────
	vb.add_child(_lbl("SCEGLI MODALITÀ", 14, C_DIM))

	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 16)
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(mode_hbox)

	# Bottone STANDARD
	_start_btn = Button.new()
	_start_btn.text                = "▶  STANDARD"
	_start_btn.custom_minimum_size = Vector2(280, 62)
	_start_btn.add_theme_font_size_override("font_size", 24)
	_start_btn.add_theme_color_override("font_color",         Color(0.02, 0.02, 0.08))
	_start_btn.add_theme_color_override("font_hover_color",   Color.BLACK)
	_start_btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	var sn := _mk_style(Color(0.10, 0.75, 1.00), Color(0.20, 0.95, 1.00), 12, 2)
	var sh := _mk_style(Color(0.15, 0.92, 1.00), Color.WHITE, 12, 3)
	_start_btn.add_theme_stylebox_override("normal",  sn)
	_start_btn.add_theme_stylebox_override("hover",   sh)
	_start_btn.add_theme_stylebox_override("pressed", sh)
	_start_btn.add_theme_stylebox_override("focus",   sh)
	_start_btn.focus_mode = Control.FOCUS_ALL
	_start_btn.pressed.connect(_on_start_pressed)
	mode_hbox.add_child(_start_btn)

	# Bottone HARDCORE
	var hc_unlocked := MetaManager.is_hardcore_unlocked()
	_hardcore_btn = Button.new()
	_hardcore_btn.text = ("☠  HARDCORE" if hc_unlocked
		else "🔒  HARDCORE\n[wave 8+ o 500 ψ]")
	_hardcore_btn.custom_minimum_size = Vector2(280, 62)
	_hardcore_btn.add_theme_font_size_override("font_size", 22)
	var hc_base_col := Color(1.00, 0.22, 0.22)
	var hc_bg_col   := Color(0.40, 0.03, 0.05) if not hc_unlocked else Color(0.80, 0.10, 0.10)
	_hardcore_btn.add_theme_color_override("font_color",
		hc_base_col if hc_unlocked else Color(0.50, 0.30, 0.30))
	_hardcore_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.6))
	_hardcore_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var hn := _mk_style(hc_bg_col,        Color(hc_base_col.r, hc_base_col.g, hc_base_col.b, 0.70), 12, 2)
	var hh := _mk_style(Color(0.75, 0.10, 0.10), Color.WHITE, 12, 3)
	_hardcore_btn.add_theme_stylebox_override("normal",  hn)
	_hardcore_btn.add_theme_stylebox_override("hover",   hh if hc_unlocked else hn)
	_hardcore_btn.add_theme_stylebox_override("pressed", hh)
	_hardcore_btn.add_theme_stylebox_override("focus",   hh if hc_unlocked else hn)
	_hardcore_btn.focus_mode = Control.FOCUS_ALL
	_hardcore_btn.pressed.connect(_on_hardcore_pressed)
	mode_hbox.add_child(_hardcore_btn)

	# Focus sul bottone standard
	_start_btn.grab_focus()
	_start_btn.focus_neighbor_right = _hardcore_btn.get_path()
	_hardcore_btn.focus_neighbor_left = _start_btn.get_path()

	# Descrizioni modalità
	var desc_hbox := HBoxContainer.new()
	desc_hbox.add_theme_constant_override("separation", 16)
	desc_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(desc_hbox)

	var std_lbl := _lbl("Difficoltà bilanciata\nBoss ogni 5 wave", 13, C_DIM)
	std_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	std_lbl.custom_minimum_size  = Vector2(280, 0)
	desc_hbox.add_child(std_lbl)

	var hc_hint := ("HP ×2 | Danno ×1.5 | Boss ogni 3 wave\n+50% Souls reward"
		if hc_unlocked else "Completa wave 8 o accumula 500 ψ Souls\nper sbloccare la modalità Hardcore")
	var hc_lbl := _lbl(hc_hint, 13, Color(1.0, 0.5, 0.5) if hc_unlocked else Color(0.45, 0.30, 0.30))
	hc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hc_lbl.custom_minimum_size  = Vector2(280, 0)
	desc_hbox.add_child(hc_lbl)

	vb.add_child(_lbl("Enter / Space / A Controller  per avviare", 14, C_DIM))


# ══════════════════════════════════════════════
#  Animazione
# ══════════════════════════════════════════════

func _animate_title() -> void:
	if not _title_lbl:
		return
	_title_lbl.scale      = Vector2(0.75, 0.75)
	_title_lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_title_lbl, "scale",      Vector2.ONE, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(_title_lbl, "modulate:a", 1.0,         0.40).set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════
#  Helper UI
# ══════════════════════════════════════════════

## Crea un panel stilizzato, lo aggiunge a parent e restituisce il VBox interno.
func _make_section(parent: Control, title: String, col: Color) -> VBoxContainer:
	var outer := PanelContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_stylebox_override("panel",
		_mk_style(Color(0.03, 0.01, 0.10, 0.95), Color(col.r, col.g, col.b, 0.28), 10, 1))
	parent.add_child(outer)

	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left",   14)
	mg.add_theme_constant_override("margin_right",  14)
	mg.add_theme_constant_override("margin_top",    12)
	mg.add_theme_constant_override("margin_bottom", 12)
	outer.add_child(mg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	mg.add_child(vbox)

	vbox.add_child(_lbl(title, 18, col, 2, Color(0, 0, 0, 0.8)))
	var line := ColorRect.new()
	line.color               = Color(col.r, col.g, col.b, 0.40)
	line.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(line)

	return vbox


func _ctrl_grid(parent: VBoxContainer, rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation",  7)
	parent.add_child(grid)
	for row: Array in rows:
		# Nessun outline sotto 16px: causa blur in Godot 4
		grid.add_child(_lbl(row[0] as String, 15, C_DIM))
		grid.add_child(_lbl(row[1] as String, 15, C_HI))


func _key_badge(txt: String, col: Color) -> PanelContainer:
	var pc  := PanelContainer.new()
	var sty := _mk_style(
		Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.92), col, 6, 2)
	sty.content_margin_left   = 10.0
	sty.content_margin_right  = 10.0
	sty.content_margin_top    = 2.0
	sty.content_margin_bottom = 2.0
	pc.add_theme_stylebox_override("panel", sty)
	pc.add_child(_lbl(txt, 18, col, 2, Color(0, 0, 0, 0.8)))
	return pc


func _hline(parent: Control, col: Color, alpha: float = 0.4) -> void:
	var r := ColorRect.new()
	r.color               = Color(col.r, col.g, col.b, alpha)
	r.custom_minimum_size = Vector2(0, 2)
	parent.add_child(r)


func _vline(parent: Control) -> void:
	var r := ColorRect.new()
	r.color               = Color(C_ACC2.r, C_ACC2.g, C_ACC2.b, 0.25)
	r.custom_minimum_size = Vector2(2, 0)
	parent.add_child(r)


func _add_nebula_background() -> void:
	var nebula := ColorRect.new()
	nebula.set_anchors_preset(Control.PRESET_FULL_RECT)
	nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nebula)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float time_scale : hint_range(0.0, 1.0) = 0.012;
uniform vec4  col_a : source_color = vec4(0.10, 0.02, 0.35, 1.0);
uniform vec4  col_b : source_color = vec4(0.30, 0.05, 0.70, 1.0);
uniform vec4  col_c : source_color = vec4(0.02, 0.05, 0.20, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p  = p * 2.1 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv  = UV * 2.8;
	float t  = TIME * time_scale;
	vec2 q   = vec2(fbm(uv + t), fbm(uv + vec2(1.3, 4.1) + t * 0.9));
	float c1 = fbm(uv + q * 1.5 + t * 0.5);
	float c2 = fbm(uv + q       + vec2(t * 0.3, 0.0));
	float cl: float = smoothstep(0.38, 0.75, c1 * 0.6 + c2 * 0.4);
	vec3  rgb = mix(col_c.rgb, mix(col_a.rgb, col_b.rgb, cl), cl * 0.9);
	COLOR = vec4(rgb, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	nebula.material = mat


func _add_stars(parent: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in 70:
		var dot := ColorRect.new()
		var sz  := rng.randf_range(1.0, 3.5)
		dot.custom_minimum_size = Vector2(sz, sz)
		dot.color               = Color(1, 1, 1, rng.randf_range(0.06, 0.30))
		dot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		dot.offset_left = rng.randf_range(0, 1920)
		dot.offset_top  = rng.randf_range(0, 1080)
		parent.add_child(dot)


func _mk_style(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg
	s.border_color               = border
	s.border_width_left          = border_w
	s.border_width_right         = border_w
	s.border_width_top           = border_w
	s.border_width_bottom        = border_w
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.anti_aliasing              = true
	return s


func _lbl(txt: String, sz: int, col: Color,
		outline: int = 0, out_col: Color = Color.BLACK) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size",     outline)
		l.add_theme_color_override("font_outline_color",  out_col)
	return l
