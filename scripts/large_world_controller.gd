extends Node

# Large-world layer: expands the playable battlefield without replacing the core RTS simulation.
# Target battlefield: 140 x 140 world units, roughly 4x the surface area of the old 70 x 70 map.
const WORLD_SIZE := 140.0
const HALF_WORLD := 68.0
const CAMERA_SIZE := 52.0
const CAMERA_MIN := 24.0
const CAMERA_MAX := 76.0

var game: Node3D
var camera: Camera3D

func _ready() -> void:
    game = get_parent() as Node3D
    await get_tree().process_frame
    await get_tree().process_frame
    _expand_world()

func _expand_world() -> void:
    if game == null:
        return
    camera = game.get("cam") as Camera3D
    # Scale the runtime ground and collision body created by main.gd.
    for child in game.get_children():
        if child is MeshInstance3D and child.mesh is BoxMesh:
            var mesh := child.mesh as BoxMesh
            if mesh.size.x >= 60.0 and mesh.size.z >= 60.0:
                mesh.size = Vector3(WORLD_SIZE, mesh.size.y, WORLD_SIZE)
        elif child is StaticBody3D:
            for c in child.get_children():
                if c is CollisionShape3D and c.shape is BoxShape3D:
                    var shape := c.shape as BoxShape3D
                    if shape.size.x >= 60.0 and shape.size.z >= 60.0:
                        shape.size = Vector3(WORLD_SIZE, shape.size.y, WORLD_SIZE)
    _configure_camera()

func _configure_camera() -> void:
    if camera == null:
        return
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = CAMERA_SIZE
    camera.current = true

func _process(_delta: float) -> void:
    if game == null:
        return
    if camera == null:
        camera = game.get("cam") as Camera3D
    if camera == null:
        return
    # This node runs after the legacy camera node in main.tscn, so the larger bounds win.
    camera.position.x = clamp(camera.position.x, -HALF_WORLD, HALF_WORLD)
    camera.position.z = clamp(camera.position.z, -HALF_WORLD, HALF_WORLD)
    camera.size = clamp(camera.size, CAMERA_MIN, CAMERA_MAX)

func _input(event: InputEvent) -> void:
    if game == null or camera == null:
        return
    # Handle the command before main.gd's unhandled-input layer so commands can reach
    # the expanded battlefield instead of the legacy 70-unit safety clamp.
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        var selected = game.get("selected")
        if selected == null or selected.is_empty():
            return
        var p := _mouse_world(event.position)
        p.x = clamp(p.x, -HALF_WORLD, HALF_WORLD)
        p.z = clamp(p.z, -HALF_WORLD, HALF_WORLD)
        var ids: Array[int] = []
        for u in selected:
            if is_instance_valid(u):
                var id_value = u.get_meta("id", u.get_meta("entity_id", 0))
                if int(id_value) > 0:
                    ids.append(int(id_value))
                if u.has_meta("target"):
                    u.set_meta("target", p)
                elif u.has_meta("move_to"):
                    u.set_meta("move_to", p)
        # Server-side direct application keeps this compatible with the existing authority model.
        if not ids.is_empty() and game.has_method("_apply_move"):
            game.call("_apply_move", ids, p, game.call("_local_peer_id"))
        get_viewport().set_input_as_handled()

func _mouse_world(pos: Vector2) -> Vector3:
    var from := camera.project_ray_origin(pos)
    var dir := camera.project_ray_normal(pos)
    var t := -from.y / dir.y if abs(dir.y) > 0.001 else 0.0
    return from + dir * t
