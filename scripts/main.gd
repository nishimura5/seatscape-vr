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

static func load_external_glb_packed_scene(glb_path: String) -> PackedScene:
	var resource := ResourceLoader.load(glb_path)
	if resource is PackedScene:
		return resource

	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var append_err := gltf_document.append_from_file(glb_path, gltf_state)
	if append_err != OK:
		print("GLTFDocumentの読み込みに失敗: %s (err=%d)" % [glb_path, append_err])
		push_error("GLTFDocumentの読み込みに失敗: %s (err=%d)" % [glb_path, append_err])
		return null

	var generated_root := gltf_document.generate_scene(gltf_state)
	if generated_root == null:
		print("GLTFDocument.generate_sceneに失敗: " + glb_path)
		push_error("GLTFDocument.generate_sceneに失敗: " + glb_path)
		return null

	var packed := PackedScene.new()
	var pack_err := packed.pack(generated_root)
	generated_root.free()
	if pack_err != OK:
		print("PackedScene.packに失敗: %s (err=%d)" % [glb_path, pack_err])
		push_error("PackedScene.packに失敗: %s (err=%d)" % [glb_path, pack_err])
		return null

	return packed

static func load_data_packed_scene(relative_path: String) -> PackedScene:
	var clean_path := clean_data_relative_path(relative_path)
	# .glb は存在確認してから load_data_resource で読む
	if clean_path.to_lower().ends_with(".glb"):
		var glb_path := get_data_path(clean_path)
		if not FileAccess.file_exists(glb_path):
			print(".glbファイルが見つかりませんでした: " + glb_path)
			push_error(".glbファイルが見つかりませんでした: " + glb_path)
			return null

		var glb_scene := load_external_glb_packed_scene(glb_path)
		if glb_scene:
			print("PackedSceneを正常に読み込みました: " + glb_path)
			return glb_scene

		print(".glbのPackedScene化に失敗しました: " + glb_path)
		push_error(".glbのPackedScene化に失敗しました: " + glb_path)
		return null

	var resource := load_data_resource(relative_path)
	if not resource:
		print("PackedSceneを読み込めませんでした: " + get_data_path(relative_path))
		return null
	if resource is PackedScene:
		print("PackedSceneを正常に読み込みました: " + get_data_path(relative_path))
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
