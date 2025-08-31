# scripts/spawn_manager.gd
class_name SpawnManager
extends RefCounted

signal spawn_moved(new_position: Vector3)
signal spawn_rotated(new_rotation: float)

var is_spawn_selected: bool = false
var move_step: float = 0.1  # 0.1m単位での移動
var rotation_step: float = 45.0  # 45度単位での回転

func select_spawn() -> bool:
    is_spawn_selected = true
    return true

func deselect_spawn():
    is_spawn_selected = false

func handle_input(event: InputEvent) -> bool:
    if not is_spawn_selected:
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
            deselect_spawn()
            return true
        elif event.is_action_pressed("ui_rotate"):
            rotate_spawn()
            return true
        else:
            return false
        
        if movement != Vector3.ZERO:
            move_spawn(movement)
            return true
    
    return false

func move_spawn(movement: Vector3):
    var room = DataRepository.room_repository.get_current_room()
    if not room:
        return
    
    var new_position = room.player_spawn_position + movement
    
    # 部屋の境界内に制限
    new_position.x = clamp(new_position.x, 0.5, room.size.x - 0.5)
    new_position.z = clamp(new_position.z, 0.5, room.size.z - 0.5)
    
    # 部屋データを更新
    room.player_spawn_position = new_position
    DataRepository.room_repository.set_current_room(room)
    
    spawn_moved.emit(new_position)

func rotate_spawn():
    var room = DataRepository.room_repository.get_current_room()
    if not room:
        return
    
    # 45度時計回りに回転
    var new_rotation = room.player_spawn_rotation + rotation_step
    
    # 0-360度の範囲に正規化
    if new_rotation >= 360.0:
        new_rotation -= 360.0
    
    # 部屋データを更新
    room.player_spawn_rotation = new_rotation
    DataRepository.room_repository.set_current_room(room)
    
    spawn_rotated.emit(new_rotation)
