# scripts/grid_manager.gd
class_name GridManager
extends RefCounted

const GRID_SPACING: float = 1.0
const GRID_MINOR_SPACING: float = 0.2
const GRID_LINE_WIDTH: float = 1.0
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.17)
const GRID_MINOR_COLOR: Color = Color(1.0, 1.0, 1.0, 0.07)

var grid_lines: Array[Line2D] = []

func create_grid(parent_node: Node2D, room_rect: Rect2, scale_factor: float) -> Array[Line2D]:
    """グリッド線を作成してparent_nodeに追加"""
    clear_grid()
    
    var room_size_meters = Vector2(room_rect.size.x / scale_factor, room_rect.size.y / scale_factor)
    
    # マイナーグリッド線を先に作成（背景）
    create_minor_vertical_lines(parent_node, room_rect, room_size_meters, scale_factor)
    create_minor_horizontal_lines(parent_node, room_rect, room_size_meters, scale_factor)
    
    # メジャーグリッド線を後に作成（前景）
    create_major_vertical_lines(parent_node, room_rect, room_size_meters, scale_factor)
    create_major_horizontal_lines(parent_node, room_rect, room_size_meters, scale_factor)
    
    return grid_lines

func create_major_vertical_lines(parent_node: Node2D, room_rect: Rect2, room_size_meters: Vector2, scale_factor: float):
    """メジャー縦グリッド線を作成（1m間隔）"""
    var lines_count = int(room_size_meters.x / GRID_SPACING) + 1
    
    for i in range(lines_count):
        var x_pos = i * GRID_SPACING * scale_factor
        
        # 部屋の境界を超えないようにクランプ
        if x_pos > room_rect.size.x:
            break
        
        var line = Line2D.new()
        line.width = GRID_LINE_WIDTH
        line.default_color = GRID_COLOR
        line.z_index = -1  # 背景に配置
        
        # 線の開始点と終了点を設定
        line.add_point(Vector2(x_pos, 0))
        line.add_point(Vector2(x_pos, room_rect.size.y))
        
        line.position = room_rect.position
        parent_node.add_child(line)
        grid_lines.append(line)

func create_major_horizontal_lines(parent_node: Node2D, room_rect: Rect2, room_size_meters: Vector2, scale_factor: float):
    """メジャー横グリッド線を作成（1m間隔）"""
    var lines_count = int(room_size_meters.y / GRID_SPACING) + 1
    
    for i in range(lines_count):
        var y_pos = i * GRID_SPACING * scale_factor
        
        # 部屋の境界を超えないようにクランプ
        if y_pos > room_rect.size.y:
            break
        
        var line = Line2D.new()
        line.width = GRID_LINE_WIDTH
        line.default_color = GRID_COLOR
        line.z_index = -1  # 背景に配置
        
        # 線の開始点と終了点を設定
        line.add_point(Vector2(0, y_pos))
        line.add_point(Vector2(room_rect.size.x, y_pos))
        
        line.position = room_rect.position
        parent_node.add_child(line)
        grid_lines.append(line)

func create_minor_vertical_lines(parent_node: Node2D, room_rect: Rect2, room_size_meters: Vector2, scale_factor: float):
    """マイナー縦グリッド線を作成"""
    var lines_count = int(room_size_meters.x / GRID_MINOR_SPACING) + 1
    
    for i in range(lines_count):
        var x_pos = i * GRID_MINOR_SPACING * scale_factor
        
        # 部屋の境界を超えないようにクランプ
        if x_pos > room_rect.size.x:
            break
        
        var line = Line2D.new()
        line.width = GRID_LINE_WIDTH
        line.default_color = GRID_MINOR_COLOR
        line.z_index = -2  # メジャーグリッドより更に背景に配置
        
        # 線の開始点と終了点を設定
        line.add_point(Vector2(x_pos, 0))
        line.add_point(Vector2(x_pos, room_rect.size.y))
        
        line.position = room_rect.position
        parent_node.add_child(line)
        grid_lines.append(line)

func create_minor_horizontal_lines(parent_node: Node2D, room_rect: Rect2, room_size_meters: Vector2, scale_factor: float):
    """マイナー横グリッド線を作成"""
    var lines_count = int(room_size_meters.y / GRID_MINOR_SPACING) + 1
    
    for i in range(lines_count):
        var y_pos = i * GRID_MINOR_SPACING * scale_factor
        
        # 部屋の境界を超えないようにクランプ
        if y_pos > room_rect.size.y:
            break
        
        var line = Line2D.new()
        line.width = GRID_LINE_WIDTH
        line.default_color = GRID_MINOR_COLOR
        line.z_index = -2  # メジャーグリッドより更に背景に配置
        
        # 線の開始点と終了点を設定
        line.add_point(Vector2(0, y_pos))
        line.add_point(Vector2(room_rect.size.x, y_pos))
        
        line.position = room_rect.position
        parent_node.add_child(line)
        grid_lines.append(line)

func clear_grid():
    """既存のグリッド線を削除"""
    for line in grid_lines:
        if is_instance_valid(line):
            line.queue_free()
    grid_lines.clear()

func get_grid_spacing() -> float:
    """メジャーグリッド間隔を返す（メートル単位）"""
    return GRID_SPACING

func get_minor_grid_spacing() -> float:
    """マイナーグリッド間隔を返す（メートル単位）"""
    return GRID_MINOR_SPACING

func regenerate_grid(parent_node: Node2D, room_rect: Rect2, scale_factor: float) -> Array[Line2D]:
    """グリッドを再生成（部屋サイズ変更時などに使用）"""
    return create_grid(parent_node, room_rect, scale_factor)
