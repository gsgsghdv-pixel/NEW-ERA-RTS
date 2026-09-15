extends Node
class_name RTSCombatController

const ATTACK_ORDER_LIFETIME := 0.28

var game: Node
var data: RTSDataRegistry
var damage_system: RTSDamageSystem
var attack_state: Dictionary = {}
var order_marker: MeshInstance3D
var marker_timer := 0.0

func _ready() -> void:
    game = get_parent()
    data = game.get_node_or_null("RTSDataRegistry") as RTSDataRegistry
    if data == null:
        data = RTSDataRegistry.new()
        data.name = "RTSDataRegistry"
        game.add_child(data)
    damage_system = RTSDamageSystem.new()
    damage_system.name = "RTSDamageSystem"
    add_child(damage_system)
    damage_system.setup(data)
    _create_marker()

func _input(event: InputEvent) -> void:
    if not (event is InputEventMouseButton):
        return
    var mouse := event as InputEventMouseButton
    if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
        return
    if not game.has_method("_mouse_world"):
        return
    var world: Vector3 = game.call("_mouse_world", mouse.position)
    var target := _find_enemy_at(world)
    if target == null:
        return
    var selected: Array = game.get("selected") if game.get("selected") is Array else []
    var ids: Array[int] = []
    var peer_id := int(game.call("_local_peer_id"))
    for unit in selected:
        if is_instance_valid(unit) and game.call("_owns_entity", unit, peer_id):
            ids.append(int(unit.get_meta("id", 0)))
    if ids.is_empty():
        return
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        request_attack.rpc_id(1, ids, int(target.get_meta("id", 0)))
    else:
        _issue_attack(ids, int(target.get_meta("id", 0)), peer_id)
    _show_marker(world)
    if game.has_method("_log"):
        game.call("_log", "أمر هجوم: %d وحدة" % ids.size())
    get_viewport().set_input_as_handled()

@rpc("any_peer", "reliable")
func request_attack(attacker_ids: Array, target_id: int) -> void:
    if not multiplayer.is_server():
        return
    var sender := multiplayer.get_remote_sender_id()
    _issue_attack(attacker_ids, target_id, sender)

func _issue_attack(attacker_ids: Array, target_id: int, owner_peer: int) -> void:
    var target := _find_entity_by_id(target_id)
    if target == null:
        return
    for entity_id in attacker_ids:
        var attacker := _find_entity_by_id(int(entity_id))
        if attacker == null or not game.call("_owns_entity", attacker, owner_peer):
            continue
        if int(attacker.get_meta("team", 0)) == int(target.get_meta("team", 1)):
            continue
        attack_state[int(entity_id)] = {"target_id": target_id, "cooldown": 0.0}
        attacker.set_meta("attack_target_id", target_id)

func _process(delta: float) -> void:
    if marker_timer > 0.0:
        marker_timer -= delta
        if marker_timer <= 0.0 and is_instance_valid(order_marker):
            order_marker.visible = false
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        return
    for attacker_id in attack_state.keys().duplicate():
        var state: Dictionary = attack_state[attacker_id]
        var attacker := _find_entity_by_id(int(attacker_id))
        var target := _find_entity_by_id(int(state.get("target_id", 0)))
        if attacker == null or target == null:
            attack_state.erase(attacker_id)
            continue
        var unit_kind := str(attacker.get_meta("kind", ""))
        var unit_def := data.get_unit(unit_kind)
        var weapon_id := str(unit_def.get("weapon", ""))
        var weapon := data.get_weapon(weapon_id)
        var range := float(unit_def.get("range", 10.0))
        var distance := attacker.position.distance_to(target.position)
        if distance > range:
            attacker.position = attacker.position.move_toward(target.position, float(unit_def.get("speed", 4.0)) * delta)
            state["cooldown"] = max(0.0, float(state.get("cooldown", 0.0)) - delta)
            attack_state[attacker_id] = state
            continue
        state["cooldown"] = float(state.get("cooldown", 0.0)) - delta
        if state["cooldown"] <= 0.0:
            var dealt := damage_system.calculate_damage(attacker, target, weapon_id)
            var destroyed := damage_system.apply_damage(target, dealt)
            state["cooldown"] = float(weapon.get("reload", 1.0))
            attack_state[attacker_id] = state
            if game.has_method("_log"):
                game.call("_log", "%s أصاب %s (-%d HP)" % [unit_kind, str(target.get_meta("kind", "هدف")), int(round(dealt))])
            if destroyed:
                _destroy_entity(target)
                attack_state.erase(attacker_id)

func _find_enemy_at(world: Vector3) -> Node3D:
    var best: Node3D
    var best_distance := 2.8
    var enemies = game.get("enemies")
    if not (enemies is Array):
        return null
    for enemy in enemies:
        if is_instance_valid(enemy):
            var d: float = enemy.position.distance_to(world)
            if d <= best_distance:
                best_distance = d
                best = enemy
    return best

func _find_entity_by_id(entity_id: int) -> Node3D:
    for collection_name in ["units", "enemies", "buildings"]:
        var collection = game.get(collection_name)
        if not (collection is Array):
            continue
        for entity in collection:
            if is_instance_valid(entity) and int(entity.get_meta("id", -1)) == entity_id:
                return entity
    return null

func _destroy_entity(entity: Node3D) -> void:
    var collection_name := "enemies" if int(entity.get_meta("team", 1)) != 0 else "units"
    var collection = game.get(collection_name)
    if collection is Array:
        collection.erase(entity)
    if game.has_method("_log"):
        game.call("_log", "%s تم تدميره" % str(entity.get_meta("kind", "الهدف")))
    entity.queue_free()

func _create_marker() -> void:
    order_marker = MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 1.25
    cylinder.bottom_radius = 1.25
    cylinder.height = 0.04
    order_marker.mesh = cylinder
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.9, 0.08, 0.08, 0.85)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    order_marker.material_override = material
    order_marker.visible = false
    game.add_child(order_marker)

func _show_marker(position: Vector3) -> void:
    if not is_instance_valid(order_marker):
        return
    order_marker.position = Vector3(position.x, 0.05, position.z)
    order_marker.visible = true
    marker_timer = ATTACK_ORDER_LIFETIME
