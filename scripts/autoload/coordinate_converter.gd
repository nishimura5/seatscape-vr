# scripts/autoload/coordinate_converter.gd
extends Node

# 座標系変換の定数
const PIXELS_PER_METER: float = 100.0  # 1メートル = 100ピクセル
const ROOM_OFFSET_2D: Vector2 = Vector2(200, 200)  # 2D画面でのルーム表示オフセット
const POOL_OFFSET_2D: Vector2 = Vector2(800, 200)  # 2D画面でのプール表示オフセット

# メートル座標を2Dピクセル座標に変換（ルーム内座標）
func room_meters_to_pixels(position_meters: Vector2) -> Vector2:
	return (position_meters * PIXELS_PER_METER) + ROOM_OFFSET_2D

# 2Dピクセル座標をメートル座標に変換（ルーム内座標）
func room_pixels_to_meters(position_pixels: Vector2) -> Vector2:
	return (position_pixels - ROOM_OFFSET_2D) / PIXELS_PER_METER

# プール内のNPC位置をピクセル座標で計算
func pool_npc_position_to_pixels(npc_index: int, total_npcs: int) -> Vector2:
	if total_npcs == 0:
		return POOL_OFFSET_2D
	
	var cols = ceil(sqrt(total_npcs))
	var row = floor(npc_index / cols)
	var col = npc_index % int(cols)
	
	var npc_offset = Vector2(col * PIXELS_PER_METER, row * PIXELS_PER_METER)
	return POOL_OFFSET_2D + npc_offset

# メートル座標を3D座標に変換
func meters_to_3d(position_meters: Vector2) -> Vector3:
	return Vector3(position_meters.x, 0, position_meters.y)

# 角度変換：シート方向を基準としたNPC回転角度を計算
func calculate_npc_rotation(seat_rotation: float, npc_base_rotation: float = 0.0) -> float:
	return seat_rotation + npc_base_rotation

# 2D画面上でのルーム境界を取得
func get_room_bounds_pixels(room_size: Vector3) -> Rect2:
	var top_left = ROOM_OFFSET_2D
	var size = Vector2(room_size.x, room_size.z) * PIXELS_PER_METER
	return Rect2(top_left, size)

# 2D画面上でのプール境界を取得
func get_pool_bounds_pixels(pool_size: Vector2) -> Rect2:
	var top_left = POOL_OFFSET_2D
	var size = pool_size * PIXELS_PER_METER
	return Rect2(top_left, size)

# 座標が特定の領域内にあるかチェック
func is_position_in_room(position_pixels: Vector2, room_size: Vector3) -> bool:
	var bounds = get_room_bounds_pixels(room_size)
	return bounds.has_point(position_pixels)

func is_position_in_pool(position_pixels: Vector2, pool_size: Vector2) -> bool:
	var bounds = get_pool_bounds_pixels(pool_size)
	return bounds.has_point(position_pixels)