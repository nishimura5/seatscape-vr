# scripts/protocol_selection.gd (XRButtonFocus使用版 - 改善版)
extends Control

@onready var shared_ui: Control = $SharedUI
@onready var xr_ui: Node3D = $XRUI
@onready var sub_viewport: SubViewport = $XRUI/UIPanel/SubViewport
@onready var xr_ui_panel: Node3D = $XRUI/UIPanel
@onready var panel_mesh: MeshInstance3D = $XRUI/UIPanel/PanelMesh

@onready var protocol_buttons_container: VBoxContainer = $SharedUI/CenterContainer/MainHBoxContainer/VBoxContainer/ScrollContainer/ProtocolOptionsContainer
@onready var confirm_button: Button = $SharedUI/CenterContainer/MainHBoxContainer/ConfirmButton
@onready var back_to_title_button: Button = $SharedUI/CenterContainer/MainHBoxContainer/BackToTitleButton
@onready var title_label: Label = $SharedUI/CenterContainer/MainHBoxContainer/MessagePanel/VBoxContainer/TitleLabel
@onready var message_label: Label = $SharedUI/CenterContainer/MainHBoxContainer/MessagePanel/VBoxContainer/MessageLabel
@onready var dialog_system: Control = $SharedUI/DialogSystem

@onready var xr_origin: XROrigin3D = $XRUI/XROrigin3D
@onready var right_controller: XRController3D = $XRUI/XROrigin3D/RightController
@onready var left_controller: XRController3D = $XRUI/XROrigin3D/LeftController

var selected_protocol_id: String = ""
var protocol_buttons: Dictionary = {}
var button_group: ButtonGroup
var protocols: Dictionary = {}

# XR関連
var is_xr_mode: bool = false
var ui_panel_material: StandardMaterial3D
var xr_button_focus: XRButtonFocus

func _ready():
    setup_mode()
    button_group = ButtonGroup.new()
    setup_ui()
    setup_connections()
    show_initial_dialog()

func setup_mode():
    """XRまたはデスクトップモードの設定"""
    if XRManager.is_xr_available and XRManager.initialize_xr():
        setup_xr_mode()
        dialog_system.set_xr_enabled(true, right_controller)
    else:
        setup_desktop_mode()

func setup_desktop_mode():
    """デスクトップモード用設定"""
    is_xr_mode = false
    xr_ui.visible = false
    shared_ui.visible = true

func setup_xr_mode():
    """XRモード用設定"""
    print("XR mode")
    is_xr_mode = true

    xr_ui.visible = true
    shared_ui.visible = false

    setup_xr_viewport()
    setup_xr_panel()
    # XRナビゲーションは後でボタンが作成されてから設定

func setup_xr_viewport():
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    
    # UIをSubViewportに移動
    shared_ui.reparent(sub_viewport, false)
    shared_ui.visible = true

func setup_xr_panel():
    xr_ui_panel.position = Vector3(0, 1.5, -2.8)
    
    # マテリアル設定
    ui_panel_material = StandardMaterial3D.new()
    ui_panel_material.flags_unshaded = true
    ui_panel_material.flags_do_not_use_vertex_lighting = true
    ui_panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    
    panel_mesh.material_override = ui_panel_material
    call_deferred("apply_viewport_texture")

func setup_xr_navigation():
    """XRナビゲーションシステムの設定"""
    if not is_xr_mode:
        return
        
    print("XRナビゲーション設定開始")
    
    # XRButtonFocusインスタンスを作成
    xr_button_focus = XRButtonFocus.new(left_controller, right_controller)
    
    # 全てのボタンを配列に集める
    var all_buttons: Array[Button] = []
    
    # プロトコルボタンを追加（作成順序で追加）
    print("プロトコルボタン数: ", protocol_buttons.size())
    for child in protocol_buttons_container.get_children():
        if child is Button and is_instance_valid(child):
            all_buttons.append(child)
            print("プロトコルボタン追加: ", child.text)
    
    # 制御ボタンを追加
    all_buttons.append(confirm_button)
    all_buttons.append(back_to_title_button)
    
    print("総ボタン数: ", all_buttons.size())
    
    # XRButtonFocusに設定（最初のプロトコルボタンからスタート）
    if all_buttons.size() > 0:
        xr_button_focus.setup_buttons(all_buttons, 0)
        print("XRナビゲーション設定完了")
    else:
        print("警告: ナビゲーション可能なボタンがありません")
    
    # ボタン有効化シグナルを接続
    xr_button_focus.button_activated.connect(_on_xr_button_activated)

func apply_viewport_texture():
    """SubViewportのテクスチャをマテリアルに適用"""
    if ui_panel_material and sub_viewport:
        ui_panel_material.albedo_texture = sub_viewport.get_texture()
        ui_panel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

func setup_ui():
    clear_existing_buttons()
    create_protocol_buttons()
    
    # XRナビゲーションをボタン作成後に設定
    call_deferred("setup_xr_navigation")

    confirm_button.text = "Next"
    confirm_button.disabled = false
    back_to_title_button.text = "Title"
    title_label.text = "プロトコルを選択してください"

    if not is_xr_mode:
        back_to_title_button.grab_focus()

func clear_existing_buttons():
    """既存の固定ボタンをクリア"""
    for child in protocol_buttons_container.get_children():
        if child is Button:
            child.queue_free()
    protocol_buttons.clear()

func create_protocol_buttons():
    protocols = load_protocol_menu()
    for protocol_id in protocols.keys():
        create_protocol_button(protocol_id)

func load_protocol_menu() -> Dictionary:
    var file = FileAccess.open("res://data/configs/selection.json", FileAccess.READ)
    if not file:
        print("selection.json not found.")
        return {}

    var json_text = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_text)

    if parse_result != OK:
        print("selection.jsonのパースエラー: ", json.get_error_message())
        return {}

    var data = json.data
    if data.has("for_experiment") and data.for_experiment is Dictionary:
        var result: Dictionary = {}
        for protocol_id in data.for_experiment.keys():
            result[protocol_id] = data.for_experiment[protocol_id]
        return result

    return {}

func create_protocol_button(protocol_id: String):
    var button = Button.new()
    button.text = protocol_id
    button.toggle_mode = true
    button.button_group = button_group

    # XRモードでは通常のpressedシグナルを使用（toggleの問題を回避）
    button.pressed.connect(_on_protocol_button_pressed.bind(protocol_id))

    # コンテナに追加
    protocol_buttons_container.add_child(button)
    protocol_buttons[protocol_id] = button

func setup_connections():
    confirm_button.pressed.connect(_on_confirm_button_pressed)
    back_to_title_button.pressed.connect(_on_back_to_title_pressed)
    EventBus.ui_status_updated.connect(_on_ui_status_updated)

func show_initial_dialog():
    DialogManager.start_dialog("room_selection_intro", dialog_system)

func _process(_delta):
    if is_xr_mode and xr_button_focus:
        xr_button_focus.process_input()

func _on_xr_button_activated(button: Button):
    """XRモードでボタンが有効化された時の処理"""
    print("XRボタン有効化: ", button.text if is_instance_valid(button) else "null")
   
    if button == confirm_button:
        _on_confirm_button_pressed()
    elif button == back_to_title_button:
        _on_back_to_title_pressed()
    else:
        # プロトコルボタンの場合
        var found_protocol = ""
        for protocol_id in protocol_buttons.keys():
            if protocol_buttons[protocol_id] == button:
                found_protocol = protocol_id
                break
        
        handle_protocol_selection_xr(found_protocol, button)

func handle_protocol_selection_xr(protocol_id: String, button: Button):
    """XRモードでのプロトコル選択処理"""
    # 選択状態を保存（最初に保存）
    selected_protocol_id = protocol_id
    
    # 他のボタンの選択状態をクリア
    for other_protocol_id in protocol_buttons.keys():
        var other_button = protocol_buttons[other_protocol_id]
        if is_instance_valid(other_button):
            other_button.button_pressed = false
            other_button.modulate = Color.WHITE
    
    # 選択されたボタンの状態を更新
    if is_instance_valid(button):
        button.button_pressed = true
        button.modulate = Color.LIGHT_BLUE
    
    # 確認ボタンを有効化
    confirm_button.disabled = false
    
    print("プロトコル選択: ", protocol_id, selected_protocol_id)

func _on_protocol_button_pressed(protocol_id: String):
    """デスクトップモードでのプロトコルボタン処理"""
    if is_xr_mode:
        # XRモードでは_on_xr_button_activatedで処理される
        return
    
    select_protocol(protocol_id)

func select_protocol(protocol_id: String):
    print("Selected protocol: ", protocol_id)
    selected_protocol_id = protocol_id
    update_protocol_selection_ui()
    confirm_button.disabled = false

func update_protocol_selection_ui():
    """デスクトップモード用のUI更新"""
    for button_id in protocol_buttons.keys():
        var button = protocol_buttons[button_id]
        if button_id == selected_protocol_id:
            button.modulate = Color.LIGHT_BLUE
        else:
            button.modulate = Color.WHITE

func _on_confirm_button_pressed():
    print("確認ボタンが押されました。選択されたプロトコル: ", selected_protocol_id)
    
    if selected_protocol_id.is_empty():
        title_label.text = "プロトコルを選択してください"
        return

    set_ui_enabled(false)

    # formatting Array[String]
    var room_order: Array[String] = []
    for room_id in protocols[selected_protocol_id]:
        room_order.append(room_id)
    GameStateManager.start_scenario_mode(room_order)

func _on_back_to_title_pressed():
    DataRepository.clear_all_data()
    GameStateManager.transition_to(GameStateManager.GameState.TITLE)

func _on_ui_status_updated(message: String):
    message_label.text = message

func set_ui_enabled(enabled: bool):
    for button in protocol_buttons.values():
        button.disabled = not enabled
    confirm_button.disabled = not enabled
    back_to_title_button.disabled = not enabled
    
    # XRナビゲーションも無効化
    if is_xr_mode and xr_button_focus and not enabled:
        xr_button_focus.clear_focus()