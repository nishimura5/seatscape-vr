extends Node

var seat_repository: SeatRepository
var npc_repository: NpcRepository
var room_repository: RoomRepository
var pool_repository: PoolRepository
var assignment_repository: AssignmentRepository

func _ready():
    seat_repository = SeatRepository.new()
    npc_repository = NpcRepository.new()
    room_repository = RoomRepository.new()
    pool_repository = PoolRepository.new()
    assignment_repository = AssignmentRepository.new()
    
    # Connect to event bus for coordination
    EventBus.npc_moved_to_seat.connect(_on_npc_moved_to_seat)
    EventBus.npc_moved_to_pool.connect(_on_npc_moved_to_pool)

# === 座席関連クエリ（assignment_repositoryを信頼できる情報源とする） ===

func is_seat_occupied(seat_id: String) -> bool:
    return assignment_repository.is_seat_occupied(seat_id)

func get_seat_occupant(seat_id: String) -> String:
    var assignment = assignment_repository.get_assignment_for_seat(seat_id)
    return assignment.npc_id if not assignment.is_empty() else ""

func get_vacant_seats() -> Array[SeatRepository.Seat]:
    var result: Array[SeatRepository.Seat] = []
    for seat in seat_repository.get_all_seats():
        if not is_seat_occupied(seat.id):
            result.append(seat)
    return result

func get_occupied_seats() -> Array[SeatRepository.Seat]:
    var result: Array[SeatRepository.Seat] = []
    for seat in seat_repository.get_all_seats():
        if is_seat_occupied(seat.id):
            result.append(seat)
    return result

# === プール関連クエリ ===

func get_pool_npc_ids() -> Array[String]:
    return assignment_repository.get_pool_npc_ids()

func get_pool_size() -> Vector2:
    var npc_count = assignment_repository.get_pool_count()
    pool_repository.update_pool_size(npc_count)
    return pool_repository.get_pool_size()

func get_npc_position_in_pool(npc_id: String) -> Vector2:
    var pool_npcs = get_pool_npc_ids()
    var npc_index = pool_npcs.find(npc_id)
    if npc_index < 0:
        return Vector2.ZERO
    return pool_repository.get_npc_position_in_pool(npc_index, pool_npcs.size())

# === NPC配置状態クエリ ===

func is_npc_in_pool(npc_id: String) -> bool:
    return assignment_repository.is_npc_in_pool(npc_id)

func is_npc_seated(npc_id: String) -> bool:
    return assignment_repository.is_npc_seated(npc_id)

func get_npc_seat_id(npc_id: String) -> String:
    var assignment = assignment_repository.get_assignment_for_npc(npc_id)
    return assignment.seat_id if assignment_repository.is_npc_seated(npc_id) else ""

# === イベントハンドラー ===

func _on_npc_moved_to_seat(npc_id: String, seat_id: String):
    var npc = npc_repository.get_npc(npc_id)
    var seat = seat_repository.get_seat(seat_id)
    
    if npc and seat:
        # NPCの向きを座席に合わせる
        npc.rotation_degrees = seat.rotation_degrees
        npc_repository.update_npc(npc)
        
        # 配置情報を更新（信頼できる情報源）
        assignment_repository.assign_to_seat(npc_id, seat_id)
        
        EventBus.seat_occupied.emit(seat_id, npc_id)

func _on_npc_moved_to_pool(npc_id: String):
    print("NPC ", npc_id, " がプールに移動しました")
    # プールに移動
    assignment_repository.assign_to_pool(npc_id)

# === 初期化・管理メソッド ===

# NPCをシステムに登録（初期状態はプール）
func register_npc(npc: NpcRepository.Npc) -> void:
    npc_repository.add_npc(npc)
    assignment_repository.assign_to_pool(npc.id)

# 座席をシステムに登録
func register_seat(seat: SeatRepository.Seat) -> void:
    seat_repository.add_seat(seat)

# 部屋をシステムに設定
func set_room(room: RoomRepository.Room) -> void:
    room_repository.set_current_room(room)

# 全データをクリアする便利メソッド
func clear_all_data():
    seat_repository.clear_all_seats()
    npc_repository.clear_all_npcs()
    room_repository.clear_current_room()
    assignment_repository.clear_all_assignments()

# デバッグ用：全状態を出力
func debug_print_all_status():
    print("=== DataRepository Status ===")
    #assignment_repository.debug_print_assignments()
    pool_repository.debug_print_pool()
    print("Total seats: ", seat_repository.get_seat_count())
    print("Total NPCs: ", npc_repository.get_all_npcs().size())
