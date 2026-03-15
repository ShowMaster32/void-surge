extends Node2D
## EnemyVisual — forma geometrica moderna per i nemici di Void Surge
##
## Disegna tutto in bianco; il .modulate del nodo padre applica il colore.
## Esempio: modulate = Color(0.8, 0.2, 1.0)  →  nemico viola brillante.
## L'hit-flash funziona automaticamente: enemy.gd fa sprite.modulate=WHITE,
## che rimuove il tint e mostra il disegno bianco (flash luminoso).
##
## Come usarlo:
##   In enemy.gd, _ready():
##     if sprite != null: sprite.visible = false
##     var vis := load("res://scripts/visuals/enemy_visual.gd").new()
##     add_child(vis)
##     sprite = vis   # ora modulate funziona sul visual

const SIZE  := 14.0   # raggio base (px)
const SPIKE :=  4.5   # lunghezza spine agli angoli


func _draw() -> void:
	var s  := SIZE
	var sp := SPIKE

	# ── corpo esterno: diamante ───────────────────────────────────────────────
	var outer := PackedVector2Array([
		Vector2( 0.0,       -s),
		Vector2( s * 0.80,   0.0),
		Vector2( 0.0,        s),
		Vector2(-s * 0.80,   0.0),
	])
	draw_colored_polygon(outer, Color(0.58, 0.58, 0.64, 0.95))

	# outline brillante
	draw_polyline(
		PackedVector2Array([outer[0], outer[1], outer[2], outer[3], outer[0]]),
		Color(1.0, 1.0, 1.0, 0.90), 1.6
	)

	# ── nucleo interno (più brillante) ────────────────────────────────────────
	var ic := s * 0.40
	draw_colored_polygon(PackedVector2Array([
		Vector2( 0.0,        -ic),
		Vector2( ic * 0.80,   0.0),
		Vector2( 0.0,         ic),
		Vector2(-ic * 0.80,   0.0),
	]), Color(1.0, 1.0, 1.0, 0.92))

	# ── "occhio" centrale (scuro, dà profondità) ──────────────────────────────
	draw_circle(Vector2.ZERO, s * 0.14, Color(0.04, 0.04, 0.10, 1.0))

	# ── spine dagli angoli (aspetto aggressivo) ───────────────────────────────
	var spine_pairs := [
		[Vector2( 0.0,        -s),        Vector2( 0.0,              -(s + sp))    ],
		[Vector2( s * 0.80,    0.0),       Vector2( s * 0.80 + sp * 0.78,  0.0)   ],
		[Vector2( 0.0,         s),         Vector2( 0.0,               s + sp)     ],
		[Vector2(-s * 0.80,    0.0),       Vector2(-s * 0.80 - sp * 0.78,  0.0)   ],
	]
	for pair in spine_pairs:
		draw_line(pair[0], pair[1], Color(1.0, 1.0, 1.0, 0.68), 1.2)
