# scripts/autoload/dialog_manager.gd
extends Node

const DIALOGS_DATA_PATH = "res://data/configs/dialogs.json"

var dialog_data: Dictionary = {}
var current_dialog_system: Control = null

func _ready():
    load_dialog_data()

func load_dialog_data():
    var file = FileAccess.open(DIALOGS_DATA_PATH, FileAccess.READ)
    if not file:
        print("ダイアログデータファイルが見つかりません: ", DIALOGS_DATA_PATH)
        return
    
    var json_text = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var parse_result = json.parse(json_text)
    
    if parse_result != OK:
        print("ダイアログデータのJSONパースエラー: ", json.get_error_message())
        return
    
    var data = json.data
    if data.has("dialogs"):
        dialog_data = data.dialogs
        print("ダイアログデータを読み込みました: ", dialog_data.keys().size(), "個のダイアログ")
    else:
        print("ダイアログデータの形式が正しくありません")

func start_dialog(dialog_key: String, dialog_system: Control):
    if not dialog_data.has(dialog_key):
        print("ダイアログキーが見つかりません: ", dialog_key)
        return

    if not dialog_system:
        print("Dialog system is not set.")
        return

    current_dialog_system = dialog_system
    var dialog_info = dialog_data[dialog_key]
    
    dialog_system.show_dialog(dialog_info.character, dialog_info.messages)

func get_dialog_data(dialog_key: String) -> Dictionary:
    return dialog_data.get(dialog_key, {})

func reload_dialog_data():
    """開発中のリロード機能"""
    print("ダイアログデータを再読み込み中...")
    load_dialog_data()

func has_dialog(dialog_key: String) -> bool:
    """指定されたダイアログキーが存在するかチェック"""
    return dialog_data.has(dialog_key)

func add_dialog_runtime(dialog_key: String, character: String, messages: Array[String]):
    """実行時にダイアログを追加（動的生成用）"""
    dialog_data[dialog_key] = {
        "character": character,
        "messages": messages
    }
    print("ダイアログを追加しました: ", dialog_key)

func get_all_dialog_keys() -> Array[String]:
    """利用可能なダイアログキーの一覧を取得"""
    var keys: Array[String] = []
    for key in dialog_data.keys():
        keys.append(key)
    return keys
