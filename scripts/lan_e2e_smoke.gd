extends SceneTree

const PORT := 27125
const PROTOCOL := "NEWERA-RTS-LAN-1"
const TIMEOUT_MS := 15000

class LanTestPeer extends Node:
    var role: String = ""
    var peer := ENetMultiplayerPeer.new()
    var phase: int = 0
    var deadline: int = 0
    var passed: bool = false
    var connected: bool = false

    func setup(test_role: String) -> void:
        role = test_role
        process_mode = Node.PROCESS_MODE_ALWAYS
        multiplayer.peer_connected.connect(_on_peer_connected)
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)
        if role == "client":
            multiplayer.connected_to_server.connect(_on_connected_to_server)
            multiplayer.connection_failed.connect(_on_connection_failed)
        if role == "host":
            var err: Error = peer.create_server(PORT, 8)
            if err != OK:
                push_error("LAN E2E host create_server failed: %s" % err)
                get_tree().quit(3)
                return
            multiplayer.multiplayer_peer = peer
            deadline = Time.get_ticks_msec() + TIMEOUT_MS
            print("LAN E2E HOST READY port=%d" % PORT)
        else:
            var err: Error = peer.create_client("127.0.0.1", PORT)
            if err != OK:
                push_error("LAN E2E client create_client failed: %s" % err)
                get_tree().quit(4)
                return
            multiplayer.multiplayer_peer = peer
            deadline = Time.get_ticks_msec() + TIMEOUT_MS
            print("LAN E2E CLIENT CONNECTING")

    func _process(_delta: float) -> void:
        if passed:
            return
        if deadline > 0 and Time.get_ticks_msec() > deadline:
            push_error("LAN E2E timeout phase=%d role=%s connected=%s peers=%d" % [phase, role, connected, multiplayer.get_peers().size()])
            get_tree().quit(10)

    func _on_connected_to_server() -> void:
        connected = true
        phase = 1
        rpc_id(1, "receive_protocol", PROTOCOL)
        print("LAN E2E CLIENT: connected_to_server; protocol sent")

    func _on_connection_failed() -> void:
        push_error("LAN E2E CLIENT: connection_failed")
        get_tree().quit(5)

    func _on_peer_connected(id: int) -> void:
        connected = true
        phase = 1
        if role == "host":
            rpc_id(id, "receive_protocol", PROTOCOL)
            print("LAN E2E HOST: peer connected id=%d; protocol challenge sent" % id)
        elif id == 1:
            print("LAN E2E CLIENT: peer_connected id=1")

    @rpc("any_peer", "reliable")
    func receive_protocol(remote: String) -> void:
        var sender: int = multiplayer.get_remote_sender_id()
        print("LAN E2E %s: protocol received from=%d value=%s" % [role.to_upper(), sender, remote])
        if remote != PROTOCOL:
            push_error("LAN E2E protocol mismatch")
            if multiplayer.is_server() and sender != 0:
                multiplayer.disconnect_peer(sender)
            get_tree().quit(11)
            return
        if role == "host" and sender != 0:
            phase = 2
            rpc_id(sender, "receive_lobby", {"players": 2, "map": 0})
            print("LAN E2E HOST: lobby state sent")
        elif role == "client" and sender == 1:
            phase = 2
            print("LAN E2E CLIENT: protocol accepted")

    @rpc("authority", "reliable")
    func receive_lobby(state: Dictionary) -> void:
        if role != "client":
            return
        if int(state.get("players", 0)) != 2 or int(state.get("map", -1)) != 0:
            push_error("LAN E2E lobby state invalid")
            get_tree().quit(12)
            return
        phase = 3
        rpc_id(1, "receive_ready", true)
        print("LAN E2E CLIENT: lobby state received; ready sent")

    @rpc("any_peer", "reliable")
    func receive_ready(is_ready: bool) -> void:
        if role != "host":
            return
        var sender: int = multiplayer.get_remote_sender_id()
        if sender != 0 and is_ready:
            phase = 4
            rpc_id(sender, "receive_start", 0)
            print("LAN E2E HOST: client ready; match start sent")

    @rpc("authority", "reliable")
    func receive_start(map_id: int) -> void:
        if role != "client":
            return
        if map_id != 0:
            push_error("LAN E2E start map invalid")
            get_tree().quit(13)
            return
        phase = 5
        passed = true
        print("LAN E2E PASS: connect -> protocol -> lobby -> ready -> start")
        get_tree().quit(0)

    func _on_peer_disconnected(id: int) -> void:
        if not passed:
            push_error("LAN E2E peer disconnected before completion id=%d" % id)
            get_tree().quit(14)

var test_peer: LanTestPeer

func _initialize() -> void:
    var role: String = ""
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--role="):
            role = a.substr(7)
    if role != "host" and role != "client":
        push_error("LAN E2E: missing --role=host|client")
        quit(2)
        return
    test_peer = LanTestPeer.new()
    root.add_child(test_peer)
    test_peer.setup(role)
