# scripts/seating_environment.gd
extends Node3D

@onready var room_mesh: MeshInstance3D = $RoomMesh
@onready var seats_container: Node3D = $SeatsContainer
@onready var npcs_container: Node3D = $NpcsContainer
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var lightmap_gi: LightmapGI = $LightmapGI

var floor_generator: FloorGenerator
var ceil_generator: CeilGenerator
var wall_generator: WallGenerator
var lighting_manager: LightingManager
var seat_scene = preload("res://scenes/3d/seat_3d.tscn") if ResourceLoader.exists("res://scenes/3d/seat_3d.tscn") else null
var npc_scene = preload("res://scenes/3d/npc_3d.tscn") if ResourceLoader.exists("res://scenes/3d/npc_3d.tscn") else null

var floor_tiles: Array[MeshInstance3D] = []
var ceil_tiles: Array[MeshInstance3D] = []
var wall_meshes: Array[MeshInstance3D] = []
var room_lights: Array[Light3D] = []
var seat_nodes: Dictionary = {}  # seat_id -> Node3D の管理

func _ready():
    floor_generator = FloorGenerator.new()
    floor_generator.set_color_style(FloorGenerator.ColorStyle.CORPORATE)
    
    ceil_generator = CeilGenerator.new()
    
    wall_generator = WallGenerator.new()
    
    lighting_manager = LightingManager.new()

func setup_environment():
    create_room_geometry()
    setup_lighting()
    spawn_seats()
    spawn_npcs()
    setup_lightmap_gi()
    
func create_room_geometry():
    var room = DataRepository.room_repository.get_current_room()
    if not room:
        return
    
    create_floor(room)
    create_walls(room)
    create_ceiling(room)

func create_ceiling(room: RoomRepository.Room):
    cleanup_ceiling()
    ceil_tiles = ceil_generator.create_ceiling(self, room)

func cleanup_ceiling():
    var children_to_remove = []
    for child in get_children():
        if child.name.begins_with("Ceiling"):
            children_to_remove.append(child)
    
    for child in children_to_remove:
        child.queue_free()
    
    ceil_tiles.clear()

func set_ceiling_visibility(tar_visible: bool):
    for tile in ceil_tiles:
        if is_instance_valid(tile):
            tile.visible = tar_visible

func set_wall_visibility(tar_visible: bool):
    for wall_mesh in wall_meshes:
        if is_instance_valid(wall_mesh) and wall_mesh.name == "SouthWall_Mesh":
            wall_mesh.visible = tar_visible
            break

func setup_lighting():
    var room = DataRepository.room_repository.get_current_room()
    if not room:
        return
    
#    room_lights = lighting_manager.create_ambient_lighting(self, room)
    room_lights = lighting_manager.create_layered_room_lighting(self, room)


func create_floor(room: RoomRepository.Room):
    if room_mesh:
        room_mesh.queue_free()
    floor_tiles = floor_generator.create_tiled_floor(self, room)

func create_walls(room: RoomRepository.Room):
    wall_meshes = wall_generator.create_walls(self, room)

func spawn_seats():
    for child in seats_container.get_children():
        child.queue_free()
    
    seat_nodes.clear()
    
    var seats = DataRepository.seat_repository.get_all_seats()
    for seat in seats:
        create_seat_3d(seat)

func create_seat_3d(seat: SeatRepository.Seat):
    var seat_node: Node3D
    
    if seat_scene:
        seat_node = seat_scene.instantiate()
        if seat_node.has_method("set_seat_data"):
            seat_node.set_seat_data(seat)
   
    seat_node.name = "Seat_" + seat.id
    seat_node.position = seat.position
    seat_node.rotation_degrees.y = seat.rotation_degrees
    
    seats_container.add_child(seat_node)
    seat_nodes[seat.id] = seat_node  # 座席ノードを辞書に登録
    
func spawn_npcs():
    for child in npcs_container.get_children():
        child.queue_free()
    
    var seated_npc_ids = DataRepository.assignment_repository.get_seated_npc_ids()
    for npc_id in seated_npc_ids:
        var npc = DataRepository.npc_repository.get_npc(npc_id)
        var seat_id = DataRepository.get_npc_seat_id(npc_id)
        var seat = DataRepository.seat_repository.get_seat(seat_id)
        
        if npc and seat:
            create_npc_3d(npc, seat)

func create_npc_3d(npc: NpcRepository.Npc, seat: SeatRepository.Seat):
    var npc_node = npc_scene.instantiate()
    npc_node.set_npc_data(npc)

    if npc_node.has_method("set_sitting_pose"):
        npc_node.set_sitting_pose()

    disable_shadows_recursive(npc_node)
    
    npc_node.name = "NPC_" + npc.id
    var offset = Vector3(0, 0, 0.2).rotated(Vector3.UP, deg_to_rad(seat.rotation_degrees))
    npc_node.position = seat.position + offset
    npc_node.rotation_degrees.y = seat.rotation_degrees
    
    npcs_container.add_child(npc_node)

func disable_shadows_recursive(node: Node):
    if node is MeshInstance3D:
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    
    for child in node.get_children():
        disable_shadows_recursive(child)

func set_seat_occupied_state(seat_id: String, occupied: bool):
    var seat_node = seat_nodes.get(seat_id)
    if seat_node and seat_node.has_method("set_occupied_state"):
        print("座席 ", seat_id, " の占有状態を ", occupied, " に設定")
        seat_node.set_occupied_state(occupied)

func setup_lightmap_gi():
    # tscnで設定済み
    lightmap_gi.quality = LightmapGI.BAKE_QUALITY_LOW
    lightmap_gi.environment_custom_energy = 0.3

func test_lightmap_without_lights():
    """ライトマップ確認のため光源を削除"""
    lighting_manager.light_toggle()
