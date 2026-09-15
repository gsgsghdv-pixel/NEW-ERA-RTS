extends Node
class_name RTSTechTree

## Lightweight, extensible technology graph. Unlocks are owned per player.
## The graph is original to NEW ERA RTS and is deliberately data-driven.

const NODES := {
    "مركز_القيادة": {"cost": 0, "rank": 0, "requires": []},
    "تسليح_ميداني": {"cost": 1200, "rank": 1, "requires": ["مركز_القيادة"]},
    "دروع_ثقيلة": {"cost": 1800, "rank": 2, "requires": ["تسليح_ميداني"]},
    "مدفعية_بعيدة": {"cost": 2200, "rank": 2, "requires": ["تسليح_ميداني"]},
    "تفوق_جوي": {"cost": 2600, "rank": 3, "requires": ["دروع_ثقيلة"]},
    "دفاع_متقدم": {"cost": 2400, "rank": 3, "requires": ["مدفعية_بعيدة"]},
    "قيادة_ميدانية": {"cost": 3200, "rank": 4, "requires": ["تفوق_جوي", "دفاع_متقدم"]},
}

var unlocked: Dictionary = {}

func setup_player(peer_id: int) -> void:
    unlocked[peer_id] = {"مركز_القيادة": true}

func is_unlocked(peer_id: int, node_id: String) -> bool:
    return bool(unlocked.get(peer_id, {}).get(node_id, false))

func can_unlock(peer_id: int, node_id: String) -> bool:
    if not NODES.has(node_id) or is_unlocked(peer_id, node_id):
        return false
    for requirement in NODES[node_id].get("requires", []):
        if not is_unlocked(peer_id, str(requirement)):
            return false
    return true

func unlock(peer_id: int, node_id: String) -> bool:
    if not can_unlock(peer_id, node_id):
        return false
    if not unlocked.has(peer_id):
        unlocked[peer_id] = {}
    unlocked[peer_id][node_id] = true
    return true

func get_node_data(node_id: String) -> Dictionary:
    return NODES.get(node_id, {}).duplicate(true)

func get_available(peer_id: int) -> Array[String]:
    var result: Array[String] = []
    for node_id in NODES.keys():
        if can_unlock(peer_id, str(node_id)):
            result.append(str(node_id))
    return result
