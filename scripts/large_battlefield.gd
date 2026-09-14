extends Node

# Strategic battlefield layer: visual landmarks, roads, cover, resource fields and tactical points.
# Designed to stay lightweight: primitive meshes, no external assets.
const FIELD_LIMIT := 33.0
const RESOURCE_COUNT := 12
const COVER_COUNT := 24
var game: Node3D
var resource_nodes: Array[Node3D] = []
var tactical_points: Array[Node3D] = []

func _ready() -> void:
    game = get_parent()
    await get_tree().process_frame
    _build_battlefield()

func _mat(hex: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: StandardMaterial3D, y: float = 0.0) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.material_override = material
    n.position = Vector3(pos.x, y + size.y * 0.5, pos.z)
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
    n.position = Vector3(pos.x, pos.y + height * 0.5, pos.z)
    parent.add_child(n)
    return n

func _build_battlefield() -> void:
    if game == null: return
    var root := Node3D.new()
    root.name = "StrategicBattlefield"
    game.add_child(root)

    # Main roads create readable lanes across the battlefield.
    var road := _mat("#55534a")
    var road_edge := _mat("#403f39")
    _box(root, Vector3(58,0.06,4.5), Vector3(0,0,0), road, 0.02)
    _box(root, Vector3(4.5,0.06,58), Vector3(0,0,0), road, 0.025)
    _box(root, Vector3(42,0.05,2.0), Vector3(0,0,-15), road_edge, 0.03)
    _box(root, Vector3(2.0,0.05,42), Vector3(15,0,0), road_edge, 0.03)

    # Resource fields: visualized as compact supply depots.
    var resource_mat := _mat("#c69b3b")
    var resource_glow := _mat("#e0bd58")
    var resource_positions := [
        Vector3(-25,0,-25), Vector3(-19,0,-25), Vector3(-25,0,-19),
        Vector3(25,0,25), Vector3(19,0,25), Vector3(25,0,19),
        Vector3(-26,0,23), Vector3(-21,0,27), Vector3(26,0,-23), Vector3(21,0,-27),
        Vector3(-6,0,-27), Vector3(6,0,27)
    ]
    for p in resource_positions:
        var node := Node3D.new()
        node.name = "SupplyField_%d" % resource_nodes.size()
        node.position = p
        root.add_child(node)
        _cylinder(node, 1.2, 0.35, Vector3.ZERO, resource_mat)
        _cylinder(node, 0.55, 0.5, Vector3(0,0.3,0), resource_glow)
        node.set_meta("resource_value", 1500)
        resource_nodes.append(node)

    # Defensive cover / ruins. Low poly but visually differentiated.
    var concrete := _mat("#6d7169")
    var dark := _mat("#41443f")
    var cover_positions := [
        Vector3(-28,0,-10), Vector3(-24,0,-8), Vector3(-20,0,-6),
        Vector3(28,0,10), Vector3(24,0,8), Vector3(20,0,6),
        Vector3(-10,0,28), Vector3(-8,0,24), Vector3(-6,0,20),
        Vector3(10,0,-28), Vector3(8,0,-24), Vector3(6,0,-20),
        Vector3(-30,0,5), Vector3(-30,0,10), Vector3(30,0,-5), Vector3(30,0,-10),
        Vector3(-12,0,-30), Vector3(-7,0,-30), Vector3(12,0,30), Vector3(7,0,30),
        Vector3(-17,0,7), Vector3(17,0,-7), Vector3(-7,0,17), Vector3(7,0,-17)
    ]
    for i in range(cover_positions.size()):
        var p: Vector3 = cover_positions[i]
        var h := 1.0 + float(i % 3) * 0.45
        var w := 2.5 + float(i % 2) * 1.5
        _box(root, Vector3(w,h,1.8), p, concrete if i % 2 == 0 else dark, 0.0)

    # Four strategic command points.
    var marker := _mat("#87934c")
    var tactical_positions := [Vector3(-27,0,-27), Vector3(27,0,-27), Vector3(-27,0,27), Vector3(27,0,27)]
    for i in range(tactical_positions.size()):
        var p: Vector3 = tactical_positions[i]
        var point := Node3D.new()
        point.name = "TacticalPoint_%d" % (i + 1)
        point.position = p
        point.set_meta("strategic", true)
        root.add_child(point)
        _cylinder(point, 2.4, 0.18, Vector3.ZERO, dark)
        _cylinder(point, 1.4, 0.22, Vector3(0,0.18,0), marker)
        tactical_points.append(point)

    # Sparse terrain blocks to break up long sight lines.
    var terrain := _mat("#263a25")
    for p in [Vector3(-16,0,-16), Vector3(16,0,-16), Vector3(-16,0,16), Vector3(16,0,16)]:
        _cylinder(root, 4.0, 0.35, p, terrain)

func get_resource_nodes() -> Array[Node3D]:
    return resource_nodes

func get_tactical_points() -> Array[Node3D]:
    return tactical_points
