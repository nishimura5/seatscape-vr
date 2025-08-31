# scripts/seat_manager.gd
class_name SeatManager
extends RefCounted

signal seat_moved(seat_id: String, new_position: Vector3)
signal seat_rotated(seat_id: String, new_rotation: float)

var selected_seat_id: String = ""
var is_move_mode: bool = false
var move_step: float = 0.1  # 0.1m単位での移動
var rotation_step: float = 45.0  # 45度単位での回転

func select_seat(seat_id: String) -> bool:
    # 占有されている座席は選択不可
    if DataRepository.is_seat_occupied(seat_id):
        return false
    
    selected_seat_id = seat_id
    is_move_mode = true
    return true

func deselect_seat():
    selected_seat_id = ""
    is_move_mode = false

func handle_input(event: InputEvent) -> bool:
    if not is_move_mode or selected_seat_id.is_empty():
        return false
    
    if event is InputEventKey and event.pressed:
        var movement = Vector3.ZERO
        
        if event.is_action_pressed("ui_up"):
            if event.is_shift_pressed():
                movement.z = -move_step * 10
            else:
                movement.z = -move_step
        elif event.is_action_pressed("ui_down"):
            if event.is_shift_pressed():
                movement.z = move_step * 10
            else:
                movement.z = move_step
        elif event.is_action_pressed("ui_left"):
            if event.is_shift_pressed():
                movement.x = -move_step * 10
            else:
                movement.x = -move_step
        elif event.is_action_pressed("ui_right"):
            if event.is_shift_pressed():
                movement.x = move_step * 10
            else:
                movement.x = move_step
        elif event.is_action_pressed("ui_cancel"):
            deselect_seat()
            return true
        elif event.is_action_pressed("ui_rotate"):
            rotate_seat()
            return true
        else:
            return false
       
        if movement != Vector3.ZERO:
            move_seat(movement)
            return true
    
    return false

func move_seat(movement: Vector3):
    var seat = DataRepository.seat_repository.get_seat(selected_seat_id)
    if not seat:
        return
    
    var new_position = seat.position + movement
    
    # 部屋の境界内に制限
    var room = DataRepository.room_repository.get_current_room()
    if room:
        new_position.x = clamp(new_position.x, 0.0, room.size.x)
        new_position.z = clamp(new_position.z, 0.0, room.size.z)
    
    seat.position = new_position
    DataRepository.seat_repository.update_seat(seat)
    
    seat_moved.emit(selected_seat_id, new_position)

func rotate_seat():
    var seat = DataRepository.seat_repository.get_seat(selected_seat_id)
    if not seat:
        return
    
    # 45度時計回りに回転
    var new_rotation = seat.rotation_degrees + rotation_step
    
    # 0-360度の範囲に正規化
    if new_rotation >= 360.0:
        new_rotation -= 360.0
    
    # 座席データを更新
    seat.rotation_degrees = new_rotation
    DataRepository.seat_repository.update_seat(seat)
    
    seat_rotated.emit(selected_seat_id, new_rotation)

func get_selected_seat_id() -> String:
    return selected_seat_id

func is_in_move_mode() -> bool:
    return is_move_mode
