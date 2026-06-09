# scripts/file_manager.gd
class_name FileManager
extends RefCounted

const ROOMS_DATA_PATH = "configs/rooms.json"
const MESHES_DATA_PATH = "configs/meshes.json"
const NPCS_DATA_PATH = "configs/npcs.json"
const NARRATIVE_DATA_PATH = "configs/narrative_data.json"
const DIALOGS_DATA_PATH = "configs/dialogs.json"
const SELECTION_DATA_PATH = "configs/selection.json"

func save_rooms_data() -> bool:
    # 既存のrooms.jsonを読み込み
    var existing_data = load_existing_rooms_data()
    if existing_data.is_empty():
        print("既存データの読み込みに失敗しました")
        return false
    
    # 現在の部屋データのみを更新
    var current_room_data = build_current_room_data()
    var current_room = DataRepository.room_repository.get_current_room()
    if not current_room or current_room_data.is_empty():
        print("現在の部屋データの構築に失敗しました")
        return false
    
    # 既存データに現在の部屋データをマージ
    existing_data[current_room.id] = current_room_data
    
    # ファイルに保存
    var json_string = JSON.stringify(existing_data, "\t")
    json_string = format_position_arrays(json_string)
    
    var rooms_path = Main.get_data_path(ROOMS_DATA_PATH)
    var file = FileAccess.open(rooms_path, FileAccess.WRITE)
    if not file:
        print("ファイルを開けませんでした: ", rooms_path)
        return false
    
    file.store_string(json_string)
    file.close()
    
    print("rooms.json ファイルを保存しました（", current_room.id, "のみ更新）")
    return true

func format_position_arrays(json_string: String) -> String:
    var regex = RegEx.new()
    regex.compile("\\[\n\\t+([0-9.-]+),\n\\t+([0-9.-]+),\n\\t+([0-9.-]+)\n\\t+\\]")
    var result = regex.sub(json_string, "[$1, $2, $3]", true)

    regex.compile("\"display_name\": \"(.*?)\",\n\\s+\"id\": \"(.*?)\"")
    result = regex.sub(result, "\"display_name\": \"$1\", \"id\": \"$2\"", true)

    return result

func load_existing_rooms_data() -> Dictionary:
    return load_json(ROOMS_DATA_PATH)

func load_meshes_data() -> Dictionary:
    return load_json(MESHES_DATA_PATH)

func load_npcs_data() -> Dictionary:
    return load_json(NPCS_DATA_PATH)

func load_narrative_data() -> Dictionary:
    return load_json(NARRATIVE_DATA_PATH)

func load_dialogs_data() -> Dictionary:
    return load_json(DIALOGS_DATA_PATH)

func load_selection_data() -> Dictionary:
    return load_json(SELECTION_DATA_PATH)

func load_json(file_path: String) -> Dictionary:
    var data_path = Main.get_data_path(file_path)
    var file = FileAccess.open(data_path, FileAccess.READ)
    if not file:
        print("ファイルを開けませんでした: ", data_path)
        return {}
    
    var json_text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_text)
    
    if parse_result != OK:
        print("JSONのパースエラー: ", json.get_error_message())
        return {}
    
    return json.data

func build_current_room_data() -> Dictionary:
    var current_room = DataRepository.room_repository.get_current_room()
    if not current_room:
        return {}
    
    var seats = DataRepository.seat_repository.get_all_seats()
    
    var room_data = {
        "size": [
            round_to_decimal(current_room.size.x, 1), 
            round_to_decimal(current_room.size.y, 1), 
            round_to_decimal(current_room.size.z, 1)
        ],
        "player_spawn_position": [
            round_to_decimal(current_room.player_spawn_position.x, 1), 
            round_to_decimal(current_room.player_spawn_position.y, 1), 
            round_to_decimal(current_room.player_spawn_position.z, 1)
        ],
        "player_spawn_rotation": round_to_decimal(current_room.player_spawn_rotation, 1),
        "exit_position": [
            round_to_decimal(current_room.exit_position.x, 1), 
            round_to_decimal(current_room.exit_position.y, 1), 
            round_to_decimal(current_room.exit_position.z, 1)
        ],
        "display_name": current_room.display_name,
        "seats": [],
        "default_assignment": []  # 新規追加
    }
    
    # 座席データを追加
    for seat in seats:
        var seat_data = {
            "id": seat.id,
            "position": [
                round_to_decimal(seat.position.x, 1), 
                round_to_decimal(seat.position.y, 1), 
                round_to_decimal(seat.position.z, 1)
            ],
            "rotation": round_to_decimal(seat.rotation_degrees, 1),
            "mesh_id": seat.mesh_id,
            "display_name": seat.display_name
        }
        room_data.seats.append(seat_data)
    
    # 現在のNPC配置をdefault_assignmentとして追加
    var seated_npcs = DataRepository.assignment_repository.get_seated_npc_ids()
    for npc_id in seated_npcs:
        var seat_id = DataRepository.get_npc_seat_id(npc_id)
        if not seat_id.is_empty():
            var assignment_data = {
                "seat_id": seat_id,
                "npc_id": npc_id
            }
            room_data.default_assignment.append(assignment_data)
    
    print("Default assignment データを生成: ", room_data.default_assignment.size(), "件")
    return room_data

func round_to_decimal(value: float, decimal_places: int) -> float:
    var multiplier = pow(10, decimal_places)
    return round(value * multiplier) / multiplier
