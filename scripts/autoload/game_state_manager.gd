# scripts/autoload/game_state_manager.gd
extends Node

enum GameState {
    TITLE,
    ROOM_SELECTION,
    PROTOCOL_SELECTION,
    ASSIGNMENT,
    SEATING,
    NARRATIVE
}

enum GameMode {
    SCENARIO,
    EXPERIMENT,
    ROOM_EDIT
}

var current_state: GameState = GameState.TITLE
var current_mode: GameMode = GameMode.EXPERIMENT
var selected_room_id: String = ""
var is_transitioning: bool = false
var narrative_data: Dictionary = {}

# シナリオ進行管理
var scenario_room_ids: Array[String] = []
var current_scenario_index: int = 0

func _ready():
    EventBus.room_selected.connect(_on_room_selected)
    EventBus.scene_changed.connect(_on_scene_changed)

    # narrative_data.jsonの読み込み
    var file_manager = FileManager.new()
    narrative_data = file_manager.load_narrative_data()

func _on_room_selected(room_id: String):
    selected_room_id = room_id
    if current_mode == GameMode.SCENARIO:
        transition_to(GameState.SEATING)
    elif current_mode == GameMode.EXPERIMENT:
        transition_to(GameState.SEATING)
    elif current_mode == GameMode.ROOM_EDIT:
        transition_to(GameState.ASSIGNMENT)

func _on_scene_changed(_scene_name: String):
    is_transitioning = false

func transition_to(new_state: GameState):
    print("Transition requested: ", get_current_state_name(), " -> ", get_state_name(new_state))
    
    if is_transitioning:
        print("遷移中のため、リクエストを無視: ", get_state_name(new_state))
        return
    
    current_state = new_state
    is_transitioning = true
    
    match new_state:
        GameState.TITLE:
            SceneManager.change_scene("title")
        GameState.ROOM_SELECTION:
            SceneManager.change_scene("room_selection")
        GameState.PROTOCOL_SELECTION:
            SceneManager.change_scene("protocol_selection")
        GameState.ASSIGNMENT:
            SceneManager.change_scene("assignment")
        GameState.SEATING:
            SceneManager.change_scene("seating")
        GameState.NARRATIVE:
            SceneManager.change_scene("narrative")

func start_scenario_mode(order: Array[String] = []):
    """シナリオモード：room_scenario.jsonの順番で部屋を移動"""
    current_mode = GameMode.SCENARIO
    if order.size() > 0:
        scenario_room_ids = order
    else:
        load_scenario_room_list()
    
    if scenario_room_ids.is_empty():
        print("シナリオ部屋リストが見つかりません")
        transition_to(GameState.ROOM_SELECTION)
        return
    
    current_scenario_index = 0
    print("シナリオモードを開始: ", scenario_room_ids.size(), "部屋")
    print(scenario_room_ids)

    start_current_scenario_room()

func start_current_scenario_room():
    """現在のシナリオインデックスの部屋でseatingを開始"""
    if current_scenario_index >= scenario_room_ids.size():
        print("全シナリオ完了、タイトルに戻ります")
        complete_scenario()
        return
    
    selected_room_id = scenario_room_ids[current_scenario_index]

    # room_idがseatingなのかnarrativeなのかを判定
    # narrative_data.jsonに定義されている部屋はnarrativeとして扱う
    if selected_room_id in narrative_data:
        transition_to(GameState.NARRATIVE)
        return

    print("シナリオ進行: ", current_scenario_index + 1, "/", scenario_room_ids.size(), " - ", selected_room_id)

    # データを初期化してからseatingに遷移
    EventBus.room_selected.emit(selected_room_id)
    await get_tree().process_frame
    transition_to(GameState.SEATING)

func proceed_to_next_scenario_room():
    """次のシナリオ部屋に進む"""
    current_scenario_index += 1
    
    if current_scenario_index >= scenario_room_ids.size():
        print("全シナリオ完了")
        complete_scenario()
    else:
        print("次のシナリオ部屋に移動中...")
        # データをクリアしてから次の部屋に移動
        DataRepository.clear_all_data()
        PlayerDataManager.reset_data()
        start_current_scenario_room()

func complete_scenario():
    """シナリオ完了時の処理"""
    print("シナリオモード完了、タイトルに戻ります")
    current_scenario_index = 0
    scenario_room_ids.clear()
    DataRepository.clear_all_data()
    PlayerDataManager.reset_data()
    transition_to(GameState.TITLE)

func restart_current_scenario_room():
    """現在のシナリオ部屋をリトライ"""
    print("現在のシナリオ部屋をリトライ: ", get_current_scenario_room_id())
    DataRepository.clear_all_data()
    PlayerDataManager.reset_data()
    start_current_scenario_room()

func load_scenario_room_list():
    """room_scenario.jsonからroom_idsリストを読み込み"""
    scenario_room_ids.clear()
    
    var file = FileAccess.open("res://data/configs/selection.json", FileAccess.READ)
    if not file:
        print("selection.jsonが見つかりません")
        return
    
    var json_text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_text)
    
    if parse_result != OK:
        print("room_scenario.jsonのパースエラー: ", json.get_error_message())
        return
    
    var data = json.data
    if data.has("for_scenario") and data.for_scenario is Array:
        for room_id in data.for_scenario:
            scenario_room_ids.append(room_id)

func start_experiment_mode():
    """実験モード：protocol_selection から開始"""
    current_mode = GameMode.EXPERIMENT
    print("実験モードに設定されました")
    
    transition_to(GameState.PROTOCOL_SELECTION)

func start_room_edit_mode():
    """部屋編集モード：room_selection から開始"""
    current_mode = GameMode.ROOM_EDIT
    print("部屋編集モードに設定されました")

    transition_to(GameState.ROOM_SELECTION)

# === シナリオ進行管理メソッド ===

func get_current_scenario_room_id() -> String:
    """現在のシナリオ部屋IDを取得"""
    if current_scenario_index < scenario_room_ids.size():
        return scenario_room_ids[current_scenario_index]
    return ""

func get_scenario_progress() -> Dictionary:
    """シナリオの進行状況を取得"""
    return {
        "current_index": current_scenario_index,
        "total_rooms": scenario_room_ids.size(),
        "current_room_id": get_current_scenario_room_id(),
        "is_last_room": current_scenario_index >= scenario_room_ids.size() - 1
    }

func get_scenario_progress_text() -> String:
    """シナリオ進行状況のテキストを取得"""
    if scenario_room_ids.is_empty():
        return ""
    return "%d/%d" % [current_scenario_index + 1, scenario_room_ids.size()]

func is_last_scenario_room() -> bool:
    """現在が最後のシナリオ部屋かどうか"""
    return current_scenario_index >= scenario_room_ids.size() - 1

# === モード管理関連のメソッド ===

func is_scenario_mode() -> bool:
    """現在シナリオモードかどうかを判定"""
    return current_mode == GameMode.SCENARIO

func is_experiment_mode() -> bool:
    """現在実験モードかどうかを判定"""
    return current_mode == GameMode.EXPERIMENT

func get_current_mode() -> GameMode:
    """現在のゲームモードを取得"""
    return current_mode

func get_current_mode_name() -> String:
    """現在のゲームモード名を文字列で取得"""
    return get_mode_name(current_mode)

func get_mode_name(mode: GameMode) -> String:
    """モード名を文字列で取得"""
    match mode:
        GameMode.SCENARIO:
            return "SCENARIO"
        GameMode.EXPERIMENT:
            return "EXPERIMENT"
        GameMode.ROOM_EDIT:
            return "ROOM_EDIT"
        _:
            return "UNKNOWN"

func set_mode(mode: GameMode):
    """ゲームモードを直接設定（デバッグ用）"""
    current_mode = mode
    print("ゲームモードを", get_mode_name(mode), "に設定しました")

func get_current_state() -> GameState:
    return current_state

func get_selected_room_id() -> String:
    return selected_room_id

func get_current_state_name() -> String:
    return get_state_name(current_state)

func get_state_name(state: GameState) -> String:
    """状態名を文字列で取得"""
    match state:
        GameState.TITLE:
            return "TITLE"
        GameState.ROOM_SELECTION:
            return "ROOM_SELECTION"
        GameState.PROTOCOL_SELECTION:
            return "PROTOCOL_SELECTION"
        GameState.ASSIGNMENT:
            return "ASSIGNMENT"
        GameState.SEATING:
            return "SEATING"
        GameState.NARRATIVE:
            return "NARRATIVE"
        _:
            return "UNKNOWN"
