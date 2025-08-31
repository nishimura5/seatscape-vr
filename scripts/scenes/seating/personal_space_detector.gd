# scripts/personal_space_detector.gd
extends Area3D

signal zone_entered(zone_id: String, zone_level: String)
signal zone_exited(zone_id: String, zone_level: String)

var current_zones: Dictionary = {}  # area_name -> zone_level

func _ready():
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D):
    if area.name.begins_with("IntimateArea_"):
        zone_entered.emit(area.name.replace("IntimateArea_", ""), "intimate")
    elif area.name.begins_with("PersonalArea_"):
        zone_entered.emit(area.name.replace("PersonalArea_", ""), "personal")
    elif area.name.begins_with("SocialArea_"):
        zone_entered.emit(area.name.replace("SocialArea_", ""), "social")
        
func _on_area_exited(area: Area3D):
    if area.name.begins_with("IntimateArea_"):
        zone_exited.emit(area.name.replace("IntimateArea_", ""), "personal")
    elif area.name.begins_with("PersonalArea_"):
        zone_exited.emit(area.name.replace("PersonalArea_", ""), "social")
    elif area.name.begins_with("SocialArea_"):
        zone_exited.emit(area.name.replace("SocialArea_", ""), "none")

func get_current_zones() -> Dictionary:
    return current_zones.duplicate()

func is_in_zone(zone_id: String, zone_level: String) -> bool:
    for area_name in current_zones.keys():
        if current_zones[area_name] == zone_level:
            # このエリアが指定されたNPCのものかチェック
            if area_name.ends_with("_" + zone_id):
                return true
    return false
