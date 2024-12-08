extends Node

# Define our signals
signal enemy_killed(enemy)

func register_kill(enemy):
    enemy_killed.emit(enemy)