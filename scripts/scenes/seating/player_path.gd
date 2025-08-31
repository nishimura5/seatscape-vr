# scripts/player_path.gd
extends Node3D

const PATH_HEIGHT: float = 0.2

var path_spheres: Array[MeshInstance3D] = []

func _ready():
    visible = false

func draw_path(movement_log: Array[Dictionary]):
    clear_path()
    
    if movement_log.size() == 0:
        return
    
    var maker_mesh = load("res://data/3d/path_marker.blend").instantiate()

    # 各サンプル点にスフィアを配置
    for i in range(movement_log.size()):
        var sphere_mesh = maker_mesh.duplicate() as Node3D
        var log_entry = movement_log[i]
        sphere_mesh.position = Vector3(log_entry.position.x, PATH_HEIGHT, log_entry.position.z)
        add_child(sphere_mesh)
        path_spheres.append(sphere_mesh)


func clear_path():
    for sphere in path_spheres:
        if is_instance_valid(sphere):
            sphere.queue_free()
    path_spheres.clear()

func set_path_visibility(visible_state: bool):
    visible = visible_state