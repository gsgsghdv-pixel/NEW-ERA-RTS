extends Node
const SPEED := 30.0
const MIN_SIZE := 20.0
const MAX_SIZE := 60.0
var game: Node3D
func _ready() -> void:
    game = get_parent()
    await get_tree().process_frame
    if game != null and game.cam != null:
        game.cam.projection = Camera3D.PROJECTION_ORTHOGONAL
        game.cam.size = 38.0
        game.cam.position = Vector3(0,38,30)
        game.cam.rotation_degrees = Vector3(-55,0,0)
        game.cam.current = true
func _process(delta: float) -> void:
    if game == null or game.cam == null: return
    var v := Vector3.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.z -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.z += 1
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
    if v.length() > 0: game.cam.position += v.normalized() * SPEED * delta
    game.cam.position.x = clamp(game.cam.position.x,-32.0,32.0)
    game.cam.position.z = clamp(game.cam.position.z,8.0,62.0)
func _input(event: InputEvent) -> void:
    if game == null or game.cam == null: return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: game.cam.size = clamp(game.cam.size - 3.0,MIN_SIZE,MAX_SIZE)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: game.cam.size = clamp(game.cam.size + 3.0,MIN_SIZE,MAX_SIZE)
