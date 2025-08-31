# scripts/main.gd
extends Control

func _ready():
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
