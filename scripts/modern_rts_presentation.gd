extends CanvasLayer

# Generals-style presentation layer: responsive RTS HUD, minimap and camera controls.
var game: Node3D
var resources_label: Label
var selected_label: Label
var zoom_label: Label
const CAMERA_SPEED := 28.0
const ZOOM_STEP := 5.0
const MIN_ZOOM := 18.0
const MAX_ZOOM := 58.0

func _ready() -> void:
    layer = 10
    game = get_parent()
    await get_tree().process_frame
    if game == null:
        return
    for child in game.get_children():
        if child is CanvasLayer and child != self and child.layer < 20:
            child.visible = false
    _build_hud()

func _build_hud() -> void:
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)

    var top := Panel.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_bottom = 74
    ui.add_child(top)

    var title := Label.new()
    title.text = "NEW ERA RTS"
    title.position = Vector2(24, 9)
    title.add_theme_font_size_override("font_size", 28)
    top.add_child(title)

    resources_label = Label.new()
    resources_label.position = Vector2(360, 18)
    resources_label.add_theme_font_size_override("font_size", 21)
    top.add_child(resources_label)

    var controls := Label.new()
    controls.text = "WASD/الأسهم: كاميرا   •   عجلة: تقريب   •   F11: ملء الشاشة"
    controls.position = Vector2(360, 48)
    controls.add_theme_font_size_override("font_size", 13)
    top.add_child(controls)

    _command_panel(ui)
    _selection_panel(ui)
    _minimap(ui)

    var bottom := Panel.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_top = -42
    ui.add_child(bottom)
    var hint := Label.new()
    hint.text = "زر أيسر: تحديد   •   سحب: تحديد جماعي   •   زر أيمن: حركة/أمر"
    hint.position = Vector2(24, 11)
    bottom.add_child(hint)

    zoom_label = Label.new()
    zoom_label.position = Vector2(24, 82)
    ui.add_child(zoom_label)

func _button(parent: Control, text: String, y: float, action: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.position = Vector2(12, y)
    b.size = Vector2(276, 31)
    b.pressed.connect(action)
    parent.add_child(b)

func _command_panel(ui: Control) -> void:
    var p := Panel.new()
    p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    p.position = Vector2(20, -255)
    p.size = Vector2(305, 230)
    ui.add_child(p)
    var h := Label.new()
    h.text = "مركز القيادة"
    h.position = Vector2(16, 10)
    h.add_theme_font_size_override("font_size", 20)
    p.add_child(h)
    _button(p, "جندي   [1]", 46, func(): game.call("_produce", "جندي"))
    _button(p, "دبابة   [2]", 82, func(): game.call("_produce", "دبابة"))
    _button(p, "مدفعية [3]", 118, func(): game.call("_produce", "مدفعية"))
    _button(p, "طائرة   [4]", 154, func(): game.call("_produce", "طائرة"))
    _button(p, "بناء ثكنة", 190, func(): game.call("_build", "ثكنة", 1500))

func _selection_panel(ui: Control) -> void:
    var p := Panel.new()
    p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    p.position = Vector2(-550, -255)
    p.size = Vector2(285, 220)
    ui.add_child(p)
    selected_label = Label.new()
    selected_label.position = Vector2(16, 16)
    selected_label.size = Vector2(250, 185)
    selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selected_label.add_theme_font_size_override("font_size", 17)
    p.add_child(selected_label)

func _minimap(ui: Control) -> void:
    var p := Panel.new()
    p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    p.position = Vector2(-250, -255)
    p.size = Vector2(220, 220)
    ui.add_child(p)
    var h := Label.new()
    h.text = "الخريطة التكتيكية"
    h.position = Vector2(12, 8)
    p.add_child(h)
    var map := ColorRect.new()
    map.position = Vector2(10, 36)
    map.size = Vector2(200, 170)
    map.color = Color("#18251b")
    p.add_child(map)

func _process(delta: float) -> void:
    if game == null or not is_instance_valid(game):
        return
    var r: Variant = game.get("resources")
    resources_label.text = "💰 %d     ⚡ %d     🎖 %s     🌊 %d" % [int(r), int(game.get("power")), str(game.get("faction")), int(game.get("wave"))]
    var list: Variant = game.get("selected")
    if list is Array and not list.is_empty():
        var lines := ["الوحدات المحددة: %d" % list.size()]
        for u in list:
            if is_instance_valid(u):
                lines.append("• %s   HP %d" % [str(u.get_meta("kind", "وحدة")), int(u.get_meta("hp", 0.0))])
        selected_label.text = "\n".join(lines)
    else:
        selected_label.text = "لا توجد وحدات محددة\n\nحدد وحداتك ثم استخدم الزر الأيمن لإصدار الأوامر."
    _camera(delta)
    if game.cam != null:
        zoom_label.text = "Zoom: %.1f" % game.cam.position.y

func _camera(delta: float) -> void:
    if game.cam == null:
        return
    var d: Vector3 = Vector3.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): d.z -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): d.z += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): d.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
    if d.length() > 0.0:
        game.cam.position += d.normalized() * CAMERA_SPEED * delta
    game.cam.position.x = clamp(game.cam.position.x, -55.0, 55.0)
    game.cam.position.z = clamp(game.cam.position.z, 18.0, 75.0)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
        var mode: int = DisplayServer.window_get_mode()
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-ZOOM_STEP)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(ZOOM_STEP)

func _zoom(amount: float) -> void:
    if game.cam == null:
        return
    var old_y: float = maxf(float(game.cam.position.y), 0.1)
    var new_y: float = clampf(old_y + amount, MIN_ZOOM, MAX_ZOOM)
    game.cam.position.y = new_y
    game.cam.position.z = clampf(game.cam.position.z * new_y / old_y, 18.0, 75.0)
