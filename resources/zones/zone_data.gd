extends Resource
class_name ZoneData
## ZoneData - Definisce le caratteristiche di un bioma/zona

@export_group("Identity")
@export var zone_id: String = "void_black"
@export var zone_name: String = "Void Black"
@export var description: String = "The endless darkness of the void."

@export_group("Visuals")
@export var background_color_top: Color = Color(0.02, 0.01, 0.05)
@export var background_color_bottom: Color = Color(0.05, 0.02, 0.1)
@export var ambient_color: Color = Color(0.1, 0.1, 0.2)
@export var particle_color: Color = Color(0.3, 0.3, 0.5, 0.5)
@export var glow_color: Color = Color(0.5, 0.5, 1.0)

@export_group("Gameplay Modifiers")
@export var enemy_spawn_multiplier: float = 1.0
@export var enemy_health_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var enemy_speed_multiplier: float = 1.0
@export var drop_rate_multiplier: float = 1.0
@export var player_speed_modifier: float = 1.0

@export_group("Environment")
@export var obstacle_density: float = 0.1  # 0-1, quanto denso di ostacoli
@export var hazard_enabled: bool = false
@export var hazard_damage: float = 5.0
@export var hazard_interval: float = 2.0

@export_group("Audio")
@export var ambient_sound: AudioStream
@export var music_intensity: float = 1.0  # 0-2, influenza BPM musica

@export_group("Spawn Settings")
@export var min_enemies_per_wave: int = 5
@export var max_enemies_per_wave: int = 15
@export var special_enemy_chance: float = 0.1


func get_combined_difficulty() -> float:
	## Restituisce un valore di difficoltà complessiva della zona
	return enemy_spawn_multiplier * enemy_health_multiplier * enemy_damage_multiplier
