extends Node3D

@onready var name_label: Label3D = $NameLabel
@onready var npc_mesh: Node3D = $NpcMesh

@onready var toon_material: ShaderMaterial = load("res://tres/toon_shader_material.tres")
@onready var outline_material: ShaderMaterial = load("res://tres/outline_shader_material.tres")

var npc_data: NpcRepository.Npc

func setup_npc_mesh(npc: NpcRepository.Npc):
    var mesh_path = "3d/characters/" + npc.mesh_file_name
    print(mesh_path)
    var npc_packed_scene = Main.load_data_packed_scene(mesh_path)
    if not npc_packed_scene:
        return
    npc_mesh = npc_packed_scene.instantiate()
    add_child(npc_mesh)

func set_npc_data(npc: NpcRepository.Npc):
    npc_data = npc
    call_deferred("setup_npc_mesh", npc)
    call_deferred("setup_areas")
    call_deferred("apply_npc_data", npc)

func apply_npc_data(npc: NpcRepository.Npc):
    name_label.text = npc.display_name

    var random_seek_time = randf_range(20.0, 120.0)

    npc_mesh.position.y = -0.0
    name_label.position.y -= 0.3

    # toon shader setup
    var body_mesh = npc_mesh.get_node("Armature01/Skeleton3D/body")
    apply_toon_outline_to_mesh(body_mesh)
    var head_mesh = npc_mesh.get_node("Armature01/Skeleton3D/head")
    apply_toon_outline_to_mesh(head_mesh)
    var wear_mesh = npc_mesh.get_node("Armature01/Skeleton3D/wear1")
    apply_toon_outline_to_mesh(wear_mesh)
    var feet_mesh = npc_mesh.get_node("Armature01/Skeleton3D/feet")
    apply_toon_outline_to_mesh(feet_mesh)

    # unvisible hand
    var hand_mesh = npc_mesh.get_node("Armature01/Skeleton3D/hand")
    hand_mesh.visible = false

    # animation setup
    var animator_player = npc_mesh.get_node_or_null("AnimationPlayer")
    if animator_player:
        animator_player.play("Anim_0")
        animator_player.seek(random_seek_time, true)

func apply_toon_outline_to_mesh(mesh_instance: MeshInstance3D):
    """
    Skeleton3Dの子MeshInstance3Dに対してtoon+outlineエフェクトを適用
    骨格アニメーションでも正しく追従するように修正
    """

    mesh_instance.set_surface_override_material(0, toon_material)

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
        
        # レンダリング順序を調整
        outline_material.render_priority = -1
        toon_material.render_priority = 0


func search_node_for_mesh(node: Node, target_name: String) -> Mesh:
    if node.name == target_name and node is MeshInstance3D:
        return node.mesh
    for child in node.get_children():
        var result = search_node_for_mesh(child, target_name)
        if result:
            return result
    return null

func get_npc_id() -> String:
    return npc_data.id if npc_data else ""
