extends Node
class_name RTSBuildIntegration

@export var starting_resources := 12000
var builder: BaseBuildingController
var economy: BaseEconomy
var game: Node
var sync_timer := 0.0
var registered_buildings: Dictionary = {}
var rewired_buttons: Dictionary = {}
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
    builder.construction_rejected.connect(_on_construction_rejected)
    builder.production_started.connect(_on_production_started)
    economy.economy_tick.connect(_on_economy_tick)
    builder.setup_player(1, starting_resources)
    economy.setup_player(1, starting_resources, 100)
    call_deferred("_sync_players")
    call_deferred("_rewire_commands")

func _process(delta: float) -> void:
    if builder == null or economy == null:
        return
    builder.tick(delta)
    economy.tick(delta)
    sync_timer += delta
    if sync_timer >= 0.5:
        sync_timer = 0.0
        _sync_players()
        _register_existing_buildings()
        _rewire_commands()

func _sync_players() -> void:
    if game == null:
        return
    var players = game.get("player_peers")
    if not (players is Dictionary):
        return
    for peer_key in players.keys():
        var owner_peer := int(peer_key)
        if owner_peer <= 0:
            continue
        if not builder.player_resources.has(owner_peer):
            var player_state = game.get("player_resources")
            var initial := int(player_state.get(owner_peer, starting_resources)) if player_state is Dictionary else starting_resources
            builder.setup_player(owner_peer, initial)
        if not economy.credits.has(owner_peer):
            economy.setup_player(owner_peer, builder.get_resources(owner_peer), 100)

func _register_existing_buildings() -> void:
    if game == null:
        return
    var buildings = game.get("buildings")
    if not (buildings is Array):
        return
    for building in buildings:
        if not is_instance_valid(building):
            continue
        var owner_peer := int(building.get_meta("owner_peer", 0))
        if owner_peer <= 0:
            continue
        var key := building.get_instance_id()
        if registered_buildings.has(key):
            continue
        register_existing_building(owner_peer, building)
        registered_buildings[key] = true

func register_existing_building(owner_peer: int, building: Node3D) -> void:
    if builder == null or not is_instance_valid(building) or owner_peer <= 0:
        return
    if not builder.player_resources.has(owner_peer):
        builder.setup_player(owner_peer, starting_resources)
    builder.register_completed_building(owner_peer, building)

func can_build(kind: String, position: Vector3, owner_peer := 1) -> bool:
    return builder != null and builder.can_place(owner_peer, kind, position) and builder.missing_prerequisites(owner_peer, kind).is_empty()

func issue_build(kind: String, position: Vector3, owner_peer := 1) -> bool:
    if builder == null:
        return false
    return builder.request_build(owner_peer, kind, position)

func issue_production(kind: String, owner_peer := 1) -> bool:
    if builder == null:
        return false
    return builder.request_production(owner_peer, kind)

func get_resources(owner_peer := 1) -> int:
    return builder.get_resources(owner_peer) if builder != null else 0

func get_power(owner_peer := 1) -> int:
    return economy.get_power(owner_peer) if economy != null else 0

func get_construction_queue(owner_peer := 1) -> Array:
    return builder.get_construction_queue(owner_peer) if builder != null else []

func get_production_queue(owner_peer := 1) -> Array:
    return builder.get_production_queue(owner_peer) if builder != null else []

func _rewire_commands() -> void:
    if game == null:
        return
    var root := game.get_node_or_null(".")
    if root == null:
        root = game
    _scan_controls(root)

func _scan_controls(node: Node) -> void:
    for child in node.get_children():
        if child is Button:
            var button := child as Button
            var text := button.text.strip_edges()
            var kind := _command_kind(text)
            if kind != "":
                _rewire_button(button, kind)
        _scan_controls(child)

func _command_kind(text: String) -> String:
    if text.begins_with("ثكنة"):
        return "BUILD:ثكنة"
    if text.begins_with("مصنع"):
        return "BUILD:مصنع"
    if text.begins_with("طاقة"):
        return "BUILD:طاقة"
    if text.begins_with("مستودع"):
        return "BUILD:مستودع"
    if text.begins_with("دفاع"):
        return "BUILD:دفاع"
    if text.begins_with("مطار"):
        return "BUILD:مطار"
    if text.begins_with("مقر"):
        return "BUILD:مقر"
    if text.begins_with("جندي"):
        return "UNIT:جندي"
    if text.begins_with("دبابة"):
        return "UNIT:دبابة"
    if text.begins_with("مدفعية"):
        return "UNIT:مدفعية"
    if text.begins_with("طائرة"):
        return "UNIT:طائرة"
    return ""

func _rewire_button(button: Button, kind: String) -> void:
    var key := button.get_instance_id()
    if rewired_buttons.get(key, "") == kind:
        return
    for connection in button.pressed.get_connections():
        var callable: Callable = connection.get("callable", Callable())
        if callable.is_valid():
            button.pressed.disconnect(callable)
    button.pressed.connect(func(): _execute_command(kind))
    rewired_buttons[key] = kind

func _execute_command(command: String) -> void:
    var owner_peer := int(game.call("_local_peer_id")) if game.has_method("_local_peer_id") else 1
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        if game.has_method("_log"):
            game.call("_log", "الأوامر المتقدمة تُنفّذ عبر المضيف")
        return
    if command.begins_with("BUILD:"):
        var kind := command.trim_prefix("BUILD:")
        var position := _next_build_position(kind, owner_peer)
        if position == null:
            _on_construction_rejected(owner_peer, kind, "لا يوجد موقع صالح ضمن القاعدة")
            return
        if issue_build(kind, position, owner_peer):
            _sync_main_resources(owner_peer)
    elif command.begins_with("UNIT:"):
        var unit_kind := command.trim_prefix("UNIT:")
        if issue_production(unit_kind, owner_peer):
            _sync_main_resources(owner_peer)

func _next_build_position(kind: String, owner_peer: int) -> Variant:
    var anchor := Vector3(-15, 0, 18)
    for b in builder.player_buildings.get(owner_peer, []):
        if is_instance_valid(b) and str(b.get_meta("kind", "")) == "مقر":
            anchor = b.position
            break
    var candidates: Array[Vector3] = []
    for radius in [8.0, 12.0, 16.0, 20.0]:
        for i in range(8):
            var angle := TAU * float(i) / 8.0
            candidates.append(anchor + Vector3(cos(angle) * radius, 0, sin(angle) * radius))
    for position in candidates:
        if can_build(kind, position, owner_peer):
            return position
    return null

func _sync_main_resources(owner_peer: int) -> void:
    if game != null and game.has_method("_set_resource_for"):
        game.call("_set_resource_for", owner_peer, get_resources(owner_peer))

func _on_construction_completed(owner_peer: int, kind: String, position: Vector3) -> void:
    build_finished.emit(owner_peer, kind, position)
    if game != null and game.has_method("_spawn_building"):
        var team := int(game.call("_player_team", owner_peer)) if game.has_method("_player_team") else 0
        var building = game.call("_spawn_building", kind, position, team, owner_peer)
        if is_instance_valid(building):
            builder.register_completed_building(owner_peer, building)
            registered_buildings[building.get_instance_id()] = true

func _on_production_completed(owner_peer: int, kind: String) -> void:
    unit_ready.emit(owner_peer, kind)
    if game != null and game.has_method("_spawn_unit"):
        var team := int(game.call("_player_team", owner_peer)) if game.has_method("_player_team") else 0
        game.call("_spawn_unit", kind, _find_spawn_position(owner_peer, kind), team, owner_peer)

func _find_spawn_position(owner_peer: int, kind: String) -> Vector3:
    var preferred_factory := "ثكنة" if kind == "جندي" else "مصنع" if kind in ["دبابة", "مدفعية"] else "مطار"
    for b in builder.player_buildings.get(owner_peer, []):
        if is_instance_valid(b) and str(b.get_meta("kind", "")) == preferred_factory:
            return b.position + Vector3(5, 0, 0)
    for b in builder.player_buildings.get(owner_peer, []):
        if is_instance_valid(b):
            return b.position + Vector3(5, 0, 0)
    return Vector3.ZERO

func _on_construction_rejected(owner_peer: int, kind: String, reason: String) -> void:
    if owner_peer == 1 and game != null and game.has_method("_log"):
        game.call("_log", "تعذر بناء %s: %s" % [kind, reason])

func _on_production_started(owner_peer: int, kind: String) -> void:
    if owner_peer == 1 and game != null and game.has_method("_log"):
        game.call("_log", "بدأ إنتاج %s" % kind)

func _on_economy_tick(owner_peer: int, credits: int, current_power: int) -> void:
    if owner_peer != 1:
        return
    ui_state_changed.emit(credits, current_power)
    if game != null and game.has_method("_set_resource_for"):
        game.call("_set_resource_for", owner_peer, credits)
