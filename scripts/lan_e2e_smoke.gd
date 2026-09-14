extends SceneTree

const PORT: int = 27125
const PROTOCOL := "NEWERA-RTS-LAN-1"
const TIMEOUT_MS: int = 20000

class LanTestPeer extends Node:
    var role: String = ""
    var peer: ENetMultiplayerPeer
    var mp: MultiplayerAPI
    var phase: int = 0
    var deadline: int = 0
    var passed: bool = false
    var connected: bool = false

    func setup(test_role: String) -> void:
        role = test_role
        process_mode = Node.PROCESS_MODE_ALWAYS
        set_multiplayer_authority(1)
        mp = get_tree().get_multiplayer()
        if mp == null:
            push_error("LAN E2E: MultiplayerAPI unavailable")
            get_tree().quit(6)
            return
        get_tree().set_multiplayer_poll_enabled(false)
        mp.peer_connected.connect(_on_peer_connected)
        mp.peer_disconnected.connect(_on_peer_disconnected)
        if role == "client":
            mp.connected_to_server.connect(_on_connected_to_server)
            mp.connection_failed.connect(_on_connection_failed)
        peer = ENetMultiplayerPeer.new()
        if role == "host":
            var err: Error = peer.create_server(PORT, 8, 0)
            if err != OK:
                push_error("LAN E2E host create_server failed: %s" % err)
                get_tree().quit(3)
                return
            mp.multiplayer_peer = peer
            deadline = Time.get_ticks_msec() + TIMEOUT_MS
            print("LAN E2E HOST READY port=%d id=%d" % [PORT, mp.get_unique_id()])
        else:
            var err: Error = peer.create_client("127.0.0.1", PORT, 0, 0, 0, 0)
            if err != OK:
                push_error("LAN E2E client create_client failed: %s" % err)
                get_tree().quit(4)
                return
            mp.multiplayer_peer = peer
            deadline = Time.get_ticks_msec() + TIMEOUT_MS
            print("LAN E2E CLIENT CONNECTING id=%d" % mp.get_unique_id())

    func _process(_delta: float) -> void:
        if mp != null and mp.has_multiplayer_peer():
            mp.poll()
        if passed:
            return
        if deadline > 0 and Time.get_ticks_msec() > deadline:
            var peer_count: int = mp.get_peers().size() if mp != null else -1
            push_error("LAN E2E timeout phase=%d role=%s connected=%s peers=%d" % [phase, role, connected, peer_count])
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
        var sender: int = mp.get_remote_sender_id()
        print("LAN E2E %s: protocol received from=%d value=%s" % [role.to_upper(), sender, remote])
        if remote != PROTOCOL:
            push_error("LAN E2E protocol mismatch")
            if mp.is_server() and sender != 0:
                mp.multiplayer_peer.disconnect_peer(sender)
            get_tree().quit(11)
            return
        if role == "host" and sender > 1:
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
        var sender: int = mp.get_remote_sender_id()
        if sender > 1 and is_ready:
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
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--role="):
            role = arg.substr(7).strip_edges().to_lower()
    if role != "host" and role != "client":
        push_error("LAN E2E: missing --role=host|client")
        quit(2)
        return
    call_deferred("_start_test", role)

func _start_test(role: String) -> void:
    if root == null:
        push_error("LAN E2E: SceneTree root unavailable after initialization")
        quit(7)
        return
    test_peer = LanTestPeer.new()
    test_peer.name = "LanTestPeer"
    root.add_child(test_peer)
    await process_frame
    test_peer.setup(role)
