extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    var scene := load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("main scene could not be loaded")
        quit(1)
        return
    var game := scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    if not is_instance_valid(game):
        _fail("game root was not instantiated")
        quit(1)
        return
    _check(game.cam != null, "camera initialized")
    _check(game.MAP_SIZE >= 100.0, "safe map size")
    _check(game.units.size() >= 3, "starting units spawned")
    _check(game.buildings.size() >= 4, "starting buildings spawned")
    _check(game._has_building("ثكنة"), "barracks exists")
    _check(game._has_building("مصنع"), "factory exists")

    var before_units := game.units.size()
    game._produce("جندي")
    _check(game.units.size() == before_units + 1, "infantry production")
    game._produce("دبابة")
    _check(game.units.size() == before_units + 2, "tank production")
    game._produce("مدفعية")
    _check(game.units.size() == before_units + 3, "artillery production")
    game._produce("طائرة")
    _check(game.units.size() == before_units + 4, "aircraft production")

    var moving := game.units[0]
    var start := moving.position
    var target := start + Vector3(5, 0, 0)
    moving.set_meta("target", target)
    for i in range(20):
        await process_frame
    _check(moving.position.distance_to(start) > 0.5, "unit movement")

    var old_map := game.map_index
    game._cycle_map()
    _check(game.map_index != old_map, "map cycling")
    var old_faction := game.faction
    game._cycle_faction()
    _check(game.faction != old_faction, "faction cycling")
    var old_ai := game.difficulty
    game._cycle_ai()
    _check(game.difficulty != old_ai, "AI difficulty cycling")

    var saved_resources := game.resources
    game.resources = 777
    game._save()
    game.resources = 1
    game._load()
    _check(game.resources == saved_resources, "save/load resources")

    var guard := game.get_node_or_null("NetworkGuard")
    _check(guard != null, "network guard node")
    _check(guard.PROTOCOL_VERSION == "NEWERA-RTS-LAN-1", "LAN protocol version")
    _check(game.MAP_SIZE <= 120.0, "map bounded")

    if failures.is_empty():
        print("GAMEPLAY SMOKE PASS")
        quit(0)
    else:
        print("GAMEPLAY SMOKE FAIL")
        for failure in failures:
            print(failure)
        quit(1)

func _check(condition: bool, name: String) -> void:
    if not condition:
        _fail(name)
    else:
        print("PASS: " + name)

func _fail(name: String) -> void:
    failures.append("FAIL: " + name)
