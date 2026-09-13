extends Node

const SAFE_CAMERA_SIZE := 60.0

func _ready() -> void:
    await get_tree().process_frame
    var game := get_parent()
    if game == null:
        return
    var cam = game.get("cam")
    if cam is Camera3D:
        cam.projection = Camera3D.PROJECTION_ORTHOGONAL
        cam.size = SAFE_CAMERA_SIZE
        cam.position = Vector3(0,50,50)
        cam.rotation_degrees = Vector3(-45,0,0)
        cam.current = true
