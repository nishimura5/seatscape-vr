# scripts/seating.gd
extends Node3D

@onready var environment: Node3D = $Environment
@onready var player_manager : Node = $PlayerManager
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var player_path: Node3D = $Environment/PlayerPath
@onready var npcs_container: Node3D = $Environment/NpcsContainer

enum CameraMode {
    FIRST_PERSON,
    OVERVIEW_RESULT
}

var current_camera_mode: CameraMode = CameraMode.FIRST_PERSON
var is_personal_space_visible: bool = false
var is_in_intimate_zone: bool = false
var player: Node3D

func _ready():
    EventBus.seating_started.emit()
    # グループに追加してXRプレイヤーからアクセス可能にする
    add_to_group("seating")
    
    setup_player_mode()
    initialize_3d_scene()
    setup_connections()

    show_initial_dialog()

func setup_player_mode():
    """プレイヤーモード（XRまたはデスクトップ）を設定"""
    if XRManager.is_xr_available:
        if XRManager.initialize_xr():
            player = player_manager.get_node("XrPlayer3D")
            player_manager.remove_child(player_manager.get_node("DesktopPlayer3D"))
        else:
            player = player_manager.get_node("DesktopPlayer3D")
            player_manager.remove_child(player_manager.get_node("XrPlayer3D"))
    else:
        XRManager.initialize_desktop_for_seating()
        player = player_manager.get_node("DesktopPlayer3D")
        player_manager.remove_child(player_manager.get_node("XrPlayer3D"))
    PlayerDataManager.start_movement_sampling(player)

    # head height offset 1.0m +/-
    player.set_height(1.6)

func setup_connections():
    player.seating_completed.connect(_on_seating_completed)

    player.result_ui.next_pressed.connect(_on_next_pressed)
    player.result_ui.retry_pressed.connect(_on_retry_pressed)
    player.result_ui.back_to_menu_pressed.connect(_on_back_to_menu_pressed)

    player.seat_available.connect(_on_seat_available)
    player.seat_unavailable.connect(_on_seat_unavailable)
    player.sat_down.connect(_on_sat_down)

    player.personal_space_detector.zone_entered.connect(_on_personal_space_entered)
    player.personal_space_detector.zone_exited.connect(_on_personal_space_exited)

func initialize_3d_scene():
    environment.setup_environment()
    call_deferred("capture_mouse")

func capture_mouse():
    if current_camera_mode == CameraMode.FIRST_PERSON and XRManager.is_desktop_mode():
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_initial_dialog():
    var current_room_id = GameStateManager.get_current_scenario_room_id()
    player.show_dialog(current_room_id)

func _on_seating_completed():
    show_player_path()
    if XRManager.is_desktop_mode():
        switch_to_result_mode_desktop()
    else:
        switch_to_result_mode_xr()

func _on_seat_available():
    if player.has_method("show_can_sit_down_icon"):
        player.show_can_sit_down_icon()

func _on_seat_unavailable():
    if player.has_method("hide_can_sit_down_icon"):
        player.hide_can_sit_down_icon()

func _on_personal_space_entered(zone_id: String, zone_level: String):
    print("Zone entered: ", zone_id, " with level: ", zone_level)
    PlayerDataManager.update_player_zone_status(zone_id, zone_level)
    if zone_level == "intimate" and not player.is_sitting and not is_in_intimate_zone:
        PlayerDataManager.log_intimate_violation(zone_id, global_position, Time.get_unix_time_from_system())
        is_in_intimate_zone = true
    elif zone_level != "intimate" and zone_level != "personal":
        is_in_intimate_zone = false

func _on_personal_space_exited(zone_id: String, zone_level: String):
    print("Zone exited: ", zone_id, " with level: ", zone_level)
    PlayerDataManager.update_player_zone_status(zone_id, zone_level)

func _on_sat_down(seat_pos):
    var seat_id = player.get_seat_id()
    environment.set_seat_occupied_state(seat_id, true)

    PlayerDataManager.set_final_seat(seat_id, seat_pos)

    print("_on_sat_down called with seat_pos: ", seat_pos, " and seat_id: ", seat_id)

func switch_to_result_mode_desktop():
    current_camera_mode = CameraMode.OVERVIEW_RESULT
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

    # stop player movement and input processing    
    player.set_physics_process(false)
    player.set_process_input(false)

    hide_ceiling_and_walls()
    setup_overview_camera()
    overview_camera.current = true
    
    personal_space_visibility(true)
    player.show_result()

func switch_to_result_mode_xr():
    personal_space_visibility(true)
    # XRプレイヤーの show_result() メソッドを呼び出す
    player.show_result()

func setup_overview_camera():
    if not overview_camera:
        return
        
    var room = DataRepository.room_repository.get_current_room()
    if room:
        var center = Vector3(room.size.x * 0.5, 0, room.size.z * 0.5)
        var height = max(room.size.x, room.size.z) * 1.4
        
        overview_camera.position = center + Vector3(0, height, height * 0.7)
        overview_camera.look_at(center, Vector3.UP)

        overview_camera.fov = 30.0

func hide_ceiling_and_walls():
    if environment and environment.has_method("set_ceiling_visibility"):
        environment.set_ceiling_visibility(false)
    if environment and environment.has_method("set_wall_visibility"):
        environment.set_wall_visibility(false)

func show_player_path():
    if not player_path:
        return
    
    var movement_data = PlayerDataManager.get_movement_log()
    if movement_data.size() > 0:
        player_path.draw_path(movement_data)
        player_path.visible = true

# ResultUIからのシグナルハンドラー
func _on_retry_pressed():
    if GameStateManager.is_scenario_mode():
        cleanup_scene()
        GameStateManager.restart_current_scenario_room()
    else:
        cleanup_scene()
        PlayerDataManager.reset_data()
        var current_room_id = GameStateManager.get_selected_room_id()
        
        if not current_room_id.is_empty():
            DataRepository.clear_all_data()
            StageInitializer.initialize_room_data(current_room_id)
            StageInitializer.initialize_npc_data()
            StageInitializer.initialize_default_assignment(current_room_id)
            
            await get_tree().process_frame
            SceneManager.change_scene("seating")
        else:
            GameStateManager.transition_to(GameStateManager.GameState.ROOM_SELECTION)

func _on_next_pressed():
    var is_last_room = GameStateManager.is_last_scenario_room()
    
    if is_last_room:
        cleanup_scene()
        GameStateManager.complete_scenario()
    else:
        cleanup_scene()
        GameStateManager.proceed_to_next_scenario_room()

func _on_back_to_menu_pressed():
    cleanup_scene()
    DataRepository.clear_all_data()
    PlayerDataManager.reset_data()
    
    if GameStateManager.is_scenario_mode():
        GameStateManager.transition_to(GameStateManager.GameState.TITLE)
    else:
        GameStateManager.transition_to(GameStateManager.GameState.ROOM_SELECTION)

func cleanup_scene():
    """シーン終了時のクリーンアップ"""
    if XRManager.is_desktop_mode():
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
    match current_camera_mode:
        CameraMode.FIRST_PERSON:
            handle_first_person_input(event)
        CameraMode.OVERVIEW_RESULT:
            handle_result_input(event)

    if event is InputEventKey and event.pressed and event.keycode == KEY_L:
        environment.test_lightmap_without_lights()

func handle_first_person_input(event):
    if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_Q):
        cleanup_scene()
        GameStateManager.transition_to(GameStateManager.GameState.ASSIGNMENT)
    
    if XRManager.is_desktop_mode() and event is InputEventMouseButton and event.pressed:
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func handle_result_input(event):
    if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
        personal_space_visibility(not is_personal_space_visible)

func personal_space_visibility(is_visible: bool):
    is_personal_space_visible = is_visible
    for npc in npcs_container.get_children():
        npc.set_personal_space_visibility(is_visible)

func _exit_tree():
    """ノード削除時のクリーンアップ"""
    cleanup_scene()
