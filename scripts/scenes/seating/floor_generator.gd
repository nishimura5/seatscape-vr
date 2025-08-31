# scripts/floor_generator.gd
class_name FloorGenerator
extends RefCounted

var tile_size: float = 0.7
var carpet_textures: Array[Texture2D] = []
var base_colors: Array[Color] = [
    Color(0.8, 0.7, 0.6),
    Color(0.7, 0.6, 0.5),
    Color(0.6, 0.7, 0.8),
    Color(0.5, 0.6, 0.7),
    Color(0.7, 0.8, 0.6),
    Color(0.6, 0.7, 0.5),
]

enum ColorStyle {
    NEUTRAL,
    WARM,
    COOL,
    CORPORATE
}

var current_color_style: ColorStyle = ColorStyle.NEUTRAL

func _init():
    load_carpet_textures()
    setup_color_palettes()

func setup_color_palettes():
    pass

func set_color_style(style: ColorStyle):
    current_color_style = style
    base_colors = get_color_palette(style)

func get_color_palette(style: ColorStyle) -> Array[Color]:
    match style:
        ColorStyle.NEUTRAL:
            return [
                Color(0.6, 0.7, 0.8),
                Color(0.7, 0.8, 0.6),
            ]
        ColorStyle.WARM:
            return [
                Color(0.9, 0.7, 0.5),
                Color(0.9, 0.8, 0.7),
            ]
        ColorStyle.COOL:
            return [
                Color(0.7, 0.9, 0.8),
                Color(0.8, 0.8, 0.9),
            ]
        ColorStyle.CORPORATE:
            return [
                Color(0.71, 0.73, 0.74),
                Color(0.81, 0.79, 0.79),
            ]
        _:
            return base_colors

func load_carpet_textures():
    var texture_paths = [
        "res://data/3d/textures/carpet_pattern_h1.png",
        "res://data/3d/textures/carpet_pattern_h2.png", 
        "res://data/3d/textures/carpet_pattern_v1.png",
        "res://data/3d/textures/carpet_pattern_v2.png"
    ]
    
    for path in texture_paths:
        if ResourceLoader.exists(path):
            var texture = load(path)
            # チラつき防止のためミップマップを有効化
            if texture is ImageTexture:
                var image = texture.get_image()
                if image:
                    image.generate_mipmaps()
                    texture.set_image(image)
            carpet_textures.append(texture)

# ライトマップ対応のメイン生成関数
func create_tiled_floor(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    var floor_tiles: Array[MeshInstance3D] = []
    
    # タイルの数を計算
    var tiles_x = int(ceil(room.size.x / tile_size))
    var tiles_z = int(ceil(room.size.z / tile_size))
    
    # 各タイルを生成
    for x in range(tiles_x):
        for z in range(tiles_z):
            var tile = create_floor_tile_for_lightmap(parent_node, x, z)
            floor_tiles.append(tile)
    
    # 床のコリジョンを作成
    create_floor_collision(parent_node, room)
    
    return floor_tiles

func create_floor_tile_for_lightmap(parent_node: Node3D, tile_x: int, tile_z: int) -> MeshInstance3D:
    var tile_mesh = MeshInstance3D.new()
    var quad_mesh = QuadMesh.new()
    quad_mesh.size = Vector2(tile_size, tile_size)
    tile_mesh.mesh = quad_mesh
    
    # タイルの位置を設定
    var pos_x = tile_x * tile_size + tile_size * 0.5
    var pos_z = tile_z * tile_size + tile_size * 0.5
    tile_mesh.position = Vector3(pos_x, 0, pos_z)
    tile_mesh.rotation_degrees.x = -90
    
    # ライトマップ用の設定
    tile_mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
    tile_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    
    # テクスチャと色を適用
    var texture = get_tile_texture(tile_x, tile_z)
    var tile_color = get_tile_color(tile_x, tile_z)
    
    var material = create_lightmap_material(texture, tile_color)
    tile_mesh.material_override = material
    
    tile_mesh.name = "FloorTile_" + str(tile_x) + "_" + str(tile_z)
    parent_node.add_child(tile_mesh)
    
    return tile_mesh

func create_lightmap_material(texture: Texture2D, tile_color: Color) -> StandardMaterial3D:
    var material = StandardMaterial3D.new()
    material.roughness = 1.0
    material.metallic = 0.0
    
    # チラつき防止のためのフィルター設定
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    material.texture_repeat = true

    # ライトマップ用の設定
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

    if texture:
        material.albedo_texture = texture
        material.albedo_color = tile_color
    else:
        material.albedo_color = tile_color
    
    return material

func get_tile_texture(tile_x: int, tile_z: int) -> Texture2D:
    if carpet_textures.is_empty():
        return null
    
    # 4枚のテクスチャを均等に使用するための改善されたアルゴリズム
    var pattern_seed = (tile_x * 17 + tile_z * 31) % 4  # 0-3の範囲で4種類のパターン
    
    if pattern_seed < carpet_textures.size():
        return carpet_textures[pattern_seed]
    else:
        return carpet_textures[0]  # フォールバック

func get_tile_color(tile_x: int, tile_z: int) -> Color:
    if base_colors.is_empty():
        return Color.WHITE
    
    # テクスチャとは独立した色のバリエーション
    var color_seed = (tile_x * 7 + tile_z * 13) % base_colors.size()
    return base_colors[color_seed]

func is_tile_horizontal(tile_x: int, tile_z: int) -> bool:
    return (tile_x + tile_z) % 2 == 0

func create_floor_collision(parent_node: Node3D, room: RoomRepository.Room):
    var floor_body = StaticBody3D.new()
    floor_body.name = "FloorCollision"
    
    var floor_collision = CollisionShape3D.new()
    var floor_shape = BoxShape3D.new()
    floor_shape.size = Vector3(room.size.x, 0.1, room.size.z)
    floor_collision.shape = floor_shape
    
    floor_body.position = Vector3(room.size.x * 0.5, -0.05, room.size.z * 0.5)
    
    floor_body.add_child(floor_collision)
    parent_node.add_child(floor_body)

func cleanup_floor(parent_node: Node3D):
    var children_to_remove = []
    for child in parent_node.get_children():
        if child.name.begins_with("FloorTile_") or child.name == "FloorCollision":
            children_to_remove.append(child)
    
    for child in children_to_remove:
        child.queue_free()

func regenerate_floor(parent_node: Node3D, room: RoomRepository.Room) -> Array[MeshInstance3D]:
    cleanup_floor(parent_node)
    await parent_node.get_tree().process_frame
    return create_tiled_floor(parent_node, room)
