class_name PoolRepository
extends RefCounted

class Pool:
	var id: String = "default_pool"
	var size: Vector2  # width, height in meters
	
	func calculate_size(npc_count: int) -> void:
		if npc_count == 0:
			size = Vector2(2.0, 2.0)
		else:
			# 1つのNPCあたり1x1メートル、適切にグリッド配置する
			var cols = ceil(sqrt(npc_count))
			var rows = ceil(npc_count / cols)
			size = Vector2(cols * 1.0, rows * 1.0)

var pool: Pool

func _init():
	pool = Pool.new()

# プールのサイズを更新（NPC数に基づく）
func update_pool_size(npc_count: int) -> void:
	pool.calculate_size(npc_count)

# プールのサイズを取得
func get_pool_size() -> Vector2:
	return pool.size

# プール内でのNPCの配置位置を計算
func get_npc_position_in_pool(npc_index: int, total_npc_count: int) -> Vector2:
	update_pool_size(total_npc_count)
	
	if total_npc_count == 0:
		return Vector2.ZERO
	
	var cols = ceil(sqrt(total_npc_count))
	var row = floor(npc_index / cols)
	var col = npc_index % int(cols)
	
	# 1x1メートルのグリッド配置
	return Vector2(col * 1.0, row * 1.0)

# プールの中心位置を取得
func get_pool_center() -> Vector2:
	return pool.size * 0.5

# デバッグ用：プール情報を出力
func debug_print_pool() -> void:
	print("=== Pool Status ===")
	print("Pool size: ", pool.size)