extends Node
class_name RTSIntroController

## Opening sequence restored from the project's v25 design:
## an 8-second cinematic orbit that can be skipped by input.
const INTRO_TIME := 8.0

var game: Node
var camera: Camera3D
var camera_controller: Node
var elapsed := 0.0
var active := true

func _ready() -> void:
    game = get_parent()
    call_deferred("_begin")

func _begin() -> void:
    if game == null:
        active = false
        return
    camera = game.get("cam") as Camera3D
    if camera == null:
        camera = game.get_node_or_null("Camera3D") as Camera3D
    camera_controller = game.get_node_or_null("RTSCamera")
    if is_instance_valid(camera):
        camera.current = true
        camera.look_at(Vector3.ZERO)
    if is_instance_valid(camera_controller):
        camera_controller.set_process(false)
        camera_controller.set_process_input(false)
        camera_controller.set_process_unhandled_input(false)

func _process(delta: float) -> void:
    if not active:
        return
    if not is_instance_valid(camera):
        camera = game.get("cam") as Camera3D
        if not is_instance_valid(camera):
            return
    elapsed += delta
    camera.position = Vector3(sin(elapsed * 0.7) * 30.0, 20.0 + sin(elapsed) * 3.0, 30.0 - cos(elapsed * 0.7) * 13.0)
    camera.look_at(Vector3.ZERO)
    if elapsed >= INTRO_TIME:
        _finish()

func _input(event: InputEvent) -> void:
    if not active:
        return
    if event is InputEventMouseButton or event is InputEventKey:
        _finish()
        get_viewport().set_input_as_handled()

func _finish() -> void:
    if not active:
        return
    active = false
    if is_instance_valid(camera):
        camera.position = Vector3(0, 34, 31)
        camera.look_at(Vector3.ZERO)
    if is_instance_valid(camera_controller):
        camera_controller.set_process(true)
        camera_controller.set_process_input(true)
        camera_controller.set_process_unhandled_input(true)
