extends Node2D
## PlayerVisual v5 — astronave moderna Void Surge 2026
##
## Disegna in bianco puro; .modulate del nodo applica il colore player
## (cyan P1, magenta P2, verde P3, giallo P4).
##
## Feature:
##   • scafo con ali e cockpit
##   • motore con glow pulsante
##   • orb esagonali colorati per elemento attorno alla nave:
##       fire   → arancione  |  void  → viola
##       plasma → azzurro    |  chaos → oro
##   • upgrade visivi per sinergia attiva:
##       fire_build   → punte fiamma alle ali
##       void_build   → fin ombra posteriori
##       plasma_build → archi plasma rotanti
##       chaos_build  → stud diamante dorati sullo scafo

const SIZE := 11.0

const ELEMENT_COLORS: Dictionary = {
	"fire":    Color(1.00, 0.38, 0.08),
	"void":    Color(0.60, 0.12, 0.95),
	"plasma":  Color(0.18, 0.82, 1.00),
	"chaos":   Color(1.00, 0.82, 0.10),
	"generic": Color(0.72, 0.72, 0.82),
}

const ITEM_ELEMENTS: Dictionary = {
	"fire_surge":      "fire",
	"inferno_core":    "fire",
	"blazing_heart":   "fire",
	"void_shard":      "void",
	"dark_matter":     "void",
	"void_nexus":      "void",
	"plasma_cell":     "plasma",
	"storm_capacitor": "plasma",
	"plasma_core":     "plasma",
	"chaos_fragment":  "chaos",
	"reality_tear":    "chaos",
	"chaos_stone":     "chaos",
}

var _orbit_angle:   float = 0.0
var _pulse:         float = 0.0
var _plasma_ring_a: float = 0.0

var _orb_data:  Array = []   # Array di {color: Color, element: String}
var _synergies: Array = []   # Array di String  e.g. ["fire_build"]


func _process(delta: float) -> void:
	_orbit_angle   += delta * 0.65
	_pulse         += delta * 3.20
	_plasma_ring_a += delta * 2.40

	var em := get_node_or_null("/root/EquipmentManager")
	if em:
		_orb_data  = _build_orb_data(em)
		_synergies = em.get_active_synergies() if em.has_method("get_active_synergies") else []
	else:
		_orb_data  = []
		_synergies = []

	queue_redraw()


# ── lettura inventario ────────────────────────────────────────────────────────

func _build_orb_data(em: Node) -> Array:
	var result := []
	var inventory = em.get("inventory")
	if not inventory is Dictionary:
		return result
	for item_id in inventory:
		var cnt: int = int(inventory[item_id])
		var element := _classify(str(item_id))
		var col: Color = ELEMENT_COLORS.get(element, ELEMENT_COLORS["generic"])
		for _i in cnt:
			if result.size() >= 6:
				return result
			result.append({"color": col, "element": element})
	return result


func _classify(item_id: String) -> String:
	if ITEM_ELEMENTS.has(item_id):
		return ITEM_ELEMENTS[item_id]
	var id := item_id.to_lower()
	if id.contains("fire") or id.contains("inferno") or id.contains("blaz") or id.contains("flame"):
		return "fire"
	if id.contains("void") or id.contains("dark") or id.contains("shadow") or id.contains("null"):
		return "void"
	if id.contains("plasma") or id.contains("storm") or id.contains("elec") or id.contains("arc"):
		return "plasma"
	if id.contains("chaos") or id.contains("reality") or id.contains("gold") or id.contains("entropy"):
		return "chaos"
	return "generic"


# ══════════════════════════════════════════════
#  _draw principale
# ══════════════════════════════════════════════

func _draw() -> void:
	var s := SIZE

	# ── upgrade sinergici DIETRO la nave ─────────────────────────────────────
	if "void_build" in _synergies:
		_draw_void_fins(s)
	if "plasma_build" in _synergies:
		_draw_plasma_rings(s)

	# ── ali ───────────────────────────────────────────────────────────────────
	var wing_t := PackedVector2Array([
		Vector2(-s * 0.08, -s * 0.50),
		Vector2( s * 0.28, -s * 0.50),
		Vector2( s * 0.06, -s * 0.94),
		Vector2(-s * 0.36, -s * 0.72),
	])
	var wing_b := PackedVector2Array([
		Vector2(-s * 0.08,  s * 0.50),
		Vector2( s * 0.28,  s * 0.50),
		Vector2( s * 0.06,  s * 0.94),
		Vector2(-s * 0.36,  s * 0.72),
	])
	draw_colored_polygon(wing_t, Color(0.48, 0.48, 0.56))
	draw_colored_polygon(wing_b, Color(0.48, 0.48, 0.56))
	draw_polyline(PackedVector2Array([wing_t[0], wing_t[1], wing_t[2], wing_t[3], wing_t[0]]),
		Color(1.0, 1.0, 1.0, 0.55), 1.0)
	draw_polyline(PackedVector2Array([wing_b[0], wing_b[1], wing_b[2], wing_b[3], wing_b[0]]),
		Color(1.0, 1.0, 1.0, 0.55), 1.0)

	# ── punte fiamma (FIRE synergy, sopra le ali) ─────────────────────────────
	if "fire_build" in _synergies:
		_draw_fire_tips(s)

	# ── scafo principale ──────────────────────────────────────────────────────
	var hull := PackedVector2Array([
		Vector2( s,          0.0),
		Vector2( s * 0.22,  -s * 0.52),
		Vector2(-s * 0.62,  -s * 0.40),
		Vector2(-s * 0.88,   0.0),
		Vector2(-s * 0.62,   s * 0.40),
		Vector2( s * 0.22,   s * 0.52),
	])
	draw_colored_polygon(hull, Color(0.68, 0.68, 0.74))
	draw_polyline(
		PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[4], hull[5], hull[0]]),
		Color(1.0, 1.0, 1.0, 0.88), 1.5
	)

	# ── stud dorati CHAOS (sopra lo scafo, prima del cockpit) ────────────────
	if "chaos_build" in _synergies:
		_draw_chaos_studs(s)

	# ── cockpit ───────────────────────────────────────────────────────────────
	draw_circle(Vector2(s * 0.30, 0.0), s * 0.24, Color(0.42, 0.62, 0.95, 0.88))
	draw_circle(Vector2(s * 0.30, 0.0), s * 0.13, Color(1.0, 1.0, 1.0, 0.92))

	# ── motore pulsante ───────────────────────────────────────────────────────
	var pr := s * 0.22 + sin(_pulse) * s * 0.065
	draw_circle(Vector2(-s * 0.88, 0.0), pr,        Color(1.0, 0.46, 0.10, 0.82))
	draw_circle(Vector2(-s * 0.88, 0.0), pr * 0.50, Color(1.0, 0.80, 0.36, 0.96))

	# ── orb esagonali orbitanti ───────────────────────────────────────────────
	_draw_orbs(s)


# ══════════════════════════════════════════════
#  Orb esagonali
# ══════════════════════════════════════════════

func _draw_orbs(s: float) -> void:
	if _orb_data.is_empty():
		return
	var n  := _orb_data.size()
	var r  := s * 1.68
	for i in n:
		var d    = _orb_data[i]
		var a    := _orbit_angle + (float(i) / n) * TAU
		var pos  := Vector2(cos(a), sin(a)) * r
		var col: Color = d["color"]
		# alone glow colorato
		draw_circle(pos, 7.5, Color(col.r, col.g, col.b, 0.22))
		# esagono colorato
		_draw_hex(pos, 4.0, Color(col.r, col.g, col.b, 0.88))
		# punto brillante centrale
		draw_circle(pos, 1.5, Color(1.0, 1.0, 1.0, 0.95))


func _draw_hex(center: Vector2, radius: float, col: Color) -> void:
	## Disegna un esagono "flat-top" riempito + outline bianco
	var pts := PackedVector2Array()
	for i in 6:
		var a := (float(i) / 6.0) * TAU - PI / 6.0   # flat-top orientation
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, col)
	# outline luminoso
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(p)
	outline.append(pts[0])
	draw_polyline(outline, Color(1.0, 1.0, 1.0, 0.70), 0.9)


# ══════════════════════════════════════════════
#  Upgrade visivi per sinergia
# ══════════════════════════════════════════════

func _draw_void_fins(s: float) -> void:
	## Fin ombra viola che si estendono posteriormente
	var col_fill := Color(0.45, 0.08, 0.78, 0.68)
	var col_line := Color(0.72, 0.28, 1.00, 0.82)
	var fin_t := PackedVector2Array([
		Vector2(-s * 0.62, -s * 0.40),
		Vector2(-s * 0.88,  0.0),
		Vector2(-s * 1.55, -s * 0.60),
		Vector2(-s * 1.25, -s * 0.18),
	])
	var fin_b := PackedVector2Array([
		Vector2(-s * 0.62,  s * 0.40),
		Vector2(-s * 0.88,  0.0),
		Vector2(-s * 1.55,  s * 0.60),
		Vector2(-s * 1.25,  s * 0.18),
	])
	draw_colored_polygon(fin_t, col_fill)
	draw_colored_polygon(fin_b, col_fill)
	draw_polyline(PackedVector2Array([fin_t[0], fin_t[2], fin_t[3], fin_t[1], fin_t[0]]), col_line, 1.1)
	draw_polyline(PackedVector2Array([fin_b[0], fin_b[2], fin_b[3], fin_b[1], fin_b[0]]), col_line, 1.1)


func _draw_fire_tips(s: float) -> void:
	## Punta fiamma arancione alle estremità delle ali
	var c1 := Color(1.00, 0.38, 0.08, 0.85)
	var c2 := Color(1.00, 0.62, 0.10, 0.35)
	# ala superiore
	draw_colored_polygon(PackedVector2Array([
		Vector2( s * 0.06, -s * 0.94),
		Vector2(-s * 0.36, -s * 0.72),
		Vector2(-s * 0.18, -s * 1.28),
	]), c1)
	draw_circle(Vector2(-s * 0.12, -s * 1.05), s * 0.20, c2)
	# ala inferiore
	draw_colored_polygon(PackedVector2Array([
		Vector2( s * 0.06,  s * 0.94),
		Vector2(-s * 0.36,  s * 0.72),
		Vector2(-s * 0.18,  s * 1.28),
	]), c1)
	draw_circle(Vector2(-s * 0.12,  s * 1.05), s * 0.20, c2)


func _draw_plasma_rings(s: float) -> void:
	## Archi plasma azzurri rotanti attorno allo scafo
	for ri in 2:
		var base_a  := _plasma_ring_a + ri * PI
		var ring_r  := s * 1.22 + ri * s * 0.20
		var arc_n   := 12
		var arc_pts := PackedVector2Array()
		for j in arc_n + 1:
			var a := base_a + (float(j) / arc_n) * PI * 0.90
			arc_pts.append(Vector2(cos(a), sin(a)) * ring_r)
		var alpha := 0.72 - ri * 0.20
		draw_polyline(arc_pts, Color(0.18, 0.85, 1.00, alpha), 1.6)
		# scintille ai capi dell'arco
		if arc_pts.size() > arc_n:
			draw_circle(arc_pts[0],     2.2, Color(0.60, 0.95, 1.00, 0.88))
			draw_circle(arc_pts[arc_n], 2.2, Color(0.60, 0.95, 1.00, 0.88))


func _draw_chaos_studs(s: float) -> void:
	## Stud diamante dorati sullo scafo
	var stud_positions := [
		Vector2( s * 0.60, -s * 0.22),
		Vector2( s * 0.60,  s * 0.22),
		Vector2(-s * 0.08, -s * 0.30),
		Vector2(-s * 0.08,  s * 0.30),
	]
	for pos in stud_positions:
		var ds := s * 0.13
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(        0, -ds),
			pos + Vector2( ds * 0.72, 0),
			pos + Vector2(        0,  ds),
			pos + Vector2(-ds * 0.72, 0),
		]), Color(1.00, 0.82, 0.10, 0.92))
		draw_circle(pos, ds * 0.40, Color(1.0, 0.96, 0.68, 0.90))
