# scripts/assignment.gd
extends Control

@onready var assignment_world: Node2D = $HBoxContainer/AssignmentWorldContainer/AssignmentWorld
@onready var start_seating_button: Button = $HBoxContainer/MarginContainer/UIControls/StartSeatingButton
@onready var back_button: Button = $HBoxContainer/MarginContainer/UIControls/BackButton
@onready var save_button: Button = $HBoxContainer/MarginContainer/UIControls/SaveButton
@onready var clear_button: Button = $HBoxContainer/MarginContainer/UIControls/ClearButton
@onready var drag_preview: Control = $DragPreview
@onready var drag_npc_sprite: Sprite2D = $DragPreview/DragNpcSprite

# マネージャー
var seat_manager: SeatManager
var spawn_manager: SpawnManager
var room_size_manager: RoomSizeManager

# ドラッグ関連の状態管理
var is_dragging: bool = false
var dragged_npc_id: String = ""
var drag_start_position: Vector2
const DRAG_THRESHOLD: float = 5.0

func _ready():
    _initialize_managers()
    _setup_ui()
    _setup_connections()
    _initialize_room_data()

func _initialize_managers():
    """マネージャークラスの初期化"""
    seat_manager = SeatManager.new()
    spawn_manager = SpawnManager.new()
    room_size_manager = RoomSizeManager.new()

func _setup_ui():
    """UI要素の初期設定"""
    start_seating_button.text = "Enter"
    back_button.text = "Back"
    save_button.text = "Save"
    clear_button.text = "Clear"
    
    start_seating_button.disabled = false
    drag_preview.visible = false

func _setup_connections():
    """シグナル接続の設定"""
    # UIボタン
    start_seating_button.pressed.connect(_on_start_seating_pressed)
    back_button.pressed.connect(_on_back_pressed)
    save_button.pressed.connect(_on_save_pressed)
    clear_button.pressed.connect(_on_clear_pressed)
    
    # イベントバス
    EventBus.data_initialized.connect(_on_data_initialized)
    
    # マネージャー
    seat_manager.seat_moved.connect(_on_seat_moved)
    seat_manager.seat_rotated.connect(_on_seat_rotated)
    spawn_manager.spawn_moved.connect(_on_spawn_moved)
    spawn_manager.spawn_rotated.connect(_on_spawn_rotated)
    room_size_manager.room_size_changed.connect(_on_room_size_changed)

func _initialize_room_data():
    """部屋データの初期化"""
    var current_room = DataRepository.room_repository.get_current_room()
    if current_room:
        _perform_room_setup()

func _perform_room_setup():
    """実際の部屋セットアップ処理"""
    var current_room = DataRepository.room_repository.get_current_room()
    if not current_room:
        EventBus.ui_status_updated.emit("部屋データが見つかりません")
        return

    # フレーム待機でレイアウト安定化
    await get_tree().process_frame
    
    var room_seats = DataRepository.seat_repository.get_all_seats()
    var pool_npcs = DataRepository.get_pool_npc_ids()
    
    assignment_world.setup_room(current_room, room_seats, pool_npcs)

# =============================================================================
# 入力処理
# =============================================================================

func _input(event):
    # ドラッグ処理を最優先
    if _handle_drag_input(event):
        return
    
    # 優先順位に従って入力を処理
    if room_size_manager.handle_input(event):
        return
    if spawn_manager.handle_input(event):
        return
    if seat_manager.handle_input(event):
        return

func _handle_drag_input(event: InputEvent) -> bool:
    """ドラッグ関連の入力処理"""
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                return _try_start_drag(event.position)
            else:
                _end_drag(event.position)
                return is_dragging or not dragged_npc_id.is_empty()
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            return _handle_right_click(event.position)
    
    elif event is InputEventMouseMotion and (is_dragging or not dragged_npc_id.is_empty()):
        _handle_mouse_motion(event)
        return true
    
    return false

func _handle_right_click(pos: Vector2) -> bool:
    var npc_id = _get_npc_at_position(pos)
    if npc_id.is_empty():
        return false
    
    # NPCが座席にいる場合のみプールに戻す
    var seat_id = DataRepository.get_npc_seat_id(npc_id)
    if not seat_id.is_empty():
        move_npc_to_pool(npc_id)
        EventBus.npc_moved_to_pool.emit(npc_id)
        return true
    
    return false

func _handle_mouse_motion(event: InputEventMouseMotion):
    """マウス移動イベントの処理"""
    if is_dragging:
        _update_drag(event.position)
    elif not dragged_npc_id.is_empty():
        var distance = drag_start_position.distance_to(event.position)
        if distance > DRAG_THRESHOLD:
            _start_drag(event.position)

func _try_start_drag(pos: Vector2) -> bool:
    """ドラッグ開始の試行"""
    if not assignment_world:
        return false
    
    # 優先順位: spawn > seat > room_size > npc
    if _is_position_on_element(pos, "spawn_point"):
        _handle_spawn_click()
        return true
    
    var seat_id = _get_seat_at_position(pos)
    if not seat_id.is_empty():
        _handle_seat_click(seat_id)
        return true
    
    if _is_position_on_element(pos, "room_size"):
        _handle_room_size_click()
        return true

    # NPCドラッグの確認
    var npc_id = _get_npc_at_position(pos)
    if npc_id.is_empty():
        return false
    
    _deselect_all()
    dragged_npc_id = npc_id
    drag_start_position = pos
    return true

func _start_drag(current_pos: Vector2):
    """ドラッグ開始処理"""
    if dragged_npc_id.is_empty():
        return
    
    is_dragging = true
    _setup_drag_preview(dragged_npc_id, current_pos)
    
    var npc_icon = assignment_world.npc_icons.get(dragged_npc_id)
    if npc_icon:
        npc_icon.visible = false

func _setup_drag_preview(npc_id: String, pos: Vector2):
    """ドラッグプレビューの設定"""
    var original_npc_icon = assignment_world.npc_icons.get(npc_id)
    if not original_npc_icon:
        return
    
    drag_preview.visible = true
    drag_preview.position = pos - Vector2(20, 20)
    
    drag_npc_sprite.rotation_degrees = 0.0
    drag_npc_sprite.texture = original_npc_icon.texture
    drag_npc_sprite.modulate = original_npc_icon.modulate

func _update_drag(pos: Vector2):
    """ドラッグ中の更新処理"""
    drag_preview.position = pos
    _update_drop_hints(pos)

func _update_drop_hints(pos: Vector2):
    """ドロップヒントの更新"""
    if not assignment_world:
        return
    
    var seat_id = _get_seat_at_position(pos)
    if not seat_id.is_empty() and not DataRepository.is_seat_occupied(seat_id):
        _highlight_seat(seat_id, true)
    else:
        _clear_all_highlights()

func _end_drag(pos: Vector2):
    """ドラッグ終了処理"""
    var was_dragging = is_dragging
    is_dragging = false
    drag_preview.visible = false
    _clear_all_highlights()

    var npc_icon = assignment_world.npc_icons.get(dragged_npc_id)
    if npc_icon:
        npc_icon.visible = true
        npc_icon.position = pos
    
    if was_dragging:
        _handle_drop(pos)
    
    dragged_npc_id = ""

func _handle_drop(pos: Vector2):
    """ドロップ処理"""
    if not assignment_world or dragged_npc_id.is_empty():
        return
    
    var seat_id = _get_seat_at_position(pos)
    
    if not seat_id.is_empty() and not DataRepository.is_seat_occupied(seat_id):
        if move_npc_to_seat(dragged_npc_id, seat_id):
            EventBus.npc_moved_to_seat.emit(dragged_npc_id, seat_id)
    else:
        move_npc_to_pool(dragged_npc_id)
        EventBus.npc_moved_to_pool.emit(dragged_npc_id)

func move_npc_to_pool(npc_id: String):
    """NPCをプールに移動する - ロジック処理"""
    var old_seat_id = DataRepository.get_npc_seat_id(npc_id)
    DataRepository.assignment_repository.assign_to_pool(npc_id)
    
    if not old_seat_id.is_empty():
        _clear_seat_occupation(old_seat_id)
    
    _update_npc_visual_position(npc_id)
    

func move_npc_to_seat(npc_id: String, seat_id: String):
    """NPCを座席に移動する - ロジック処理"""
    if DataRepository.is_seat_occupied(seat_id):
        print("座席 ", seat_id, " は既に占有されています")
        return false
    
    DataRepository.assignment_repository.assign_to_seat(npc_id, seat_id)
    
    _set_seat_occupation(seat_id, true)
    
    _update_npc_visual_position(npc_id)
    
    
    return true

# =============================================================================
# 位置判定ヘルパーメソッド
# =============================================================================

func _get_seat_at_position(pos: Vector2) -> String:
    """指定位置の座席IDを取得"""
    if not assignment_world:
        return ""
    
    for seat_id in assignment_world.seat_icons.keys():
        var seat_icon = assignment_world.seat_icons[seat_id]
        if _is_point_in_sprite(pos, seat_icon):
            return seat_id
    return ""

func _is_point_in_sprite(point: Vector2, sprite: Sprite2D) -> bool:
    """標準的な点とスプライトの当たり判定 - Godot標準機能を使用"""
    var texture_size = Vector2(40, 20)
    if sprite.texture:
        texture_size = sprite.texture.get_size()
    
    var sprite_rect = Rect2(sprite.position - texture_size * 0.5, texture_size)
    return sprite_rect.has_point(point)

func _is_position_on_element(pos: Vector2, element_name: String) -> bool:
    """要素上の位置判定"""
    var element = assignment_world.room_elements.get(element_name)
    if not element:
        return false
    
    var element_size = Vector2(30, 30) if element_name == "spawn_point" else Vector2(20, 20)
    var element_rect = Rect2(element.position - element_size * 0.5, element_size)
    return element_rect.has_point(pos)

func _get_npc_at_position(pos: Vector2) -> String:
    """指定位置のNPC IDを取得"""
    if not assignment_world:
        return ""
    
    for npc_id in assignment_world.npc_icons.keys():
        var npc_icon = assignment_world.npc_icons[npc_id]
        if not npc_icon.visible:
            continue
            
        var texture_size = Vector2(40, 40)
        if npc_icon.texture:
            texture_size = npc_icon.texture.get_size()
        
        var npc_rect = Rect2(npc_icon.position - texture_size * 0.5, texture_size)
        if npc_rect.has_point(pos):
            return npc_id
    return ""

func _highlight_seat(seat_id: String, available: bool):
    """座席のハイライト表示"""
    _clear_all_highlights()
    var seat_icon = assignment_world.seat_icons.get(seat_id)
    if seat_icon and seat_icon.has_method("set_highlight"):
        seat_icon.set_highlight(available)

func _clear_all_highlights():
    """全てのハイライト表示をクリア"""
    if not assignment_world:
        return
    for seat_icon in assignment_world.seat_icons.values():
        if seat_icon.has_method("set_highlight"):
            seat_icon.set_highlight(false)

# =============================================================================
# クリックハンドラー
# =============================================================================

func _handle_seat_click(seat_id: String):
    """席がクリックされた時の処理"""
    _deselect_all()
    if seat_manager.select_seat(seat_id):
        assignment_world.clear_all_move_modes()
        assignment_world.set_seat_move_mode(seat_id, true)
        # load image from res/data/3d_previews/<seat_id>.png
        var preview_name = assignment_world.get_preview_image_name(seat_id)
        var preview_path = "res://data/3d_previews/%s.png" % preview_name
        assignment_world.preview_image.texture = load(preview_path)
        assignment_world.preview_image.visible = true

func _handle_spawn_click():
    """スポーン地点がクリックされた時の処理"""
    _deselect_all()
    spawn_manager.select_spawn()
    assignment_world.set_spawn_move_mode(true)

func _handle_room_size_click():
    """部屋サイズアイコンがクリックされた時の処理"""
    _deselect_all()
    room_size_manager.select_room_size()
    assignment_world.set_room_size_move_mode(true)

# =============================================================================
# イベントハンドラー
# =============================================================================

func _on_data_initialized():
    """データ初期化完了時の処理"""
    _perform_room_setup()

func _on_start_seating_pressed():
    """着席シーンに遷移"""
    GameStateManager.transition_to(GameStateManager.GameState.SEATING)

func _on_back_pressed():
    """部屋選択画面に戻る"""
    _cleanup_and_return_to_selection()

func _on_save_pressed():
    """部屋データを保存"""
    var file_manager = FileManager.new()
    file_manager.save_rooms_data()

func _on_clear_pressed():
    """全ての配置をクリア"""
    _clear_all_assignments()

func _on_seat_moved(seat_id: String, new_position: Vector3):
    """席が移動した時の処理"""
    assignment_world.update_seat_position(seat_id, new_position)

func _on_seat_rotated(seat_id: String, new_rotation: float):
    """席が回転した時の処理"""
    assignment_world.update_seat_rotation(seat_id, new_rotation)

func _on_spawn_moved(new_position: Vector3):
    """スポーン地点が移動した時の処理"""
    assignment_world.update_spawn_position(new_position)

func _on_spawn_rotated(new_rotation: float):
    """スポーン地点が回転した時の処理"""
    assignment_world.update_spawn_rotation(new_rotation)

func _on_room_size_changed(new_width: float, new_depth: float):
    """部屋サイズが変更された時の処理"""
    assignment_world.update_room_size(new_width, new_depth)
    
    # 部屋情報ラベルも更新
    var current_room = DataRepository.room_repository.get_current_room()
    var info_label = assignment_world.room_elements.get("room_info")
    if info_label:
        info_label.text = "%s (%.1f×%.1fm)" % [current_room.display_name, new_width, new_depth]

# =============================================================================
# ユーティリティメソッド
# =============================================================================

func _deselect_all():
    """全ての選択状態を解除"""
    seat_manager.deselect_seat()
    spawn_manager.deselect_spawn()
    room_size_manager.deselect_room_size()
    assignment_world.clear_all_move_modes()
    assignment_world.clear_all_highlights()

func _clear_all_assignments():
    """全てのNPC配置をクリア"""
    var seated_npcs = DataRepository.assignment_repository.get_seated_npc_ids().duplicate()
    
    for npc_id in seated_npcs:
        DataRepository.assignment_repository.assign_to_pool(npc_id)
    
    if assignment_world and assignment_world.has_method("refresh_all_npc_positions"):
        assignment_world.refresh_all_npc_positions()
    

func _cleanup_and_return_to_selection():
    """クリーンアップして部屋選択画面に戻る"""
    assignment_world.clear_all_visual_elements()
    DataRepository.clear_all_data()
    GameStateManager.transition_to(GameStateManager.GameState.ROOM_SELECTION)

# =============================================================================
# ビュー更新ヘルパーメソッド
# =============================================================================

func _update_npc_visual_position(npc_id: String):
    """NPCの視覚的位置を更新"""
    var npc_icon = assignment_world.npc_icons.get(npc_id)
    if not npc_icon:
        return
    
    var seat_id = DataRepository.get_npc_seat_id(npc_id)
    
    if seat_id.is_empty():
        _move_npc_icon_to_pool(npc_id)
    else:
        _move_npc_icon_to_seat(npc_id, npc_icon, seat_id)

func _move_npc_icon_to_pool(npc_id: String):
    """NPCアイコンを固定pool位置に移動"""
    if not assignment_world:
        return
        
    assignment_world.move_npc_icon_to_pool(npc_id)

func _move_npc_icon_to_seat(npc_id: String, npc_icon: Sprite2D, seat_id: String):
    """NPCアイコンを座席位置に移動"""
    var seat_icon = assignment_world.seat_icons.get(seat_id)
    if not seat_icon:
        return

    var tween = create_tween()
    tween.tween_property(npc_icon, "position", seat_icon.position, 0.3).from_current()
    tween.parallel().tween_property(npc_icon, "rotation_degrees", seat_icon.rotation_degrees, 0.3)

func _set_seat_occupation(seat_id: String, occupied: bool):
    """座席の占有状態を設定"""
    var seat_icon = assignment_world.seat_icons.get(seat_id)
    if seat_icon and seat_icon.has_method("set_occupied"):
        seat_icon.set_occupied(occupied)

func _clear_seat_occupation(seat_id: String):
    """座席の占有状態をクリア"""
    _set_seat_occupation(seat_id, false)
