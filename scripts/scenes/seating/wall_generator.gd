# scripts/wall_generator.gd
class_name WallGenerator
extends RefCounted

var wall_thickness: float = 0.3
var base_color: Color = Color(0.9, 0.9, 0.9)

# ベースボード設定
var baseboard_height: float = 0.15
var baseboard_depth: float = 0.05
var baseboard_color: Color = Color(0.35, 0.35, 0.35)

func _init():
    set_base_color(Color(0.9, 0.9, 0.9))

func create_walls(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    var wall_meshes: Array[MeshInstance3D] = []
    cleanup_walls(parent_node)
    
    var wall_height = room.size.y
    var wall_material = create_wall_material()
    var baseboard_material = create_baseboard_material()
    
    var wall_configs = [
        {
            "name": "NorthWall",
            "size": Vector3(room.size.x, wall_height, wall_thickness),
            "position": Vector3(room.size.x * 0.5, wall_height * 0.5, -wall_thickness * 0.5),
            "material": wall_material,
            "baseboard_size": Vector3(room.size.x, baseboard_height, baseboard_depth),
            "baseboard_position": Vector3(room.size.x * 0.5, baseboard_height * 0.5, -baseboard_depth * 0.5 + 0.01)
        },
        {
            "name": "SouthWall", 
            "size": Vector3(room.size.x, wall_height, wall_thickness),
            "position": Vector3(room.size.x * 0.5, wall_height * 0.5, room.size.z + wall_thickness * 0.5),
            "material": wall_material,
            "baseboard_size": Vector3(room.size.x, baseboard_height, baseboard_depth),
            "baseboard_position": Vector3(room.size.x * 0.5, baseboard_height * 0.5, room.size.z + baseboard_depth * 0.5 - 0.01)
        },
        {
            "name": "WestWall",
            "size": Vector3(wall_thickness, wall_height, room.size.z),
            "position": Vector3(-wall_thickness * 0.5, wall_height * 0.5, room.size.z * 0.5),
            "material": wall_material,
            "baseboard_size": Vector3(baseboard_depth, baseboard_height, room.size.z),
            "baseboard_position": Vector3(-baseboard_depth * 0.5 + 0.01, baseboard_height * 0.5, room.size.z * 0.5)
        },
        {
            "name": "EastWall",
            "size": Vector3(wall_thickness, wall_height, room.size.z),
            "position": Vector3(room.size.x + wall_thickness * 0.5, wall_height * 0.5, room.size.z * 0.5),
            "material": wall_material,
            "baseboard_size": Vector3(baseboard_depth, baseboard_height, room.size.z),
            "baseboard_position": Vector3(room.size.x + baseboard_depth * 0.5 - 0.01, baseboard_height * 0.5, room.size.z * 0.5)
        }
    ]
    
    for config in wall_configs:
        var wall_mesh = create_wall(parent_node, config)
        wall_meshes.append(wall_mesh)
    
        # ベースボードを作成
        var baseboard_mesh = create_baseboard(parent_node, config, baseboard_material)
        wall_meshes.append(baseboard_mesh)
    
    return wall_meshes

func create_wall_material() -> StandardMaterial3D:
    var material = StandardMaterial3D.new()
    material.albedo_color = base_color
    material.roughness = 0.8
    material.metallic = 0.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    
    material.emission_enabled = false
    
    # UV設定を最適化
    material.uv1_scale = Vector3(1.0, 1.0, 1.0)
    material.uv1_offset = Vector3(0.0, 0.0, 0.0)
    
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    
    return material

func create_baseboard_material() -> StandardMaterial3D:
    var material = StandardMaterial3D.new()
    material.albedo_color = baseboard_color
    material.roughness = 0.7  # 壁より少し光沢を出す
    material.metallic = 0.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    
    material.emission_enabled = false
    
    # ベースボード用のUV設定
    material.uv1_scale = Vector3(2.0, 1.0, 1.0)  # 横方向を2倍にして細かいテクスチャ
    material.uv1_offset = Vector3(0.0, 0.0, 0.0)
    
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    
    return material

func create_wall(parent_node: Node3D, config: Dictionary) -> MeshInstance3D:
    var wall_mesh = MeshInstance3D.new()
    var box_mesh = BoxMesh.new()
    box_mesh.size = config.size
    
    # ライトマップ用のUV設定を改善
    box_mesh.subdivide_width = max(1, int(config.size.x / 2.0))
    box_mesh.subdivide_height = max(1, int(config.size.y / 2.0))
    box_mesh.subdivide_depth = max(1, int(config.size.z / 2.0))
    
    wall_mesh.mesh = box_mesh
    wall_mesh.material_override = config.material
    wall_mesh.position = config.position
    wall_mesh.name = config.name + "_Mesh"
    
    # ライトマップ用の設定
    wall_mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    wall_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    
    # ライトマップ解像度を向上させる
    wall_mesh.gi_lightmap_texel_scale = 1.0
    
    parent_node.add_child(wall_mesh)
    
    # コリジョンも作成
    create_wall_collision(parent_node, config)
    
    return wall_mesh

func create_baseboard(parent_node: Node3D, wall_config: Dictionary, baseboard_material: StandardMaterial3D) -> MeshInstance3D:
    var baseboard_mesh = MeshInstance3D.new()
    var box_mesh = BoxMesh.new()
    box_mesh.size = wall_config.baseboard_size
    
    # ベースボード用の細分化設定
    box_mesh.subdivide_width = max(1, int(wall_config.baseboard_size.x / 1.0))
    box_mesh.subdivide_height = 1  # 高さは低いので1のまま
    box_mesh.subdivide_depth = 1   # 奥行きも薄いので1のまま
    
    baseboard_mesh.mesh = box_mesh
    baseboard_mesh.material_override = baseboard_material
    baseboard_mesh.position = wall_config.baseboard_position
    baseboard_mesh.name = wall_config.name + "_Baseboard"
    
    # ライトマップ用の設定
    baseboard_mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    baseboard_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    baseboard_mesh.gi_lightmap_texel_scale = 2.0  # ベースボードは細かく
    
    parent_node.add_child(baseboard_mesh)
    
    # ベースボード用のコリジョンも作成
    create_baseboard_collision(parent_node, wall_config)
    
    return baseboard_mesh

func create_wall_collision(parent_node: Node3D, config: Dictionary):
    var wall_body = StaticBody3D.new()
    wall_body.name = config.name + "_Collision"
    wall_body.position = config.position
    
    var wall_collision = CollisionShape3D.new()
    var wall_shape = BoxShape3D.new()
    wall_shape.size = config.size
    wall_collision.shape = wall_shape
    
    wall_body.add_child(wall_collision)
    parent_node.add_child(wall_body)

func create_baseboard_collision(parent_node: Node3D, wall_config: Dictionary):
    var baseboard_body = StaticBody3D.new()
    baseboard_body.name = wall_config.name + "_BaseboardCollision"
    baseboard_body.position = wall_config.baseboard_position
    
    var baseboard_collision = CollisionShape3D.new()
    var baseboard_shape = BoxShape3D.new()
    baseboard_shape.size = wall_config.baseboard_size
    baseboard_collision.shape = baseboard_shape
    
    baseboard_body.add_child(baseboard_collision)
    parent_node.add_child(baseboard_body)

func cleanup_walls(parent_node: Node3D):
    var children_to_remove = []
    for child in parent_node.get_children():
        if child.name.ends_with("_Mesh") or \
           child.name.ends_with("_Collision") or \
           child.name.ends_with("_Baseboard") or \
           child.name.ends_with("_BaseboardCollision"):
            children_to_remove.append(child)
    
    for child in children_to_remove:
        child.queue_free()

func regenerate_walls(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    cleanup_walls(parent_node)
    await parent_node.get_tree().process_frame
    return create_walls(parent_node, room)

# ベースボードの設定メソッド
func set_baseboard_height(height: float):
    """ベースボードの高さを設定"""
    baseboard_height = height

func set_baseboard_depth(depth: float):
    """ベースボードの奥行きを設定"""
    baseboard_depth = depth

func set_baseboard_color(color: Color):
    """ベースボードの色を設定"""
    baseboard_color = color

# 既存の設定メソッド
func set_wall_thickness(thickness: float):
    wall_thickness = thickness

func set_base_color(color: Color):
    base_color = color
