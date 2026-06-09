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

    # NPCのgenderに基づいてアバター画像を設定
    var texture_path = get_avatar_texture_path(npc_data.gender)
    if texture_path.is_empty():
        return

    var loaded_texture = Main.load_data_texture(texture_path)
    if not loaded_texture:
        return
    
    texture = loaded_texture
    scale = Vector2(0.8, 0.8)

func get_avatar_texture_path(gender: String) -> String:
    # npcs.jsonで管理するgenderに従ってアイコンを決定
    print("Getting avatar texture for gender: ", gender)
    match gender.to_lower():
        "male":
            return "icons/male_avatar.svg"
        "female":
            return "icons/female_avatar.svg"
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
