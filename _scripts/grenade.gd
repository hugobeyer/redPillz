extends RigidBody3D

@export_group("Explosion")
@export var explosion_radius: float = 15.0
@export var explosion_force: float = 25.0
@export var damage: float = 100.0
@export var fuse_time: float = 2.0
@export var explosion_effect_scene: PackedScene
@export var effect_animation_time: float = 1.25
@export var animation_name: String = "explode"

@export_group("Glow Effect")
@export var glow_speed: float = 2.0
@export var pixel_size_start: float = 1.000
@export var pixel_size_end: float = 2.500
@export var modulate_start: Color = Color(1, 1, 1, 0.2)
@export var modulate_end: Color = Color(1, 0.2, 0.2, 1.0)
@export var pulse_curve: Curve
@export var speed_curve: Curve

var time_alive: float = 0.0
var tween: Tween
var update_timer: float = 0.0

@onready var glow_sprite: Sprite3D = $GrenadeGlow

func _ready():
    time_alive = 0.0
    if not pulse_curve:
        # Create default curve if none provided
        pulse_curve = Curve.new()
        pulse_curve.add_point(Vector2(0, 0))
        pulse_curve.add_point(Vector2(0.5, 1))
        pulse_curve.add_point(Vector2(1, 0))
    
    if not speed_curve:
        # Create default speed curve if none provided
        speed_curve = Curve.new()
        speed_curve.add_point(Vector2(0, 1))      # Start at normal speed
        speed_curve.add_point(Vector2(0.6, 1.5))  # Gradual increase
        speed_curve.add_point(Vector2(0.8, 2.5))  # Faster increase
        speed_curve.add_point(Vector2(1, 4))      # Maximum speed multiplier
    
    start_glow_effect()

func _physics_process(delta: float) -> void:
    time_alive += delta
    update_timer += delta
    
    # Update tween speed every 0.1 seconds
    if update_timer >= 0.1:
        update_timer = 0.0  # Reset timer
        update_tween_speed()
    
    if time_alive >= fuse_time:
        explode()

func start_glow_effect():
    if tween:
        tween.kill()
    
    tween = create_tween().set_loops()
    tween.set_trans(Tween.TRANS_SINE)
    update_tween_speed()

func update_tween_speed():
    if not tween:
        return
        
    # Get current time progress
    var time_progress = time_alive / fuse_time
    
    # Get speed multiplier from curve
    var speed_multiplier = speed_curve.sample(time_progress)
    
    # Calculate new loop duration
    var single_loop_duration = 1.0 / (glow_speed * speed_multiplier)
    
    # Create the repeating tween sequence with new speed
    tween.kill()  # Clear existing tween
    tween = create_tween().set_loops()
    tween.set_trans(Tween.TRANS_SINE)
    tween.tween_method(
        update_glow_effect,
        0.0,
        1.0,
        single_loop_duration
    )

func update_glow_effect(progress: float):
    # Use curve to modify the progress
    var curve_value = pulse_curve.sample(progress)
    
    # As fuse gets closer to end, increase the effect intensity
    var time_factor = time_alive / fuse_time
    var intensity = lerp(1.0, 2.0, time_factor)
    
    # Update pixel size with increasing intensity
    var current_pixel_size = lerp(
        pixel_size_start,
        pixel_size_end * intensity,
        curve_value
    )
    glow_sprite.pixel_size = current_pixel_size
    
    # Make color more intense towards the end
    var final_modulate = modulate_start.lerp(modulate_end, curve_value)
    final_modulate.r = min(final_modulate.r * intensity, 1.0)
    glow_sprite.modulate = final_modulate

func explode():
    if tween:
        tween.kill()
        
    # Instantiate the explosion effect
    if explosion_effect_scene:
        var explosion_effect = explosion_effect_scene.instantiate()
        var game_root = get_tree().get_first_node_in_group("gameroot")
        if game_root:
            game_root.add_child(explosion_effect)
            explosion_effect.global_position = global_position
        
        # Get and play the animation
        var anim_player = explosion_effect.get_node_or_null("AnimationPlayer")
        if anim_player and anim_player.has_animation("explode"):
            print("Playing explosion animation")
            anim_player.play("explode")
        else:
            print("Animation player or animation not found!")
            print("Available animations: ", anim_player.get_animation_list() if anim_player else "No AnimationPlayer")
        
        # Clean up after animation
        get_tree().create_timer(effect_animation_time).timeout.connect(
            func(): explosion_effect.queue_free()
        )

    # Add camera shake
    var camera = get_tree().get_first_node_in_group("cameragame")
    if camera:
        camera.add_shake(2.0)

    # Rest of explosion logic...
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if is_instance_valid(enemy):
            var enemy_position = enemy.global_position
            var distance = global_position.distance_to(enemy_position)
            if distance <= explosion_radius:
                apply_explosion_damage(enemy, distance)
    
    queue_free()

func apply_explosion_damage(target, distance):
    var direction = (target.global_position - global_position).normalized()
    direction.y = 0
    
    var damage_multiplier = 1.0 - (distance / explosion_radius)
    damage_multiplier = clamp(damage_multiplier, 0.0, 1.0)
    var final_damage = damage * damage_multiplier
    
    var camera = get_tree().get_first_node_in_group("cameragame")
    if camera:
        var shake_intensity = 1.0 - (distance / explosion_radius)
        shake_intensity = clamp(shake_intensity, 0.0, 1.0)
        camera.add_shake(shake_intensity * 2.0)
    
    if target.has_method("hit"):
        target.hit(direction, final_damage)
        
        var parent_point = target.get_parent()
        if parent_point and is_instance_valid(parent_point):
            var flocking_manager = parent_point.get_parent()
            if flocking_manager and flocking_manager.has_method("apply_point_knockback"):
                flocking_manager.apply_point_knockback(parent_point, direction, explosion_force * damage_multiplier)

func _integrate_forces(state):
    if state.get_contact_count() > 0:
        explode()