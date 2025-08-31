# scripts/ui/seat_icon.gd
extends Sprite2D

@onready var seat_label: Label = $SeatLabel
@onready var occupied_indicator: Sprite2D = $OccupiedIndicator

var seat_data: SeatRepository.Seat
var is_occupied: bool = false
var is_highlighted: bool = false
var is_move_mode: bool = false
var width: int = 30
var height: int = 30
var default_texture: Texture2D

signal seat_clicked(seat_id: String)

func _ready():
    if not seat_label:
        seat_label = get_node("SeatLabel")
    if not occupied_indicator:
        occupied_indicator = get_node("OccupiedIndicator")
    
    scale = Vector2.ONE
    offset = Vector2.ZERO

func _gui_input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not is_occupied:
            seat_clicked.emit(get_seat_id())

func create_texture():
    var image = Image.create(width, height, false, Image.FORMAT_RGB8)
    image.fill(Color.LIGHT_GRAY)
    default_texture = ImageTexture.new()
    default_texture.set_image(image)
    
    texture = default_texture

func setup_seat(seat: SeatRepository.Seat):
    seat_data = seat
    create_texture()
    
    if not seat_label:
        seat_label = get_node("SeatLabel")
    
    if seat_label:
        seat_label.text = seat.display_name
        seat_label.add_theme_font_size_override("font_size", 18)
    
    modulate = Color.LIGHT_GRAY
    update_appearance()

func set_occupied(occupied: bool):
    is_occupied = occupied
    
    if not occupied_indicator:
        occupied_indicator = get_node("OccupiedIndicator")
    
    if occupied_indicator:
        occupied_indicator.visible = occupied
    
    update_appearance()

func set_highlight(highlight: bool):
    is_highlighted = highlight
    update_appearance()

func set_move_mode(move_mode: bool):
    is_move_mode = move_mode
    update_appearance()

func update_appearance():
    if is_move_mode:
        modulate = Color.CYAN  # 移動モード中の座席
    elif is_highlighted:
        modulate = Color.GREEN  # ドラッグ時のハイライト
    elif is_occupied:
        modulate = Color.DARK_GRAY  # 占有済みの席
    else:
        modulate = Color.LIGHT_GRAY  # 通常の空席

func get_seat_id() -> String:
    return seat_data.id if seat_data else ""