class_name GameConfig
extends Resource

@export var width: int = 15
@export var height: int = 11
@export var tick_rate: int = 60
@export var fuse_ticks: int = 150
@export var fire_ticks: int = 30
@export var player_step_ticks: int = 9
@export var enemy_step_ticks: int = 25
@export var initial_range: int = 2
@export var initial_capacity: int = 1
@export var max_range: int = 6
@export var max_capacity: int = 5
@export var min_step_ticks: int = 5
@export var drop_chance: float = 0.3
@export var campaign_seeds: Array[int] = [731, 1559, 2801]
@export var enemy_counts: Array[int] = [1, 2, 3]
@export var crate_density: float = 0.37
