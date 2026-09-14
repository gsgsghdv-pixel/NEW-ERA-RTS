extends SceneTree

const PORT := 27125
const PROTOCOL := "NEWERA-RTS-LAN-1"
var role := ""
var peer := ENetMultiplayerPeer.new()
var done := false
var passed := false
var phase := 0
var deadline := 0

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    for a in args:
        if a.begins_with("--role="):
            role = a.substr(7)
    if role != "host" and role != "client":
        push_error("LAN E2E: missing --role=host|client")
        quit(2)
        return
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    if role == "host":
        var err := peer.create_server(PORT, 8)
        if err != OK:
            push_error("LAN E2E host create_server failed: %s" % err)
            quit(3)
            return
        multiplayer.multiplayer_peer = peer
        deadline = Time.get_ticks_msec() + 10000
        print("LAN E2E HOST READY")
    else:
        var err := peer.create_client("127.0.0.1", PORT)
        if err != OK:
            push_error("LAN E2E client create_client failed: %s" % err)
            quit(4)
            return
        multiplayer.multiplayer_peer = peer
        deadline = Time.get_ticks_msec() + 10000
        print("LAN E2E CLIENT CONNECTING")

func _process(_delta: float) -> bool:
    if done:
        return false
    if Time.get_ticks_msec() > deadline:
        push_error("LAN E2E timeout phase=%d role=%s" % [phase, role])
        quit(10)
        done = true
        return false
    return false

func _on_peer_connected(id: int) -> void:
    if role == "host":
        phase = 1
        rpc_id(id, "receive_protocol", PROTOCOL)
        print("LAN E2E HOST: peer connected")
    else:
        phase = 1
        rpc_id(1, "receive_protocol", PROTOCOL)
        print("LAN E2E CLIENT: peer connected")

@rpc("any_peer", "reliable")
func receive_protocol(remote: String) -> void:
    var sender := multiplayer.get_remote_sender_id()
    if remote != PROTOCOL:
        push_error("LAN E2E protocol mismatch")
        if multiplayer.is_server(): multiplayer.disconnect_peer(sender)
        quit(11)
        return
    if role == "host" and sender != 0:
        phase = 2
        rpc_id(sender, "receive_lobby", {"players": 2, "map": 0, "ready": true})
    elif role == "client" and sender == 1:
        phase = 2
        print("LAN E2E CLIENT: protocol accepted")

@rpc("authority", "reliable")
func receive_lobby(state: Dictionary) -> void:
    if role != "client": return
    if int(state.get("players", 0)) != 2:
        push_error("LAN E2E lobby state invalid")
        quit(12)
        return
    phase = 3
    rpc_id(1, "receive_ready", true)
    print("LAN E2E CLIENT: lobby state received")

@rpc("any_peer", "reliable")
func receive_ready(is_ready: bool) -> void:
    if role != "host": return
    var sender := multiplayer.get_remote_sender_id()
    if sender != 0 and is_ready:
        phase = 4
        rpc_id(sender, "receive_start", 0)
        print("LAN E2E HOST: client ready; match start sent")

@rpc("authority", "reliable")
func receive_start(map_id: int) -> void:
    if role != "client": return
    if map_id != 0:
        push_error("LAN E2E start map invalid")
        quit(13)
        return
    phase = 5
    passed = true
    print("LAN E2E PASS: connect -> protocol -> lobby -> ready -> start")
    quit(0)

func _on_peer_disconnected(_id: int) -> void:
    if not passed and not done:
        push_error("LAN E2E peer disconnected before completion")
        quit(14)
