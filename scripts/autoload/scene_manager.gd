# scripts/autoload/scene_manager.gd
extends Node

var scene_paths: Dictionary = {
    "title": "res://scenes/title.tscn",
    "room_selection": "res://scenes/room_selection.tscn",
    "protocol_selection": "res://scenes/protocol_selection.tscn",
    "assignment": "res://scenes/assignment.tscn", 
    "seating": "res://scenes/seating.tscn",
    "narrative": "res://scenes/narrative.tscn"
}

var is_scene_changing: bool = false
var current_scene_name: String = ""

func _ready():
    call_deferred("initialize_first_scene")

func initialize_first_scene():
    change_scene("title")

func change_scene(tar_scene_name: String):
    if is_scene_changing:
        print("シーン変更中のため、リクエストを無視: ", tar_scene_name)
        return

    if not scene_paths.has(tar_scene_name):
        print("シーンが見つかりません: ", tar_scene_name)
        return
    
    is_scene_changing = true

    var tar_scene_path = scene_paths[tar_scene_name]

    # 3Dシーン以外では確実にデスクトップモードに設定
    if not is_3d_scene(tar_scene_name):
        XRManager.ensure_desktop_mode()

    if is_3d_scene(tar_scene_name):
        await load_3d_scene(tar_scene_path)
    else:
        await load_2d_scene(tar_scene_path)

    current_scene_name = tar_scene_name
    is_scene_changing = false
    
    EventBus.scene_changed.emit(tar_scene_name)

func is_3d_scene(scene_name: String) -> bool:
    """3Dシーンかどうかを判定"""
    return scene_name == "seating"

func load_2d_scene(scene_path: String):
    var was_3d_scene = is_3d_scene_active()
    if get_tree().current_scene.name != "Main":
        get_tree().change_scene_to_file("res://scenes/main.tscn")
        await get_tree().process_frame
        if was_3d_scene:
            await get_tree().process_frame

    var main_node = get_main_node()
    if not main_node:
        print("メインノードが見つかりません")
        return
    
    clear_main_children(main_node)
    
    var scene_resource = load(scene_path)
    if scene_resource:
        var new_scene = scene_resource.instantiate()
        main_node.add_child(new_scene)
        await get_tree().process_frame

func load_3d_scene(scene_path: String):
    get_tree().change_scene_to_file(scene_path)
    await get_tree().process_frame
    print("3Dシーン読み込み完了: ", scene_path)

func get_main_node() -> Control:
    var main_node = get_tree().get_first_node_in_group("main")
    if not main_node:
        var root = get_tree().current_scene
        if root and root.name == "Main":
            main_node = root
    return main_node

func clear_main_children(main_node: Control):
    for child in main_node.get_children():
        child.queue_free()
    
    if main_node.get_child_count() > 0:
        await get_tree().process_frame

func get_current_scene_name() -> String:
    if not current_scene_name.is_empty():
        return current_scene_name
        
    var current = get_tree().current_scene
    if current:
        if current.name == "Main":
            var main_node = get_main_node()
            if main_node and main_node.get_child_count() > 0:
                return main_node.get_child(0).name
        return current.name
    return ""

func is_3d_scene_active() -> bool:
    var scene_name = get_tree().current_scene.name
    return scene_name == "Seating"