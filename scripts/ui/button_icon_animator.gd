class_name ButtonIconAnimator
extends Sprite2D

@export var animation_speed: float = 2.0

var button_textures: Array[Texture2D] = []
var current_frame: int = 0
var animation_timer: float = 0.0
var is_animation_active: bool = false

func _ready():
    load_textures()
    if not button_textures.is_empty():
        texture = button_textures[0]
    
    modulate = Color(1, 1, 1, 0.8)
    set_process(false)

func load_textures():
    var texture_paths = [
        "res://data/icons/button_icon_release.svg",
        "res://data/icons/button_icon_push.svg"
    ]
    
    for path in texture_paths:
        if ResourceLoader.exists(path):
            var tex = load(path)
            button_textures.append(tex)

func _process(delta):
    if not is_animation_active or button_textures.is_empty():
        return
    update_animation(delta)

func update_animation(delta):
    animation_timer += delta
    
    if animation_timer >= 1.0 / animation_speed:
        animation_timer = 0.0
        advance_frame()

func advance_frame():
    current_frame = (current_frame + 1) % button_textures.size()
    texture = button_textures[current_frame]

func start_animation():
    """アニメーション開始"""
    is_animation_active = true
    current_frame = 0
    animation_timer = 0.0
    
    if not button_textures.is_empty():
        texture = button_textures[0]  # releaseから開始
    
    set_process(true)

func stop_animation():
    """アニメーション停止"""
    is_animation_active = false
    set_process(false)
    
    # 停止時はreleaseフレームに戻す
    current_frame = 0
    if not button_textures.is_empty():
        texture = button_textures[0]

func set_scale_xy(tar_scale: float):
    if tar_scale >1.2:
        tar_scale = 1.2
    elif tar_scale < 0.8:
        tar_scale = 0.8
    scale = Vector2(tar_scale*0.6, tar_scale*0.6)

func is_playing() -> bool:
    """アニメーションが再生中かどうかを返す"""
    return is_animation_active