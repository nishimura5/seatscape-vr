# scripts/main.gd
class_name Main
extends Control

const DATA_FOLDER_FULL_PATH := "C:/Users/a5/Desktop/data"
const PROJECT_DATA_FOLDER := "res://data"

static func get_data_root_path() -> String:
	var path := DATA_FOLDER_FULL_PATH.strip_edges().replace("\\", "/")
	while path.ends_with("/") and path.length() > 0:
		path = path.substr(0, path.length() - 1)
	return path

static func get_data_path(relative_path: String) -> String:
	var data_root := get_data_root_path()
	var clean_path := clean_data_relative_path(relative_path)
	if data_root.is_empty():
		return get_project_data_path(clean_path)
	return data_root + "/" + clean_path

static func get_project_data_path(relative_path: String) -> String:
	return PROJECT_DATA_FOLDER + "/" + clean_data_relative_path(relative_path)

static func clean_data_relative_path(relative_path: String) -> String:
	var path := relative_path.strip_edges().replace("\\", "/")
	if path.begins_with("res://data/"):
		path = path.substr("res://data/".length())
	elif path.begins_with("data/"):
		path = path.substr("data/".length())
	while path.begins_with("/"):
		path = path.substr(1)
	return path

static func is_data_root_available() -> bool:
	var data_root := get_data_root_path()
	return not data_root.is_empty() and DirAccess.dir_exists_absolute(data_root)

static func load_data_resource(relative_path: String) -> Resource:
	var path := get_data_path(relative_path)
	var resource := ResourceLoader.load(path)
	if resource:
		return resource
	resource = load(path)
	if resource:
		return resource
	push_error("外部dataリソースを読み込めませんでした: " + path)
	return null

static func load_data_packed_scene(relative_path: String) -> PackedScene:
	var resource := load_data_resource(relative_path)
	if not resource:
		return null
	if resource is PackedScene:
		return resource
	push_error("PackedSceneではありません: " + get_data_path(relative_path))
	return null

static func load_data_texture(relative_path: String) -> Texture2D:
	var path := get_data_path(relative_path)
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource

	resource = load(path)
	if resource is Texture2D:
		return resource

	if FileAccess.file_exists(path):
		var image := Image.new()
		var err := image.load(path)
		if err == OK:
			return ImageTexture.create_from_image(image)

	push_error("外部dataテクスチャを読み込めませんでした: " + path)
	return null

func _ready():
	_initialize_external_data()

	# メインノードとしてグループに追加
	add_to_group("main")
	print("gamepad:", Input.get_connected_joypads())
	print("Main node initialized and added to group")
	
	# SceneManagerの初期化を待つ
	call_deferred("notify_scene_manager")

func notify_scene_manager():
	# SceneManagerが存在することを確認
	if SceneManager:
		print("Main node ready for scene management")

func _initialize_external_data():
	print("External data folder: ", Main.get_data_root_path())
	if not Main.is_data_root_available():
		push_warning("外部dataフォルダが見つかりません: " + Main.get_data_root_path())

	if DialogManager:
		DialogManager.reload_dialog_data()
	if StageInitializer:
		StageInitializer.load_json_data()
	if GameStateManager:
		GameStateManager.reload_narrative_data()
