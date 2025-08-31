# scripts/3d/desktop_player_3d.gd
extends CharacterBody3D

@onready var player_model: Node3D = $player
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var player_collision: CollisionShape3D = $PlayerCollision
@onready var back_area_detector: Node = $BackAreaDetector
@onready var back_area_collision: CollisionShape3D = $BackAreaDetector/BackAreaCollision
@onready var personal_space_detector: Area3D = $PersonalSpaceDetector
@onready var personal_space_collision: CollisionShape3D = $PersonalSpaceDetector/PersonalSpaceCollision
@onready var dialog_system: Control = $UILayer/DialogSystem
@onready var can_sit_down_icon: TextureRect = $UILayer/CanSitDownIcon
@onready var dissolve_overlay: ColorRect = $UILayer/DissolveOverlay
@onready var result_ui: Control = $UILayer/UIOverlay/ResultUI

# Movement constants
const WALK_SPEED = 1.0
const SENSITIVITY = 0.002
const GAMEPAD_SENSITIVITY = 2.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Height adjustment
var target_camera_height: float = 1.0

# Sitting state
var is_sitting: bool = false
var is_camera_tweening: bool = false
var seat_id: String = ""
var wait_timer: Timer

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

func _unhandled_input(event):
    if not is_sitting and not is_camera_tweening:
        # rotate mouse
        if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            handle_mouse_look(event)
        if event.is_action_pressed("ui_accept"):
            attempt_sit()

func _physics_process(delta):
    if not is_sitting and not is_camera_tweening:
        handle_movement(delta)
        # rotate gamepad
        handle_gamepad_look(delta)

func handle_mouse_look(event: InputEventMouseMotion):
    rotate_y(-event.relative.x * SENSITIVITY)
    head.rotate_x(-event.relative.y * SENSITIVITY)
    head.rotation.x = clamp(head.rotation.x, -PI, PI)

func handle_gamepad_look(delta: float):
    var look_input = Vector2(
        Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
        Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
    )
    var deadzone = 0.1
    if look_input.length() < deadzone:
        return
    
    var look_sensitivity = GAMEPAD_SENSITIVITY * delta
    rotate_y(-look_input.x * look_sensitivity)
    head.rotate_x(-look_input.y * look_sensitivity)
    head.rotation.x = clamp(head.rotation.x, -PI, PI)

func handle_movement(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta
    
    var input_dir = get_input_direction()
    
    if input_dir != Vector2.ZERO:
        var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
        velocity.x = direction.x * WALK_SPEED
        velocity.z = direction.z * WALK_SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 10)
        velocity.z = move_toward(velocity.z, 0, WALK_SPEED * delta * 10)
    move_and_slide()

func get_input_direction() -> Vector2:
    var input_dir = Vector2.ZERO
    if Input.is_action_pressed("ui_right"):
        input_dir.x += 1
    if Input.is_action_pressed("ui_left"):
        input_dir.x -= 1
    if Input.is_action_pressed("ui_down"):
        input_dir.y += 1
    if Input.is_action_pressed("ui_up"):
        input_dir.y -= 1
    return input_dir

func set_height(target_height: float):
    target_camera_height = target_height
    apply_height_offset()

func apply_height_offset():
    head.position.y = target_camera_height

func show_dialog(dialog_key: String):
    DialogManager.start_dialog(dialog_key, dialog_system)

func show_result():
    var result_manager = ResultManager.new()
    if result_manager:
        result_manager.calculate_results()
        var results = result_manager.get_results()
        
        if GameStateManager.is_scenario_mode():
            var progress = GameStateManager.get_scenario_progress()
            result_ui.show_scenario_results(results, progress)
        else:
            result_ui.show_experiment_results(results)

func _on_seat_available():
    seat_available.emit()

func _on_seat_unavailable():
    seat_unavailable.emit()

func attempt_sit():
    if back_area_detector.can_sit():
        var seat_position = back_area_detector.get_current_seat_position()
        start_sitting_animation(seat_position)

func _on_wait_timer_timeout():
    start_dissolve_transition()

func start_dissolve_transition():
    var tween = create_tween()
    dissolve_overlay.visible = true
    tween.tween_property(dissolve_overlay, "modulate:a", 1.0, 1.0)
    tween.tween_callback(_on_dissolve_fade_out_complete)

func _on_dissolve_fade_out_complete():
    dissolve_overlay.visible = false
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
    if is_camera_tweening or is_sitting:
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
        rotation_degrees.y = -room.player_spawn_rotation
    print("Initial position set to: ", global_position, " with rotation: ", rotation_degrees.y)

func get_seat_id() -> String:
    return seat_id
