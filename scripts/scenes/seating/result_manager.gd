# scripts/result_manager.gd
class_name ResultManager
extends RefCounted

var results: Dictionary = {}

# スコア計算の重み
const INTIMATE_VIOLATION_PENALTY = 10
const ZONE_SCORE_WEIGHT = 30
const DIRECTION_SCORE_WEIGHT = 20
const BASE_SCORE = 100

func calculate_results():
    var final_seat_id = PlayerDataManager.get_final_seat_id()
    print("Calculating results for final seat: ", final_seat_id)
    results.clear()
    
    calculate_intimate_violations()
    calculate_seat_zone_score()
    calculate_direction_score()

func calculate_intimate_violations():
    var violation_count = PlayerDataManager.get_intimate_violations_count()
    results["intimate_violations"] = violation_count
    results["intimate_penalty"] = violation_count * INTIMATE_VIOLATION_PENALTY

func calculate_seat_zone_score():
    var final_seat_id = PlayerDataManager.get_final_seat_id()
    if final_seat_id.is_empty():
        results["seat_zone_status"] = ["未着席"]
        return

    var seat_zone_status_list = []
    for npc_id in PlayerDataManager.current_zone_status:
        seat_zone_status_list.append("%s: %s" % [npc_id, PlayerDataManager.current_zone_status[npc_id]])

    results["seat_zone_status"] = seat_zone_status_list

func calculate_direction_score():
    var final_seat_id = PlayerDataManager.get_final_seat_id()
    if final_seat_id.is_empty():
        results["direction_status"] = "未着席"
        results["direction_score"] = 0
        return
    
    var facing_analysis = analyze_facing_situation(final_seat_id)
    results["direction_status"] = facing_analysis.status

func analyze_facing_situation(seat_id: String) -> Dictionary:
    var seat = DataRepository.seat_repository.get_seat(seat_id)
    if not seat:
        return {"status": "不明", "score": 0}
    
    var facing_count = 0
    var seated_npcs = DataRepository.assignment_repository.get_seated_npc_ids()
    
    for npc_id in seated_npcs:
        var npc_seat_id = DataRepository.get_npc_seat_id(npc_id)
        var npc_seat = DataRepository.seat_repository.get_seat(npc_seat_id)
        
        if npc_seat and is_npc_facing_seat(npc_seat, seat):
            facing_count += 1
    
    # 視線集中度による評価
    if facing_count == 0:
        return {"status": "良好", "score": 20}
    elif facing_count <= 2:
        return {"status": "普通", "score": 10}
    else:
        return {"status": "視線が集中", "score": 0}

func is_npc_facing_seat(npc_seat: SeatRepository.Seat, target_seat: SeatRepository.Seat) -> bool:
    var distance = npc_seat.position.distance_to(target_seat.position)
    if distance > 10.0:
        return false
    
    var npc_forward = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(npc_seat.rotation_degrees))
    var to_target = (target_seat.position - npc_seat.position).normalized()
    
    var angle = rad_to_deg(npc_forward.angle_to(to_target))
    return angle <= 45.0

func get_results() -> Dictionary:
    return results.duplicate()
