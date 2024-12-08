# res://_scripts/hit_effect.gd
class_name HitEffect
extends Node3D

@export var auto_free := true
@export var lifetime := 0.1
@export var effect_cooldown := 0.1

@onready var particles = $GPUParticles3D  # Get the child node

signal effect_finished

# Use collision info directly
func spawn_from_collision(collision: KinematicCollision3D) -> GPUParticles3D:
    var effect = particles as GPUParticles3D
    add_child(effect)
    
    # Use collision position and normal
    effect.global_position = collision.get_position()
    effect.look_at(collision.get_position() + collision.get_normal())
    
    # Start emitting
    effect.emitting = true
    
    if auto_free:
        await get_tree().create_timer(lifetime).timeout
        effect.queue_free()
        effect_finished.emit()
    
    return effect

# Add this method to match what bullet.gd is calling
func spawn_from_hit(position: Vector3, direction: Vector3) -> GPUParticles3D:
    # print("=== HIT EFFECT DEBUG ===")
    # print("Particles node exists:", particles != null)
    
    if particles == null:
        printerr("No particles node found!")
        return null
    
    # Use the existing particles node
    particles.global_position = position
    particles.look_at(position + direction)
    particles.restart()  # Reset and restart particles
    particles.emitting = true
    
    return particles
