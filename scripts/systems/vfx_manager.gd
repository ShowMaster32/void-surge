extends Node2D
class_name VFXManager
## VFXManager - Gestisce effetti visivi (hit, death, pickup)
## Singleton per spawn effetti ottimizzato

# Pool di particelle per performance
var hit_particles_pool: Array[GPUParticles2D] = []
var death_particles_pool: Array[GPUParticles2D] = []
const POOL_SIZE := 20

# Riferimenti alle scene particelle
var hit_particle_scene: PackedScene
var death_particle_scene: PackedScene


func _ready() -> void:
	# Crea particelle programmaticamente (no scene esterne richieste)
	_create_particle_pools()


func _create_particle_pools() -> void:
	# Pool per hit particles
	for i in POOL_SIZE:
		var hit_p := _create_hit_particle()
		hit_p.emitting = false
		hit_p.visible = false
		add_child(hit_p)
		hit_particles_pool.append(hit_p)
	
	# Pool per death particles
	for i in POOL_SIZE:
		var death_p := _create_death_particle()
		death_p.emitting = false
		death_p.visible = false
		add_child(death_p)
		death_particles_pool.append(death_p)


func _create_hit_particle() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 8
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 5.0
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0
	material.gravity = Vector3.ZERO
	material.scale_min = 2.0
	material.scale_max = 4.0
	material.color = Color(0, 1, 1, 1)  # Cyan
	
	particles.process_material = material
	particles.finished.connect(_on_particle_finished.bind(particles, hit_particles_pool))
	
	return particles


func _create_death_particle() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 10.0
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 150.0
	material.initial_velocity_max = 300.0
	material.gravity = Vector3.ZERO
	material.scale_min = 3.0
	material.scale_max = 6.0
	material.color = Color(1, 0.3, 0.3, 1)  # Red
	
	particles.process_material = material
	particles.finished.connect(_on_particle_finished.bind(particles, death_particles_pool))
	
	return particles


func spawn_hit_effect(pos: Vector2, color: Color = Color(0, 1, 1)) -> void:
	var particle := _get_from_pool(hit_particles_pool)
	if particle:
		particle.global_position = pos
		var mat := particle.process_material as ParticleProcessMaterial
		if mat:
			mat.color = color
		particle.visible = true
		particle.emitting = true


func spawn_death_effect(pos: Vector2, color: Color = Color(1, 0.3, 0.3)) -> void:
	var particle := _get_from_pool(death_particles_pool)
	if particle:
		particle.global_position = pos
		var mat := particle.process_material as ParticleProcessMaterial
		if mat:
			mat.color = color
		particle.visible = true
		particle.emitting = true


func _get_from_pool(pool: Array[GPUParticles2D]) -> GPUParticles2D:
	for p in pool:
		if not p.emitting:
			return p
	# Pool esaurito, restituisci il primo (verrà riutilizzato)
	if pool.size() > 0:
		return pool[0]
	return null


func _on_particle_finished(particles: GPUParticles2D, _pool: Array[GPUParticles2D]) -> void:
	particles.visible = false
