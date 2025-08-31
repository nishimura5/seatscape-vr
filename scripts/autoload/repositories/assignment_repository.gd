class_name AssignmentRepository
extends RefCounted

class Assignment:
    var npc_id: String
    var seat_id: String
    
    func _init(p_npc_id: String = "", p_seat_id: String = ""):
        npc_id = p_npc_id
        seat_id = p_seat_id
    
    func is_empty() -> bool:
        return npc_id.is_empty() or seat_id.is_empty()
    
    func is_in_pool() -> bool:
        return not npc_id.is_empty() and seat_id.is_empty()

# NPCの所属状態を一元管理
# - seat_id が空文字列 = プールに所属
# - seat_id が設定済み = その座席に着席
var assignments: Dictionary = {}  # npc_id -> Assignment

# NPCをプールに配置
func assign_to_pool(npc_id: String) -> void:
    assignments[npc_id] = Assignment.new(npc_id, "")

# NPCを座席に配置
func assign_to_seat(npc_id: String, seat_id: String) -> void:
    assignments[npc_id] = Assignment.new(npc_id, seat_id)

# NPCの現在の配置を取得
func get_assignment_for_npc(npc_id: String) -> Assignment:
    return assignments.get(npc_id, Assignment.new())

# 座席の占有者を取得
func get_assignment_for_seat(seat_id: String) -> Assignment:
    for assignment in assignments.values():
        if assignment.seat_id == seat_id:
            return assignment
    return Assignment.new()

# 全配置情報を取得
func get_all_assignments() -> Array[Assignment]:
    var result: Array[Assignment] = []
    for assignment in assignments.values():
        result.append(assignment)
    return result

# プールに所属するNPCのIDリストを取得
func get_pool_npc_ids() -> Array[String]:
    var result: Array[String] = []
    for assignment in assignments.values():
        if assignment.is_in_pool():
            result.append(assignment.npc_id)
    return result

# 着席しているNPCのIDリストを取得
func get_seated_npc_ids() -> Array[String]:
    var result: Array[String] = []
    for assignment in assignments.values():
        if not assignment.is_in_pool() and not assignment.is_empty():
            result.append(assignment.npc_id)
    return result

# NPCが管理対象かチェック
func has_npc(npc_id: String) -> bool:
    return assignments.has(npc_id)

# NPCが座席に着席しているかチェック
func is_npc_seated(npc_id: String) -> bool:
    var assignment = get_assignment_for_npc(npc_id)
    return not assignment.is_empty() and not assignment.is_in_pool()

# NPCがプールにいるかチェック
func is_npc_in_pool(npc_id: String) -> bool:
    var assignment = get_assignment_for_npc(npc_id)
    return assignment.is_in_pool()

# 座席が占有されているかチェック
func is_seat_occupied(seat_id: String) -> bool:
    return not get_assignment_for_seat(seat_id).is_empty()

# NPCを管理対象から除去
func remove_npc(npc_id: String) -> void:
    assignments.erase(npc_id)

# 全配置情報をクリア
func clear_all_assignments() -> void:
    assignments.clear()

# プールのNPC数を取得
func get_pool_count() -> int:
    return get_pool_npc_ids().size()

# 着席済みNPC数を取得
func get_seated_count() -> int:
    return get_seated_npc_ids().size()

# デバッグ用：現在の配置状況を出力
func debug_print_assignments() -> void:
    print("=== Assignment Status ===")
    print("Pool NPCs: ", get_pool_npc_ids())
    print("Seated NPCs: ", get_seated_npc_ids())
    for assignment in assignments.values():
        if assignment.is_in_pool():
            print("NPC ", assignment.npc_id, " -> Pool")
        elif not assignment.is_empty():
            print("NPC ", assignment.npc_id, " -> Seat ", assignment.seat_id)
