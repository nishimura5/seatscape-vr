# scripts/assignment_world.gd
extends Node2D

@onready var room_background: NinePatchRect = $RoomBackground
@onready var pool_background: NinePatchRect = $PoolBackground
@onready var seats_container: Node2D = $SeatsContainer
@onready var npcs_container: Node2D = $NpcsContainer
@onready var preview_image: TextureRect = $PreviewImage
@onready var preview_frame: TextureRect = $PreviewFrame

const SEAT_ICON_SCENE = preload("res://scenes/ui/seat_icon.tscn")
const NPC_ICON_SCENE = preload("res://scenes/ui/npc_icon.tscn")

var room_rect: Rect2
var pool_rect: Rect2
var seat_icons: Dictionary = {}
var npc_icons: Dictionary = {}
var scale_factor: float = 80.0  # 1m = 80px
var current_room: RoomRepository.Room
var room_elements: Dictionary = {}
var spawn_icon_selected: bool = false
var room_size_icon_selected: bool = false

var grid_manager: GridManager
# Pool位置管理 - NPCのIDベースでの一対一対応
var npc_id_to_pool_index: Dictionary = {}
var pool_positions: Array[Vector2] = []

# all mesh_id
var preview_image_file_names: Array
# table seat_id and mesh_id
var preview_dict: Dictionary = {}

func _ready():
    var file = FileAccess.open("res://data/configs/meshes.json", FileAccess.READ)
    if file:
        var json = JSON.new()
        var result = json.parse(file.get_as_text())
        if result == OK:
            for key in json.get_data().keys():
                preview_image_file_names.append(key)
        file.close()
    print("Loaded preview image file names: ", preview_image_file_names)

    grid_manager = GridManager.new()

func setup_room(room: RoomRepository.Room, seats: Array[SeatRepository.Seat], pool_npc_ids: Array[String]):
    current_room = room
    
    # コンテナのリサイズ信号に接続
    var container = get_parent()
    if container and container.has_signal("resized"):
        if not container.resized.is_connected(_on_container_resized):
            container.resized.connect(_on_container_resized)
    
    calculate_layout(room, pool_npc_ids.size())
    setup_backgrounds()
    setup_pool_system(pool_npc_ids)
    setup_preview()
    create_room_elements(room)
    create_seat_icons(seats)
    create_all_npc_icons(pool_npc_ids)
    restore_existing_assignments()

    grid_manager.create_grid(self, room_rect, scale_factor)


func setup_pool_system(pool_npc_ids: Array[String]):
    """Pool位置システムの初期化 - NPCごとに固定位置を割り当て"""
    pool_positions.clear()
    npc_id_to_pool_index.clear()
    
    var all_npcs = DataRepository.npc_repository.get_all_npcs()
    var total_npc_count = all_npcs.size()
    
    var cols = 4
    for i in range(total_npc_count):
        var npc = all_npcs[i]
        npc_id_to_pool_index[npc.id] = i
        
        var col = i % cols
        var row = i / cols
        var pool_pos = Vector2(col * 70 + 45, row * 70 + 45)
        var screen_pos = pool_rect.position + pool_pos
        
        pool_positions.append(screen_pos)

func setup_preview():
    """previewの位置決め、poolの下に配置"""
    preview_image.position = pool_rect.position + Vector2(25, pool_rect.size.y+25)
    preview_frame.position = pool_rect.position + Vector2(20, pool_rect.size.y)

func get_npc_pool_position(npc_id: String) -> Vector2:
    """NPCの固定pool位置を取得"""
    var pool_index = npc_id_to_pool_index.get(npc_id, -1)
    if pool_index == -1 or pool_index >= pool_positions.size():
        print("警告: NPC ", npc_id, " のpool位置が見つかりません")
        return Vector2.ZERO
    
    return pool_positions[pool_index]

func _on_container_resized():
    # コンテナサイズが変更されたときにレイアウトを再計算
    if current_room:
        var pool_npc_count = DataRepository.get_pool_npc_ids().size()
        calculate_layout(current_room, pool_npc_count)
        setup_backgrounds()
        refresh_all_npc_positions()

func refresh_all_npc_positions():
    """全てのNPCの位置を現在のアサインメント状態に基づいて更新"""
    print("NPCポジションのリフレッシュを開始...")
    
    # 全ての座席アイコンを空席状態にリセット
    for seat_icon in seat_icons.values():
        if seat_icon.has_method("set_occupied"):
            seat_icon.set_occupied(false)
    
    # プールにいるNPC - 各NPCを固定のpool位置に配置
    var pool_npc_ids = DataRepository.get_pool_npc_ids()
    for npc_id in pool_npc_ids:
        var npc_icon = npc_icons.get(npc_id)
        if npc_icon:
            npc_icon.position = get_npc_pool_position(npc_id)
            npc_icon.rotation_degrees = 0.0
    
    # 座席に配置されているNPC
    var seated_npc_ids = DataRepository.assignment_repository.get_seated_npc_ids()
    for npc_id in seated_npc_ids:
        var seat_id = DataRepository.get_npc_seat_id(npc_id)
        var npc_icon = npc_icons.get(npc_id)
        var seat_icon = seat_icons.get(seat_id)
        
        if npc_icon and seat_icon:
            # 座席位置に移動
            npc_icon.position = seat_icon.position
            npc_icon.rotation_degrees = seat_icon.rotation_degrees
            
            # 座席を占有状態に設定
            if seat_icon.has_method("set_occupied"):
                seat_icon.set_occupied(true)
    
    print("NPCポジションのリフレッシュ完了: プール", pool_npc_ids.size(), "名, 着席", seated_npc_ids.size(), "名")

func move_npc_icon_to_pool(npc_id: String):
    """NPCアイコンを固定のpool位置に移動"""
    var npc_icon = npc_icons.get(npc_id)
    if not npc_icon:
        return
    
    var target_position = get_npc_pool_position(npc_id)
    if target_position == Vector2.ZERO:
        return
    
    # アニメーション付きで移動
    var tween = create_tween()
    tween.tween_property(npc_icon, "position", target_position, 0.3)
    tween.parallel().tween_property(npc_icon, "rotation_degrees", 0.0, 0.3)

func create_pool_npc_icons(npc_ids: Array[String]):
    """プールにいるNPCのアイコンを作成"""
    for npc_id in npc_ids:
        var npc_icon = create_npc_icon_in_pool(npc_id)
        if npc_icon:
            npcs_container.add_child(npc_icon)
            npc_icons[npc_id] = npc_icon

func create_npc_icon_in_pool(npc_id: String) -> Sprite2D:
    """プール内でのNPCアイコンを作成"""
    var npc_icon = NPC_ICON_SCENE.instantiate()
    var npc = DataRepository.npc_repository.get_npc(npc_id)
    
    if not npc:
        return null
    
    # NPCの固定pool位置を設定
    npc_icon.position = get_npc_pool_position(npc_id)
    
    if npc_icon.has_method("setup_npc"):
        npc_icon.setup_npc(npc)
    
    # テクスチャ読み込みを確実に実行
    ensure_npc_texture_loaded(npc_icon)
    
    return npc_icon

func calculate_layout(room: RoomRepository.Room, npc_count: int):
    # AssignmentWorldContainerのサイズを取得（70%の領域）
    var container = get_parent() # AssignmentWorldContainer
    var container_size = container.size if container.size != Vector2.ZERO else get_viewport().get_visible_rect().size * Vector2(0.7, 1.0)
    
    var available_width = container_size.x - 100
    var available_height = container_size.y - 100
    
    var room_size = Vector2(room.size.x * scale_factor, room.size.z * scale_factor)
    
    var pool_cols = min(npc_count, 4)
    var pool_rows = ceili(float(npc_count) / pool_cols)
    var pool_size = Vector2(pool_cols * 80 + 40, pool_rows * 80 + 40)
    
    var start_x = (container_size.x - room_size.x - pool_size.x - 40) / 2
    var start_y = (available_height - max(room_size.y, pool_size.y)) / 2 + 50
    
    room_rect = Rect2(start_x, start_y, room_size.x, room_size.y)
    pool_rect = Rect2(start_x + room_size.x + 40, start_y, pool_size.x, pool_size.y)

func setup_backgrounds():
    setup_nine_patch_rect(room_background, room_rect, Color(0.9, 0.9, 0.9, 0.8))
    setup_nine_patch_rect(pool_background, pool_rect, Color(0.7, 0.9, 1.0, 0.8))

func setup_nine_patch_rect(nine_patch: NinePatchRect, rect: Rect2, color: Color):
    nine_patch.position = rect.position
    nine_patch.size = rect.size
    nine_patch.modulate = color

func create_room_elements(room: RoomRepository.Room):
    clear_room_elements()
    create_spawn_point_indicator(room.player_spawn_position, room.player_spawn_rotation)
    create_exit_point_indicator(room.exit_position)
    create_room_outline()
    create_room_info_label(room)
    create_room_right_bottom(room.size.x, room.size.z)

func create_spawn_point_indicator(spawn_pos: Vector3, spawn_rotation: float):
    var spawn_icon = Sprite2D.new()
    var spawn_texture = create_spawn_texture()
    spawn_icon.texture = spawn_texture
    
    var world_pos = Vector2(spawn_pos.x, spawn_pos.z) * scale_factor

    spawn_icon.position = room_rect.position + world_pos
    spawn_icon.rotation_degrees = spawn_rotation
    spawn_icon.modulate = Color.WHITE
    
    # クリック可能にする（以下を追加）
    var area = Area2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(30, 30)
    collision.shape = shape
    
    area.add_child(collision)
    spawn_icon.add_child(area)
    
    add_child(spawn_icon)
    room_elements["spawn_point"] = spawn_icon

func create_room_right_bottom(room_width: float, room_depth: float):
    var size_icon = Sprite2D.new()
    var size_texture = create_room_size_texture()
    size_icon.texture = size_texture

    var world_pos = Vector2(room_width, room_depth) * scale_factor
    size_icon.position = room_rect.position + world_pos
    size_icon.modulate = Color.WHITE

    var area = Area2D.new()
    var collision = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(30, 30)
    collision.shape = shape
    
    area.add_child(collision)
    size_icon.add_child(area)
    
    add_child(size_icon)
    room_elements["room_size"] = size_icon

func create_exit_point_indicator(exit_pos: Vector3):
    var exit_icon = Sprite2D.new()
    var exit_texture = create_exit_texture()
    exit_icon.texture = exit_texture
    
    var world_pos = Vector2(exit_pos.x, exit_pos.z) * scale_factor
    var screen_pos = room_rect.position + world_pos
    
    exit_icon.position = screen_pos
    exit_icon.modulate = Color.RED
    
    add_child(exit_icon)
    room_elements["exit_point"] = exit_icon
    
    var exit_label = Label.new()
    exit_label.text = "出口"
    exit_label.position = screen_pos + Vector2(-20, 25)
    exit_label.add_theme_color_override("font_color", Color.RED)
    add_child(exit_label)
    room_elements["exit_label"] = exit_label
    # hide exit icons
    exit_icon.visible = false
    exit_label.visible = false

func create_room_outline():
    var outline = Line2D.new()
    outline.width = 2.0
    outline.default_color = Color.WHITE
    outline.closed = true
    
    outline.add_point(Vector2(0, 0))
    outline.add_point(Vector2(room_rect.size.x, 0))
    outline.add_point(Vector2(room_rect.size.x, room_rect.size.y))
    outline.add_point(Vector2(0, room_rect.size.y))
    
    outline.position = room_rect.position
    add_child(outline)
    room_elements["room_outline"] = outline

func create_room_info_label(room: RoomRepository.Room):
    var info_label = Label.new()
    info_label.text = "%s (%.1f×%.1fm)" % [room.display_name, room.size.x, room.size.z]
    info_label.position = room_rect.position + Vector2(0, -60)
    info_label.add_theme_color_override("font_color", Color.WHITE)
    info_label.add_theme_font_size_override("font_size", 28)
    
    add_child(info_label)
    room_elements["room_info"] = info_label

func create_room_size_texture() -> Texture2D:
    var image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
        
    # 小さな正方形を描画
    for y in range(20):
        for x in range(20):
            image.set_pixel(x, y, Color.WHITE)
    
    var texture = ImageTexture.new()
    texture.set_image(image)
    return texture

func create_spawn_texture() -> Texture2D:
    var image = Image.create(30, 30, false, Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    
    for y in range(30):
        for x in range(30):
            var center_x = 15
            var base_y = 25
            var tip_y = 5
            
            if y >= tip_y and y <= base_y:
                var width_at_y = (y - tip_y) * center_x / (base_y - tip_y)
                if x >= center_x - width_at_y and x <= center_x + width_at_y:
                    image.set_pixel(x, y, Color.WHITE)
    
    var texture = ImageTexture.new()
    texture.set_image(image)
    return texture

func create_exit_texture() -> Texture2D:
    var image = Image.create(25, 25, false, Image.FORMAT_RGB8)
    image.fill(Color.WHITE)
    
    var texture = ImageTexture.new()
    texture.set_image(image)
    return texture

func clear_room_elements():
    for element in room_elements.values():
        if element and is_instance_valid(element):
            element.queue_free()
    room_elements.clear()

func create_seat_icons(seats: Array[SeatRepository.Seat]):
    for seat in seats:
        var seat_icon = create_seat_icon(seat)
        seats_container.add_child(seat_icon)
        seat_icons[seat.id] = seat_icon
        add_preview_image_name(seat)

func create_seat_icon(seat: SeatRepository.Seat) -> Sprite2D:
    var seat_icon = SEAT_ICON_SCENE.instantiate()
    
    var world_pos = Vector2(seat.position.x, seat.position.z) * scale_factor
    var screen_pos = room_rect.position + world_pos

    seat_icon.position = round_to_decimal(screen_pos)
    seat_icon.rotation_degrees = -seat.rotation_degrees
    seat_icon.width = seat.size.x * scale_factor
    seat_icon.height = seat.size.z * scale_factor

    if seat_icon.has_method("setup_seat"):
        seat_icon.setup_seat(seat)
    return seat_icon

func add_preview_image_name(seat: SeatRepository.Seat):
    preview_dict[seat.id] = seat.mesh_id

func get_preview_image_name(seat_id: String) -> String:
    return preview_dict.get(seat_id, "")

func set_room_size_move_mode(move_mode: bool):
    room_size_icon_selected = move_mode
    var size_icon = room_elements.get("room_size")
    if size_icon:
        if move_mode:
            size_icon.modulate = Color.YELLOW  # selected
        else:
            size_icon.modulate = Color.WHITE  # unselected

func update_room_size(new_width: float, new_depth: float):
    var size_icon = room_elements.get("room_size")

    var world_pos = Vector2(new_width, new_depth) * scale_factor
    var screen_pos = room_rect.position + world_pos

    size_icon.position = screen_pos
    
    update_room_outline(new_width, new_depth)

    var new_room_size = Vector2(new_width, new_depth) * scale_factor
    var updated_room_rect = Rect2(room_rect.position, new_room_size)
    grid_manager.regenerate_grid(self, updated_room_rect, scale_factor)

func update_room_outline(new_width: float, new_depth: float):
    var outline = room_elements.get("room_outline")
    if outline:
        outline.clear_points()
        var new_size = Vector2(new_width, new_depth) * scale_factor
        outline.add_point(Vector2(0, 0))
        outline.add_point(Vector2(new_size.x, 0))
        outline.add_point(Vector2(new_size.x, new_size.y))
        outline.add_point(Vector2(0, new_size.y))
        outline.position = room_rect.position

func create_all_npc_icons(pool_npc_ids: Array[String]):
    create_pool_npc_icons(pool_npc_ids)
    create_seated_npc_icons()

func create_seated_npc_icons():
    """座席に配置されているNPCのアイコンを作成"""
    var seated_npc_ids = DataRepository.assignment_repository.get_seated_npc_ids()
    for npc_id in seated_npc_ids:
        # 既にプールでアイコンが作成されている場合はスキップ
        if npc_icons.has(npc_id):
            continue
            
        var npc_icon = create_npc_icon_for_seat(npc_id)
        if npc_icon:
            npcs_container.add_child(npc_icon)
            npc_icons[npc_id] = npc_icon

func create_npc_icon_for_seat(npc_id: String) -> Sprite2D:
    """座席配置用のNPCアイコンを作成（初期位置は座席位置）"""
    var npc_icon = NPC_ICON_SCENE.instantiate()
    var npc = DataRepository.npc_repository.get_npc(npc_id)
    
    if not npc:
        return null
    
    npc_icon.position = Vector2.ZERO
    
    if npc_icon.has_method("setup_npc"):
        npc_icon.setup_npc(npc)
    
    # テクスチャ読み込みを確実に実行
    ensure_npc_texture_loaded(npc_icon)
    
    return npc_icon

func restore_existing_assignments():
    """既存の配置を復元（default_assignmentとユーザー配置の両方を含む）"""
    var all_assignments = DataRepository.assignment_repository.get_all_assignments()
    var restored_count = 0
    
    print("配置復元を開始: ", all_assignments.size(), "件の配置情報")
    
    for assignment in all_assignments:
        if assignment.is_empty() or assignment.is_in_pool():
            continue
        
        var npc_icon = npc_icons.get(assignment.npc_id)
        var seat_icon = seat_icons.get(assignment.seat_id)
        
        if npc_icon and seat_icon:
            # NPCアイコンを座席位置に移動
            npc_icon.position = seat_icon.position
            npc_icon.rotation_degrees = seat_icon.rotation_degrees
            
            # 座席を占有状態に設定
            if seat_icon.has_method("set_occupied"):
                seat_icon.set_occupied(true)
            
            restored_count += 1
            
            var npc = DataRepository.npc_repository.get_npc(assignment.npc_id)
            var seat = DataRepository.seat_repository.get_seat(assignment.seat_id)
            if npc and seat:
                print("配置復元: ", npc.display_name, " → ", seat.display_name)
    
    print("配置復元完了: ", restored_count, "件")

func highlight_seat(seat_id: String, highlight: bool):
    var seat_icon = seat_icons.get(seat_id)
    if seat_icon and seat_icon.has_method("set_highlight"):
        seat_icon.set_highlight(highlight)

func set_seat_move_mode(seat_id: String, move_mode: bool):
    var seat_icon = seat_icons.get(seat_id)
    if seat_icon and seat_icon.has_method("set_move_mode"):
        seat_icon.set_move_mode(move_mode)

func set_spawn_move_mode(move_mode: bool):
    spawn_icon_selected = move_mode
    var spawn_icon = room_elements.get("spawn_point")
    if spawn_icon:
        if move_mode:
            spawn_icon.modulate = Color.YELLOW  # selected
        else:
            spawn_icon.modulate = Color.WHITE # unselected

func clear_all_highlights():
    for seat_icon in seat_icons.values():
        if seat_icon.has_method("set_highlight"):
            seat_icon.set_highlight(false)

func clear_all_move_modes():
    for seat_icon in seat_icons.values():
        if seat_icon.has_method("set_move_mode"):
            seat_icon.set_move_mode(false)
    clear_spawn_move_mode()
    clear_room_size_move_mode()

func clear_spawn_move_mode():
    set_spawn_move_mode(false)

func clear_room_size_move_mode():
    set_room_size_move_mode(false)

func update_seat_position(seat_id: String, new_position: Vector3):
    var seat_icon = seat_icons.get(seat_id)
    var world_pos = Vector2(new_position.x, new_position.z) * scale_factor
    seat_icon.position = round_to_decimal(room_rect.position + world_pos)

func update_seat_rotation(seat_id: String, new_rotation: float):
    var seat_icon = seat_icons.get(seat_id)
    if seat_icon:
        seat_icon.rotation_degrees = -new_rotation

func update_spawn_position(new_position: Vector3):
    """spawn地点の位置更新"""
    var spawn_icon = room_elements.get("spawn_point")
    var world_pos = Vector2(new_position.x, new_position.z) * scale_factor
    var screen_pos = room_rect.position + world_pos
    spawn_icon.position = screen_pos

func update_spawn_rotation(new_rotation: float):
    """spawn地点の回転更新"""
    var spawn_icon = room_elements.get("spawn_point")
    spawn_icon.rotation_degrees = new_rotation

func is_position_in_pool(pos: Vector2) -> bool:
    return pool_rect.has_point(pos)

func clear_all_visual_elements():
    for seat_id in seat_icons.keys():
        var seat_icon = seat_icons[seat_id]
        if seat_icon and is_instance_valid(seat_icon):
            seat_icon.queue_free()
    seat_icons.clear()
    
    for npc_id in npc_icons.keys():
        var npc_icon = npc_icons[npc_id]
        if npc_icon and is_instance_valid(npc_icon):
            npc_icon.queue_free()
    npc_icons.clear()
    
    clear_room_elements()

func ensure_npc_texture_loaded(npc_icon: Sprite2D):
    """NPCアイコンのテクスチャ読み込みを確実に実行"""
    if not npc_icon:
        return
    
    # フレーム後にシーンツリーに追加された後にテクスチャ読み込みを実行
    call_deferred("_deferred_texture_load", npc_icon)

func _deferred_texture_load(npc_icon: Sprite2D):
    """遅延実行でテクスチャ読み込みを行う"""
    if npc_icon and is_instance_valid(npc_icon) and npc_icon.has_method("force_reload_texture"):
        npc_icon.force_reload_texture()

func round_to_decimal(value: Vector2) -> Vector2:
    return Vector2(round(value.x), round(value.y))
