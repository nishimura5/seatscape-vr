# scripts/narrative.gd
extends Control

@onready var background_image: TextureRect = $SharedUI/BackgroundImage
@onready var shared_ui: Control = $SharedUI
@onready var xr_ui: Node3D = $XRUI
@onready var sub_viewport: SubViewport = $XRUI/UIPanel/SubViewport
@onready var xr_ui_panel: Node3D = $XRUI/UIPanel
@onready var panel_mesh: MeshInstance3D = $XRUI/UIPanel/PanelMesh

@onready var dialog_system: Control = $SharedUI/DialogSystem

# Buttons
@onready var next_button: Button = $SharedUI/NarrativeInput/MarginContainer/NextButton

# XR入力関連
@onready var xr_origin: XROrigin3D = $XRUI/XROrigin3D
@onready var right_controller: XRController3D = $XRUI/XROrigin3D/RightController

var is_xr_mode: bool = false
var ui_panel_material: StandardMaterial3D
var right_trigger_pressed: bool = false

# ダイアログから抜けてきたときにacceptが押された状態になっているのであえてtrueに初期化
var accept_pressed: bool = true

var current_narrative_id: String = ""
var narrative_data: Dictionary = {}
var is_dialog_showing: bool = false

func _ready():
    setup_mode()
    setup_ui()
    setup_connections()
    load_narrative_data()
    load_narrative_content()

    show_initial_dialog()

func setup_mode():
    """XRまたはデスクトップモードの設定"""
    if XRManager.is_xr_available and XRManager.initialize_xr():
        setup_xr_mode()
        dialog_system.set_xr_enabled(true, right_controller)
    else:
        setup_desktop_mode()

func setup_ui():
    # フルスクリーン設定
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    
    # 背景画像の設定
    background_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func setup_connections():
    next_button.pressed.connect(_on_next_pressed)
    dialog_system.dialog_ended.connect(_on_dialog_ended)

func setup_desktop_mode():
    """デスクトップモード用UI設定"""
    is_xr_mode = false
    xr_ui.visible = false
    shared_ui.visible = true

func setup_xr_mode():
    """XRモード用UI設定"""
    print("XR mode")
    is_xr_mode = true

    xr_ui.visible = true
    shared_ui.visible = false

    setup_xr_viewport()
    setup_xr_panel()

func setup_xr_viewport():
    """XR用SubViewport設定"""
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    # UIをSubViewportに移動
    shared_ui.reparent(sub_viewport, false)
    shared_ui.visible = true

func setup_xr_panel():
    """3D空間でのUIパネル設定"""
    xr_ui_panel.position = Vector3(0, 1.5, -2.8)

    # マテリアル設定
    ui_panel_material = StandardMaterial3D.new()
    ui_panel_material.flags_unshaded = true
    ui_panel_material.flags_do_not_use_vertex_lighting = true
    ui_panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED

    panel_mesh.material_override = ui_panel_material
    call_deferred("apply_viewport_texture")

func apply_viewport_texture():
    """SubViewportのテクスチャをマテリアルに適用"""
    if ui_panel_material and sub_viewport:
        ui_panel_material.albedo_texture = sub_viewport.get_texture()
        ui_panel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

func load_narrative_content():
    """現在のナラティブIDに基づいてコンテンツを読み込み"""
    current_narrative_id = GameStateManager.get_current_scenario_room_id()
    
    if current_narrative_id.is_empty():
        print("Narrative ID is empty")
        return
    if not narrative_data.has(current_narrative_id):
        print("Narrative data not found for ID: ", current_narrative_id)
        return

    setup_background_image()

func load_narrative_data():
    """narrative_data.jsonからデータを読み込み"""
    var file_manager = FileManager.new()
    narrative_data = file_manager.load_narrative_data()
    if narrative_data.is_empty():
        print("ナラティブデータの読み込みに失敗しました")
        return

func show_initial_dialog():
    var current_room_id = GameStateManager.get_current_scenario_room_id()
    DialogManager.start_dialog(current_room_id, dialog_system)

func setup_background_image():
    """背景画像を設定"""
    var image_path = narrative_data.get(current_narrative_id, {}).get("image_path", "")
    
    if not ResourceLoader.exists(image_path):
        print("画像ファイルが存在しません: ", image_path)
        return
    
    var texture = load(image_path)
    background_image.texture = texture
    next_button.visible = false

func _process(_delta):
    if is_xr_mode:
        var accept_current = right_controller.is_button_pressed("accept")
        if accept_current and not accept_pressed:
            _on_next_pressed()
        accept_pressed = accept_current

func _on_dialog_ended():
    next_button.visible = true
    next_button.grab_focus()

func _on_next_pressed():
    if dialog_system.is_dialog_active:
        print("Dialog is active, cannot proceed")
        return
    
    var is_last_entry = GameStateManager.is_last_scenario_room()

    if is_last_entry:
        GameStateManager.complete_scenario()
    else:
        GameStateManager.proceed_to_next_scenario_room()

func get_narrative_id() -> String:
    return current_narrative_id
