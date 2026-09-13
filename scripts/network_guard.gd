extends Node

# LAN protocol gate. Increment this whenever network state/RPC/schema changes.
const PROTOCOL_VERSION := "NEWERA-RTS-LAN-1"
var handshake_ok := false
var rejected := false
var connected_peers: Dictionary = {}

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(peer_id: int) -> void:
    handshake_ok = false
    rejected = false
    if multiplayer.is_server():
        rpc_id(peer_id, "_protocol_challenge", PROTOCOL_VERSION)
    else:
        rpc_id(1, "_receive_protocol", PROTOCOL_VERSION)

@rpc("authority", "reliable")
func _protocol_challenge(expected_version: String) -> void:
    if expected_version != PROTOCOL_VERSION:
        rejected = true
        handshake_ok = false
        _close_peer()
        return
    rpc_id(1, "_receive_protocol", PROTOCOL_VERSION)

@rpc("any_peer", "reliable")
func _receive_protocol(remote_version: String) -> void:
    var sender := multiplayer.get_remote_sender_id()
    if remote_version != PROTOCOL_VERSION:
        rejected = true
        handshake_ok = false
        if multiplayer.is_server() and sender != 0 and sender != 1:
            rpc_id(sender, "_protocol_rejected", PROTOCOL_VERSION)
            multiplayer.disconnect_peer(sender)
        elif not multiplayer.is_server():
            _close_peer()
        return
    if multiplayer.is_server():
        if sender != 0 and sender != 1:
            connected_peers[sender] = true
            rpc_id(sender, "_protocol_accepted", PROTOCOL_VERSION)
        else:
            handshake_ok = true
    else:
        handshake_ok = true

@rpc("authority", "reliable")
func _protocol_accepted(version: String) -> void:
    if version == PROTOCOL_VERSION:
        handshake_ok = true
        rejected = false
    else:
        rejected = true
        handshake_ok = false
        _close_peer()

@rpc("authority", "reliable")
func _protocol_rejected(expected_version: String) -> void:
    rejected = true
    handshake_ok = false
    push_error("LAN MISMATCH: expected " + expected_version + ", local=" + PROTOCOL_VERSION)
    _close_peer()

func _on_peer_disconnected(peer_id: int) -> void:
    connected_peers.erase(peer_id)
    if connected_peers.is_empty():
        handshake_ok = false

func _close_peer() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()

func can_start_match() -> bool:
    if multiplayer.multiplayer_peer == null:
        return true
    return handshake_ok and not rejected

func get_protocol_version() -> String:
    return PROTOCOL_VERSION
