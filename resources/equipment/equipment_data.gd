extends Resource
class_name EquipmentData
## EquipmentData - Definisce un equipaggiamento/potenziamento

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum EquipmentType { WEAPON, ARMOR, UTILITY, SPECIAL }
enum ElementType { NONE, FIRE, VOID, PLASMA, CHAOS }

@export_group("Identity")
@export var equipment_id: String = "base_equipment"
@export var equipment_name: String = "Base Equipment"
@export var description: String = "A basic equipment."
@export var icon: Texture2D

@export_group("Classification")
@export var rarity: Rarity = Rarity.COMMON
@export var equipment_type: EquipmentType = EquipmentType.UTILITY
@export var element: ElementType = ElementType.NONE

@export_group("Stats Modifiers")
@export var damage_bonus: float = 0.0          # Percentuale: 0.1 = +10%
@export var fire_rate_bonus: float = 0.0       # Percentuale
@export var projectile_speed_bonus: float = 0.0
@export var projectile_size_bonus: float = 0.0
@export var pierce_bonus: int = 0              # Numero aggiuntivo di nemici penetrati
@export var health_bonus: float = 0.0          # HP flat bonus
@export var health_regen: float = 0.0          # HP/sec
@export var move_speed_bonus: float = 0.0      # Percentuale
@export var crit_chance_bonus: float = 0.0     # Percentuale (0.1 = 10%)
@export var crit_damage_bonus: float = 0.0     # Moltiplicatore extra (0.5 = +50% crit damage)

@export_group("Special Effects")
@export var special_effect_id: String = ""     # ID per effetti speciali custom
@export var special_effect_value: float = 0.0

@export_group("Visual")
@export var glow_color: Color = Color.WHITE


func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.7, 0.7, 0.7)  # Grigio
		Rarity.RARE:
			return Color(0.3, 0.5, 1.0)  # Blu
		Rarity.EPIC:
			return Color(0.7, 0.3, 1.0)  # Viola
		Rarity.LEGENDARY:
			return Color(1.0, 0.8, 0.2)  # Oro
	return Color.WHITE


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Unknown"


func get_element_name() -> String:
	match element:
		ElementType.NONE:
			return ""
		ElementType.FIRE:
			return "Fire"
		ElementType.VOID:
			return "Void"
		ElementType.PLASMA:
			return "Plasma"
		ElementType.CHAOS:
			return "Chaos"
	return ""


func get_stats_summary() -> String:
	var stats := []
	
	if damage_bonus != 0:
		stats.append("+%d%% Damage" % int(damage_bonus * 100))
	if fire_rate_bonus != 0:
		stats.append("+%d%% Fire Rate" % int(fire_rate_bonus * 100))
	if projectile_speed_bonus != 0:
		stats.append("+%d%% Proj Speed" % int(projectile_speed_bonus * 100))
	if pierce_bonus > 0:
		stats.append("+%d Pierce" % pierce_bonus)
	if health_bonus != 0:
		stats.append("+%d HP" % int(health_bonus))
	if health_regen != 0:
		stats.append("+%.1f HP/s" % health_regen)
	if move_speed_bonus != 0:
		stats.append("+%d%% Speed" % int(move_speed_bonus * 100))
	if crit_chance_bonus != 0:
		stats.append("+%d%% Crit" % int(crit_chance_bonus * 100))
	
	return ", ".join(stats) if stats.size() > 0 else "No bonuses"
