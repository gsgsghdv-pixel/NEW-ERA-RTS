extends Node

# Map safety layer: keeps the complete 70x70 playable area visible and
# prevents units/buildings/orders from escaping the playable rectangle.
const MAP_HALF := 35.0
const EDGE_MARGIN := 3.0
const SAFE_CAMERA_SIZE := 104.0

func _ready() -> void:
    await get_tree().process_frame
    _apply_camera_safety()

func _process(_delta: float) -> void:
    var game := get_parent()
    if game == null:
        return
    _apply_camera_safety()
    _clamp_world_objects(game)

func _apply_camera_safety() -> void:
    var game := get_parent()
    if game == null:
        return
    var cam = game.get("cam")
    if cam is Camera3D:
        cam.projection = Camera3D.PROJECTION_ORTHOGONAL
        cam.size = SAFE_CAMERA_SIZE
        cam.position = Vector3(0, 50, 50)
        cam.rotation_degrees = Vector3(-45, 0, 0)
        cam.current = true

func _clamp_world_objects(game: Node) -> void:
    var min_v := -MAP_HALF + EDGE_MARGIN
    var max_v := MAP_HALF - EDGE_MARGIN
    var lists := [game.get("units"), game.get("enemies"), game.get("buildings")]
    for collection in lists:
        if collection == null:
            continue
        for obj in collection:
            if is_instance_valid(obj) and obj is Node3D:
                var p: Vector3 = obj.position
                p.x = clamp(p.x, min_v, max_v)
                p.z = clamp(p.z, min_v, max_v)
                obj.position = p
                if obj.has_meta("target"):
                    var target: Vector3 = obj.get_meta("target")
                    target.x = clamp(target.x, min_v, max_v)
                    target.z = clamp(target.z, min_v, max_v)
                    obj.set_meta("target", target)
