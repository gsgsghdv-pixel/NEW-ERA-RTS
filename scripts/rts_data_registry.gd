extends Node
class_name RTSDataRegistry

## Original, data-driven gameplay definitions for NEW ERA RTS.
## Values are intentionally independent from the source game's files.

const UNITS := {
    "جندي": {"cost": 350, "build_time": 4.0, "hp": 80.0, "speed": 6.5, "range": 18.0, "weapon": "rifle", "armor": "infantry"},
    "دبابة": {"cost": 900, "build_time": 8.0, "hp": 220.0, "speed": 4.0, "range": 28.0, "weapon": "cannon", "armor": "vehicle"},
    "مدفعية": {"cost": 1200, "build_time": 11.0, "hp": 150.0, "speed": 3.5, "range": 38.0, "weapon": "artillery", "armor": "vehicle"},
    "طائرة": {"cost": 1600, "build_time": 14.0, "hp": 130.0, "speed": 9.0, "range": 32.0, "weapon": "airstrike", "armor": "air"},
}

const WEAPONS := {
    "rifle": {"damage": 12.0, "damage_type": "small_arms", "reload": 0.75, "splash": 0.0},
    "cannon": {"damage": 30.0, "damage_type": "armor_piercing", "reload": 2.0, "splash": 1.5},
    "artillery": {"damage": 55.0, "damage_type": "explosive", "reload": 3.2, "splash": 5.0},
    "airstrike": {"damage": 45.0, "damage_type": "explosive", "reload": 2.5, "splash": 4.0},
}

const ARMOR := {
    "infantry": {"small_arms": 1.0, "armor_piercing": 1.25, "explosive": 1.10, "flame": 1.15},
    "vehicle": {"small_arms": 0.35, "armor_piercing": 1.0, "explosive": 0.85, "flame": 1.10},
    "air": {"small_arms": 0.75, "armor_piercing": 1.10, "explosive": 0.70, "flame": 0.90},
    "structure": {"small_arms": 0.10, "armor_piercing": 0.80, "explosive": 0.70, "flame": 0.80},
}

const BUILDINGS := {
    "مقر": {"cost": 5000, "build_time": 25.0, "hp": 3000.0, "prerequisites": []},
    "ثكنة": {"cost": 1500, "build_time": 10.0, "hp": 1600.0, "prerequisites": ["مقر"]},
    "مصنع": {"cost": 2500, "build_time": 16.0, "hp": 2200.0, "prerequisites": ["مقر"]},
    "مطار": {"cost": 3200, "build_time": 20.0, "hp": 1800.0, "prerequisites": ["مصنع"]},
    "طاقة": {"cost": 1000, "build_time": 8.0, "hp": 1200.0, "prerequisites": ["مقر"]},
    "مستودع": {"cost": 1800, "build_time": 12.0, "hp": 1500.0, "prerequisites": ["مقر"]},
    "دفاع": {"cost": 2200, "build_time": 14.0, "hp": 1800.0, "prerequisites": ["ثكنة"]},
}

const FACTIONS := {
    "لبنان": {"income_bonus": 0.05, "armor_bonus": 0.0, "air_bonus": 0.05},
    "الشام": {"income_bonus": 0.0, "armor_bonus": 0.08, "air_bonus": 0.0},
    "الرافدين": {"income_bonus": 0.08, "armor_bonus": 0.04, "air_bonus": 0.0},
    "المشرق": {"income_bonus": 0.0, "armor_bonus": 0.0, "air_bonus": 0.10},
}

func get_unit(kind: String) -> Dictionary:
    return UNITS.get(kind, {}).duplicate(true)

func get_weapon(id: String) -> Dictionary:
    return WEAPONS.get(id, {}).duplicate(true)

func get_armor(id: String) -> Dictionary:
    return ARMOR.get(id, {}).duplicate(true)

func get_building(kind: String) -> Dictionary:
    return BUILDINGS.get(kind, {}).duplicate(true)

func get_faction(id: String) -> Dictionary:
    return FACTIONS.get(id, {}).duplicate(true)

func has_unit(kind: String) -> bool:
    return UNITS.has(kind)

func has_building(kind: String) -> bool:
    return BUILDINGS.has(kind)
