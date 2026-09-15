extends Node
class_name BaseEconomy

## Strategic economy layer: passive income, power balance and upkeep.
## Designed to sit above BaseBuildingController and feed the main RTS state.

signal economy_tick(owner_peer: int, credits: int, power: int)
signal power_changed(owner_peer: int, power: int)

const TICK_INTERVAL := 1.0
const BASE_INCOME := 180
const POWER_PER_GENERATOR := 25
const POWER_PER_BUILDING := 5
const POWER_LOW_PENALTY := 0.55

var elapsed := 0.0
var credits: Dictionary = {}
var power: Dictionary = {}
var controller: BaseBuildingController

func setup(controller_ref: BaseBuildingController) -> void:
    controller = controller_ref

func setup_player(owner_peer: int, starting_credits: int = 12000, starting_power: int = 100) -> void:
    credits[owner_peer] = starting_credits
    power[owner_peer] = starting_power
    if controller != null and not controller.player_resources.has(owner_peer):
        controller.setup_player(owner_peer, starting_credits)

func get_credits(owner_peer: int) -> int:
    return int(credits.get(owner_peer, 0))

func get_power(owner_peer: int) -> int:
    return int(power.get(owner_peer, 0))

func sync_credits(owner_peer: int, amount: int) -> void:
    credits[owner_peer] = max(0, amount)
    if controller != null:
        controller.set_resources(owner_peer, credits[owner_peer])

func tick(delta: float) -> void:
    elapsed += delta
    if elapsed < TICK_INTERVAL:
        return
    elapsed -= TICK_INTERVAL
    for owner_peer in credits.keys():
        _process_player(int(owner_peer))

func _process_player(owner_peer: int) -> void:
    var buildings: Array = []
    if controller != null:
        buildings = controller.player_buildings.get(owner_peer, [])
    var generators := 0
    var active_buildings := 0
    for b in buildings:
        if not is_instance_valid(b):
            continue
        active_buildings += 1
        if str(b.get_meta("kind", "")) == "طاقة":
            generators += 1
    var supply := BASE_INCOME + active_buildings * 35
    var demand := active_buildings * POWER_PER_BUILDING
    var produced := generators * POWER_PER_GENERATOR
    var new_power := 100 + produced - demand
    power[owner_peer] = new_power
    var income := supply
    if new_power < 0:
        income = int(round(float(income) * POWER_LOW_PENALTY))
    sync_credits(owner_peer, get_credits(owner_peer) + income)
    power_changed.emit(owner_peer, new_power)
    economy_tick.emit(owner_peer, get_credits(owner_peer), new_power)
