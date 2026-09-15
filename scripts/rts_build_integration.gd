extends Node
class_name RTSBuildIntegration

@export var starting_resources := 12000
var builder: BaseBuildingController
var economy: BaseEconomy
var game: Node
signal ui_state_changed(resources: int, power: int)
signal build_finished(owner_peer: int, kind: String, position: Vector3)
signal unit_ready(owner_peer: int, kind: String)

func _ready() -> void:
    game = get_parent()
    builder = game.get_node_or_null("BaseBuildingController") as BaseBuildingController
    if builder == null:
        builder = BaseBuildingController.new()
        builder.name = "BaseBuildingController"
        game.add_child(builder)
    economy = BaseEconomy.new()
    economy.name = "BaseEconomy"
    add_child(economy)
    economy.setup(builder)
    builder.construction_completed.connect(_on_construction_completed)
    builder.production_completed.connect(_on_production_completed)
    economy.economy_tick.connect(_on_economy_tick)
    builder.setup_player(1, starting_resources)
    economy.setup_player(1, starting_resources, 100)

func _process(delta: float) -> void:
    if builder == null or economy == null: return
    builder.tick(delta)
    economy.tick(delta)

func register_existing_building(owner_peer: int, building: Node3D) -> void:
    if is_instance_valid(building): builder.register_completed_building(owner_peer, building)

func can_build(kind: String, position: Vector3, owner_peer := 1) -> bool:
    return builder != null and builder.can_place(owner_peer, kind, position) and builder.missing_prerequisites(owner_peer, kind).is_empty()

func issue_build(kind: String, position: Vector3, owner_peer := 1) -> bool:
    return builder != null and builder.request_build(owner_peer, kind, position)

func issue_production(kind: String, owner_peer := 1) -> bool:
    return builder != null and builder.request_production(owner_peer, kind)

func get_resources(owner_peer := 1) -> int:
    return builder.get_resources(owner_peer) if builder != null else 0

func get_power(owner_peer := 1) -> int:
    return economy.get_power(owner_peer) if economy != null else 0

func _on_construction_completed(owner_peer: int, kind: String, position: Vector3) -> void:
    build_finished.emit(owner_peer, kind, position)
    if game != null and game.has_method("_spawn_building"):
        var building = game.call("_spawn_building", kind, position, 0, owner_peer)
        if is_instance_valid(building): builder.register_completed_building(owner_peer, building)

func _on_production_completed(owner_peer: int, kind: String) -> void:
    unit_ready.emit(owner_peer, kind)
    if game != null and game.has_method("_spawn_unit"):
        game.call("_spawn_unit", kind, _find_spawn_position(owner_peer), 0, owner_peer)

func _find_spawn_position(owner_peer: int) -> Vector3:
    for b in builder.player_buildings.get(owner_peer, []):
        if is_instance_valid(b): return b.position + Vector3(5, 0, 0)
    return Vector3.ZERO

func _on_economy_tick(owner_peer: int, credits: int, current_power: int) -> void:
    if owner_peer != 1: return
    ui_state_changed.emit(credits, current_power)
    if game.has_method("_set_resource_for"):
        game.call("_set_resource_for", owner_peer, credits)
