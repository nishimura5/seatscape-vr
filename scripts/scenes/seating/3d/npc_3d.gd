# scripts/3d/npc_3d.gd
extends Node3D

@onready var name_label: Label3D = $NameLabel
@onready var npc_mesh: Node3D = $NpcMesh
@onready var personal_space_mesh: Node3D = $BlenderImport/PersonalSpaceMesh

@onready var personal_space_container: Node3D = $PersonalSpaceContainer
@onready var intimate_area_detector: Area3D = $PersonalSpaceContainer/IntimateAreaDetector
@onready var personal_area_detector: Area3D = $PersonalSpaceContainer/PersonalAreaDetector
@onready var social_area_detector: Area3D = $PersonalSpaceContainer/SocialAreaDetector

@onready var intimate_visual: MeshInstance3D = $PersonalSpaceContainer/IntimateAreaDetector/IntimateVisual
@onready var personal_visual: MeshInstance3D = $PersonalSpaceContainer/PersonalAreaDetector/PersonalVisual
@onready var social_visual: MeshInstance3D = $PersonalSpaceContainer/SocialAreaDetector/SocialVisual

@onready var intimate_collision: CollisionShape3D = $PersonalSpaceContainer/IntimateAreaDetector/IntimateCollision
@onready var personal_collision: CollisionShape3D = $PersonalSpaceContainer/PersonalAreaDetector/PersonalCollision
@onready var social_collision: CollisionShape3D = $PersonalSpaceContainer/SocialAreaDetector/SocialCollision

@onready var toon_wear_material: ShaderMaterial = load("res://tres/toon_wear_shader_material.tres")
@onready var toon_skin_material: ShaderMaterial = load("res://tres/toon_skin_shader_material.tres")
@onready var toon_head_material: ShaderMaterial = load("res://tres/toon_head_shader_material.tres")
@onready var outline_material: ShaderMaterial = load("res://tres/outline_shader_material.tres")

const NPC_BLEND_SHAPES := {
    "SkA": 1.0,
    "SkB": 0.0,
}
const PERSONAL_SPACE_TEXTURE_PATHS := [
    "3d/helpers/personal_space_line_color.png",
    "3d/textures/personal_space_line_color.png",
]

var npc_data: NpcRepository.Npc
var is_personal_space_visible: bool = false
var personal_space_texture: Texture2D

func _ready():
    setup_toon_materials()

func setup_toon_materials():
    toon_wear_material = toon_wear_material.duplicate() as ShaderMaterial
    toon_skin_material = toon_skin_material.duplicate() as ShaderMaterial
    toon_head_material = toon_head_material.duplicate() as ShaderMaterial

    apply_toon_texture(toon_wear_material, "3d/textures/wear_tex.png")
    apply_toon_texture(toon_skin_material, "3d/textures/skin_tex.png")
    apply_toon_texture(toon_head_material, "3d/textures/head_tex.png")

func apply_toon_texture(material: ShaderMaterial, texture_path: String):
    var texture = Main.load_data_texture(texture_path)
    if texture:
        material.set_shader_parameter("albedo_texture", texture)

func setup_areas():
    setup_area("PSIntimate", intimate_visual, intimate_collision, intimate_area_detector)
    setup_area("PSPersonal", personal_visual, personal_collision, personal_area_detector)
    setup_area("PSSocial", social_visual, social_collision, social_area_detector)

func setup_area(zone_name: String, visual: MeshInstance3D, collision: CollisionShape3D, area_detector: Area3D):
    var source_mesh_instance := find_mesh_instance_by_name(personal_space_mesh, zone_name)
    if source_mesh_instance == null or source_mesh_instance.mesh == null:
        push_error("personal space meshを読み込めませんでした: " + zone_name)
        return
    var mesh := source_mesh_instance.mesh
    collision.shape = mesh.create_convex_shape()
 
    area_detector.collision_layer = 0x04
    area_detector.collision_mask = 0x01

    visual.mesh = mesh
    apply_personal_space_materials(source_mesh_instance, visual)
    visual.visible = false

    if npc_data:
        intimate_area_detector.name = "IntimateArea_" + npc_data.id
        personal_area_detector.name = "PersonalArea_" + npc_data.id
        social_area_detector.name = "SocialArea_" + npc_data.id

func apply_personal_space_materials(source_mesh_instance: MeshInstance3D, visual: MeshInstance3D):
    if source_mesh_instance == null or source_mesh_instance.mesh == null:
        return

    for surface_index in range(source_mesh_instance.mesh.get_surface_count()):
        var material := source_mesh_instance.get_active_material(surface_index)
        var prepared_material: Material
        if material == null:
            prepared_material = create_personal_space_material()
        else:
            prepared_material = prepare_personal_space_material(material)
        visual.set_surface_override_material(surface_index, prepared_material)

func prepare_personal_space_material(material: Material) -> Material:
    if not (material is BaseMaterial3D):
        return material

    var prepared := material.duplicate() as BaseMaterial3D
    if prepared.albedo_texture == null:
        var fallback_texture := get_personal_space_texture()
        if fallback_texture:
            prepared.albedo_texture = fallback_texture
    prepared.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    prepared.cull_mode = BaseMaterial3D.CULL_DISABLED
    return prepared

func create_personal_space_material() -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    var texture := get_personal_space_texture()
    if texture:
        material.albedo_texture = texture
    material.albedo_color = Color(1.0, 1.0, 1.0, 0.2)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func get_personal_space_texture() -> Texture2D:
    if personal_space_texture:
        return personal_space_texture

    for texture_path in PERSONAL_SPACE_TEXTURE_PATHS:
        if not FileAccess.file_exists(Main.get_data_path(texture_path)):
            continue
        personal_space_texture = Main.load_data_texture(texture_path)
        if personal_space_texture:
            return personal_space_texture
    return null

func setup_npc_mesh(npc: NpcRepository.Npc) -> bool:
    var mesh_path = "3d/characters/" + npc.mesh_file_name
    var npc_packed_scene = Main.load_data_packed_scene(mesh_path)
    if not npc_packed_scene:
        push_error("NPCメッシュを読み込めませんでした: " + mesh_path)
        return false
    npc_mesh = npc_packed_scene.instantiate()
    add_child(npc_mesh)

    var personal_space_path = "3d/helpers/" + npc.personal_space_file_name
    var ps_packed_scene = Main.load_data_packed_scene(personal_space_path)
    if not ps_packed_scene:
        push_error("personal space helperを読み込めませんでした: " + Main.get_data_path(personal_space_path))
        return false
    personal_space_mesh = ps_packed_scene.instantiate()
    personal_space_mesh.visible = false
    add_child(personal_space_mesh)
    return true

func set_npc_data(npc: NpcRepository.Npc):
    npc_data = npc
    call_deferred("initialize_npc", npc)

func initialize_npc(npc: NpcRepository.Npc):
    var setup_ok := setup_npc_mesh(npc)
    if not setup_ok:
        push_error("NPC初期化を中断しました: " + npc.id)
        return
    setup_areas()
    apply_npc_data(npc)

func apply_npc_data(npc: NpcRepository.Npc):
    if npc_mesh == null or personal_space_mesh == null:
        return

    name_label.text = npc.display_name

#    var random_seek_time = randf_range(20.0, 120.0)

    npc_mesh.position.y = 0.0
    name_label.position.y -= 0.3

    # toon shader setup
    var body_mesh := find_mesh_instance_by_name(npc_mesh, "BodyObj")
    if body_mesh:
        apply_toon_outline_to_mesh(body_mesh)
    else:
        push_warning("BodyObjが見つからないためtoon/outline適用をスキップ: " + npc_mesh.name)

    apply_blend_shapes(npc_mesh, NPC_BLEND_SHAPES)

    # animation setup
    var animator_player = npc_mesh.get_node_or_null("AnimationPlayer")
    if animator_player:
        animator_player.play("Sitting")
        animator_player.advance(0.0)
#        animator_player.seek(random_seek_time, true)

func apply_blend_shapes(target_mesh, blend_shape_val_dict):
    if target_mesh == null:
        return

    if target_mesh is MeshInstance3D:
        for blend_shape_name in blend_shape_val_dict.keys():
            var blend_shape_idx = target_mesh.find_blend_shape_by_name(blend_shape_name)
            if blend_shape_idx != -1:
                target_mesh.set_blend_shape_value(blend_shape_idx, float(blend_shape_val_dict[blend_shape_name]))

    for child in target_mesh.get_children():
        apply_blend_shapes(child, blend_shape_val_dict)

func apply_toon_outline_to_mesh(mesh_instance: MeshInstance3D):
    """
    Skeleton3Dの子MeshInstance3Dに対してtoon+outlineエフェクトを適用
    骨格アニメーションでも正しく追従するように修正
    """

    if mesh_instance == null:
        return

    mesh_instance.set_surface_override_material(0, toon_wear_material)
    mesh_instance.set_surface_override_material(1, toon_skin_material)
    mesh_instance.set_surface_override_material(2, toon_head_material)

    var outline_node = mesh_instance.get_node_or_null("Outline")
    if outline_node == null:
        outline_node = MeshInstance3D.new()
        outline_node.name = "Outline"

        # mesh_instanceと同じディレクトリにadd_childする
        var parent = mesh_instance.get_parent()
        if parent:
            parent.add_child(outline_node)
        
        # 同じメッシュを設定
        outline_node.mesh = mesh_instance.mesh
        
        var skeleton_path = mesh_instance.get_skeleton_path()
        if not skeleton_path.is_empty():
            outline_node.skeleton = skeleton_path
        else:
            var parent_skeleton = mesh_instance.get_parent()
            if parent_skeleton is Skeleton3D:
                outline_node.skeleton = NodePath("..")
        
        if mesh_instance.skin != null:
            outline_node.skin = mesh_instance.skin
        
        # アウトラインマテリアルを適用
        outline_node.set_surface_override_material(0, outline_material)
        outline_node.set_surface_override_material(1, outline_material)
        outline_node.set_surface_override_material(2, outline_material)
        
        # レンダリング順序を調整
        outline_material.render_priority = -1
        toon_wear_material.render_priority = 0

        
func find_mesh_by_name(target_name: String) -> Mesh:
    return search_node_for_mesh(personal_space_mesh, target_name)

func search_node_for_mesh(node: Node, target_name: String) -> Mesh:
    if node == null:
        return null

    if node.name == target_name and node is MeshInstance3D:
        return node.mesh
    for child in node.get_children():
        var result = search_node_for_mesh(child, target_name)
        if result:
            return result
    return null

func find_mesh_instance_by_name(node: Node, target_name: String) -> MeshInstance3D:
    if node == null:
        return null

    if node.name == target_name and node is MeshInstance3D:
        return node

    for child in node.get_children():
        var result := find_mesh_instance_by_name(child, target_name)
        if result:
            return result

    return null

func set_personal_space_visibility(target_visible: bool):
    is_personal_space_visible = target_visible

    intimate_visual.visible = target_visible
    personal_visual.visible = target_visible
    social_visual.visible = target_visible

func get_npc_id() -> String:
    return npc_data.id if npc_data else ""
