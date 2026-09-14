extends Node3D

const PORT := 27015
const MAP_SIZE := 70.0
const START_RESOURCES := 12000
const SNAPSHOT_INTERVAL := 0.25
const MAX_PLAYERS := 8

var resources := START_RESOURCES
var power := 100
var kills := 0
var wave := 1
var difficulty := 2
var faction := "لبنان"
var mission := 1
var map_index := 0
var cam: Camera3D
var units: Array[Node3D] = []
var enemies: Array[Node3D] = []
var buildings: Array[Node3D] = []
var selected: Array[Node3D] = []
var peer: ENetMultiplayerPeer
var status: Label
var log_label: Label
var ip_edit: LineEdit
var next_id := 1
var sim_time := 0.0
var enemy_time := 0.0
var snapshot_time := 0.0
var handshake_ok := true
var player_peers: Dictionary = {1: {"team": 0, "faction": "لبنان"}}
var player_resources: Dictionary = {1: START_RESOURCES}
var maps := ["وادي الأرز","الساحل","الصحراء","المدينة","الحدود"]
var factions := ["لبنان","الشام","الرافدين","المشرق"]
var costs := {"جندي":350,"دبابة":900,"مدفعية":1200,"طائرة":1600}
var hp := {"جندي":80.0,"دبابة":220.0,"مدفعية":150.0,"طائرة":130.0}
var speed := {"جندي":6.5,"دبابة":4.0,"مدفعية":3.5,"طائرة":9.0}
var damage := {"جندي":12.0,"دبابة":30.0,"مدفعية":55.0,"طائرة":45.0}

func _ready() -> void:
    _world()
    _ui()
    _ensure_player(1)
    _spawn_unit("جندي",Vector3(-10,0,12),0,1)
    _spawn_unit("جندي",Vector3(-7,0,14),0,1)
    _spawn_unit("دبابة",Vector3(-12,0,9),0,1)
    _spawn_building("مقر",Vector3(-15,0,18),0,1)
    _spawn_building("ثكنة",Vector3(-8,0,20),0,1)
    _spawn_building("مصنع",Vector3(-2,0,20),0,1)
    _spawn_enemy()
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    _update()

func _world() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("#0b1117")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_energy = 0.9
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55,-25,0)
    sun.light_energy = 1.2
    add_child(sun)
    var ground := MeshInstance3D.new()
    var gm := BoxMesh.new()
    gm.size = Vector3(MAP_SIZE,0.5,MAP_SIZE)
    ground.mesh = gm
    ground.position.y = -0.25
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#35482f")
    ground.material_override = mat
    add_child(ground)
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(MAP_SIZE,0.5,MAP_SIZE)
    shape.shape = box
    shape.position.y = -0.25
    body.add_child(shape)
    add_child(body)
    cam = Camera3D.new()
    cam.position = Vector3(0,35,31)
    cam.rotation_degrees = Vector3(-52,0,0)
    cam.current = true
    add_child(cam)

func _ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var top := ColorRect.new()
    top.color = Color(0.03,0.04,0.05,0.94)
    top.size = Vector2(1280,90)
    layer.add_child(top)
    var title := Label.new()
    title.text = "NEW ERA RTS"
    title.position = Vector2(20,8)
    title.add_theme_font_size_override("font_size",26)
    top.add_child(title)
    var dev := Label.new()
    dev.text = "تطوير: Zein Haidar 🇱🇧 | Windows x86_64 | LAN"
    dev.position = Vector2(20,48)
    top.add_child(dev)
    status = Label.new()
    status.position = Vector2(360,25)
    status.add_theme_font_size_override("font_size",16)
    top.add_child(status)
    var panel := Panel.new()
    panel.position = Vector2(18,105)
    panel.size = Vector2(265,595)
    layer.add_child(panel)
    var head := Label.new()
    head.text = "القيادة والبناء"
    head.position = Vector2(18,10)
    head.add_theme_font_size_override("font_size",20)
    panel.add_child(head)
    _button(panel,"ثكنة — 1500",48,func(): _build("ثكنة",1500))
    _button(panel,"مصنع — 2500",88,func(): _build("مصنع",2500))
    _button(panel,"طاقة — 1000",128,func(): _build("طاقة",1000))
    _button(panel,"جندي — 350",168,func(): _produce("جندي"))
    _button(panel,"دبابة — 900",208,func(): _produce("دبابة"))
    _button(panel,"مدفعية — 1200",248,func(): _produce("مدفعية"))
    _button(panel,"طائرة — 1600",288,func(): _produce("طائرة"))
    _button(panel,"تغيير الفصيل",328,func(): _cycle_faction())
    _button(panel,"مستوى AI",368,func(): _cycle_ai())
    _button(panel,"تغيير الخريطة",408,func(): _cycle_map())
    _button(panel,"حفظ",448,func(): _save())
    _button(panel,"تحميل",488,func(): _load())
    _button(panel,"استضافة LAN",528,func(): _host())
    _button(panel,"انضمام LAN",568,func(): _join())
    ip_edit = LineEdit.new()
    ip_edit.text = "127.0.0.1"
    ip_edit.placeholder_text = "IP المضيف"
    ip_edit.position = Vector2(18,610)
    ip_edit.size = Vector2(220,34)
    panel.add_child(ip_edit)
    log_label = Label.new()
    log_label.position = Vector2(310,570)
    log_label.size = Vector2(850,60)
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layer.add_child(log_label)
    var hint := Label.new()
    hint.text = "زر يسار: تحديد وحداتك | زر يمين: حركة | 1 جندي | 2 دبابة | 3 مدفعية | 4 طائرة"
    hint.position = Vector2(310,95)
    layer.add_child(hint)

func _button(parent: Control, text: String, y: float, action: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.position = Vector2(18,y)
    b.size = Vector2(220,34)
    b.pressed.connect(action)
    parent.add_child(b)

func _process(delta: float) -> void:
    sim_time += delta
    enemy_time += delta
    snapshot_time += delta
    if multiplayer.is_server() and enemy_time > max(1.5,4.0-difficulty):
        enemy_time = 0.0
        _enemy_attack()
    for u in units.duplicate():
        if is_instance_valid(u) and u.has_meta("target"):
            var target: Vector3 = u.get_meta("target")
            u.position = u.position.move_toward(target, float(speed.get(u.get_meta("kind"),4.0))*delta)
            if u.position.distance_to(target) < 0.2: u.remove_meta("target")
    if multiplayer.is_server() and snapshot_time >= SNAPSHOT_INTERVAL:
        snapshot_time = 0.0
        _broadcast_snapshot()
    _update()

func _unhandled_input(ev: InputEvent) -> void:
    if ev is InputEventMouseButton and ev.pressed:
        var m := ev as InputEventMouseButton
        var world := _mouse_world(m.position)
        if m.button_index == MOUSE_BUTTON_LEFT:
            _select_near(world)
        elif m.button_index == MOUSE_BUTTON_RIGHT and not selected.is_empty():
            var ids: Array[int] = []
            for u in selected:
                if is_instance_valid(u) and _owns_entity(u, _local_peer_id()): ids.append(int(u.get_meta("id",0)))
            if ids.is_empty(): return
            if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
                if handshake_ok: request_move.rpc_id(1,ids,_safe_pos(world))
            else:
                _apply_move(ids,_safe_pos(world),_local_peer_id())
            _log("تم إصدار أمر الحركة للوحدات المحددة")
    if ev is InputEventKey and ev.pressed and not ev.echo:
        if ev.keycode == KEY_1: _produce("جندي")
        elif ev.keycode == KEY_2: _produce("دبابة")
        elif ev.keycode == KEY_3: _produce("مدفعية")
        elif ev.keycode == KEY_4: _produce("طائرة")

func _mouse_world(pos: Vector2) -> Vector3:
    var from := cam.project_ray_origin(pos)
    var dir := cam.project_ray_normal(pos)
    var t := -from.y/dir.y if abs(dir.y)>0.001 else 0.0
    return from + dir*t

func _safe_pos(p: Vector3) -> Vector3:
    var limit := MAP_SIZE * 0.5 - 2.0
    return Vector3(clamp(p.x,-limit,limit),0.0,clamp(p.z,-limit,limit))

func _local_peer_id() -> int:
    if multiplayer.multiplayer_peer == null: return 1
    return multiplayer.get_unique_id()

func _ensure_player(peer_id: int) -> void:
    if peer_id <= 0: return
    if not player_peers.has(peer_id):
        var slot := (player_peers.size()) % factions.size()
        player_peers[peer_id] = {"team": slot, "faction": factions[slot]}
    if not player_resources.has(peer_id): player_resources[peer_id] = START_RESOURCES

func _player_team(peer_id: int) -> int:
    _ensure_player(peer_id)
    return int(player_peers[peer_id].get("team",0))

func _owns_entity(entity: Node3D, peer_id: int) -> bool:
    return is_instance_valid(entity) and int(entity.get_meta("owner_peer",1)) == peer_id

func _select_near(p: Vector3) -> void:
    selected.clear()
    var me := _local_peer_id()
    for u in units:
        if is_instance_valid(u) and u.position.distance_to(p)<2.8 and _owns_entity(u,me): selected.append(u)
    _log("تم تحديد %d وحدة من وحداتك" % selected.size())

func _spawn_unit(kind: String, pos: Vector3, team: int, owner_peer: int = 1, forced_id: int = -1) -> Node3D:
    var u := Node3D.new()
    var entity_id := forced_id if forced_id > 0 else next_id
    if forced_id <= 0: next_id += 1
    else: next_id = max(next_id,forced_id + 1)
    u.name = kind + "_%d" % entity_id
    u.position = _safe_pos(pos)
    u.set_meta("kind",kind)
    u.set_meta("team",team)
    u.set_meta("owner_peer",owner_peer)
    u.set_meta("hp",float(hp.get(kind,100.0)))
    u.set_meta("id",entity_id)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.5,1.2,1.5) if kind != "طائرة" else Vector3(2.2,0.4,1.2)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#b33b32") if team != 0 else Color("#3f86c7")
    mesh.material_override = mat
    mesh.position.y = 0.7
    u.add_child(mesh)
    add_child(u)
    if team == 0: units.append(u)
    else: enemies.append(u)
    return u

func _spawn_enemy() -> void:
    for i in range(5): _spawn_unit("جندي" if i%2==0 else "دبابة",Vector3(10+i*2,0,-12+i),1,0)

func _spawn_building(kind: String, pos: Vector3, team: int, owner_peer: int = 1, forced_id: int = -1) -> Node3D:
    var b := Node3D.new()
    var entity_id := forced_id if forced_id > 0 else next_id
    if forced_id <= 0: next_id += 1
    else: next_id = max(next_id,forced_id + 1)
    b.name = kind + "_%d" % entity_id
    b.position = _safe_pos(pos)
    b.set_meta("kind",kind)
    b.set_meta("team",team)
    b.set_meta("owner_peer",owner_peer)
    b.set_meta("hp",1200.0)
    b.set_meta("id",entity_id)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(4,2.5,4)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#8d9b45") if team==0 else Color("#7d3c3c")
    mesh.material_override = mat
    mesh.position.y = 1.25
    b.add_child(mesh)
    add_child(b)
    buildings.append(b)
    return b

func _resource_for(peer_id: int) -> int:
    _ensure_player(peer_id)
    return int(player_resources[peer_id])

func _set_resource_for(peer_id: int, value: int) -> void:
    _ensure_player(peer_id)
    player_resources[peer_id] = max(0,value)
    if peer_id == _local_peer_id(): resources = player_resources[peer_id]

func _build(kind: String, cost: int) -> void:
    if not _can_issue_local(): return
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        if handshake_ok: request_build.rpc_id(1,kind,cost)
        return
    _apply_build(kind,cost,_local_peer_id())

func _apply_build(kind: String, cost: int, owner_peer: int) -> bool:
    if owner_peer != 1 and not player_peers.has(owner_peer): return false
    var allowed_cost := 1500 if kind == "ثكنة" else 2500 if kind == "مصنع" else 1000 if kind == "طاقة" else -1
    if allowed_cost < 0 or cost != allowed_cost: return false
    if _resource_for(owner_peer) < cost: return false
    _set_resource_for(owner_peer,_resource_for(owner_peer)-cost)
    var team := _player_team(owner_peer)
    var base_x := -15.0 + float((_player_team(owner_peer)%4)*10)
    _spawn_building(kind,Vector3(base_x+randf()*8,0,10+randf()*8),team,owner_peer)
    return true

func _produce(kind: String) -> void:
    if not _can_issue_local(): return
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        if handshake_ok: request_produce.rpc_id(1,kind)
        return
    _apply_produce(kind,_local_peer_id())

func _apply_produce(kind: String, owner_peer: int) -> bool:
    if not costs.has(kind): return false
    if not player_peers.has(owner_peer): return false
    var cost: int = costs[kind]
    if _resource_for(owner_peer) < cost: return false
    if not _has_building("ثكنة",owner_peer) and kind == "جندي": return false
    if not _has_building("مصنع",owner_peer) and kind in ["دبابة","مدفعية","طائرة"]: return false
    _set_resource_for(owner_peer,_resource_for(owner_peer)-cost)
    var team := _player_team(owner_peer)
    var pos := Vector3(-10+randf()*10,0,12+randf()*8)
    _spawn_unit(kind,pos,team,owner_peer)
    return true

func _has_building(kind: String, owner_peer: int = 1) -> bool:
    for b in buildings:
        if is_instance_valid(b) and str(b.get_meta("kind",""))==kind and _owns_entity(b,owner_peer): return true
    return false

func _enemy_attack() -> void:
    if units.is_empty(): return
    var u := units[randi()%units.size()]
    u.set_meta("hp",float(u.get_meta("hp"))-float(damage["جندي"])*difficulty*0.25)
    if float(u.get_meta("hp"))<=0:
        units.erase(u); selected.erase(u); u.queue_free()

func _cycle_faction() -> void:
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
    faction = factions[(factions.find(faction)+1)%factions.size()]
    player_peers[1]["faction"] = faction

func _cycle_ai() -> void:
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
    difficulty = 1 if difficulty>=3 else difficulty+1

func _cycle_map() -> void:
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
    map_index = (map_index+1)%maps.size()

func _save() -> void:
    var f := FileAccess.open("user://new_era_save.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"resources":resources,"power":power,"kills":kills,"wave":wave,"difficulty":difficulty,"faction":faction,"mission":mission,"map":map_index}))
    f.close()

func _load() -> void:
    if not FileAccess.file_exists("user://new_era_save.json"): return
    var f := FileAccess.open("user://new_era_save.json",FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text()); f.close()
    if typeof(d)==TYPE_DICTIONARY:
        resources=int(d.get("resources",resources)); power=int(d.get("power",power)); kills=int(d.get("kills",kills)); wave=int(d.get("wave",wave)); difficulty=int(d.get("difficulty",difficulty)); faction=str(d.get("faction",faction)); mission=int(d.get("mission",mission)); map_index=clampi(int(d.get("map",map_index)),0,maps.size()-1)
        _set_resource_for(1,resources)

func _host() -> void:
    if peer!=null: return
    peer=ENetMultiplayerPeer.new()
    var err=peer.create_server(PORT,MAX_PLAYERS)
    if err==OK:
        multiplayer.multiplayer_peer=peer
        handshake_ok=true
        _ensure_player(1)
        _log("تم فتح LAN على المنفذ 27015")
    else: _log("فشل LAN: %s" % err)

func _join() -> void:
    if peer!=null: return
    peer=ENetMultiplayerPeer.new()
    var err=peer.create_client(ip_edit.text.strip_edges(),PORT)
    if err==OK:
        multiplayer.multiplayer_peer=peer
        handshake_ok=false
        _log("جارٍ الاتصال بالمضيف")
    else: _log("فشل الاتصال: %s" % err)

func _on_peer_connected(id: int) -> void:
    if multiplayer.is_server():
        _ensure_player(id)
        _broadcast_snapshot_to(id)
        _log("اتصل لاعب LAN: %d" % id)

func _on_peer_disconnected(id: int) -> void:
    if multiplayer.is_server():
        _remove_peer_entities(id)
        player_peers.erase(id)
        player_resources.erase(id)
    _log("غادر لاعب LAN: %d" % id)

func _remove_peer_entities(peer_id: int) -> void:
    for u in units.duplicate():
        if is_instance_valid(u) and _owns_entity(u,peer_id):
            units.erase(u); selected.erase(u); u.queue_free()
    for b in buildings.duplicate():
        if is_instance_valid(b) and _owns_entity(b,peer_id):
            buildings.erase(b); b.queue_free()

func _can_issue_local() -> bool:
    if multiplayer.multiplayer_peer == null: return true
    if multiplayer.is_server(): return true
    return handshake_ok

func _unit_state(u: Node3D) -> Dictionary:
    return {"id":int(u.get_meta("id",0)),"kind":str(u.get_meta("kind","جندي")),"team":int(u.get_meta("team",0)),"owner_peer":int(u.get_meta("owner_peer",1)),"hp":float(u.get_meta("hp",100.0)),"pos":[u.position.x,u.position.y,u.position.z]}

func _building_state(b: Node3D) -> Dictionary:
    return {"id":int(b.get_meta("id",0)),"kind":str(b.get_meta("kind","مقر")),"team":int(b.get_meta("team",0)),"owner_peer":int(b.get_meta("owner_peer",1)),"hp":float(b.get_meta("hp",1200.0)),"pos":[b.position.x,b.position.y,b.position.z]}

func _make_snapshot() -> Dictionary:
    var us: Array = []
    var bs: Array = []
    for u in units:
        if is_instance_valid(u): us.append(_unit_state(u))
    for b in buildings:
        if is_instance_valid(b): bs.append(_building_state(b))
    return {"resources":resources,"power":power,"kills":kills,"wave":wave,"difficulty":difficulty,"faction":faction,"mission":mission,"map":map_index,"players":player_peers,"player_resources":player_resources,"units":us,"buildings":bs}

func _broadcast_snapshot() -> void:
    if multiplayer.is_server(): sync_snapshot.rpc(_make_snapshot())

func _broadcast_snapshot_to(id: int) -> void:
    if multiplayer.is_server(): sync_snapshot.rpc_id(id,_make_snapshot())

@rpc("authority", "unreliable_ordered")
func sync_snapshot(state: Dictionary) -> void:
    resources = int(state.get("player_resources",{}).get(_local_peer_id(),state.get("resources",resources)))
    power = int(state.get("power",power))
    kills = int(state.get("kills",kills))
    wave = int(state.get("wave",wave))
    difficulty = int(state.get("difficulty",difficulty))
    faction = str(state.get("faction",faction))
    mission = int(state.get("mission",mission))
    map_index = clampi(int(state.get("map",map_index)),0,maps.size()-1)
    var pstate = state.get("players",{})
    if pstate is Dictionary: player_peers = pstate.duplicate(true)
    var rstate = state.get("player_resources",{})
    if rstate is Dictionary: player_resources = rstate.duplicate(true)
    if multiplayer.is_server(): return
    _apply_unit_snapshot(state.get("units",[]))
    _apply_building_snapshot(state.get("buildings",[]))

func _apply_unit_snapshot(states: Array) -> void:
    var wanted := {}
    for data in states:
        if typeof(data) != TYPE_DICTIONARY: continue
        var id := int(data.get("id",0)); wanted[id] = true
        var u := _find_unit(id)
        if u == null:
            u = _spawn_unit(str(data.get("kind","جندي")),_array_pos(data.get("pos",[])),int(data.get("team",0)),int(data.get("owner_peer",1)),id)
        u.position = _safe_pos(_array_pos(data.get("pos",[])))
        u.set_meta("hp",float(data.get("hp",100.0)))
        u.set_meta("owner_peer",int(data.get("owner_peer",1)))
    for u in units.duplicate():
        if is_instance_valid(u) and not wanted.has(int(u.get_meta("id",0))):
            units.erase(u); selected.erase(u); u.queue_free()

func _apply_building_snapshot(states: Array) -> void:
    var wanted := {}
    for data in states:
        if typeof(data) != TYPE_DICTIONARY: continue
        var id := int(data.get("id",0)); wanted[id] = true
        var b := _find_building(id)
        if b == null: b = _spawn_building(str(data.get("kind","مقر")),_array_pos(data.get("pos",[])),int(data.get("team",0)),int(data.get("owner_peer",1)),id)
        b.position = _safe_pos(_array_pos(data.get("pos",[])))
        b.set_meta("hp",float(data.get("hp",1200.0)))
        b.set_meta("owner_peer",int(data.get("owner_peer",1)))
    for b in buildings.duplicate():
        if is_instance_valid(b) and not wanted.has(int(b.get_meta("id",0))):
            buildings.erase(b); b.queue_free()

func _array_pos(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3: return Vector3(float(value[0]),float(value[1]),float(value[2]))
    return Vector3.ZERO

func _find_unit(id: int) -> Node3D:
    for u in units:
        if is_instance_valid(u) and int(u.get_meta("id",0)) == id: return u
    return null

func _find_building(id: int) -> Node3D:
    for b in buildings:
        if is_instance_valid(b) and int(b.get_meta("id",0)) == id: return b
    return null

@rpc("any_peer", "reliable")
func request_move(ids: Array, target: Vector3) -> void:
    if not multiplayer.is_server(): return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 0: return
    _ensure_player(sender)
    _apply_move(ids,_safe_pos(target),sender)

func _apply_move(ids: Array, target: Vector3, owner_peer: int = 1) -> void:
    for id_value in ids:
        var u := _find_unit(int(id_value))
        if u != null and _owns_entity(u,owner_peer): u.set_meta("target",_safe_pos(target))

@rpc("any_peer", "reliable")
func request_produce(kind: String) -> void:
    if not multiplayer.is_server(): return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 0: return
    _ensure_player(sender)
    _apply_produce(kind,sender)

@rpc("any_peer", "reliable")
func request_build(kind: String, cost: int) -> void:
    if not multiplayer.is_server(): return
    var sender := multiplayer.get_remote_sender_id()
    if sender <= 0: return
    _ensure_player(sender)
    _apply_build(kind,cost,sender)

func _update() -> void:
    if status: status.text = "المهمة %d | %s | الخريطة: %s | الموارد: %d | الطاقة: %d | قتلى: %d | LAN ملكية آمنة" % [mission,faction,maps[map_index],resources,power,kills]

func _log(t: String) -> void:
    if log_label: log_label.text = t
