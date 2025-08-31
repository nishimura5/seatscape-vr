# scripts/ui/dialog_system.gd
extends Control

@onready var dialog_text: RichTextLabel = $DialogBackground/DialogMargin/DialogContainer/DialogText
@onready var button_indicate_image: TextureRect = $DialogBackground/DialogMargin/DialogContainer/ButtonIndicateImage
@onready var character_container: MarginContainer = $CharacterPortraitContainer
@onready var character_portrait: TextureRect = $CharacterPortraitContainer/CharacterPortrait

var current_messages: Array[String] = []
var current_message_index: int = 0
var is_dialog_active: bool = false
var button_icon_animator: ButtonIconAnimator
var guide_animator: GuideCharacterAnimator
var animation_delay_timer: Timer
var scale_factor: Vector2 = Vector2(1.0, 1.0)
var is_xr_mode: bool = false
var right_controller: XRController3D = null
var accept_pressed: bool = true

signal dialog_ended()

func _ready():
    setup_ui()
    var character_image_size = setup_character_portrait()
    setup_button_animation(character_image_size.x - 100)
    setup_animation_timer()
    hide_dialog()
    
    # ダイアログが開いている間は他の入力をブロック
    process_mode = Node.PROCESS_MODE_ALWAYS

func setup_ui():
    var viewport_size = get_viewport().get_size()

    position = Vector2(0, viewport_size.y)

    var dialog_height = viewport_size.y * 0.21
    if dialog_height < 200:
        dialog_height = 200
    elif dialog_height > 400:
        dialog_height = 400
    custom_minimum_size = Vector2(viewport_size.x, dialog_height)

    scale_factor = Vector2(viewport_size.x / 1920.0, viewport_size.y / 1080.0)

    # font sizeを調整
    var current_font_size = dialog_text.get_theme_font_size("normal_font_size")
    var new_font_size = current_font_size * scale_factor.y
    if new_font_size < 24:
        new_font_size = 24
    elif new_font_size > 56:
        new_font_size = 56
    dialog_text.add_theme_font_size_override("normal_font_size", new_font_size)

func setup_button_animation(character_image_width: float):
    button_icon_animator = ButtonIconAnimator.new()
    button_icon_animator.name = "ButtonIconAnimator"
    button_indicate_image.add_child(button_icon_animator)

    button_icon_animator.set_scale_xy(scale_factor.x)
    button_indicate_image.custom_minimum_size = Vector2(character_image_width, 20)

    button_icon_animator.visible = false

func setup_character_portrait():
    # GuideCharacterAnimatorをcharacter_portraitに追加
    guide_animator = GuideCharacterAnimator.new()
    guide_animator.name = "GuideAnimator"
    character_portrait.add_child(guide_animator)
    
    guide_animator.visible = false
    guide_animator.set_scale_xy(scale_factor.x * 0.4)
    var image_size = guide_animator.get_size()
    character_container.offset_left = -image_size.x / 2 - 100
    character_container.offset_top = -image_size.y / 2
    return image_size

func setup_animation_timer():
    # アニメーション開始遅延用のタイマーを作成
    animation_delay_timer = Timer.new()
    animation_delay_timer.wait_time = 1.0
    animation_delay_timer.one_shot = true
    animation_delay_timer.timeout.connect(_on_animation_delay_timeout)
    add_child(animation_delay_timer)

func _input(event):
    # ダイアログが表示されている時のみ入力を処理
    if is_dialog_active:
        if event.is_action_pressed("ui_accept"):
            _on_next_button_pressed()
        # ダイアログが開いている間は全ての入力を消費してブロック
        get_viewport().set_input_as_handled()

func set_xr_enabled(enabled: bool, controller: XRController3D):
    """XRモードの有効/無効を設定"""
    is_xr_mode = enabled
    right_controller = controller

func _process(_delta):
    if is_xr_mode and is_dialog_active:
        var accept_current = right_controller.is_button_pressed("accept")
        if accept_current and not accept_pressed:
            _on_next_button_pressed()
        accept_pressed = accept_current

func show_dialog(character: String, messages: Array):
    current_messages.clear()
    for msg in messages:
        current_messages.append(msg)
    
    current_message_index = 0
    is_dialog_active = true
    
    # ダイアログを最前面に表示
    z_index = 1000
    
    # 他のノードの処理を一時停止
    get_tree().paused = true
    
    setup_character(character)
    display_current_message()
    
    # ボタンアイコンアニメーションを停止・非表示
    stop_button_animation()
    
    # 2秒後にアニメーション開始
    animation_delay_timer.start()
    
    visible = true

func setup_character(character: String):
    # 既存のテクスチャをクリア
    character_portrait.texture = null
    
    # アニメーターの表示状態をリセット
    if guide_animator:
        guide_animator.visible = false
        guide_animator.set_animation_playing(false)
    
    match character:
        "guide":
            # GuideCharacterAnimatorを表示・アニメーション開始
            if guide_animator:
                guide_animator.visible = true
                guide_animator.set_animation_playing(true)
        _:
            # デフォルトまたは不明なキャラクターの場合
            character_portrait.texture = null

func display_current_message():
    if current_message_index < current_messages.size():
        dialog_text.text = current_messages[current_message_index]
        
        reset_guide_animation()
        
        stop_button_animation()
        animation_delay_timer.start()

func reset_guide_animation():
    if guide_animator and guide_animator.visible:
        guide_animator.reset_animation()

func _on_animation_delay_timeout():
    start_button_animation()

func start_button_animation():
    if button_icon_animator:
        button_icon_animator.visible = true
        button_icon_animator.start_animation()

func stop_button_animation():
    if button_icon_animator:
        button_icon_animator.visible = false
        button_icon_animator.stop_animation()

func _on_next_button_pressed():
    if current_message_index < current_messages.size() - 1:
        current_message_index += 1
        display_current_message()
        guide_animator.set_animation_playing(true)
    else:
        hide_dialog()

func hide_dialog():
    is_dialog_active = false
    current_messages.clear()
    current_message_index = 0
    
    # タイマーを停止
    animation_delay_timer.stop()
    
    # ボタンアニメーションを停止
    stop_button_animation()
    
    # ゲームの一時停止を解除
    get_tree().paused = false
    
    # GuideCharacterAnimatorのアニメーションを停止
    if guide_animator:
        guide_animator.visible = false
        guide_animator.set_animation_playing(false)
    
    # キャラクターポートレートをクリア
    character_portrait.texture = null
    
    visible = false
    dialog_ended.emit()

# アニメーションキャラクターを設定するヘルパー関数
func set_animated_character():
    """アニメーションキャラクター（ガイド）を設定"""
    character_portrait.texture = null
    
    if guide_animator:
        guide_animator.visible = true
        guide_animator.set_animation_playing(true)
