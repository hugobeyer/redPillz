extends Area3D

@export_group("General Enemy Parameters")
@export var enable_general_features: bool = true
@export var max_health: float = 100.0
@export var death_effect_scene: PackedScene
@export var enable_melee: bool = true

@export_group("Shield Parameters")
@export var enable_shield: bool = false
@onready var _shield: EnemyShield = $WobbleEffect/CharacterMesh/EnemyShield if enable_shield else null

@onready var mesh_instance = $WobbleEffect/CharacterMesh
@onready var wobble_effect = $WobbleEffect
@onready var effects: EnemyEffects = $EnemyEffects
@onready var health_circle: MeshInstance3D = $HealthCircle
@onready var parent_point = get_parent()
@onready var flocking_manager = parent_point.get_parent()
@onready var melee_weapon = $WobbleEffect/CharacterMesh/MeleeWeapon  # Reference to the melee scene

var _health: float
var _time_alive: float = 0
var _knockback_velocity: Vector3 = Vector3.ZERO

signal enemy_killed(enemy)

func _ready():
    if not Engine.is_editor_hint():
        add_to_group("enemies")
        _health = max_health
        
        # Initialize shield if enabled
        if enable_shield and _shield:
            _shield.shield_depleted.connect(_on_shield_depleted)
            # Hide health circle if shield is active
            if health_circle:
                health_circle.visible = false
        elif not enable_shield and _shield:
            _shield.queue_free()
            # Show health circle if no shield
            update_health_circle()
        else:
            # No shield, show health circle
            update_health_circle()

func _process(delta):
    if Engine.is_editor_hint():
        return
    _time_alive += delta

func hit(direction: Vector3, hit_damage: float, knockback_force: float = 0.0):
    if _health <= 0:
        return
    
    var damage_to_apply = hit_damage
    
    # Handle shield if active
    if is_instance_valid(_shield):
        var shield_strength = _shield.get_shield_strength()
        if shield_strength > 0:
            # Calculate damage first
            damage_to_apply = _shield.take_damage(hit_damage)
            # Then apply shield effect if shield still exists
            if is_instance_valid(_shield):
                _shield.apply_shield_effect(direction * hit_damage)
            # Return early if shield absorbed all damage
            if damage_to_apply <= 0:
                return
    
    _health -= damage_to_apply
    update_health_circle()
    
    # Only apply knockback and wobble if no shield or shield is depleted
    if not is_instance_valid(_shield) or _shield.get_shield_strength() <= 0:
        # Apply knockback to the flocking point (parent)
        if knockback_force > 0 and parent_point and flocking_manager:
            if flocking_manager.has_method("apply_point_knockback"):
                print("Applying knockback to flocking point: ", knockback_force)
                flocking_manager.apply_point_knockback(parent_point, direction, knockback_force)
        
        # Apply visual effects
        if effects:
            effects.apply_damage_effect(direction)
        
        if wobble_effect:
            wobble_effect.apply_hit_wobble(-direction)
    
    if _health <= 0:
        die()
    else:
        if mesh_instance:
            mesh_instance.set_instance_shader_parameter("lerp_wave", 0.5)
            mesh_instance.set_instance_shader_parameter("lerp_color", Color(1.5, 0.1, 0.1, 1.0))
            get_tree().create_timer(0.1).connect("timeout", Callable(self, "_reset_hit_feedback"))

func _reset_hit_feedback():
    if mesh_instance:
        mesh_instance.set_instance_shader_parameter("lerp_wave", 0.0)
        mesh_instance.set_instance_shader_parameter("lerp_color", Color(0.395203, 0.24353, 0.546875, 1))

func die():
    # Prevent further hits immediately
    set_deferred("monitoring", false)
    set_deferred("monitorable", false)
    
    # Emit the signal before destroying the enemy
    emit_signal("enemy_killed", self)
    
    # Hide the mesh immediately
    if mesh_instance:
        mesh_instance.visible = false
    
    # Get camera and check if enemy is visible
    var camera = get_viewport().get_camera_3d()
    var is_visible = false
    
    if camera:
        # Simple frustum check is enough for most cases
        is_visible = camera.is_position_in_frustum(global_position)
        
        # Optional: Add a distance check if you want to limit effect range
        # var distance_to_camera = global_position.distance_to(camera.global_position)
        # is_visible = is_visible and distance_to_camera < 50.0  # Adjust distance as needed
    
    # Only spawn death effect if enemy is visible
    if death_effect_scene and is_visible:
        var effect = death_effect_scene.instantiate()
        get_tree().current_scene.add_child(effect)
        effect.global_position = global_position
        
        if effect is GPUParticles3D:
            effect.one_shot = true
            effect.emitting = true  # Changed this to just set emitting true
    
    # Register kill immediately
    GameEvents.register_kill(self)
    
    # Clean up after a tiny delay to ensure effect spawns
    await get_tree().create_timer(0.025).timeout
    
    if is_instance_valid(parent_point) and flocking_manager and flocking_manager.has_method("remove_point"):
        flocking_manager.remove_point(parent_point)
    
    if is_instance_valid(parent_point):
        parent_point.queue_free()
    queue_free()

func update_health_circle():
    if health_circle:
        var health_percent = _health / max_health
        health_circle.set_progress(health_percent, true)
        # Only show health circle if there's no active shield
        health_circle.visible = not (is_instance_valid(_shield) and _shield.get_shield_strength() > 0)

func _on_enemy_killed(_enemy):
    pass

func is_being_knocked_back() -> bool:
    return has_meta("original_position")

func _physics_process(delta):
    if _knockback_velocity.length() > 0:
        global_position += _knockback_velocity * delta
        _knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, delta * 5.0)

func _on_shield_depleted():
    if _shield:
        # Optional: Add effects or behavior when shield breaks
        # var shield_pos = _shield.global_position
        # var shield_scale = _shield.scale
        
        # Remove the shield
        _shield.queue_free()
        _shield = null
        
        # Show health circle when shield is depleted
        update_health_circle()
        
        # Optional: Add shield break effect here
        # if shield_break_effect_scene:
        #     var effect = shield_break_effect_scene.instantiate()
        #     get_tree().current_scene.add_child(effect)
        #     effect.global_position = shield_pos
        #     effect.scale = shield_scale

