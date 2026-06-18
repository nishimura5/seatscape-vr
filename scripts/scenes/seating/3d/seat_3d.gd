# scripts/3d/seat_3d.gd
extends Node3D

@onready var available_area_detector: Area3D = $AvailableAreaDetector
@onready var available_area_collision: CollisionShape3D = $AvailableAreaDetector/AvailableAreaCollision

var seat_mesh: Node3D
var seat_data: SeatRepository.Seat
var occupied_material: StandardMaterial3D

const COLONLY_SUFFIX := "-colonly"

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
    var seat_scene = Main.load_data_packed_scene("3d/furniture/" + seat_data.mesh_id + ".glb")
    if not seat_scene:
        print("座席メッシュを読み込めませんでした: " + "3d/furniture/" + seat_data.mesh_id + ".glb")
        return
    seat_mesh = seat_scene.instantiate()
    setup_colonly_colliders()
    
    # Available Areaのコリジョン設定
    var available_area_mesh = find_mesh_by_name("available_area")
    if not available_area_mesh:
        print("available_areaメッシュが見つかりません: " + seat_data.id)
        push_error("available_areaメッシュが見つかりません: " + seat_data.id)
        return
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
    var seat_mesh_instance := find_mesh_instance_by_name("seat")
    if not seat_mesh_instance:
        seat_mesh_instance = find_first_mesh_instance(seat_mesh)
        if seat_mesh_instance:
            push_warning("seatメッシュ名が見つからないため先頭MeshInstance3Dを使用: " + seat_mesh_instance.name)
    if not seat_mesh_instance:
        print("seatメッシュが見つかりません: " + seat_data.id)
        push_error("seatメッシュが見つかりません: " + seat_data.id)
        return
    seat_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    seat_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    
func set_seat_data(seat: SeatRepository.Seat):
    seat_data = seat
    call_deferred("setup_area")

func find_mesh_by_name(mesh_name: String) -> Mesh:
    var mesh_instance := search_node(seat_mesh, mesh_name)
    if not mesh_instance:
        return null
    return mesh_instance.mesh

func find_mesh_instance_by_name(mesh_name: String) -> MeshInstance3D:
    var mesh_instance = search_node(seat_mesh, mesh_name)
    return mesh_instance

func find_first_mesh_instance(node: Node) -> MeshInstance3D:
    if node == null:
        return null
    if node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var found := find_first_mesh_instance(child)
        if found:
            return found
    return null

func search_node(node: Node, target_name: String) -> MeshInstance3D:
    if node.name == target_name and node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var result = search_node(child, target_name)
        if result:
            return result
    return null

func setup_colonly_colliders():
    if seat_mesh == null:
        return

    var colonly_meshes: Array[MeshInstance3D] = []
    collect_colonly_meshes(seat_mesh, colonly_meshes)

    for mesh_instance in colonly_meshes:
        replace_colonly_mesh_with_static_body(mesh_instance)

func collect_colonly_meshes(node: Node, result: Array[MeshInstance3D]):
    if node is MeshInstance3D and is_colonly_node_name(String(node.name)):
        result.append(node as MeshInstance3D)

    for child in node.get_children():
        collect_colonly_meshes(child, result)

func is_colonly_node_name(node_name: String) -> bool:
    return node_name.to_lower().ends_with(COLONLY_SUFFIX)

func get_colonly_base_name(node_name: String) -> String:
    if not is_colonly_node_name(node_name):
        return node_name
    var base_name := node_name.substr(0, node_name.length() - COLONLY_SUFFIX.length())
    return base_name if not base_name.is_empty() else node_name

func replace_colonly_mesh_with_static_body(mesh_instance: MeshInstance3D):
    if mesh_instance.mesh == null:
        push_warning("-colonlyメッシュにMeshがありません: " + String(mesh_instance.name))
        return

    var collision_shape_resource := mesh_instance.mesh.create_trimesh_shape()
    if collision_shape_resource == null:
        push_warning("-colonlyメッシュからCollisionShapeを作成できません: " + String(mesh_instance.name))
        return

    var base_name := get_colonly_base_name(String(mesh_instance.name))
    var static_body := StaticBody3D.new()
    static_body.name = base_name
    static_body.transform = mesh_instance.transform

    var collision_shape := CollisionShape3D.new()
    collision_shape.name = base_name + "_CollisionShape"
    collision_shape.shape = collision_shape_resource
    static_body.add_child(collision_shape)

    var parent := mesh_instance.get_parent()
    if parent:
        var original_index := mesh_instance.get_index()
        parent.add_child(static_body)
        parent.move_child(static_body, original_index)
    elif mesh_instance == seat_mesh:
        seat_mesh = static_body
    else:
        push_warning("-colonlyメッシュの親ノードがありません: " + String(mesh_instance.name))
        return

    var children := mesh_instance.get_children()
    for child in children:
        mesh_instance.remove_child(child)
        static_body.add_child(child)

    if parent:
        parent.remove_child(mesh_instance)
    mesh_instance.free()

func set_occupied_state(occupied: bool):
    var target_mesh := find_mesh_instance_by_name("seat")
    if not target_mesh:
        target_mesh = find_first_mesh_instance(seat_mesh)

    if occupied and target_mesh:
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
