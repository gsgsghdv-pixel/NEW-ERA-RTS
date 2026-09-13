extends Node3D

const PORT := 27015
const MAP_SIZE := 70.0
const START_RESOURCES := 12000
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
var maps := ["وادي الأرز","الساحل","الصحراء","المدينة","الحدود"]
var factions := ["لبنان","الشام","الرافدين","المشرق"]
var costs := {"جندي":350,"دبابة":900,"مدفعية":1200,"طائرة":1600}
var hp := {"جندي":80.0,"دبابة":220.0,"مدفعية":150.0,"طائرة":130.0}
var speed := {"جندي":6.5,"دبابة":4.0,"مدفعية":3.5,"طائرة":9.0}
var damage := {"جندي":12.0,"دبابة":30.0,"مدفعية":55.0,"طائرة":45.0}

func _ready() -> void:
    _world()
    _ui()
    _spawn_unit("جندي",Vector3(-10,0,12),0)
    _spawn_unit("جندي",Vector3(-7,0,14),0)
    _spawn_unit("دبابة",Vector3(-12,0,9),0)
    _spawn_building("مقر",Vector3(-15,0,18),0)
    _spawn_building("ثكنة",Vector3(-8,0,20),0)
    _spawn_building("مصنع",Vector3(-2,0,20),0)
    _spawn_building("مقر",Vector3(18,0,-18),1)
    _spawn_enemy()
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
    hint.text = "زر يسار: تحديد | زر يمين: حركة | 1 جندي | 2 دبابة | 3 مدفعية | 4 طائرة"
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
    if enemy_time > max(1.5,4.0-difficulty):
        enemy_time = 0.0
        _enemy_attack()
    for u in units.duplicate():
        if is_instance_valid(u) and u.has_meta("target"):
            var target: Vector3 = u.get_meta("target")
            u.position = u.position.move_toward(target, float(speed.get(u.get_meta("kind"),4.0))*delta)
            if u.position.distance_to(target) < 0.2: u.remove_meta("target")
    _update()

func _unhandled_input(ev: InputEvent) -> void:
    if ev is InputEventMouseButton and ev.pressed:
        var m := ev as InputEventMouseButton
        var world := _mouse_world(m.position)
        if m.button_index == MOUSE_BUTTON_LEFT:
            _select_near(world)
        elif m.button_index == MOUSE_BUTTON_RIGHT and not selected.is_empty():
            for u in selected: u.set_meta("target",world)
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

func _select_near(p: Vector3) -> void:
    selected.clear()
    for u in units:
        if is_instance_valid(u) and u.position.distance_to(p)<2.8: selected.append(u)
    _log("تم تحديد %d وحدة" % selected.size())

func _spawn_unit(kind: String, pos: Vector3, team: int) -> Node3D:
    var u := Node3D.new()
    u.name = kind + "_%d" % next_id
    next_id += 1
    u.position = pos
    u.set_meta("kind",kind); u.set_meta("team",team); u.set_meta("hp",float(hp[kind])); u.set_meta("id",next_id)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.5,1.2,1.5) if kind != "طائرة" else Vector3(2.2,0.4,1.2)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#b33b32") if team==1 else Color("#3f86c7")
    mesh.material_override = mat
    mesh.position.y = 0.7
    u.add_child(mesh)
    add_child(u)
    if team==0: units.append(u)
    else: enemies.append(u)
    return u

func _spawn_enemy() -> void:
    for i in range(5): _spawn_unit("جندي" if i%2==0 else "دبابة",Vector3(10+i*2,0,-12+i),1)

func _spawn_building(kind: String, pos: Vector3, team: int) -> Node3D:
    var b := Node3D.new()
    b.name = kind
    b.position = pos
    b.set_meta("kind",kind); b.set_meta("team",team); b.set_meta("hp",1200.0)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(4,2.5,4)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("#8d9b45") if team==0 else Color("#7d3c3c")
    mesh.material_override = mat
    mesh.position.y = 1.25
    b.add_child(mesh); add_child(b); buildings.append(b)
    return b

func _build(kind: String, cost: int) -> void:
    if resources < cost: _log("الموارد غير كافية"); return
    resources -= cost
    _spawn_building(kind,Vector3(-10+randf()*18,0,10+randf()*8),0)
    _log("تم بناء %s" % kind)

func _produce(kind: String) -> void:
    var cost: int = costs[kind]
    if resources < cost: _log("الموارد غير كافية"); return
    if kind in ["جندي"] and not _has_building("ثكنة"): _log("تحتاج إلى ثكنة"); return
    if kind in ["دبابة","مدفعية","طائرة"] and not _has_building("مصنع"): _log("تحتاج إلى مصنع"); return
    resources -= cost
    var pos := Vector3(-10+randf()*10,0,12+randf()*8)
    _spawn_unit(kind,pos,0)
    _log("تم إنتاج %s" % kind)

func _has_building(kind: String) -> bool:
    for b in buildings:
        if is_instance_valid(b) and b.get_meta("team",1)==0 and b.get_meta("kind","")==kind: return true
    return false

func _enemy_attack() -> void:
    if units.is_empty(): return
    var u := units[randi()%units.size()]
    u.set_meta("hp",float(u.get_meta("hp"))-float(damage["جندي"])*difficulty*0.25)
    if float(u.get_meta("hp"))<=0:
        units.erase(u); selected.erase(u); u.queue_free(); _log("تحذير: فقدت وحدة")

func _cycle_faction() -> void:
    faction = factions[(factions.find(faction)+1)%factions.size()]
    _log("الفصيل: %s" % faction)

func _cycle_ai() -> void:
    difficulty = 1 if difficulty>=3 else difficulty+1
    _log("مستوى AI: %d" % difficulty)

func _cycle_map() -> void:
    map_index = (map_index+1)%maps.size()
    _log("الخريطة: %s" % maps[map_index])

func _save() -> void:
    var f := FileAccess.open("user://new_era_save.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"resources":resources,"power":power,"kills":kills,"wave":wave,"difficulty":difficulty,"faction":faction,"mission":mission,"map":map_index}))
    f.close(); _log("تم حفظ اللعبة")

func _load() -> void:
    if not FileAccess.file_exists("user://new_era_save.json"): _log("لا يوجد حفظ"); return
    var f := FileAccess.open("user://new_era_save.json",FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text()); f.close()
    if typeof(d)==TYPE_DICTIONARY:
        resources=int(d.get("resources",resources)); power=int(d.get("power",power)); kills=int(d.get("kills",kills)); wave=int(d.get("wave",wave)); difficulty=int(d.get("difficulty",difficulty)); faction=str(d.get("faction",faction)); mission=int(d.get("mission",mission)); map_index=int(d.get("map",map_index))
        _log("تم تحميل اللعبة")

func _host() -> void:
    if peer!=null: return
    peer=ENetMultiplayerPeer.new(); var err=peer.create_server(PORT,8)
    if err==OK: multiplayer.multiplayer_peer=peer; _log("تم فتح LAN على المنفذ 27015")
    else: _log("فشل LAN: %s" % err)

func _join() -> void:
    if peer!=null: return
    peer=ENetMultiplayerPeer.new(); var err=peer.create_client(ip_edit.text.strip_edges(),PORT)
    if err==OK: multiplayer.multiplayer_peer=peer; _log("جارٍ الاتصال بالمضيف")
    else: _log("فشل الاتصال: %s" % err)

func _update() -> void:
    if status: status.text = "المهمة %d | %s | الخريطة: %s | الموارد: %d | الطاقة: %d | التقنية: RTS | قتلى: %d" % [mission,faction,maps[map_index],resources,power,kills]

func _log(t: String) -> void:
    if log_label: log_label.text = t
