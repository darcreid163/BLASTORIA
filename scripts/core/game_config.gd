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

# Changing scoring, maps or pacing requires a new arcade_rules_id.
@export var arcade_rules_id: String = "arcade_v1"
@export var arcade_seeds: Array[int] = [4103, 6721, 9011]
@export var score_crate: int = 10
@export var score_enemy: int = 100
@export var score_pickup: int = 25
@export var score_stage_clear: int = 500
@export var arcade_par_seconds: int = 180
@export var score_per_second: int = 5

# Explicit presets; legacy Arcade v1 keeps its existing parameters.
@export var hidden_exit: bool = false
@export var contact_damage: bool = false
@export var level_seconds: int = 0
@export var ticks_per_game_second: int = 60
@export var timeout_enemies: int = 4
@export var exit_penalty_enemies: int = 2
@export var invulnerable_ticks: int = 1800
@export var full_powerups: bool = false
