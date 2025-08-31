# scripts/ceil_generator.gd
class_name CeilGenerator
extends RefCounted

var tile_size: float = 1.2
var base_color: Color = Color(0.9, 0.9, 0.9)

func _init():
    set_base_color(Color(0.9, 0.9, 0.9))

func create_ceiling(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    var ceiling_tiles: Array[MeshInstance3D] = []
    ceiling_tiles = create_tiled_ceiling(parent_node, room)
    return ceiling_tiles

func create_tiled_ceiling(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    var ceiling_tiles: Array[MeshInstance3D] = []
    
    var tiles_x = int(ceil(room.size.x / tile_size))
    var tiles_z = int(ceil(room.size.z / tile_size))
    
    for x in range(tiles_x):
        for z in range(tiles_z):
            var tile = create_ceiling_tile(parent_node, x, z, room)
            ceiling_tiles.append(tile)
    
    return ceiling_tiles

func create_ceiling_tile(parent_node: Node3D, tile_x: int, tile_z: int, room: RoomRepository.Room) -> MeshInstance3D:
    var tile_mesh = MeshInstance3D.new()
    var quad_mesh = QuadMesh.new()
    quad_mesh.size = Vector2(tile_size, tile_size)
    tile_mesh.mesh = quad_mesh
    
    var pos_x = tile_x * tile_size + tile_size * 0.5
    var pos_z = tile_z * tile_size + tile_size * 0.5
    tile_mesh.position = Vector3(pos_x, room.size.y, pos_z)
    tile_mesh.rotation_degrees.x = 90
    
    tile_mesh.name = "CeilingTile_" + str(tile_x) + "_" + str(tile_z)

    # color設定
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
    
    # フィルター設定
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

    tile_mesh.material_override = material

    # ライトマップ用設定
    tile_mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    tile_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

    parent_node.add_child(tile_mesh)
    
    return tile_mesh

func cleanup_ceiling(parent_node: Node3D):
    var children_to_remove = []
    for child in parent_node.get_children():
        if child.name.begins_with("Ceiling"):
            children_to_remove.append(child)
    
    for child in children_to_remove:
        child.queue_free()

func regenerate_ceiling(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    cleanup_ceiling(parent_node)
    await parent_node.get_tree().process_frame
    return create_ceiling(parent_node, room)

func set_tile_size(size: float):
    tile_size = size

func set_base_color(color: Color):
    base_color = color