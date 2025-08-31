# scripts/ui/npc_icon.gd
extends Sprite2D

@onready var name_label: Label = $NameLabel

var npc_data: NpcRepository.Npc
var is_draggable: bool = true
var default_texture: Texture2D
var texture_load_attempted: bool = false

func _ready():
    # ノードが存在するかチェック
    if not name_label:
        name_label = get_node("NameLabel")
    
    # サイズを確実に設定
    scale = Vector2.ONE
    offset = Vector2.ZERO
    
    # _ready後にテクスチャ読み込みを試行
    if npc_data and not texture_load_attempted:
        load_avatar_texture()

func setup_npc(npc: NpcRepository.Npc):
    npc_data = npc
    
    if not name_label:
        name_label = get_node("NameLabel")
    
    if name_label:
        name_label.text = npc.display_name

    # setup_npc呼び出し時に即座にテクスチャ読み込みを試行
    load_avatar_texture()

func load_avatar_texture():
    if not npc_data:
        return
    texture_load_attempted = true
    
    # NPCのメッシュIDに基づいてアバター画像を設定
    var texture_path = get_avatar_texture_path(npc_data.mesh_id)
    var loaded_texture = load(texture_path)
    
    texture = loaded_texture
    scale = Vector2(0.8, 0.8)

func get_avatar_texture_path(mesh_id: String) -> String:
    # 実際のゲームではここでNPCの画像パスを返す
    match mesh_id:
        "human_male_01", "human_male_02", "human_male_03", "human_male_04":
            return "res://data/icons/male_avatar.svg"
        "human_female_01", "human_female_02", "human_female_03", "human_female_04":
            return "res://data/icons/female_avatar.svg"
        _:
            return ""

func update_appearance():
    if not is_draggable:
        modulate = Color(0.5, 0.5, 0.5, 1.0)
    elif not npc_data:
        modulate = Color.GRAY
    else:
        # 通常状態では元の色を保持
        modulate = Color.WHITE

func set_draggable(draggable: bool):
    is_draggable = draggable
    update_appearance()

func get_npc_id() -> String:
    return npc_data.id if npc_data else ""

# テクスチャ読み込みを強制的に再試行するためのメソッド
func force_reload_texture():
    """外部から呼び出してテクスチャ読み込みを強制実行"""
    texture_load_attempted = false
    if npc_data:
        load_avatar_texture()