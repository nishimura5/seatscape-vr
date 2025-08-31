# scripts/autoload/stage_initializer.gd
extends Node

var rooms_data: Dictionary = {}
var npcs_data: Array = []
var meshes_data: Dictionary = {}

func _ready():
    load_json_data()
    EventBus.room_selected.connect(_on_room_selected)
    EventBus.scene_changed.connect(_on_scene_changed)

func _on_scene_changed(scene_name: String):
    if scene_name == "room_selection" or scene_name == "assignment":
        load_json_data()

func load_json_data():
    load_rooms_data()
    load_npcs_data()
    load_meshes_data()

func load_rooms_data():
    var file_manager = FileManager.new()
    rooms_data = file_manager.load_existing_rooms_data()
    if rooms_data.is_empty():
        print("部屋データの読み込みに失敗しました")
        return
    
func load_npcs_data():
    var file_manager = FileManager.new()
    var data = file_manager.load_npcs_data()
    if data.is_empty():
        print("NPCデータの読み込みに失敗しました")
        return
    npcs_data = data.npcs

func load_meshes_data():
    var file_manager = FileManager.new()
    meshes_data = file_manager.load_meshes_data()
    if meshes_data.is_empty():
        print("メッシュデータの読み込みに失敗しました")
        return

func _on_room_selected(room_id: String):
    DataRepository.clear_all_data()
    
    initialize_room_data(room_id)
    initialize_npc_data()
    initialize_default_assignment(room_id)
    EventBus.data_initialized.emit()

func initialize_room_data(room_id: String):
    var room_config = get_room_config(room_id)
    
    var room = RoomRepository.Room.new(
        room_id,
        array_to_vector3(room_config.size),
        array_to_vector3(room_config.player_spawn_position),
        room_config.player_spawn_rotation,
        array_to_vector3(room_config.exit_position),
        room_config.display_name
    )
    
    DataRepository.set_room(room)
    
    for seat_data in room_config.seats:
        var mesh = meshes_data.get(seat_data.mesh_id, Vector3.ONE)
        var size = Vector3(mesh.size[0], mesh.size[1], mesh.size[2])
        var seat = SeatRepository.Seat.new(
            seat_data.id,
            array_to_vector3(seat_data.position),
            size,
            seat_data.rotation,
            seat_data.mesh_id,
            seat_data.display_name
        )
        DataRepository.register_seat(seat)

func initialize_npc_data():
    for npc_data in npcs_data:
        var npc = NpcRepository.Npc.new(
            npc_data.id,
            npc_data.mesh_id,
            npc_data.animation_id,
            npc_data.display_name
        )
        DataRepository.register_npc(npc)

func initialize_default_assignment(room_id: String):
    var room_config = get_room_config(room_id)
    if not room_config.has("default_assignment"):
        print("部屋 ", room_id, " にdefault_assignmentが設定されていません")
        return
    
    var default_assignment = room_config.default_assignment
    var created_npcs = []
    
    print("Default assignment を処理中: ", default_assignment.size(), "件")
    
    for assignment in default_assignment:
        if not assignment.has("seat_id") or not assignment.has("npc_id"):
            print("無効なassignmentデータをスキップ: ", assignment)
            continue
        
        var seat_id = assignment.seat_id
        var npc_id = assignment.npc_id
        
        # 座席の存在確認
        var seat = DataRepository.seat_repository.get_seat(seat_id)
        if not seat:
            print("存在しない座席IDをスキップ: ", seat_id)
            continue
        
        # NPCの存在確認（存在しない場合は作成）
        var npc = DataRepository.npc_repository.get_npc(npc_id)
        if not npc:
            print("NPC ", npc_id, " が見つかりません。新規作成します。")
            npc = create_missing_npc(npc_id)
            if npc:
                DataRepository.register_npc(npc)
                created_npcs.append(npc_id)
            else:
                print("NPC ", npc_id, " の作成に失敗しました")
                continue
        
        # 座席が既に占有されているかチェック
        if DataRepository.is_seat_occupied(seat_id):
            print("座席 ", seat_id, " は既に占有されています。スキップします。")
            continue
        
        # NPCを座席に配置
        DataRepository.assignment_repository.assign_to_seat(npc_id, seat_id)
        print("配置完了: ", npc.display_name, " → ", seat.display_name)
    
    if created_npcs.size() > 0:
        print("  新規作成NPC: ", created_npcs)

func create_missing_npc(npc_id: String) -> NpcRepository.Npc:
    # NPCIDから基本情報を推測して作成
    var display_name = generate_display_name(npc_id)
    var mesh_id = "human_male_01"
    var animation_id = "sitting_idle"  # デフォルトアニメーション
    
    var npc = NpcRepository.Npc.new(
        npc_id,
        mesh_id,
        animation_id,
        display_name
    )
    
    print("新規NPC作成（一時的）: ", npc_id, " (", display_name, ")")
    print("注意: このNPCはnpcs.jsonには保存されません")
    
    return npc

func generate_display_name(npc_id: String) -> String:
    var id_number = npc_id.replace("npc_", "")
    return "参加者" + id_number

func get_room_config(room_id: String) -> Dictionary:
    return rooms_data.get(room_id, {})

func array_to_vector3(array: Array) -> Vector3:
    if array.size() >= 3:
        return Vector3(array[0], array[1], array[2])
    return Vector3.ZERO

func get_available_room_ids() -> Array[String]:
    var result: Array[String] = []
    for room_id in rooms_data.keys():
        result.append(room_id)
    return result

func get_room_display_name(room_id: String) -> String:
    var config = get_room_config(room_id)
    return config.get("display_name", "不明な部屋")

func get_room_info(room_id: String) -> Dictionary:
    var config = get_room_config(room_id)
    if config.is_empty():
        return {}
    
    return {
        "id": room_id,
        "display_name": config.display_name,
        "size": array_to_vector3(config.size),
        "seat_count": config.seats.size()
    }
