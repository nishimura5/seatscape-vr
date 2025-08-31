class_name NpcRepository
extends RefCounted

class Npc:
    var id: String
    var rotation_degrees: float
    var mesh_id: String
    var animation_id: String
    var display_name: String
    var blend_file_name: String
    var personal_space_file_name: String
    
    func _init(p_id: String = "", p_mesh_id: String = "", p_animation_id: String = "", p_display_name: String = ""):
        id = p_id
        mesh_id = p_mesh_id
        animation_id = p_animation_id
        display_name = p_display_name
        rotation_degrees = 0.0
        blend_file_name = "npc_01.blend"
        personal_space_file_name = "personal_space_01.blend"


var npcs: Dictionary = {}

func add_npc(npc: Npc) -> void:
    npcs[npc.id] = npc

func get_npc(npc_id: String) -> Npc:
    return npcs.get(npc_id)

func get_all_npcs() -> Array[Npc]:
    var result : Array[Npc] = []
    for npc in npcs.values():
        result.append(npc)
    return result

func update_npc(npc: Npc) -> void:
    if npcs.has(npc.id):
        npcs[npc.id] = npc

func remove_npc(npc_id: String) -> void:
    npcs.erase(npc_id)

func has_npc(npc_id: String) -> bool:
    return npcs.has(npc_id)

func clear_all_npcs() -> void:
    npcs.clear()
