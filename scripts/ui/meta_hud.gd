extends CanvasLayer
class_name MetaHUD
## MetaHUD - Overlay HUD per meta-progressione
## Mostra: Souls correnti, XP bar del personaggio, livello, notifiche unlock
##
## Come usarlo:
##   1. Aggiungi come CanvasLayer figlio di main.tscn (layer = 10)
##   2. Assegna i nodi dall'Inspector oppure lascia che li crei _ready()

@onready var souls_label: Label        = $Panel/Souls
@onready var xp_bar: ProgressBar       = $Panel/XPBar
@onready var level_label: Label        = $Panel/Level
@onready var char_name_label: Label    = $Panel/CharName
@onready var notif_label: Label        = $Panel/Notification
@onready var notif_timer: Timer        = $Panel/NotifTimer

var _char_id: String = "void_sentinel"


func _ready() -> void:
	_char_id = MetaManager.selected_character

	# Connetti segnali MetaManager
	MetaManager.xp_gained.connect(_on_xp_gained)
	MetaManager.level_up.connect(_on_level_up)
	MetaManager.character_unlocked.connect(_on_character_unlocked)
	MetaManager.talent_unlocked.connect(_on_talent_unlocked)

	# Connetti timer notifica
	if notif_timer:
		notif_timer.timeout.connect(_hide_notification)

	_refresh_ui()


func _refresh_ui() -> void:
	# Souls
	if souls_label:
		souls_label.text = "Souls: %d" % MetaManager.total_souls

	# XP bar
	var cur_xp: int = MetaManager.character_xp.get(_char_id, 0)
	var next_xp: int = MetaManager.xp_for_next_level(_char_id)
	if xp_bar:
		xp_bar.max_value = next_xp
		xp_bar.value     = cur_xp

	# Livello
	if level_label:
		level_label.text = "Lv %d" % MetaManager.character_levels.get(_char_id, 1)

	# Nome personaggio
	if char_name_label:
		var char_data: Dictionary = MetaManager.CHARACTERS.get(_char_id, {})
		char_name_label.text = char_data.get("name", "???")


func _on_xp_gained(_amount: int, _total: int) -> void:
	_refresh_ui()


func _on_level_up(char_id: String, new_level: int) -> void:
	if char_id == _char_id:
		_refresh_ui()
		_show_notification("⬆ LEVEL UP! → Lv %d" % new_level, Color(1.0, 1.0, 0.0))


func _on_character_unlocked(char_id: String) -> void:
	var char_data: Dictionary = MetaManager.CHARACTERS.get(char_id, {})
	var char_name: String = char_data.get("name", char_id)
	_show_notification("🔓 SBLOCCATO: %s!" % char_name, Color(0.0, 1.0, 0.5))


func _on_talent_unlocked(talent_id: String) -> void:
	var talent_data: Dictionary = MetaManager.TALENTS.get(talent_id, {})
	var talent_name: String = talent_data.get("name", talent_id)
	_show_notification("✦ TALENTO: %s attivo!" % talent_name, Color(0.5, 0.8, 1.0))


func _show_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notif_label:
		return
	notif_label.text = text
	notif_label.add_theme_color_override("font_color", color)
	notif_label.visible = true
	if notif_timer:
		notif_timer.stop()
		notif_timer.wait_time = 2.5
		notif_timer.one_shot = true
		notif_timer.start()


func _hide_notification() -> void:
	if notif_label:
		notif_label.visible = false
