# scripts/3d/xr_player_3d.gd
extends CharacterBody3D

@onready var player_model: Node3D = $player
@onready var head: Node3D = $XROrigin3D/Head
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var camera: Camera3D = $XROrigin3D/Head/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var pivot: Node3D = $Pivot
@onready var sub_viewport: SubViewport = $XROrigin3D/Head/UIPanel/SubViewport
@onready var xr_ui_panel: Node3D = $XROrigin3D/Head/UIPanel
@onready var panel_mesh: MeshInstance3D = $XROrigin3D/Head/UIPanel/PanelMesh
@onready var dialog_system: Control = $XROrigin3D/Head/UIPanel/SubViewport/DialogSystem
@onready var result_ui: Control = $XROrigin3D/Head/UIPanel/SubViewport/ResultUI
@onready var player_collision: CollisionShape3D = $PlayerCollision
@onready var back_area_detector: Node = $Pivot/BackAreaDetector
@onready var back_area_collision: CollisionShape3D = $Pivot/BackAreaDetector/BackAreaCollision
@onready var personal_space_detector: Area3D = $Pivot/PersonalSpaceDetector
@onready var personal_space_collision: CollisionShape3D = $Pivot/PersonalSpaceDetector/PersonalSpaceCollision
@onready var can_sit_down_icon: MeshInstance3D = $XROrigin3D/Head/CanSitDownIconMesh

# Movement constants
const WALK_SPEED = 1.0
const ROTATION_SPEED = 1.1
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var ui_panel_material: StandardMaterial3D

# Height adjustment
var target_camera_height: float = 1.0
var offset_height = 0.0

# Sitting state
var is_sitting: bool = false
var is_camera_tweening: bool = false
var seat_id: String = ""
var wait_timer: Timer

# Input tracking
var accept_pressed: bool = false

# Dialog state
var is_dialog_active: bool = false
var is_result_ui_active: bool = false

# Signals
signal seat_available()
signal seat_unavailable()
signal sat_down(seat_position: Vector3)
signal seating_completed()

func _ready():
    setup_collision_shapes()
    setup_connections()
    setup_initial_position()
    setup_wait_timer()
    add_to_group("player")
    setup_ui()
    setup_dialog_system()
    setup_result_ui()
    print("Ready to play!")

func setup_wait_timer():
    """結果表示待機用のタイマーを設定"""
    wait_timer = Timer.new()
    wait_timer.wait_time = 1.0
    wait_timer.one_shot = true
    wait_timer.timeout.connect(_on_wait_timer_timeout)
    add_child(wait_timer)

func setup_collision_shapes():
    # Blenderメッシュから自動的にコリジョン形状を生成
    setup_player_collision()
    setup_back_area_collision()
    setup_personal_space_collision()

    back_area_detector.collision_layer = 0x02
    back_area_detector.collision_mask = 0x08
    personal_space_detector.collision_layer = 0x01
    personal_space_detector.collision_mask = 0x04

func setup_player_collision():
    var player_mesh = find_mesh_by_name("player")
    player_collision.shape = player_mesh.create_convex_shape()

func setup_back_area_collision():
    var back_area_mesh = find_mesh_by_name("back_area")
    back_area_collision.shape = back_area_mesh.create_convex_shape()

func setup_personal_space_collision():
    var player_mesh = find_mesh_by_name("player")
    personal_space_collision.shape = player_mesh.create_convex_shape()

func setup_ui():
    # UIパネルの位置と設定
    xr_ui_panel.position = Vector3(0, 0, -1.5)
    
    # SubViewportの設定
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

    # マテリアル設定
    ui_panel_material = StandardMaterial3D.new()
    ui_panel_material.flags_unshaded = true
    ui_panel_material.flags_do_not_use_vertex_lighting = true
    ui_panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    # 透明度設定
    ui_panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ui_panel_material.flags_transparent = true
    ui_panel_material.no_depth_test = true
    ui_panel_material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
    panel_mesh.material_override = ui_panel_material

    call_deferred("apply_viewport_texture")

func setup_dialog_system():
    """ダイアログシステムのXR設定"""
    if dialog_system:
        dialog_system.set_xr_enabled(true, right_controller)
        dialog_system.dialog_ended.connect(_on_dialog_ended)

        # 初期状態では非表示
        xr_ui_panel.visible = false

func setup_result_ui():
    """ResultUIのXR設定"""
    if result_ui:
        result_ui.next_pressed.connect(_on_result_next_pressed)
        result_ui.retry_pressed.connect(_on_result_retry_pressed)
        result_ui.back_to_menu_pressed.connect(_on_result_back_to_menu_pressed)
        
        # 初期状態では非表示
        result_ui.visible = false

func apply_viewport_texture():
    """SubViewportのテクスチャをマテリアルに適用"""
    if ui_panel_material and sub_viewport:
        ui_panel_material.albedo_texture = sub_viewport.get_texture()
        ui_panel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
        ui_panel_material.flags_use_point_size = false

func find_mesh_by_name(target_name: String) -> Mesh:
    return search_node_for_mesh(player_model, target_name)

func search_node_for_mesh(node: Node, target_name: String) -> Mesh:
    if node.name == target_name and node is MeshInstance3D:
        return node.mesh
    for child in node.get_children():
        var result = search_node_for_mesh(child, target_name)
        if result:
            return result
    return null

func setup_connections():
    back_area_detector.seat_available.connect(_on_seat_available)
    back_area_detector.seat_unavailable.connect(_on_seat_unavailable)

func _physics_process(delta):
    if not is_sitting and not is_camera_tweening and not is_dialog_active and not is_result_ui_active:
        handle_movement(delta)
    
    # ダイアログやResultUIが表示されていない時のみ、座席入力を処理
    if not is_dialog_active and not is_result_ui_active:
        handle_input()
    
    # ResultUIが表示されている時の入力処理
    if is_result_ui_active:
        handle_result_ui_input()

func handle_input():
    """XR入力の処理"""
    # acceptボタンの状態を追跡
    var accept_current = right_controller.is_button_pressed("accept")
    if accept_current and not accept_pressed:
        attempt_sit()
    accept_pressed = accept_current

func handle_result_ui_input():
    """ResultUI表示中のXR入力処理"""
    var accept_current = right_controller.is_button_pressed("accept")
    if accept_current and not accept_pressed:
        # デフォルトでNextボタンを押す
        _on_result_next_pressed()
    accept_pressed = accept_current

func handle_movement(delta):
    var left_input = left_controller.get_vector2("player_move")
    var right_input = right_controller.get_vector2("player_look")

    var deadzone = 0.1
    
    # スナップターン方式での回転処理（XRに適している）
    if right_input.length() > deadzone:
        var look_sensitivity = ROTATION_SPEED * delta
        xr_origin.rotate_y(-right_input.x * look_sensitivity)
        pivot.rotate_y(-right_input.x * look_sensitivity)

    # 移動処理 - XROrigin3Dの向きを基準にする
    var move_input = Vector2.ZERO
    if abs(left_input.x) > deadzone or abs(left_input.y) > deadzone:
        move_input = left_input
    
    if move_input != Vector2.ZERO:
        # XROrigin3Dの向きに対する相対的な移動方向を計算
        var direction = (xr_origin.transform.basis * Vector3(move_input.x, 0, -move_input.y)).normalized()
        velocity.x = direction.x * WALK_SPEED
        velocity.z = direction.z * WALK_SPEED
    else:
        # 摩擦的な停止
        velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 3)
        velocity.z = move_toward(velocity.z, 0, WALK_SPEED * delta * 3)
    
    move_and_slide()

func set_height(target_height: float):
    target_camera_height = target_height
    offset_height = target_height - camera.global_position.y
    apply_height_offset()

func apply_height_offset():
    xr_origin.position.y = offset_height
    head.position.y = target_camera_height - offset_height
    print("camera global position: ", camera.global_position.y, "(", xr_origin.position.y, ") ", head.position.y)

# ダイアログ制御メソッド
func show_dialog(dialog_key: String):
    """ダイアログを表示"""
    if DialogManager.has_dialog(dialog_key):
        is_dialog_active = true
        is_result_ui_active = false
        
        # ResultUIを非表示にしてDialogSystemを表示
        result_ui.visible = false
        dialog_system.visible = true
        xr_ui_panel.visible = true
        
        DialogManager.start_dialog(dialog_key, dialog_system)

func show_result():
    """ResultUIを表示"""
    print("Showing XR result UI")
    is_result_ui_active = true
    is_dialog_active = false
    
    # DialogSystemを非表示にしてResultUIを表示
    dialog_system.visible = false
    result_ui.visible = true
    xr_ui_panel.visible = true
    
    # 結果を計算して表示
    var result_manager = ResultManager.new()
    if result_manager:
        result_manager.calculate_results()
        var results = result_manager.get_results()
        
        if GameStateManager.is_scenario_mode():
            var progress = GameStateManager.get_scenario_progress()
            result_ui.show_scenario_results(results, progress)
        else:
            result_ui.show_experiment_results(results)

func hide_dialog():
    """ダイアログを非表示"""
    is_dialog_active = false
    xr_ui_panel.visible = false

func hide_result_ui():
    """ResultUIを非表示"""
    is_result_ui_active = false
    xr_ui_panel.visible = false

func _on_dialog_ended():
    """ダイアログ終了時の処理"""
    hide_dialog()

# ResultUIのシグナルハンドラー
func _on_result_next_pressed():
    """Next/Finishボタンが押された時の処理"""
    hide_result_ui()
    
    # seating.gdに処理を委譲
    var seating_scene = get_tree().get_first_node_in_group("seating")
    if seating_scene and seating_scene.has_method("_on_next_pressed"):
        seating_scene._on_next_pressed()

func _on_result_retry_pressed():
    """Retryボタンが押された時の処理"""
    hide_result_ui()
    
    # seating.gdに処理を委譲
    var seating_scene = get_tree().get_first_node_in_group("seating")
    if seating_scene and seating_scene.has_method("_on_retry_pressed"):
        seating_scene._on_retry_pressed()

func _on_result_back_to_menu_pressed():
    """Back to Menuボタンが押された時の処理"""
    hide_result_ui()
    
    # seating.gdに処理を委譲
    var seating_scene = get_tree().get_first_node_in_group("seating")
    if seating_scene and seating_scene.has_method("_on_back_to_menu_pressed"):
        seating_scene._on_back_to_menu_pressed()

func _on_seat_available():
    if not is_dialog_active and not is_result_ui_active:
        seat_available.emit()

func _on_seat_unavailable():
    if not is_dialog_active and not is_result_ui_active:
        seat_unavailable.emit()

func attempt_sit():
    if back_area_detector.can_sit() and not is_dialog_active and not is_result_ui_active:
        var seat_position = back_area_detector.get_current_seat_position()
        start_sitting_animation(seat_position)

func _on_wait_timer_timeout():
    seating_completed.emit()

func start_sitting_animation(target_position: Vector3):
    is_camera_tweening = true
    hide_can_sit_down_icon()
    
    var final_position = Vector3(target_position.x, -0.4, target_position.z)
    velocity = Vector3.ZERO
    seat_id = back_area_detector.get_current_seat_id()
    
    var current_head_rotation = head.rotation
    var target_rotation = Vector3(0.0, current_head_rotation.y, current_head_rotation.z)
    
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.set_parallel(true)
    
    tween.tween_property(self, "global_position", final_position, 1.5)
    tween.tween_property(head, "rotation", target_rotation, 1.5)
    tween.tween_callback(_on_sitting_animation_completed)

func show_can_sit_down_icon():
    if is_camera_tweening or is_sitting or is_dialog_active or is_result_ui_active:
        return
    can_sit_down_icon.visible = true

func hide_can_sit_down_icon():
    can_sit_down_icon.visible = false

func _on_sitting_animation_completed():
    is_camera_tweening = false
    is_sitting = true
    
    sat_down.emit(global_position)
    wait_timer.start()

func setup_initial_position():
    var room = DataRepository.room_repository.get_current_room()
    if room:
        global_position = room.player_spawn_position
        xr_origin.rotation_degrees.y = -room.player_spawn_rotation
        pivot.rotation_degrees.y = -room.player_spawn_rotation
    print("Initial position set to: ", global_position, " with rotation: ", xr_origin.rotation_degrees.y)

func get_seat_id() -> String:
    return seat_id
