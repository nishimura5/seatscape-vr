# scripts/ui/xr_button_focus.gd
class_name XRButtonFocus
extends RefCounted

signal button_activated(button: Button)

var buttons_array: Array[Button] = []
var current_focused_button: Button = null
var left_controller: XRController3D = null
var right_controller: XRController3D = null

# サムスティック入力用の変数
var thumbstick_deadzone: float = 0.3
var last_thumbstick_input: Vector2 = Vector2.ZERO
var accept_pressed: bool = true

# フォーカス表示設定
var focus_color: Color = Color(1.2, 1.2, 1.2)
var focus_scale: Vector2 = Vector2(1.1, 1.1)
var normal_color: Color = Color.WHITE
var normal_scale: Vector2 = Vector2(1.0, 1.0)
var tween_duration: float = 0.1

func _init(left: XRController3D = null, right: XRController3D = null):
    """
    XRButtonFocusを初期化
    @param left: 左のXRController3D
    @param right: 右のXRController3D
    """
    left_controller = left
    right_controller = right

func setup_buttons(button_list: Array[Button], initial_focus_index: int = 0):
    """
    ナビゲーション対象のボタンを設定
    @param button_list: ナビゲーション対象のボタン配列
    @param initial_focus_index: 初期フォーカスボタンのインデックス
    """
    # 既存のフォーカスをクリア
    clear_focus()
    
    # 有効なボタンのみを配列に追加
    buttons_array.clear()
    for button in button_list:
        if is_instance_valid(button) and button.is_inside_tree() and button.visible and not button.disabled:
            buttons_array.append(button)
    
    # 初期フォーカスを設定
    if buttons_array.size() > 0:
        var focus_index = clamp(initial_focus_index, 0, buttons_array.size() - 1)
        set_button_focus(buttons_array[focus_index])

func set_controller(left: XRController3D, right: XRController3D):
    """XRコントローラーを設定"""
    self.left_controller = left
    self.right_controller = right

func process_input():
    """
    XR入力を処理（毎フレーム呼び出す）
    XRコントローラーが設定されている場合のみ処理
    """
    if not is_instance_valid(left_controller) or not is_instance_valid(right_controller):
        return

    var accept_current = right_controller.is_button_pressed("accept")
    var thumbstick_input = left_controller.get_vector2("player_move")

    # サムスティックによるナビゲーション
    handle_thumbstick_navigation(thumbstick_input)
    
    # Acceptボタンでの決定
    if accept_current and not accept_pressed:
        activate_current_button()
    
    accept_pressed = accept_current

func handle_thumbstick_navigation(thumbstick_input: Vector2):
    """
    サムスティックによるボタンナビゲーション
    @param thumbstick_input: サムスティックの入力値
    """
    # デッドゾーン処理
    if thumbstick_input.length() < thumbstick_deadzone:
        last_thumbstick_input = Vector2.ZERO
        return
    
    # 前回の入力と比較して、新しい入力があるかチェック
    var input_changed = (last_thumbstick_input.length() < thumbstick_deadzone and 
                        thumbstick_input.length() >= thumbstick_deadzone)
    
    if not input_changed:
        last_thumbstick_input = thumbstick_input
        return
    
    if buttons_array.is_empty():
        last_thumbstick_input = thumbstick_input
        return
    
    var current_index = buttons_array.find(current_focused_button)
    if current_index == -1:
        current_index = 0
        # 現在のフォーカスボタンが無効な場合、最初の有効なボタンにフォーカス
        set_button_focus(buttons_array[current_index])
        last_thumbstick_input = thumbstick_input
        return
    
    # 水平方向の移動（左右）
    if abs(thumbstick_input.x) > abs(thumbstick_input.y):
        if thumbstick_input.x > 0:  # 右方向
            current_index = (current_index + 1) % buttons_array.size()
        else:  # 左方向
            current_index = (current_index - 1 + buttons_array.size()) % buttons_array.size()
        
        set_button_focus(buttons_array[current_index])
    
    # 垂直方向の移動（上下）
    elif abs(thumbstick_input.y) > abs(thumbstick_input.x):
        if thumbstick_input.y > 0:  # 下方向
            current_index = (current_index + 1) % buttons_array.size()
        else:  # 上方向
            current_index = (current_index - 1 + buttons_array.size()) % buttons_array.size()
        
        set_button_focus(buttons_array[current_index])
    
    last_thumbstick_input = thumbstick_input

func set_button_focus(button: Button):
    """
    指定されたボタンにフォーカスを設定
    @param button: フォーカスを設定するボタン
    """
    if not is_instance_valid(button) or button == current_focused_button:
        return
    
    # 前のボタンのフォーカス効果をリセット
    modulate_button_focus(current_focused_button, false)
    
    current_focused_button = button
    modulate_button_focus(current_focused_button, true)

func modulate_button_focus(button: Button, is_focused: bool):
    """
    ボタンのフォーカス表示を変更
    @param button: 対象のボタン
    @param is_focused: フォーカス状態かどうか
    """
    if not is_instance_valid(button) or not button.is_inside_tree():
        return
    
    var target_color = focus_color if is_focused else normal_color
    var target_scale = focus_scale if is_focused else normal_scale
    
    button.modulate = target_color
    
    # スケールアニメーション
    var tween = button.create_tween()
    if tween:
        tween.tween_property(button, "scale", target_scale, tween_duration)

func activate_current_button():
    """現在フォーカスされているボタンを有効化"""
    button_activated.emit(current_focused_button)

func get_current_focused_button() -> Button:
    """現在フォーカスされているボタンを取得"""
    return current_focused_button

func clear_focus():
    """全てのフォーカスをクリア"""
    if is_instance_valid(current_focused_button):
        modulate_button_focus(current_focused_button, false)
    current_focused_button = null

func set_focus_appearance(focus_col: Color, focus_scl: Vector2, normal_col: Color = Color.WHITE, normal_scl: Vector2 = Vector2.ONE):
    """
    フォーカス表示の外観を設定
    @param focus_col: フォーカス時の色
    @param focus_scl: フォーカス時のスケール
    @param normal_col: 通常時の色
    @param normal_scl: 通常時のスケール
    """
    focus_color = focus_col
    focus_scale = focus_scl
    normal_color = normal_col
    normal_scale = normal_scl

func set_thumbstick_deadzone(deadzone: float):
    """
    サムスティックのデッドゾーンを設定
    @param deadzone: デッドゾーンの値（0.0-1.0）
    """
    thumbstick_deadzone = clamp(deadzone, 0.0, 1.0)

func add_button(button: Button):
    """
    ナビゲーション対象にボタンを追加
    @param button: 追加するボタン
    """
    if is_instance_valid(button) and not buttons_array.has(button):
        buttons_array.append(button)

func remove_button(button: Button):
    """
    ナビゲーション対象からボタンを削除
    @param button: 削除するボタン
    """
    if is_instance_valid(button) and buttons_array.has(button):
        if current_focused_button == button:
            clear_focus()
        buttons_array.erase(button)

func get_button_count() -> int:
    """ナビゲーション対象のボタン数を取得"""
    return buttons_array.size()

func focus_button_by_index(index: int):
    """
    インデックスでボタンにフォーカスを設定
    @param index: ボタンのインデックス
    """
    if index >= 0 and index < buttons_array.size():
        set_button_focus(buttons_array[index])

func get_focused_button_index() -> int:
    """現在フォーカスされているボタンのインデックスを取得"""
    return buttons_array.find(current_focused_button)

func refresh_buttons():
    """
    ボタン配列を更新（無効なボタンを除去）
    """
    var valid_buttons: Array[Button] = []
    for button in buttons_array:
        if is_instance_valid(button) and button.is_inside_tree() and button.visible and not button.disabled:
            valid_buttons.append(button)
    
    buttons_array = valid_buttons
    
    # 現在のフォーカスボタンが無効な場合はクリア
    if not is_instance_valid(current_focused_button) or not buttons_array.has(current_focused_button):
        clear_focus()
        if buttons_array.size() > 0:
            set_button_focus(buttons_array[0])
