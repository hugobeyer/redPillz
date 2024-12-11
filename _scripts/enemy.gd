extends Node3D

signal enemy_killed

func hit(direction: Vector3, damage: float):
    # This is where the grenade's explosion force should be received
    print("Enemy hit with damage: ", damage, " and direction: ", direction)
    emit_signal("enemy_killed") 