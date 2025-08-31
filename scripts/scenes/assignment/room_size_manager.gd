# scripts/room_size_manager.gd
class_name RoomSizeManager
extends RefCounted

signal room_size_changed(new_width: float, new_depth: float)

var is_room_size_selected: bool = false
var move_step: float = 0.1  # 0.1m単位での移動
var min_room_size: float = 2.0  # 最小room size
var max_room_size: float = 20.0  # 最大room size

func select_room_size() -> bool:
    is_room_size_selected = true
    return true

func deselect_room_size():
    is_room_size_selected = false

func handle_input(event: InputEvent) -> bool:
    if not is_room_size_selected:
        return false
    
    if event is InputEventKey and event.pressed:
        var size_change = Vector2.ZERO
        
        if event.is_action_pressed("ui_up"):
            if event.is_shift_pressed():
                size_change.y = -move_step * 10
            else:
                size_change.y = -move_step
        elif event.is_action_pressed("ui_down"):
            if event.is_shift_pressed():
                size_change.y = move_step * 10
            else:
                size_change.y = move_step
        elif event.is_action_pressed("ui_left"):
            if event.is_shift_pressed():
                size_change.x = -move_step * 10
            else:
                size_change.x = -move_step
        elif event.is_action_pressed("ui_right"):
            if event.is_shift_pressed():
                size_change.x = move_step * 10
            else:
                size_change.x = move_step
        elif event.is_action_pressed("ui_cancel"):
            deselect_room_size()
            return true
        else:
            return false

        if size_change != Vector2.ZERO:
            change_room_size(size_change)
            return true
    
    return false

func change_room_size(size_change: Vector2):
    var room = DataRepository.room_repository.get_current_room()
    if not room:
        return
    
    var new_width = room.size.x + size_change.x
    var new_depth = room.size.z + size_change.y

    # サイズ制限を適用
    new_width = clamp(new_width, min_room_size, max_room_size)
    new_depth = clamp(new_depth, min_room_size, max_room_size)
    
    # room dataを更新
    room.size.x = new_width
    room.size.z = new_depth
    DataRepository.room_repository.set_current_room(room)
    
    room_size_changed.emit(new_width, new_depth)

func is_in_move_mode() -> bool:
    return is_room_size_selected
