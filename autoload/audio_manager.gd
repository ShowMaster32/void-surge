extends Node
## AudioManager — Sistema audio completamente procedurale (zero file esterni, zero licenze)
##
## Tutti i suoni sono generati matematicamente via AudioStreamWAV (PCM 16-bit signed).
## Il drone ambientale per zona usa AudioStreamGenerator riempito in _process().
##
## Uso da qualsiasi script:
##   AudioManager.sfx("shoot")
##   AudioManager.sfx("explosion")
##   AudioManager.set_zone("plasma_storm")
##
## SFX disponibili:
##   shoot, hit_enemy, explosion, damage_taken, wave_complete,
##   buy_item, ui_click, boss_spawn, power_use, heal

const SAMPLE_RATE  := 22050
const MAX_POLYPHONY := 8

# Pool di player per polyphony
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0

# Drone ambientale
var _drone_player: AudioStreamPlayer
var _drone_gen: AudioStreamGenerator
var _drone_playback: AudioStreamGeneratorPlayback
var _drone_phase: float = 0.0
var _drone_freq: float  = 55.0
var _drone_freq2: float = 110.5   # leggera dissonanza
var _drone_vol: float   = 0.0
var _drone_target_vol: float = 0.0
var _drone_active: bool = false
var _drone_zone: String = ""

# Cache suoni già generati
var _cache: Dictionary = {}

# Configurazione drone per zona
const DRONE_CONFIGS := {
	"void_black":      {"freq": 55.0,  "freq2": 110.3, "vol": 0.10, "noise": 0.02},
	"nebula_purple":   {"freq": 82.4,  "freq2": 164.8, "vol": 0.09, "noise": 0.01},
	"asteroid_field":  {"freq": 65.4,  "freq2": 130.0, "vol": 0.12, "noise": 0.04},
	"plasma_storm":    {"freq": 110.0, "freq2": 146.8, "vol": 0.14, "noise": 0.06},
	"dimension_rift":  {"freq": 73.4,  "freq2": 110.0, "vol": 0.11, "noise": 0.03},
}


# ══════════════════════════════════════════════════════════════════════════════
#  Lifecycle
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_ensure_buses()

	# Crea pool SFX
	for _i in MAX_POLYPHONY:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = 0.0
		add_child(p)
		_sfx_pool.append(p)

	# Setup drone ambientale
	_drone_gen = AudioStreamGenerator.new()
	_drone_gen.mix_rate = float(SAMPLE_RATE)
	_drone_gen.buffer_length = 0.15

	_drone_player = AudioStreamPlayer.new()
	_drone_player.bus    = "Ambient"
	_drone_player.stream = _drone_gen
	_drone_player.volume_db = -80.0   # parte in silenzio
	add_child(_drone_player)
	_drone_player.play()
	_drone_playback = _drone_player.get_stream_playback() as AudioStreamGeneratorPlayback

	# Pre-genera tutti i suoni nella cache
	_prebuild_cache()

	# Aggancia segnali esistenti
	await get_tree().process_frame
	_hook_signals()


func _ensure_buses() -> void:
	## Crea i bus "SFX" e "Ambient" se non esistono già nel progetto.
	for bus_name in ["SFX", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _hook_signals() -> void:
	# Zone generator → cambia drone
	var zg := get_tree().get_first_node_in_group("zone_generator")
	if zg and zg.has_signal("zone_generated"):
		zg.zone_generated.connect(_on_zone_changed)

	# Wave complete → suono fanfara
	var sp := get_tree().get_first_node_in_group("enemy_spawner")
	if sp and sp.has_signal("wave_changed"):
		sp.wave_changed.connect(_on_wave_changed)

	# Boss spawn
	if sp and sp.has_signal("boss_wave_started"):
		sp.boss_wave_started.connect(_on_boss_started)


func _process(delta: float) -> void:
	# Fade in/out drone
	if _drone_vol < _drone_target_vol:
		_drone_vol = minf(_drone_vol + delta * 0.8, _drone_target_vol)
	elif _drone_vol > _drone_target_vol:
		_drone_vol = maxf(_drone_vol - delta * 0.8, _drone_target_vol)

	_drone_player.volume_db = linear_to_db(clampf(_drone_vol, 0.0001, 1.0))

	# Riempi buffer generatore
	_fill_drone_buffer()


# ══════════════════════════════════════════════════════════════════════════════
#  API pubblica
# ══════════════════════════════════════════════════════════════════════════════

func sfx(name: String, pitch_var: float = 0.0) -> void:
	## Riproduce un effetto sonoro. pitch_var aggiunge variazione casuale al tono.
	var stream: AudioStreamWAV = _cache.get(name, null)
	if stream == null:
		return

	var player := _get_next_player()
	player.stream    = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	player.play()


func set_zone(zone_id: String) -> void:
	## Cambia il drone ambientale per la zona corrente.
	if zone_id == _drone_zone:
		return
	_drone_zone = zone_id
	var cfg: Dictionary = DRONE_CONFIGS.get(zone_id, DRONE_CONFIGS["void_black"])
	_drone_freq        = cfg["freq"]
	_drone_freq2       = cfg["freq2"]
	_drone_target_vol  = cfg["vol"]
	_drone_active      = true


func stop_drone() -> void:
	_drone_target_vol = 0.0


func update_wave_intensity(wave: int) -> void:
	## Scala la frequenza e il volume del drone in base alla wave corrente.
	## wave 1-5: base. wave 6-15: tensione crescente. wave 16+: massima intensità.
	var t := clampf((wave - 1) / 20.0, 0.0, 1.0)   # 0.0 @ wave 1, 1.0 @ wave 21+

	# Pitch drone: salita graduale del 30% massimo (più urgente ad alta wave)
	var pitch_mult := 1.0 + t * 0.30
	if _drone_player:
		_drone_player.pitch_scale = pitch_mult

	# Volume drone: +50% alla wave 21
	var base_vol: float = DRONE_CONFIGS.get(_drone_zone, DRONE_CONFIGS["void_black"]).get("vol", 0.10)
	_drone_target_vol = base_vol * (1.0 + t * 0.50)

	# Frequenza base dissonanza: cresce col wave (più aggressiva)
	_drone_freq2 = _drone_freq * (2.0 + t * 0.40)

	# SFX bus: aumenta leggermente il volume degli SFX (più presenti)
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		var target_db: float = lerp(0.0, 3.0, t)
		AudioServer.set_bus_volume_db(sfx_idx, target_db)


# ══════════════════════════════════════════════════════════════════════════════
#  Signal handlers
# ══════════════════════════════════════════════════════════════════════════════

func _on_zone_changed(zone_id: String) -> void:
	set_zone(zone_id)


func _on_wave_changed(_wave: int) -> void:
	sfx("wave_complete")


func _on_boss_started(_boss_id: int, _boss) -> void:
	sfx("boss_spawn")


# ══════════════════════════════════════════════════════════════════════════════
#  Drone: generazione PCM in tempo reale
# ══════════════════════════════════════════════════════════════════════════════

func _fill_drone_buffer() -> void:
	if not is_instance_valid(_drone_playback):
		return
	var frames_available: int = _drone_playback.get_frames_available()
	if frames_available <= 0:
		return

	var cfg: Dictionary = DRONE_CONFIGS.get(_drone_zone, DRONE_CONFIGS["void_black"])
	var noise_amt: float = cfg.get("noise", 0.02)
	var dt: float = 1.0 / float(SAMPLE_RATE)

	for _i in frames_available:
		var s: float = 0.0
		# Fondamentale con sub-armonico
		s += sin(_drone_phase * TAU)                    * 0.55
		s += sin(_drone_phase * TAU * 0.50)             * 0.25   # sub-ottava
		s += sin(_drone_phase * TAU * (_drone_freq2 / _drone_freq)) * 0.15   # dissonanza
		s += sin(_drone_phase * TAU * 3.0)              * 0.05   # terza armonica
		# Rumore ambientale leggero
		s += (randf() * 2.0 - 1.0) * noise_amt
		# Tremolo lentissimo
		s *= 0.85 + sin(_drone_phase * 0.15) * 0.15

		_drone_phase += _drone_freq * dt
		if _drone_phase >= 1.0:
			_drone_phase -= 1.0

		_drone_playback.push_frame(Vector2(s, s) * clampf(_drone_vol, 0.0, 1.0))


# ══════════════════════════════════════════════════════════════════════════════
#  Pool player
# ══════════════════════════════════════════════════════════════════════════════

func _get_next_player() -> AudioStreamPlayer:
	var p := _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % MAX_POLYPHONY
	if p.playing:
		p.stop()
	return p


# ══════════════════════════════════════════════════════════════════════════════
#  Generazione procedurali dei suoni (AudioStreamWAV PCM 16-bit LE)
# ══════════════════════════════════════════════════════════════════════════════

func _prebuild_cache() -> void:
	_cache["shoot"]        = _gen_shoot()
	_cache["hit_enemy"]    = _gen_hit_enemy()
	_cache["explosion"]    = _gen_explosion()
	_cache["damage_taken"] = _gen_damage_taken()
	_cache["wave_complete"]= _gen_wave_complete()
	_cache["buy_item"]     = _gen_buy_item()
	_cache["ui_click"]     = _gen_ui_click()
	_cache["boss_spawn"]   = _gen_boss_spawn()
	_cache["power_use"]    = _gen_power_use()
	_cache["heal"]         = _gen_heal()


# Converte float [-1,1] → bytes little-endian 16-bit signed
func _f_to_s16(buf: PackedByteArray, offset: int, val: float) -> void:
	var s16: int = clampi(int(val * 32767.0), -32768, 32767)
	var u16: int = s16 & 0xFFFF
	buf[offset]     = u16 & 0xFF
	buf[offset + 1] = (u16 >> 8) & 0xFF


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format    = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate  = SAMPLE_RATE
	stream.stereo    = false
	var buf := PackedByteArray()
	buf.resize(samples.size() * 2)
	for i in samples.size():
		_f_to_s16(buf, i * 2, clampf(samples[i], -1.0, 1.0))
	stream.data = buf
	return stream


# ── Sparo (laser discendente 0.06s) ─────────────────────────────────────────
func _gen_shoot() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.065)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var freq: float = lerp(1100.0, 350.0, pow(t, 0.7))
		var env := 1.0 - pow(t, 0.6)
		s[i] = sin(float(i) / float(SAMPLE_RATE) * freq * TAU) * env * 0.55
		# Leggero overdrive
		s[i] = clampf(s[i] * 1.8, -0.9, 0.9)
	return _make_wav(s)


# ── Colpo nemico (click + rumore breve 0.04s) ────────────────────────────────
func _gen_hit_enemy() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.045)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := 1.0 - t
		# Click metallico
		var click := sin(float(i) * 680.0 / float(SAMPLE_RATE) * TAU) * env * 0.4
		# Rumore bianco smorzato
		var noise := (randf() * 2.0 - 1.0) * env * 0.35
		s[i] = click + noise
	return _make_wav(s)


# ── Esplosione (boom basso 0.35s) ────────────────────────────────────────────
func _gen_explosion() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.38)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 0.55) * (1.0 - exp(-t * 30.0))
		# Sub-bass
		var bass := sin(float(i) * 52.0 / float(SAMPLE_RATE) * TAU) * env * 0.5
		# Mid rumble
		var mid := sin(float(i) * 130.0 / float(SAMPLE_RATE) * TAU) * env * 0.25
		# Rumore
		var noise := (randf() * 2.0 - 1.0) * env * 0.55
		# Distorsione soft-clip
		var raw := bass + mid + noise
		s[i] = raw / (1.0 + abs(raw))
	return _make_wav(s)


# ── Danno ricevuto (impatto secco 0.12s) ────────────────────────────────────
func _gen_damage_taken() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.12)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := (1.0 - t) * (1.0 - exp(-t * 60.0))
		var freq: float = lerp(400.0, 180.0, t)
		var tone := sin(float(i) * freq / float(SAMPLE_RATE) * TAU) * env * 0.45
		var noise := (randf() * 2.0 - 1.0) * env * 0.45
		s[i] = tone + noise
	return _make_wav(s)


# ── Onda completata (fanfara ascendente 0.55s) ───────────────────────────────
func _gen_wave_complete() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.58)
	var s := PackedFloat32Array(); s.resize(n)
	# Quattro note ascendenti C-E-G-C (rapporto frequenze)
	var notes := [261.6, 329.6, 392.0, 523.3]
	var note_len := n / notes.size()
	for ni in notes.size():
		var freq: float = notes[ni]
		var start := ni * note_len
		for i in note_len:
			if start + i >= n:
				break
			var t := float(i) / float(note_len)
			var env := sin(t * PI) * 0.6   # campana
			var samp := sin((start + i) * freq / float(SAMPLE_RATE) * TAU) * env
			# Aggiunge ottava sopra per lucentezza
			samp += sin((start + i) * freq * 2.0 / float(SAMPLE_RATE) * TAU) * env * 0.25
			s[start + i] += samp
	return _make_wav(s)


# ── Acquisto oggetto (moneta 0.18s) ─────────────────────────────────────────
func _gen_buy_item() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.20)
	var s := PackedFloat32Array(); s.resize(n)
	var freqs := [880.0, 1108.0, 1320.0]
	for i in n:
		var t := float(i) / float(n)
		var env := exp(-t * 6.0)
		var samp := 0.0
		for fi in freqs.size():
			samp += sin(float(i) * freqs[fi] / float(SAMPLE_RATE) * TAU) * env * (0.5 - fi * 0.12)
		s[i] = samp
	return _make_wav(s)


# ── Click UI (bottone 0.04s) ─────────────────────────────────────────────────
func _gen_ui_click() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.04)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := exp(-t * 20.0)
		s[i] = sin(float(i) * 700.0 / float(SAMPLE_RATE) * TAU) * env * 0.5
	return _make_wav(s)


# ── Spawn boss (allarme sinistro 0.7s) ──────────────────────────────────────
func _gen_boss_spawn() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.72)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := sin(t * PI * 0.5) * (1.0 - exp(-t * 8.0))
		# Tono basso con vibrato
		var vib := sin(float(i) * 5.0 / float(SAMPLE_RATE) * TAU) * 4.0
		var freq := 65.4 + vib
		var tone1 := sin(float(i) * freq / float(SAMPLE_RATE) * TAU) * env * 0.45
		# Sopratono dissonante
		var tone2 := sin(float(i) * (freq * 1.78) / float(SAMPLE_RATE) * TAU) * env * 0.25
		# Rumore basso
		var noise := (randf() * 2.0 - 1.0) * env * 0.18
		var raw := tone1 + tone2 + noise
		s[i] = raw / (1.0 + abs(raw) * 0.7)
	return _make_wav(s)


# ── Uso potere (whoosh + risonanza 0.25s) ────────────────────────────────────
func _gen_power_use() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.28)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := (1.0 - exp(-t * 18.0)) * exp(-t * 4.5)
		var freq: float = lerp(220.0, 880.0, pow(t, 0.4))
		var tone := sin(float(i) * freq / float(SAMPLE_RATE) * TAU) * env * 0.5
		# Sweep noise (whoosh)
		var noise_env := sin(t * PI) * 0.30
		var noise := (randf() * 2.0 - 1.0) * noise_env
		s[i] = tone + noise
	return _make_wav(s)


# ── Cura (tono dolce ascendente 0.30s) ──────────────────────────────────────
func _gen_heal() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.32)
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var env := sin(t * PI)
		# Sweep ascendente dolce
		var freq: float = lerp(392.0, 784.0, t)
		var tone1 := sin(float(i) * freq / float(SAMPLE_RATE) * TAU) * env * 0.40
		var tone2 := sin(float(i) * freq * 1.5 / float(SAMPLE_RATE) * TAU) * env * 0.20
		s[i] = tone1 + tone2
	return _make_wav(s)
