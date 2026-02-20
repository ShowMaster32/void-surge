extends Node
## EquipmentManager - Gestisce inventario equipaggiamenti e sinergie
## Autoload singleton

signal equipment_collected(equipment: EquipmentData)
signal equipment_stats_changed(stats: Dictionary)
signal synergy_activated(synergy_name: String)
signal synergy_deactivated(synergy_name: String)

var inventory: Dictionary = {}
var cached_stats: Dictionary = {}
var active_synergies: Array[String] = []
var all_equipment: Array[EquipmentData] = []

const DROP_RATES := {
	EquipmentData.Rarity.COMMON: 0.90,
	EquipmentData.Rarity.RARE: 0.09,
	EquipmentData.Rarity.EPIC: 0.01,
}

const SYNERGIES := {
	"fire_build": {
		"name": "Inferno",
		"element": EquipmentData.ElementType.FIRE,
		"required": 3,
		"description": "Projectiles ignite enemies for burn damage",
		"bonus": {"burn_damage": 5.0}
	},
	"void_build": {
		"name": "Void Walker",
		"element": EquipmentData.ElementType.VOID,
		"required": 3,
		"description": "Projectiles deal +50% damage to pierced enemies",
		"bonus": {"pierce_damage_mult": 0.5}
	},
	"chaos_build": {
		"name": "Chaos Lord",
		"element": EquipmentData.ElementType.CHAOS,
		"required": 2,
		"description": "+25% additional crit chance",
		"bonus": {"crit_chance": 0.25}
	},
	"plasma_build": {
		"name": "Storm Bringer",
		"element": EquipmentData.ElementType.PLASMA,
		"required": 2,
		"description": "Chain lightning on kill",
		"bonus": {"chain_lightning": true}
	}
}


func _ready() -> void:
	_load_all_equipment()
	_recalculate_stats()


func _load_all_equipment() -> void:
	var equipment_paths := [
		"res://resources/equipment/fire_surge.tres",
		"res://resources/equipment/inferno_core.tres",
		"res://resources/equipment/blazing_heart.tres",
		"res://resources/equipment/void_shard.tres",
		"res://resources/equipment/dark_matter.tres",
		"res://resources/equipment/void_nexus.tres",
		"res://resources/equipment/plasma_cell.tres",
		"res://resources/equipment/storm_capacitor.tres",
		"res://resources/equipment/chaos_fragment.tres",
		"res://resources/equipment/reality_tear.tres",
	]

	for path in equipment_paths:
		var equipment := load(path) as EquipmentData
		if equipment:
			all_equipment.append(equipment)


func reset() -> void:
	inventory.clear()
	active_synergies.clear()
	_recalculate_stats()


func collect_equipment(equipment: EquipmentData) -> void:
	if equipment.equipment_id in inventory:
		inventory[equipment.equipment_id] += 1
	else:
		inventory[equipment.equipment_id] = 1

	equipment_collected.emit(equipment)
	_recalculate_stats()
	_check_synergies()


func get_equipment_count(equipment_id: String) -> int:
	return inventory.get(equipment_id, 0)


func get_total_equipment_count() -> int:
	var total := 0
	for count in inventory.values():
		total += count
	return total


func roll_random_equipment(drop_multiplier: float = 1.0) -> EquipmentData:
	var roll := randf()
	var adjusted_rates := DROP_RATES.duplicate()
	if drop_multiplier > 1.0:
		var bonus := (drop_multiplier - 1.0) * 0.05
		adjusted_rates[EquipmentData.Rarity.EPIC] += bonus
		adjusted_rates[EquipmentData.Rarity.RARE] += bonus * 2
		adjusted_rates[EquipmentData.Rarity.COMMON] -= bonus * 3

	var target_rarity: EquipmentData.Rarity
	if roll < adjusted_rates[EquipmentData.Rarity.EPIC]:
		target_rarity = EquipmentData.Rarity.EPIC
	elif roll < adjusted_rates[EquipmentData.Rarity.EPIC] + adjusted_rates[EquipmentData.Rarity.RARE]:
		target_rarity = EquipmentData.Rarity.RARE
	else:
		target_rarity = EquipmentData.Rarity.COMMON

	var filtered := all_equipment.filter(func(e): return e.rarity == target_rarity)
	if filtered.is_empty():
		filtered = all_equipment.filter(func(e): return e.rarity == EquipmentData.Rarity.COMMON)
	if filtered.is_empty():
		return null

	return filtered[randi() % filtered.size()]


func _recalculate_stats() -> void:
	cached_stats = {
		"damage_bonus": 0.0,
		"fire_rate_bonus": 0.0,
		"projectile_speed_bonus": 0.0,
		"projectile_size_bonus": 0.0,
		"pierce_count": 0,        # FIX: rinominato da pierce_bonus a pierce_count
		"health_bonus": 0.0,
		"health_regen": 0.0,
		"speed_bonus": 0.0,       # FIX: rinominato da move_speed_bonus a speed_bonus
		"crit_bonus": 0.0,        # FIX: rinominato da crit_chance_bonus a crit_bonus
		"crit_damage_bonus": 0.0,
		"burn_damage": 0.0,
		"pierce_damage_mult": 0.0,
		"chain_lightning": false,
	}

	for equipment in all_equipment:
		var count: int = inventory.get(equipment.equipment_id, 0)
		if count > 0:
			cached_stats["damage_bonus"]           += equipment.damage_bonus * count
			cached_stats["fire_rate_bonus"]        += equipment.fire_rate_bonus * count
			cached_stats["projectile_speed_bonus"] += equipment.projectile_speed_bonus * count
			cached_stats["projectile_size_bonus"]  += equipment.projectile_size_bonus * count
			cached_stats["pierce_count"]           += equipment.pierce_bonus * count
			cached_stats["health_bonus"]           += equipment.health_bonus * count
			cached_stats["health_regen"]           += equipment.health_regen * count
			cached_stats["speed_bonus"]            += equipment.move_speed_bonus * count
			cached_stats["crit_bonus"]             += equipment.crit_chance_bonus * count
			cached_stats["crit_damage_bonus"]      += equipment.crit_damage_bonus * count

	equipment_stats_changed.emit(cached_stats)


func _check_synergies() -> void:
	var element_counts := {}

	for equipment in all_equipment:
		var count: int = inventory.get(equipment.equipment_id, 0)
		if count > 0 and equipment.element != EquipmentData.ElementType.NONE:
			if equipment.element in element_counts:
				element_counts[equipment.element] += count
			else:
				element_counts[equipment.element] = count

	for synergy_id in SYNERGIES:
		var synergy: Dictionary = SYNERGIES[synergy_id]
		var element: EquipmentData.ElementType = synergy["element"]
		var required: int = synergy["required"]
		var current_count: int = element_counts.get(element, 0)

		var is_active := current_count >= required
		var was_active: bool = synergy_id in active_synergies

		if is_active and not was_active:
			active_synergies.append(synergy_id)
			_apply_synergy_bonus(synergy_id, true)
			synergy_activated.emit(synergy["name"])
		elif not is_active and was_active:
			active_synergies.erase(synergy_id)
			_apply_synergy_bonus(synergy_id, false)
			synergy_deactivated.emit(synergy["name"])


func _apply_synergy_bonus(synergy_id: String, activate: bool) -> void:
	var synergy: Dictionary = SYNERGIES[synergy_id]
	var bonus: Dictionary = synergy["bonus"]
	var mult := 1.0 if activate else -1.0

	for key in bonus:
		if key in cached_stats:
			if typeof(bonus[key]) == TYPE_BOOL:
				cached_stats[key] = activate
			else:
				cached_stats[key] += bonus[key] * mult

	equipment_stats_changed.emit(cached_stats)


func get_stat(stat_name: String) -> Variant:
	return cached_stats.get(stat_name, 0.0)


func get_all_stats() -> Dictionary:
	return cached_stats.duplicate()


func get_active_synergies() -> Array[String]:
	return active_synergies


func get_synergy_info(synergy_id: String) -> Dictionary:
	return SYNERGIES.get(synergy_id, {})


func get_equipment_by_id(equipment_id: String) -> EquipmentData:
	for equipment in all_equipment:
		if equipment.equipment_id == equipment_id:
			return equipment
	return null


func get_inventory_display() -> Array[Dictionary]:
	# FIX: var display: Array[Dictionary] invece di var display := []
	# Il tipo esplicito è necessario perché GDScript 4 non accetta
	# "return [] as Array[Dictionary]" — va dichiarato subito
	var display: Array[Dictionary] = []
	for equipment in all_equipment:
		var count: int = inventory.get(equipment.equipment_id, 0)
		if count > 0:
			display.append({
				"equipment": equipment,
				"count": count
			})
	return display
