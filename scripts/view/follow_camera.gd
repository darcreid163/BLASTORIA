class_name FollowCamera
extends RefCounted

const OFFSET := Vector3(0, 17, 12)
var center := Vector3.ZERO

func target(player: Vector3, width: int, height: int, size: float, aspect: float) -> Vector3:
	# Orthographic KEEP_HEIGHT footprint on the y=0 plane; clamp the whole footprint.
	var half_x := size * aspect * 0.5
	var half_z := size * 0.5 * OFFSET.length() / OFFSET.y
	var max_x := maxf(0, width * 0.5 - half_x)
	var max_z := maxf(0, height * 0.5 - half_z)
	return Vector3(clampf(player.x, -max_x, max_x), 0, clampf(player.z, -max_z, max_z))

func update(camera: Camera3D, player: Vector3, width: int, height: int, delta: float, snap: bool = false) -> void:
	var viewport := camera.get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(1, viewport.y)
	# Reduce coverage on ultra-wide screens so the entire footprint still fits the board.
	camera.size = minf(16.0, minf(width / maxf(0.1, aspect), height * OFFSET.y / OFFSET.length()))
	var goal := target(player, width, height, camera.size, aspect)
	center = goal if snap else center.lerp(goal, 1.0 - exp(-8.0 * delta))
	# Resizing can shrink the allowed interval while the camera is moving.
	center = target(center, width, height, camera.size, aspect)
	camera.position = center + OFFSET
	camera.look_at(center)
