extends Node
class_name RTSEntityAdapter

## Bridges the existing gameplay entities into the new data-driven systems.
## This keeps legacy spawning/network code intact while progressively moving
## combat, armor and construction rules into shared definitions.

var game: Node
var data: RTSDataRegistry
var integration: RTSBuildIntegration
var registered_buildings: Dictionary = {}
var sync_timer := 0.0

func _ready() -> void:
    game = get_parent()
    data = game.get_node_or_null("RTSDataRegistry") as RTSDataRegistry
    integration = game.get_node_or_null("RTSBuildIntegration") as RTSBuildIntegration
    call_deferred("_initial_sync")

func _initial_sync() -> void:
    _sync_entities()

func _process(delta: float) -> void:
    sync_timer += delta
    if sync_timer < 0.5:
        return
    sync_timer = 0.0
    _sync_entities()

func _sync_entities() -> void:
    if game == null or data == null:
        return
    _adapt_collection(game.get("units"))
    _adapt_collection(game.get("enemies"))
    _adapt_buildings(game.get("buildings"))

func _adapt_collection(collection) -> void:
    if not (collection is Array):
        return
    for entity in collection:
        if not is_instance_valid(entity) or entity.get_meta("rts_adapted", false):
            continue
        var kind := str(entity.get_meta("kind", ""))
        var definition := data.get_unit(kind)
        if definition.is_empty():
            continue
        entity.set_meta("armor", str(definition.get("armor", "infantry")))
        entity.set_meta("max_hp", float(definition.get("hp", entity.get_meta("hp", 100.0))))
        entity.set_meta("rts_adapted", true)

func _adapt_buildings(collection) -> void:
    if not (collection is Array):
        return
    for building in collection:
        if not is_instance_valid(building):
            continue
        var kind := str(building.get_meta("kind", ""))
        var definition := data.get_building(kind)
        if definition.is_empty():
            continue
        if not building.get_meta("rts_adapted", false):
            building.set_meta("armor", "structure")
            building.set_meta("max_hp", float(definition.get("hp", building.get_meta("hp", 1000.0))))
            building.set_meta("rts_adapted", true)
        if integration == null:
            continue
        var key := building.get_instance_id()
        if not registered_buildings.has(key):
            var owner_peer := int(building.get_meta("owner_peer", 1))
            integration.register_existing_building(owner_peer, building)
            registered_buildings[key] = true
