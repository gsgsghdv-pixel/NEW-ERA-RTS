extends Node
class_name RTSDamageSystem

var data: RTSDataRegistry

func setup(registry: RTSDataRegistry) -> void:
    data = registry

func calculate_damage(attacker: Node, target: Node, weapon_id: String) -> float:
    if not is_instance_valid(attacker) or not is_instance_valid(target) or data == null:
        return 0.0
    var weapon := data.get_weapon(weapon_id)
    if weapon.is_empty():
        return 0.0
    var target_armor := str(target.get_meta("armor", "structure"))
    var armor := data.get_armor(target_armor)
    var damage_type := str(weapon.get("damage_type", "small_arms"))
    var multiplier := float(armor.get(damage_type, 1.0))
    return max(0.0, float(weapon.get("damage", 0.0)) * multiplier)

func apply_damage(target: Node, amount: float) -> bool:
    if not is_instance_valid(target) or amount <= 0.0:
        return false
    var hp := float(target.get_meta("hp", 0.0)) - amount
    target.set_meta("hp", hp)
    return hp <= 0.0
