# scripts/improved_lighting_manager.gd
class_name LightingManager
extends RefCounted

# 照明レイヤー設定
var ceiling_light_height: float = 0.1  # 天井からの距離
var floor_light_height: float = 1.8   # 床照明の高さ

# 照明パラメータ
var ceiling_light_energy: float = 0.2
var floor_light_energy: float = 0.6

var ceiling_light_range: float = 6.0
var floor_light_range: float = 16.0

var light_color: Color = Color(1.0, 0.98, 0.95)
var up_light_energy: float = 0.3

# ライト管理
var created_lights: Array[Light3D] = []

func create_layered_room_lighting(parent_node: Node3D, room: RoomRepository.Room) -> Array[Light3D]:
    cleanup_all_lights(parent_node)
    var all_lights: Array[Light3D] = []
    
    var ceiling_lights = create_ceiling_lights(parent_node, room)
    all_lights.append_array(ceiling_lights)

    var ambient_lights = create_ambient_lights(parent_node, room)
    all_lights.append_array(ambient_lights)
    var up_light = create_up_light(parent_node)
    all_lights.append(up_light)

    created_lights = all_lights.duplicate()
    print("階層照明システム: 合計", all_lights.size(), "個のライトを配置")
    return all_lights

func create_ceiling_lights(parent_node: Node3D, room: RoomRepository.Room) -> Array[OmniLight3D]:
    var lights: Array[OmniLight3D] = []
    var positions = calculate_ceiling_positions(room)
    
    for position in positions:
        var top_light = OmniLight3D.new()
        top_light.position = position
        top_light.light_energy = ceiling_light_energy
        top_light.light_color = light_color
        top_light.omni_range = ceiling_light_range
        top_light.omni_attenuation = 0.8  # 緩やかな減衰
        top_light.shadow_enabled = false
        top_light.name = "CeilingLight_" + str(position.x) + "_" + str(position.z)
        parent_node.add_child(top_light)
        lights.append(top_light)

        var bottom_light = OmniLight3D.new()
        bottom_light.position = Vector3(position.x, floor_light_height, position.z)
        bottom_light.light_energy = floor_light_energy
        bottom_light.light_color = light_color
        bottom_light.omni_range = floor_light_range
        bottom_light.omni_attenuation = 1.2  # 強めの減衰
        bottom_light.shadow_enabled = false
        bottom_light.name = "FloorLight_" + str(position.x) + "_" + str(position.z)
        parent_node.add_child(bottom_light)
        lights.append(bottom_light)

    return lights

func create_ambient_lights(parent_node: Node3D, room: RoomRepository.Room) -> Array[DirectionalLight3D]:
    var lights: Array[DirectionalLight3D] = []
    # north, south, east, west の4方向に照射(90°)
    var directions = [Vector3(-10, 10, 0), Vector3(-10, 100, 0), Vector3(-10, 190, 0), Vector3(-10, 280, 0)]

    # ambient_energy by room_size
    var ambient_energy = 0.005 * (room.size.x * room.size.z)

    for dir in directions:
        var ambient_light = DirectionalLight3D.new()
        ambient_light.light_energy = ambient_energy
        ambient_light.light_color = light_color
        ambient_light.rotation_degrees = dir
        ambient_light.shadow_enabled = false
        ambient_light.name = "AmbientDirectional_" + str(dir)
        parent_node.add_child(ambient_light)
        lights.append(ambient_light)

    return lights   

func create_up_light(parent_node: Node3D) -> DirectionalLight3D:
    var ambient_light = DirectionalLight3D.new()
    ambient_light.light_energy = up_light_energy
    ambient_light.light_color = light_color

    # 下から真上に照射
    ambient_light.rotation_degrees = Vector3(90, 0, 0)
    ambient_light.shadow_enabled = false

    ambient_light.name = "UpLight"
    parent_node.add_child(ambient_light)
    
    return ambient_light


func calculate_ceiling_positions(room: RoomRepository.Room) -> Array[Vector3]:
    var positions: Array[Vector3] = []
    var spacing = 4.0  # 4m間隔
    var height = room.size.y - ceiling_light_height
    
    var lights_x = max(1, int(ceil(room.size.x / spacing)))
    var lights_z = max(1, int(ceil(room.size.z / spacing)))
    
    for x in range(lights_x):
        for z in range(lights_z):
            var pos_x = (x + 0.5) * room.size.x / lights_x
            var pos_z = (z + 0.5) * room.size.z / lights_z
            positions.append(Vector3(pos_x, height, pos_z))
    
    return positions

func cleanup_all_lights(parent_node: Node3D):
    var lights_to_remove = []
    for child in parent_node.get_children():
        if child.name.begins_with("CeilingLight_") or \
           child.name.begins_with("MidLight_") or \
           child.name.begins_with("FloorLight_") or \
           child.name == "AmbientDirectional":
            lights_to_remove.append(child)
    
    for light in lights_to_remove:
        light.queue_free()
    
    created_lights.clear()

func adjust_lighting_intensity(multiplier: float):
    """全照明の強度を一括調整"""
    for light in created_lights:
        if is_instance_valid(light):
            light.light_energy *= multiplier

func light_toggle():
    """全照明のオン/オフを切り替え"""
    for light in created_lights:
        if is_instance_valid(light):
            light.visible = not light.visible
            print("ライト切り替え: ", light.name, " - ", light.visible)
