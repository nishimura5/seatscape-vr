class_name RoomRepository
extends RefCounted

class Room:
	var id: String
	var size: Vector3  # width, depth, height in meters
	var player_spawn_position: Vector3  # 3D座標に統一
	var player_spawn_rotation: float  # degrees
	var exit_position: Vector3  # 3D座標に統一
	var display_name: String
	
	func _init(p_id: String = "", p_size: Vector3 = Vector3.ZERO, p_spawn_pos: Vector3 = Vector3.ZERO, p_spawn_rot: float = 0.0, p_exit_pos: Vector3 = Vector3.ZERO, p_display_name: String = ""):
		id = p_id
		size = p_size
		player_spawn_position = p_spawn_pos
		player_spawn_rotation = p_spawn_rot
		exit_position = p_exit_pos
		display_name = p_display_name

var current_room: Room

func set_current_room(room: Room) -> void:
	current_room = room

func get_current_room() -> Room:
	return current_room

func has_current_room() -> bool:
	return current_room != null

func clear_current_room() -> void:
	current_room = null