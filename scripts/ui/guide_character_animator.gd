# scripts/ui/guide_character_animator.gd
class_name GuideCharacterAnimator
extends Sprite2D

@export var animation_speed: float = 8.0

var guide_textures: Array[Texture2D] = []
var current_frame: int = 0
var animation_timer: float = 0.0
var loop_count: int = 0
var max_loops: int = 1
var is_animation_active: bool = true

func _ready():
    load_textures()
    if not guide_textures.is_empty():
        texture = guide_textures[0]
    set_process(true)

func load_textures():
    var texture_paths = [
        "res://data/images/dialog/guide_0.png",
        "res://data/images/dialog/guide_1.png",
        "res://data/images/dialog/guide_2.png", 
        "res://data/images/dialog/guide_3.png",
        "res://data/images/dialog/guide_4.png",
    ]
    
    for path in texture_paths:
        if ResourceLoader.exists(path):
            var tex = load(path)
            guide_textures.append(tex)

func _process(delta):
    if guide_textures.is_empty() or not is_animation_active:
        return
    update_animation(delta)

func update_animation(delta):
    animation_timer += delta
    
    if animation_timer >= 1.0 / animation_speed:
        animation_timer = 0.0
        advance_frame()

func advance_frame():
    var mouth_frames = [0, 1, 4, 3, 2, 1, 0, 3, 1]
    current_frame = (current_frame + 1) % mouth_frames.size()
    texture = guide_textures[mouth_frames[current_frame]]
    if current_frame == 0:
        loop_count += 1
        if loop_count >= max_loops:
            texture = guide_textures[0]
            is_animation_active = false
            set_process(false)
            return

func set_animation_playing(playing: bool):
    is_animation_active = playing
    set_process(playing)
    if playing:
        reset_animation()
    elif not guide_textures.is_empty():
        current_frame = 0
        texture = guide_textures[0]

func reset_animation():
    loop_count = 0
    current_frame = 0
    animation_timer = 0.0
    is_animation_active = true
    if not guide_textures.is_empty():
        texture = guide_textures[0]

func set_scale_xy(tar_scale: float):
    if tar_scale >1.2:
        tar_scale = 1.2
    elif tar_scale < 0.4:
        tar_scale = 0.4
    scale = Vector2(tar_scale, tar_scale)

func get_size() -> Vector2:
    """ガイドアニメーターのサイズを取得"""
    if not guide_textures.is_empty():
        return guide_textures[0].get_size() * scale
    return Vector2.ZERO