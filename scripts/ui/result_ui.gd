# scripts/ui/result_ui.gd
extends Control

@onready var title_label: Label = $BackgroundPanel/MainContainer/TitleLabel
@onready var background_panel: Panel = $BackgroundPanel
@onready var intimate_value: Label = $BackgroundPanel/MainContainer/ScoreContainer/IntimateViolationScore/IntimateValue
@onready var seat_zone_value: Label = $BackgroundPanel/MainContainer/ScoreContainer/SeatZoneScore/SeatZoneValue
@onready var direction_value: Label = $BackgroundPanel/MainContainer/ScoreContainer/DirectionScore/DirectionValue
@onready var next_button: Button = $BackgroundPanel/MainContainer/ButtonContainer/NextButton
@onready var retry_button: Button = $BackgroundPanel/MainContainer/ButtonContainer/RetryButton
@onready var back_to_menu_button: Button = $BackgroundPanel/MainContainer/ButtonContainer/BackToMenuButton

# シグナル定義
signal next_pressed()
signal retry_pressed()
signal back_to_menu_pressed()

var visible_buttons: Array[Button] = []

func _ready():
    setup_connections()
    setup_gamepad_support()
    visible = false

func setup_connections():
    next_button.pressed.connect(_on_next_pressed)
    retry_button.pressed.connect(_on_retry_pressed)
    back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)

func setup_gamepad_support():
    # 全ボタンのフォーカス設定
    next_button.focus_mode = Control.FOCUS_ALL
    retry_button.focus_mode = Control.FOCUS_ALL
    back_to_menu_button.focus_mode = Control.FOCUS_ALL
    
func update_focus_navigation():
    """ボタンの表示状態に応じてフォーカスナビゲーションを更新"""
    # 表示されているボタンのリストを作成（左から右の順序）
    visible_buttons.clear()
    if next_button.visible:
        visible_buttons.append(next_button)
    if retry_button.visible:
        visible_buttons.append(retry_button)
    if back_to_menu_button.visible:
        visible_buttons.append(back_to_menu_button)
    
    # 最初の表示ボタンにフォーカスを設定
    if visible_buttons.size() > 0:
        call_deferred("_set_initial_focus", visible_buttons[0])

func _set_initial_focus(button: Button):
    button.grab_focus()

func _input(event):
    if not visible:
        return
    
    # ゲームパッド・キーボード入力の処理
    if event.is_action_pressed("ui_accept"):
        # 現在フォーカスされているボタンを押す
        var focused_control = get_viewport().gui_get_focus_owner()
        if focused_control:
            if focused_control == retry_button:
                _on_retry_pressed()
            elif focused_control == next_button:
                _on_next_pressed()
            elif focused_control == back_to_menu_button:
                _on_back_to_menu_pressed()
    
    elif event.is_action_pressed("ui_left"):
        move_focus_left()
    
    elif event.is_action_pressed("ui_right"):
        move_focus_right()

func move_focus_left():
    var now_control = get_viewport().gui_get_focus_owner()
    for i in range(visible_buttons.size()):
        if visible_buttons[i] == now_control:
            if i == 0:
                break
            else:
                call_deferred("_set_focus_safely", visible_buttons[i - 1])
                break

func move_focus_right():
    var now_control = get_viewport().gui_get_focus_owner()
    for i in range(visible_buttons.size()):
        if visible_buttons[i] == now_control:
            if i < visible_buttons.size() - 1:
                call_deferred("_set_focus_safely", visible_buttons[i + 1])
                break
            else:
                break

func _set_focus_safely(button: Button):
    if button and button.visible and button.focus_mode != Control.FOCUS_NONE:
        button.grab_focus()

func show_scenario_results(results: Dictionary, progress: Dictionary):
    """シナリオモード用の結果表示"""
    var room_name = StageInitializer.get_room_display_name(progress.current_room_id)
    title_label.text = "\"%s\" (%s)" % [room_name, GameStateManager.get_scenario_progress_text()]
    
    # 基本的な結果のみ表示
    intimate_value.text = "%d回" % results.get("intimate_violations", 0)
    seat_zone_value.text = ""
    for seat in results.get("seat_zone_status", []):
        seat_zone_value.text += "%s" % seat
        if seat != results.get("seat_zone_status", [])[-1]:
            seat_zone_value.text += "\n"

    # ボタン設定
    var is_last_room = GameStateManager.is_last_scenario_room()
    next_button.visible = true
    next_button.text = "Finish" if is_last_room else "Next Room"
    retry_button.text = "Retry"
    back_to_menu_button.text = "Back to Title"
    
    # 方向スコア行を非表示（シナリオモードでは簡略化）
    direction_value.get_parent().visible = false

    adjust_panel_size()
    show_with_animation()
    update_focus_navigation()

func adjust_panel_size():
    await get_tree().process_frame
    var content_size = background_panel.get_child(0).size
    background_panel.custom_minimum_size.y = content_size.y + 100

func show_experiment_results(results: Dictionary):
    """実験モード用の結果表示"""
    title_label.text = "実験結果"
    
    # 詳細な結果を表示
    intimate_value.text = "%d回" % results.get("intimate_violations", 0)
    seat_zone_value.text = ""
    for seat in results.get("seat_zone_status", []):
        seat_zone_value.text += "%s\n" % seat
   
    # ボタン設定
    next_button.visible = false
    retry_button.text = "Retry"
    back_to_menu_button.text = "Back to Menu"
    
    # 方向スコア行を表示
    direction_value.get_parent().visible = true
    
    adjust_panel_size()
    show_with_animation()
    update_focus_navigation()

func show_with_animation():
    """アニメーション付きで表示"""
    visible = true
    modulate.a = 0.0
    
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, 0.5)

func hide_with_animation():
    """アニメーション付きで非表示"""
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    tween.tween_callback(func(): visible = false)

func _on_retry_pressed():
    retry_pressed.emit()

func _on_next_pressed():
    next_pressed.emit()

func _on_back_to_menu_pressed():
    back_to_menu_pressed.emit()
