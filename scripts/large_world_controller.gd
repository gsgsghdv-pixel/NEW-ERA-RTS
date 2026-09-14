extends Node

# Large-world layer: expands the playable battlefield and adds strategic landmarks.
const WORLD_SIZE := 140.0
const HALF_WORLD := 68.0
const CAMERA_SIZE := 52.0
const CAMERA_MIN := 24.0
const CAMERA_MAX := 76.0

var game: Node3D
var camera: Camera3D
var world_root: Node3D
var resource_nodes: Array[Node3D] = []
var tactical_points: Array[Node3D] = []

func _ready() -> void:
    game = get_parent() as Node3D
    await get_tree().process_frame
    await get_tree().process_frame
    _expand_world()
    _build_strategic_layer()

func _mat(hex: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.material_override = material
    n.position = Vector3(pos.x, size.y * 0.5 + 0.03, pos.z)
    parent.add_child(n)
    return n

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    n.mesh = mesh
    n.material_override = material
    n.position = Vector3(pos.x, pos.y + height * 0.5 + 0.04, pos.z)
    parent.add_child(n)
    return n

func _expand_world() -> void:
    if game == null:
        return
    camera = game.get("cam") as Camera3D
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

func _build_strategic_layer() -> void:
    if game == null or world_root != null:
        return
    world_root = Node3D.new()
    world_root.name = "StrategicBattlefield"
    game.add_child(world_root)

    var road := _mat("#57564e")
    var road_edge := _mat("#3e3d37")
    # Long central lanes make the large map read like a classic RTS battlefield.
    _box(world_root, Vector3(124, 0.07, 5.0), Vector3(0, 0, 0), road)
    _box(world_root, Vector3(5.0, 0.07, 124), Vector3(0, 0, 0), road)
    _box(world_root, Vector3(96, 0.06, 2.2), Vector3(0, 0, -25), road_edge)
    _box(world_root, Vector3(2.2, 0.06, 96), Vector3(25, 0, 0), road_edge)

    var resource_mat := _mat("#b98b2f")
    var resource_core := _mat("#e1c15b")
    var resource_positions := [
        Vector3(-55,0,-55), Vector3(-47,0,-55), Vector3(-55,0,-47),
        Vector3(55,0,55), Vector3(47,0,55), Vector3(55,0,47),
        Vector3(-54,0,49), Vector3(-44,0,58), Vector3(54,0,-49), Vector3(44,0,-58),
        Vector3(-12,0,-56), Vector3(12,0,56), Vector3(-56,0,12), Vector3(56,0,-12)
    ]
    for i in range(resource_positions.size()):
        var p: Vector3 = resource_positions[i]
        var node := Node3D.new()
        node.name = "SupplyField_%02d" % (i + 1)
        node.position = p
        node.set_meta("resource_value", 1500)
        world_root.add_child(node)
        _cylinder(node, 1.6, 0.35, Vector3.ZERO, resource_mat)
        _cylinder(node, 0.7, 0.55, Vector3(0,0.32,0), resource_core)
        resource_nodes.append(node)

    var concrete := _mat("#686d67")
    var dark := _mat("#41443f")
    var cover_positions := [
        Vector3(-58,0,-18), Vector3(-50,0,-15), Vector3(-42,0,-12),
        Vector3(58,0,18), Vector3(50,0,15), Vector3(42,0,12),
        Vector3(-18,0,58), Vector3(-15,0,50), Vector3(-12,0,42),
        Vector3(18,0,-58), Vector3(15,0,-50), Vector3(12,0,-42),
        Vector3(-58,0,8), Vector3(-58,0,18), Vector3(58,0,-8), Vector3(58,0,-18),
        Vector3(-18,0,-58), Vector3(-8,0,-58), Vector3(18,0,58), Vector3(8,0,58),
        Vector3(-32,0,14), Vector3(32,0,-14), Vector3(-14,0,32), Vector3(14,0,-32)
    ]
    for i in range(cover_positions.size()):
        var p: Vector3 = cover_positions[i]
        var h := 1.2 + float(i % 3) * 0.55
        var w := 3.0 + float(i % 2) * 1.8
        _box(world_root, Vector3(w, h, 2.0), p, concrete if i % 2 == 0 else dark)

    var marker := _mat("#788844")
    var tactical_positions := [Vector3(-55,0,-55), Vector3(55,0,-55), Vector3(-55,0,55), Vector3(55,0,55), Vector3(0,0,0)]
    for i in range(tactical_positions.size()):
        var p: Vector3 = tactical_positions[i]
        var point := Node3D.new()
        point.name = "TacticalPoint_%02d" % (i + 1)
        point.position = p
        point.set_meta("strategic", true)
        point.set_meta("capturable", true)
        world_root.add_child(point)
        _cylinder(point, 3.0, 0.18, Vector3.ZERO, dark)
        _cylinder(point, 1.8, 0.22, Vector3(0,0.18,0), marker)
        tactical_points.append(point)

    # Four large neutral compounds create recognizable combat zones.
    var compound := _mat("#333a35")
    for p in [Vector3(-34,0,-34), Vector3(34,0,-34), Vector3(-34,0,34), Vector3(34,0,34)]:
        _box(world_root, Vector3(8,0.18,8), p, compound)
        _box(world_root, Vector3(0.8,3.0,8), Vector3(p.x - 3.6,0,p.z), dark)
        _box(world_root, Vector3(0.8,3.0,8), Vector3(p.x + 3.6,0,p.z), dark)

func _process(_delta: float) -> void:
    if game == null:
        return
    if camera == null:
        camera = game.get("cam") as Camera3D
    if camera == null:
        return
    camera.position.x = clamp(camera.position.x, -HALF_WORLD, HALF_WORLD)
    camera.position.z = clamp(camera.position.z, -HALF_WORLD, HALF_WORLD)
    camera.size = clamp(camera.size, CAMERA_MIN, CAMERA_MAX)

func _input(event: InputEvent) -> void:
    if game == null or camera == null:
        return
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
        if not ids.is_empty() and game.has_method("_apply_move"):
            game.call("_apply_move", ids, p, game.call("_local_peer_id"))
        get_viewport().set_input_as_handled()

func _mouse_world(pos: Vector2) -> Vector3:
    var from := camera.project_ray_origin(pos)
    var dir := camera.project_ray_normal(pos)
    var t := -from.y / dir.y if abs(dir.y) > 0.001 else 0.0
    return from + dir * t

func get_resource_nodes() -> Array[Node3D]:
    return resource_nodes

func get_tactical_points() -> Array[Node3D]:
    return tactical_points
