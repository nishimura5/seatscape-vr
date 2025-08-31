# scripts/room_selection.gd
extends Control

@onready var room_buttons_container: VBoxContainer = $CenterContainer/MainHBoxContainer/VBoxContainer/ScrollContainer/RoomOptionsContainer
@onready var confirm_button: Button = $CenterContainer/MainHBoxContainer/ConfirmButton
@onready var back_to_title_button: Button = $CenterContainer/MainHBoxContainer/BackToTitleButton
@onready var title_label: Label = $CenterContainer/MainHBoxContainer/MessagePanel/VBoxContainer/TitleLabel
@onready var message_label: Label = $CenterContainer/MainHBoxContainer/MessagePanel/VBoxContainer/MessageLabel
@onready var dialog_system: Control = $DialogSystem
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var xr_camera: Camera3D = $XROrigin3D/XRCamera3D

var selected_room_id: String = ""
var room_buttons: Dictionary = {}
var button_group: ButtonGroup

func _ready():
    button_group = ButtonGroup.new()
    setup_ui()
    setup_connections()
    show_initial_dialog()
 
func setup_ui():
    clear_existing_buttons()
    create_room_buttons()
    
    confirm_button.text = "Next"
    confirm_button.disabled = true
    back_to_title_button.text = "Title"
    title_label.text = "部屋を選択してください"

    back_to_title_button.grab_focus()

func clear_existing_buttons():
    """既存の固定ボタンをクリア"""
    for child in room_buttons_container.get_children():
        if child is Button:
            child.queue_free()
    room_buttons.clear()

func create_room_buttons():
    var rooms = load_room_menu()
    var available_rooms = StageInitializer.get_available_room_ids()
    
    # シナリオ順で並べる
    for room_id in rooms:
        if room_id in available_rooms:
            var room_info = StageInitializer.get_room_info(room_id)
            create_room_button(room_id, room_info)
    
    # シナリオにない部屋があれば最後に追加
    for room_id in available_rooms:
        if room_id not in rooms:
            var room_info = StageInitializer.get_room_info(room_id)
            create_room_button(room_id, room_info)

func load_room_menu() -> Array[String]:
    """room_scenario.jsonから部屋IDの順番を読み込み"""
    var file = FileAccess.open("res://data/configs/selection.json", FileAccess.READ)
    if not file:
        print("selection.json not found.")
        return []
    
    var json_text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_text)
    
    if parse_result != OK:
        print("room_scenario.jsonのパースエラー: ", json.get_error_message())
        return []
    
    var data = json.data
    if data.has("for_edit") and data.for_edit is Array:
        var result: Array[String] = []
        for room_id in data.for_edit:
            result.append(str(room_id))
        return result
    
    return []

func create_room_button(room_id: String, room_info: Dictionary):
    """個別の部屋ボタンを作成"""
    var button = Button.new()
    button.text = room_info.display_name
    button.toggle_mode = true
    button.button_group = button_group
    
    button.pressed.connect(_on_room_button_pressed.bind(room_id))
    
    # コンテナに追加
    room_buttons_container.add_child(button)
    room_buttons[room_id] = button

func setup_connections():
    confirm_button.pressed.connect(_on_confirm_button_pressed)
    back_to_title_button.pressed.connect(_on_back_to_title_pressed)
    EventBus.ui_status_updated.connect(_on_ui_status_updated)
    EventBus.data_initialized.connect(_on_data_initialized)

func show_initial_dialog():
    DialogManager.start_dialog("room_selection_intro", dialog_system)

func _on_room_button_pressed(room_id: String):
    select_room(room_id)

func select_room(room_id: String):
    selected_room_id = room_id
    update_room_selection_ui()
    confirm_button.disabled = false
    show_room_details(room_id)

func update_room_selection_ui():
    for button_id in room_buttons.keys():
        var button = room_buttons[button_id]
        if button_id == selected_room_id:
            button.modulate = Color.LIGHT_BLUE
        else:
            button.modulate = Color.WHITE

func show_room_details(room_id: String):
    var room_info = StageInitializer.get_room_info(room_id)
    var size_text = "%.1fm × %.1fm × %.1fm" % [room_info.size.x, room_info.size.z, room_info.size.y]
    var details = "ID: %s\nSize: %s\nFurnitures: %d" % [room_info.id, size_text, room_info.seat_count]
    title_label.text = room_info.display_name
    message_label.text = details

func _on_confirm_button_pressed():
    if selected_room_id.is_empty():
        title_label.text = "部屋を選択してください"
        return
    
    var room_display_name = StageInitializer.get_room_display_name(selected_room_id)
    message_label.text = "%sを初期化中..." % room_display_name
    set_ui_enabled(false)
    
    EventBus.room_selected.emit(selected_room_id)

func _on_data_initialized():
    var room_display_name = StageInitializer.get_room_display_name(selected_room_id)
    message_label.text = "%sの初期化が完了しました" % room_display_name
    
    GameStateManager.transition_to(GameStateManager.GameState.ASSIGNMENT)

func _on_back_to_title_pressed():
    DataRepository.clear_all_data()
    GameStateManager.transition_to(GameStateManager.GameState.TITLE)

func _on_ui_status_updated(message: String):
    message_label.text = message

func set_ui_enabled(enabled: bool):
    for button in room_buttons.values():
        button.disabled = not enabled
    confirm_button.disabled = not enabled
    back_to_title_button.disabled = not enabled
