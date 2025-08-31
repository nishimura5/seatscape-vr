class_name SeatRepository
extends RefCounted

class Seat:
    var id: String
    var position: Vector3  # 3D座標に統一
    var size: Vector3
    var rotation_degrees: float
    var mesh_id: String
    var display_name: String

    func _init(p_id: String = "", p_position: Vector3 = Vector3.ZERO, p_size: Vector3 = Vector3.ONE, p_rotation: float = 0.0, p_mesh_id: String = "", p_display_name: String = ""):
        id = p_id
        position = p_position
        size = p_size
        rotation_degrees = p_rotation
        mesh_id = p_mesh_id
        display_name = p_display_name

var seats: Dictionary = {}

func add_seat(seat: Seat) -> void:
    seats[seat.id] = seat

func get_seat(seat_id: String) -> Seat:
    return seats.get(seat_id)

func get_all_seats() -> Array[Seat]:
    var result: Array[Seat] = []
    for seat in seats.values():
        result.append(seat)
    return result

func update_seat(seat: Seat) -> void:
    if seats.has(seat.id):
        seats[seat.id] = seat

func remove_seat(seat_id: String) -> void:
    seats.erase(seat_id)

func has_seat(seat_id: String) -> bool:
    return seats.has(seat_id)

func clear_all_seats() -> void:
    seats.clear()

func get_seat_count() -> int:
    return seats.size()
