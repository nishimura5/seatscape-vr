# scripts/title.gd (XRButtonFocus使用版)
extends Control

@onready var shared_ui: Control = $SharedUI
@onready var xr_ui: Node3D = $XRUI
@onready var sub_viewport: SubViewport = $XRUI/UIPanel/SubViewport
@onready var xr_ui_panel: Node3D = $XRUI/UIPanel
@onready var panel_mesh: MeshInstance3D = $XRUI/UIPanel/PanelMesh

# Buttons
@onready var scenario_button: Button = $SharedUI/VBoxContainer/HBoxContainer/ScenarioButton
@onready var experiment_button: Button = $SharedUI/VBoxContainer/HBoxContainer/ExperimentButton
@onready var room_edit_button: Button = $SharedUI/VBoxContainer/HBoxContainer/RoomEditButton

# XR入力関連
@onready var xr_origin: XROrigin3D = $XRUI/XROrigin3D
@onready var right_controller: XRController3D = $XRUI/XROrigin3D/RightController
@onready var left_controller: XRController3D = $XRUI/XROrigin3D/LeftController

var is_xr_mode: bool = false
var ui_panel_material: StandardMaterial3D
var xr_button_focus: XRButtonFocus

func _ready():
    setup_mode()
    setup_connections()
    call_deferred("setup_ui_focus")

func setup_mode():
    """XRまたはデスクトップモードの設定"""
    if XRManager.is_xr_available and XRManager.initialize_xr():
        setup_xr_mode()
    else:
        setup_desktop_mode()

func setup_connections():
    """ボタンイベントの接続"""
    scenario_button.pressed.connect(execute_scenario_mode)
    experiment_button.pressed.connect(execute_experiment_mode)
    room_edit_button.pressed.connect(execute_room_edit_mode)

func setup_desktop_mode():
    """デスクトップモード用UI設定"""
    is_xr_mode = false
    xr_ui.visible = false
    shared_ui.visible = true

func setup_xr_mode():
    """XRモード用UI設定"""
    print("XR mode")
    is_xr_mode = true
    room_edit_button.disabled = true

    # XR UI設定
    xr_ui.visible = true
    shared_ui.visible = false
    
    setup_xr_viewport()
    setup_xr_panel()
    setup_xr_navigation()

func setup_xr_viewport():
    """XR用SubViewport設定"""
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
    # XRButtonFocusインスタンスを作成
    xr_button_focus = XRButtonFocus.new(left_controller, right_controller)
    
    # ボタン配列を設定（room_edit_buttonは無効化されている場合は除外）
    var button_list: Array[Button] = []
    button_list.append(scenario_button)
    button_list.append(experiment_button)
    if not room_edit_button.disabled:
        button_list.append(room_edit_button)
    
    # ボタンナビゲーションを設定
    xr_button_focus.setup_buttons(button_list, 0)
    
    # ボタン有効化シグナルを接続
    xr_button_focus.button_activated.connect(_on_xr_button_activated)

func apply_viewport_texture():
    """SubViewportのテクスチャをマテリアルに適用"""
    if ui_panel_material and sub_viewport:
        ui_panel_material.albedo_texture = sub_viewport.get_texture()
        ui_panel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

func setup_ui_focus():
    """フォーカス設定を一箇所で管理"""
    # XRモードでは UIナビゲーションは不要
    if is_xr_mode:
        return
    
    # ボタンのフォーカスモードを設定
    scenario_button.focus_mode = Control.FOCUS_ALL
    experiment_button.focus_mode = Control.FOCUS_ALL
    room_edit_button.focus_mode = Control.FOCUS_ALL
    
    # 隣接フォーカス設定（左右のナビゲーション）
    scenario_button.focus_neighbor_right = experiment_button.get_path()
    scenario_button.focus_neighbor_left = room_edit_button.get_path()
    
    experiment_button.focus_neighbor_left = scenario_button.get_path()
    experiment_button.focus_neighbor_right = room_edit_button.get_path()
    
    room_edit_button.focus_neighbor_left = experiment_button.get_path()
    room_edit_button.focus_neighbor_right = scenario_button.get_path()
    
    # 初期フォーカスを設定
    set_initial_focus()

func set_initial_focus():
    """初期フォーカスの設定"""
    if is_xr_mode:
        # XRモードでは自動フォーカスは不要
        return
    
    # デスクトップモードでScenarioButtonにフォーカスを設定
    if scenario_button and scenario_button.is_visible_in_tree():
        scenario_button.grab_focus()

func _input(event):
    # デスクトップモードでのみキーボード入力を処理
    if not is_xr_mode:
        handle_desktop_input(event)

func _process(_delta):
    if is_xr_mode and xr_button_focus:
        xr_button_focus.process_input()

func _on_xr_button_activated(button: Button):
    """XRモードでボタンが有効化された時の処理"""
    if button == scenario_button:
        execute_scenario_mode()
    elif button == experiment_button:
        execute_experiment_mode()
    elif button == room_edit_button:
        execute_room_edit_mode()

func handle_desktop_input(event):
    """デスクトップモードでの入力処理"""
    # Enterキーまたはスペースキーでボタンを実行
    if event.is_action_pressed("ui_accept"):
        var focused_button = get_viewport().gui_get_focus_owner()
        if focused_button == scenario_button:
            execute_scenario_mode()
        elif focused_button == experiment_button:
            execute_experiment_mode()
        elif focused_button == room_edit_button:
            execute_room_edit_mode()

# 実行関数を分離してコードの意図を明確化
func execute_scenario_mode():
    """シナリオモードの実行"""
    print("シナリオモードを開始...")
    GameStateManager.start_scenario_mode()

func execute_experiment_mode():
    """実験モードの実行"""
    print("実験モードを開始...")
    GameStateManager.start_experiment_mode()

func execute_room_edit_mode():
    """部屋編集モードの実行"""
    print("部屋編集モードを開始...")
    GameStateManager.start_room_edit_mode()