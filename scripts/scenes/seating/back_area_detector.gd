# scripts/back_area_detector.gd
extends Area3D

signal seat_available(seat_id: String)
signal seat_unavailable(seat_id: String)

var current_seat: Area3D = null
var nearby_seats: Array[Area3D] = []

func _ready():
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D):
    if area.name.begins_with("AvailableArea"):
        if not nearby_seats.has(area):
            nearby_seats.append(area)
        update_current_seat()

func _on_area_exited(area: Area3D):
    if area.name.begins_with("AvailableArea"):
        var was_current = (area == current_seat)
        nearby_seats.erase(area)
        
        # current_seatだった場合は即座にseat_unavailableを発火
        if was_current:
            seat_unavailable.emit()
            current_seat = null
        
        # 新しい座席候補を探す
        update_current_seat()

func update_current_seat():
    var best_seat: Area3D = null
    
    # 利用可能な座席の中から最適なものを選択
    for seat_area in nearby_seats:
        if is_seat_available_for_sitting(seat_area):
            best_seat = seat_area
            break
    
    # current_seatが変更された場合のみ処理
    if best_seat != current_seat:
        # 前の座席がnullでない場合はunavailableを発火
        # （ただし、_on_area_exitedで既に処理済みの場合は除く）
        if current_seat and nearby_seats.has(current_seat):
            seat_unavailable.emit()
        
        # 新しい座席を設定
        current_seat = best_seat
        
        # 新しい座席がある場合はavailableを発火
        if current_seat:
            seat_available.emit()

func is_seat_available_for_sitting(seat_area: Area3D) -> bool:
    var seat_id = get_seat_id_from_area(seat_area)
    var is_available = not DataRepository.is_seat_occupied(seat_id)
    print("Seat ", seat_id, " availability: ", is_available)
    return is_available

func get_seat_id_from_area(area: Area3D) -> String:
    if area == null:
        return ""
    return area.name.replace("AvailableArea_", "")

func get_current_seat_id() -> String:
    if current_seat:
        return get_seat_id_from_area(current_seat)
    return ""

func can_sit() -> bool:
    return current_seat != null

func get_current_seat_position() -> Vector3:
    if current_seat:
        return current_seat.global_position
    return Vector3.ZERO
