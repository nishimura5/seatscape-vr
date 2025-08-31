# scripts/3d/seat_3d.gd
extends Node3D

@onready var available_area_detector: Area3D = $AvailableAreaDetector
@onready var available_area_collision: CollisionShape3D = $AvailableAreaDetector/AvailableAreaCollision

var seat_mesh: Node3D
var seat_data: SeatRepository.Seat
var occupied_material: StandardMaterial3D

func _ready():
    setup_materials()

func setup_materials():
    occupied_material = StandardMaterial3D.new()
    occupied_material.albedo_color = Color.RED
    occupied_material.roughness = 1.0
    occupied_material.metallic = 0.0
    occupied_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

func setup_area():
    # 座席メッシュをロードしてインスタンス化
    seat_mesh = load("res://data/3d/" + seat_data.mesh_id + ".blend").instantiate()
    
    # Available Areaのコリジョン設定
    var available_area_mesh = find_mesh_by_name("available_area")
    available_area_collision.shape = available_area_mesh.create_convex_shape()
    
    # コリジョンレイヤー設定
    available_area_detector.collision_layer = 0x08
    available_area_detector.collision_mask = 0x02
    available_area_detector.name = "AvailableArea_" + seat_data.id
    
    # 座席メッシュのライトマップ設定
    setup_seat_rendering()
    
    # シーンに追加
    add_child(seat_mesh)

func setup_seat_rendering():
    var seat_mesh_instance = find_mesh_instance_by_name("seat")
    seat_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    seat_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    
func set_seat_data(seat: SeatRepository.Seat):
    seat_data = seat
    call_deferred("setup_area")

func find_mesh_by_name(mesh_name: String) -> Mesh:
    var mesh_instance = search_node(seat_mesh, mesh_name)
    return mesh_instance.mesh

func find_mesh_instance_by_name(mesh_name: String) -> MeshInstance3D:
    var mesh_instance = search_node(seat_mesh, mesh_name)
    return mesh_instance

func search_node(node: Node, target_name: String) -> MeshInstance3D:
    if node.name == target_name and node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var result = search_node(child, target_name)
        if result:
            return result
    return null

func set_occupied_state(occupied: bool):
    var target_mesh = find_mesh_instance_by_name("seat")

    if occupied:
        target_mesh.material_override = occupied_material

    # AvailableAreaの有効/無効切り替え
    if available_area_detector:
        available_area_detector.monitoring = not occupied
        available_area_detector.monitorable = not occupied

func find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    
    if node is MeshInstance3D:
        result.append(node)
    
    for child in node.get_children():
        result.append_array(find_all_mesh_instances(child))
    
    return result

func get_seat_id() -> String:
    return seat_data.id if seat_data else ""
