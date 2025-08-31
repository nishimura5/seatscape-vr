# scripts/autoload/player_data_manager.gd (統合版)
extends Node

var movement_log: Array[Dictionary] = []
var intimate_violations: Array[Dictionary] = []
var final_seat_id: String = ""
var final_seat_position: Vector3 = Vector3.ZERO
var final_seat_zone_level: String = ""
var seating_start_time: float = 0.0
var seating_end_time: float = 0.0

# ゾーン状態管理（統合機能）
var current_zone_status: Dictionary = {}  # npc_id -> zone_level

var movement_timer: Timer
var player_reference: Node3D
var is_sampling_active: bool = false

func _ready():
    EventBus.seating_started.connect(_on_seating_started)
    setup_movement_timer()

func setup_movement_timer():
    movement_timer = Timer.new()
    movement_timer.wait_time = 0.2
    movement_timer.timeout.connect(_on_movement_timer_timeout)
    add_child(movement_timer)

func _on_seating_started():
    reset_data()

func start_movement_sampling(player: Node3D):
    seating_start_time = Time.get_unix_time_from_system()
    player_reference = player
    is_sampling_active = true
    movement_timer.start()
    print("Movement sampling started for ", player.get_class())

func stop_movement_sampling():
    is_sampling_active = false
    movement_timer.stop()
    player_reference = null
    print("Movement sampling stopped")

func _on_movement_timer_timeout():
    if is_sampling_active and player_reference:
        var position = player_reference.global_position
        var timestamp = Time.get_unix_time_from_system()
        log_player_movement(position, timestamp)

func reset_data():
    movement_log.clear()
    intimate_violations.clear()
    final_seat_id = ""
    final_seat_position = Vector3.ZERO
    final_seat_zone_level = ""
    current_zone_status.clear()
    seating_start_time = 0.0
    seating_end_time = 0.0
    stop_movement_sampling()

func log_player_movement(position: Vector3, timestamp: float):
    if movement_log.size() > 0:
        var last_entry = movement_log[movement_log.size() - 1]
        if last_entry.position.distance_to(position) < 0.1:
            return

    movement_log.append({
        "position": position,
        "timestamp": timestamp
    })

func log_intimate_violation(npc_id: String, position: Vector3, timestamp: float):
    intimate_violations.append({
        "npc_id": npc_id,
        "position": position,
        "timestamp": timestamp
    })
    print("親密ゾーン侵入記録: NPC ", npc_id, " at ", position)

func update_player_zone_status(npc_id: String, zone_level: String):
    """NPCから呼び出される：プレイヤーの現在ゾーン状態を更新"""
    if npc_id.is_empty():
        return
    
    if zone_level == "none":
        current_zone_status.erase(npc_id)
    else:
        current_zone_status[npc_id] = zone_level

#    print("ゾーン状態更新: NPC ", npc_id, " → ", zone_level, " (", current_zone_status, ")")

func set_final_seat(seat_id: String, position: Vector3):
    final_seat_id = seat_id
    final_seat_position = position
    seating_end_time = Time.get_unix_time_from_system()
    stop_movement_sampling()

func get_intimate_violations_count() -> int:
    return intimate_violations.size()

func get_intimate_violations() -> Array[Dictionary]:
    return intimate_violations.duplicate()

func get_movement_log() -> Array[Dictionary]:
    return movement_log.duplicate()

func get_final_seat_id() -> String:
    return final_seat_id

func get_final_seat_position() -> Vector3:
    return final_seat_position

func get_final_seat_zone_level() -> String:
    return final_seat_zone_level

func get_current_zone_status() -> Dictionary:
    """デバッグ用：現在のゾーン状態を取得"""
    return current_zone_status.duplicate()

func get_seating_duration() -> float:
    if seating_end_time > 0 and seating_start_time > 0:
        return seating_end_time - seating_start_time
    return 0.0

# === デバッグ関数 ===

func debug_print_data():
    print("=== Player Data Summary ===")
    print("Movement logs: ", movement_log.size())
    print("Intimate violations: ", intimate_violations.size())
    print("Final seat: ", final_seat_id)
    print("Final zone: ", final_seat_zone_level)
    print("Current zones: ", current_zone_status)
    print("Duration: ", get_seating_duration(), " seconds")
