# scripts/file_manager.gd
class_name FileManager
extends RefCounted

const ROOMS_DATA_PATH = "configs/rooms.json"
const MESHES_DATA_PATH = "configs/meshes.json"
const NPCS_DATA_PATH = "configs/npcs.json"
const NARRATIVE_DATA_PATH = "configs/narrative_data.json"
const DIALOGS_DATA_PATH = "configs/dialogs.json"
const SELECTION_DATA_PATH = "configs/selection.json"
const RESULT_CSV_PATH = "output/result.csv"

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

func append_experiment_result_csv(results: Dictionary) -> bool:
    var result_path = Main.get_data_path(RESULT_CSV_PATH)
    var output_dir = result_path.get_base_dir()
    if not ensure_directory_exists(output_dir):
        return false

    var needs_header = not FileAccess.file_exists(result_path)
    var file: FileAccess
    if needs_header:
        file = FileAccess.open(result_path, FileAccess.WRITE)
    else:
        file = FileAccess.open(result_path, FileAccess.READ_WRITE)

    if not file:
        var open_error = FileAccess.get_open_error()
        push_error("result.csvを開けませんでした: %s (error: %s)" % [result_path, error_string(open_error)])
        return false

    if not needs_header:
        file.seek_end()
    else:
        file.store_csv_line(get_result_csv_headers())

    file.store_csv_line(build_result_csv_row(results))
    var write_error = file.get_error()
    file.close()

    if write_error != OK:
        push_error("result.csvの書き込みに失敗しました: %s (error: %s)" % [result_path, error_string(write_error)])
        return false

    print("実験結果CSVを保存しました: ", result_path)
    return true

func ensure_directory_exists(path: String) -> bool:
    if DirAccess.dir_exists_absolute(path):
        return true

    var dir_error = DirAccess.make_dir_recursive_absolute(path)
    if dir_error != OK:
        push_error("outputフォルダを作成できませんでした: %s (error: %s)" % [path, error_string(dir_error)])
        return false

    return true

func get_result_csv_headers() -> PackedStringArray:
    return PackedStringArray([
        "exported_at",
        "mode",
        "room_id",
        "scenario_index",
        "scenario_total",
        "started_at",
        "ended_at",
        "duration_sec",
        "final_seat_id",
        "final_seat_display_name",
        "final_seat_position_x",
        "final_seat_position_y",
        "final_seat_position_z",
        "intimate_violations",
        "intimate_penalty",
        "seat_zone_status_json",
        "current_zone_status_json",
        "direction_status",
        "direction_score"
    ])

func build_result_csv_row(results: Dictionary) -> PackedStringArray:
    var final_seat_id = PlayerDataManager.get_final_seat_id()
    var final_seat_position = PlayerDataManager.get_final_seat_position()
    var scenario_index = ""
    var scenario_total = ""

    if GameStateManager.is_scenario_mode():
        var progress = GameStateManager.get_scenario_progress()
        scenario_index = str(int(progress.get("current_index", 0)) + 1)
        scenario_total = str(progress.get("total_rooms", ""))

    return PackedStringArray([
        format_unix_datetime(Time.get_unix_time_from_system()),
        GameStateManager.get_current_mode_name(),
        get_result_room_id(),
        scenario_index,
        scenario_total,
        format_unix_datetime(PlayerDataManager.seating_start_time),
        format_unix_datetime(PlayerDataManager.seating_end_time),
        str(PlayerDataManager.get_seating_duration()),
        final_seat_id,
        get_final_seat_display_name(final_seat_id),
        str(final_seat_position.x),
        str(final_seat_position.y),
        str(final_seat_position.z),
        str(results.get("intimate_violations", "")),
        str(results.get("intimate_penalty", "")),
        JSON.stringify(results.get("seat_zone_status", [])),
        JSON.stringify(PlayerDataManager.get_current_zone_status()),
        str(results.get("direction_status", "")),
        str(results.get("direction_score", ""))
    ])

func get_result_room_id() -> String:
    if GameStateManager.is_scenario_mode():
        return GameStateManager.get_current_scenario_room_id()
    return GameStateManager.get_selected_room_id()

func get_final_seat_display_name(seat_id: String) -> String:
    if seat_id.is_empty():
        return ""

    var seat = DataRepository.seat_repository.get_seat(seat_id)
    if not seat:
        return ""

    return seat.display_name

func format_unix_datetime(timestamp: float) -> String:
    if timestamp <= 0.0:
        return ""
    return Time.get_datetime_string_from_unix_time(int(timestamp), true)

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
