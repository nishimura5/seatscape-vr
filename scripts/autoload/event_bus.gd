# scripts/autoload/event_bus.gd
extends Node

# Used in assignment.gd
@warning_ignore("unused_signal")
signal npc_moved_to_seat(npc_id: String, seat_id: String)
@warning_ignore("unused_signal")
signal npc_moved_to_pool(npc_id: String)

# Used in assignment and seating
@warning_ignore("unused_signal")
signal seat_occupied(seat_id: String, npc_id: String)

# Used in room_selection
@warning_ignore("unused_signal")
signal room_selected(room_id: String)

# Used in seating
@warning_ignore("unused_signal")
signal seating_started()

# シーン管理関連（新規追加）
@warning_ignore("unused_signal")
signal scene_changed(scene_name: String)

# データ更新関連
@warning_ignore("unused_signal")
signal data_initialized()

# UI関連
@warning_ignore("unused_signal")
signal ui_status_updated(message: String)
