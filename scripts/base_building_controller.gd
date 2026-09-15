extends Node
class_name BaseBuildingController

## Data-driven base construction layer for NEW ERA RTS.
## Keeps placement, prerequisites, construction queues and ownership isolated
## so the gameplay scene can progressively adopt a Generals-style economy/tech tree.

signal construction_started(owner_peer: int, kind: String, position: Vector3)
signal construction_completed(owner_peer: int, kind: String, position: Vector3)
signal construction_rejected(owner_peer: int, kind: String, reason: String)
signal production_started(owner_peer: int, unit_kind: String)
signal production_completed(owner_peer: int, unit_kind: String)

const GRID_SIZE := 2.0
const MAP_LIMIT := 68.0
const MAX_QUEUE := 8

var definitions := {
    "مقر": {"cost": 5000, "time": 25.0, "footprint": Vector2i(4, 4), "requires": []},
    "ثكنة": {"cost": 1500, "time": 10.0, "footprint": Vector2i(3, 3), "requires": ["مقر"]},
    "مصنع": {"cost": 2500, "time": 16.0, "footprint": Vector2i(4, 4), "requires": ["مقر"]},
    "مطار": {"cost": 3200, "time": 20.0, "footprint": Vector2i(4, 4), "requires": ["مصنع"]},
    "طاقة": {"cost": 1000, "time": 8.0, "footprint": Vector2i(3, 3), "requires": ["مقر"]},
    "مستودع": {"cost": 1800, "time": 12.0, "footprint": Vector2i(3, 3), "requires": ["مقر"]},
    "دفاع": {"cost": 2200, "time": 14.0, "footprint": Vector2i(2, 2), "requires": ["ثكنة"]},
}

var unit_definitions := {
    "جندي": {"cost": 350, "time": 4.0, "factory": "ثكنة"},
    "دبابة": {"cost": 900, "time": 8.0, "factory": "مصنع"},
    "مدفعية": {"cost": 1200, "time": 11.0, "factory": "مصنع"},
    "طائرة": {"cost": 1600, "time": 14.0, "factory": "مطار"},
}

var player_resources: Dictionary = {}
var player_buildings: Dictionary = {}
var construction_queues: Dictionary = {}
var production_queues: Dictionary = {}

func setup_player(owner_peer: int, starting_resources: int = 12000) -> void:
    if owner_peer <= 0:
        return
    player_resources[owner_peer] = starting_resources
    player_buildings[owner_peer] = []
    construction_queues[owner_peer] = []
    production_queues[owner_peer] = []

func set_resources(owner_peer: int, amount: int) -> void:
    player_resources[owner_peer] = max(0, amount)

func get_resources(owner_peer: int) -> int:
    return int(player_resources.get(owner_peer, 0))

func snap_to_grid(position: Vector3) -> Vector3:
    return Vector3(round(position.x / GRID_SIZE) * GRID_SIZE, 0.0, round(position.z / GRID_SIZE) * GRID_SIZE)

func can_place(owner_peer: int, kind: String, position: Vector3) -> bool:
    if not definitions.has(kind):
        return false
    if not player_buildings.has(owner_peer):
        setup_player(owner_peer)
    var d: Dictionary = definitions[kind]
    if get_resources(owner_peer) < int(d.cost):
        return false
    var p := snap_to_grid(position)
    var half_x := float(d.footprint.x) * GRID_SIZE * 0.5
    var half_z := float(d.footprint.y) * GRID_SIZE * 0.5
    if abs(p.x) + half_x > MAP_LIMIT or abs(p.z) + half_z > MAP_LIMIT:
        return false
    for existing in player_buildings[owner_peer]:
        if not is_instance_valid(existing):
            continue
        var other_kind := str(existing.get_meta("kind", ""))
        var od: Dictionary = definitions.get(other_kind, {})
        var other_size: Vector2i = od.get("footprint", Vector2i(2, 2))
        var ox := float(other_size.x) * GRID_SIZE * 0.5
        var oz := float(other_size.y) * GRID_SIZE * 0.5
        var ep: Vector3 = existing.position
        if abs(p.x - ep.x) < half_x + ox and abs(p.z - ep.z) < half_z + oz:
            return false
    return true

func missing_prerequisites(owner_peer: int, kind: String) -> Array[String]:
    var missing: Array[String] = []
    if not definitions.has(kind):
        return missing
    var owned: Dictionary = {}
    for b in player_buildings.get(owner_peer, []):
        if is_instance_valid(b):
            owned[str(b.get_meta("kind", ""))] = true
    for requirement in definitions[kind].requires:
        if not owned.has(str(requirement)):
            missing.append(str(requirement))
    return missing

func request_build(owner_peer: int, kind: String, position: Vector3) -> bool:
    if not definitions.has(kind):
        construction_rejected.emit(owner_peer, kind, "نوع مبنى غير معروف")
        return false
    var missing := missing_prerequisites(owner_peer, kind)
    if not missing.is_empty():
        construction_rejected.emit(owner_peer, kind, "المتطلبات: " + ", ".join(missing))
        return false
    if not can_place(owner_peer, kind, position):
        construction_rejected.emit(owner_peer, kind, "الموقع أو الرصيد غير صالح")
        return false
    var d: Dictionary = definitions[kind]
    player_resources[owner_peer] = get_resources(owner_peer) - int(d.cost)
    construction_queues[owner_peer].append({"kind": kind, "position": snap_to_grid(position), "remaining": float(d.time)})
    construction_started.emit(owner_peer, kind, snap_to_grid(position))
    return true

func register_completed_building(owner_peer: int, building: Node3D) -> void:
    if not player_buildings.has(owner_peer):
        setup_player(owner_peer, get_resources(owner_peer))
    if building not in player_buildings[owner_peer]:
        player_buildings[owner_peer].append(building)

func request_production(owner_peer: int, unit_kind: String) -> bool:
    if not unit_definitions.has(unit_kind):
        return false
    if not player_buildings.has(owner_peer):
        return false
    var d: Dictionary = unit_definitions[unit_kind]
    var factory := str(d.factory)
    var has_factory := false
    for b in player_buildings[owner_peer]:
        if is_instance_valid(b) and str(b.get_meta("kind", "")) == factory:
            has_factory = true
            break
    if not has_factory or get_resources(owner_peer) < int(d.cost):
        return false
    var queue: Array = production_queues[owner_peer]
    if queue.size() >= MAX_QUEUE:
        return false
    player_resources[owner_peer] = get_resources(owner_peer) - int(d.cost)
    queue.append({"kind": unit_kind, "remaining": float(d.time)})
    production_started.emit(owner_peer, unit_kind)
    return true

func tick(delta: float) -> void:
    for owner_peer in construction_queues.keys():
        var queue: Array = construction_queues[owner_peer]
        if queue.is_empty():
            continue
        queue[0].remaining = float(queue[0].remaining) - delta
        if queue[0].remaining <= 0.0:
            var item: Dictionary = queue.pop_front()
            construction_completed.emit(int(owner_peer), str(item.kind), item.position)
    for owner_peer in production_queues.keys():
        var queue: Array = production_queues[owner_peer]
        if queue.is_empty():
            continue
        queue[0].remaining = float(queue[0].remaining) - delta
        if queue[0].remaining <= 0.0:
            var item: Dictionary = queue.pop_front()
            production_completed.emit(int(owner_peer), str(item.kind))

func get_building_cost(kind: String) -> int:
    return int(definitions.get(kind, {}).get("cost", -1))

func get_building_time(kind: String) -> float:
    return float(definitions.get(kind, {}).get("time", 0.0))

func get_building_footprint(kind: String) -> Vector2i:
    return definitions.get(kind, {}).get("footprint", Vector2i(2, 2))

func get_production_queue(owner_peer: int) -> Array:
    return production_queues.get(owner_peer, [])

func get_construction_queue(owner_peer: int) -> Array:
    return construction_queues.get(owner_peer, [])
