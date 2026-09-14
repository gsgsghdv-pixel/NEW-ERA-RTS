extends CanvasLayer

const MAX_PLAYERS := 8
const LOBBY_PROTOCOL := "NEWERA-RTS-LOBBY-1"
var players: Dictionary = {}
var host_started := false
var lobby_panel: Panel
var list_label: Label
var status_label: Label
var map_label: Label
var faction_label: Label
var team_label: Label
var ready := false
var local_name := "Player"
var selected_faction := 0
var selected_team := 1
var selected_map := 0
var factions := ["لبنان", "الشام", "الرافدين", "المشرق"]
var maps := ["وادي الأرز", "الساحل", "الصحراء", "المدينة", "الحدود"]

func _ready() -> void:
    layer = 20
    _build_ui()
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    _refresh()

func _build_ui() -> void:
    lobby_panel = Panel.new()
    lobby_panel.position = Vector2(310, 120)
    lobby_panel.size = Vector2(650, 470)
    add_child(lobby_panel)
    var title := Label.new()
    title.text = "LAN LOBBY — NEW ERA RTS"
    title.position = Vector2(25, 18)
    title.add_theme_font_size_override("font_size", 28)
    lobby_panel.add_child(title)
    status_label = Label.new()
    status_label.position = Vector2(25, 58)
    lobby_panel.add_child(status_label)
    list_label = Label.new()
    list_label.position = Vector2(25, 92)
    list_label.size = Vector2(390, 280)
    list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lobby_panel.add_child(list_label)
    map_label = Label.new()
    map_label.position = Vector2(440, 95)
    lobby_panel.add_child(map_label)
    faction_label = Label.new()
    faction_label.position = Vector2(440, 135)
    lobby_panel.add_child(faction_label)
    team_label = Label.new()
    team_label.position = Vector2(440, 175)
    lobby_panel.add_child(team_label)
    _button("تغيير الفصيل", 440, 215, _cycle_faction)
    _button("تغيير الفريق", 440, 255, _cycle_team)
    _button("تغيير الخريطة", 440, 295, _cycle_map)
    _button("جاهز / غير جاهز", 440, 335, _toggle_ready)
    _button("بدء المباراة — Host", 440, 375, _host_start)
    _button("إغلاق Lobby", 440, 415, _close_lobby)
    status_label.text = "LAN: في انتظار اللاعبين"

func _button(text: String, x: float, y: float, action: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.position = Vector2(x, y)
    b.size = Vector2(185, 34)
    b.pressed.connect(action)
    lobby_panel.add_child(b)

func _peer_connected(id: int) -> void:
    if multiplayer.is_server():
        if players.size() >= MAX_PLAYERS:
            multiplayer.disconnect_peer(id)
            return
        _send_lobby_state(id)
        _broadcast_player_state()

func _peer_disconnected(id: int) -> void:
    players.erase(id)
    _refresh()

func _toggle_ready() -> void:
    ready = not ready
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        submit_player.rpc_id(1, _player_data())
    else:
        players[1] = _player_data()
        _broadcast_player_state()
    _refresh()

func _player_data() -> Dictionary:
    return {"name": local_name, "faction": factions[selected_faction], "team": selected_team, "ready": ready}

func _cycle_faction() -> void:
    selected_faction = (selected_faction + 1) % factions.size()
    _submit_settings()

func _cycle_team() -> void:
    selected_team = (selected_team % 4) + 1
    _submit_settings()

func _cycle_map() -> void:
    if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
        return
    selected_map = (selected_map + 1) % maps.size()
    _broadcast_lobby_state()
    _refresh()

func _submit_settings() -> void:
    if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
        submit_player.rpc_id(1, _player_data())
    else:
        players[1] = _player_data()
        _broadcast_player_state()
    _refresh()

@rpc("any_peer", "reliable")
func submit_player(data: Dictionary) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if players.size() >= MAX_PLAYERS and not players.has(id):
        return
    players[id] = data
    _broadcast_player_state()

@rpc("authority", "reliable")
func receive_lobby_state(state: Dictionary, map_id: int, started: bool) -> void:
    players = state
    selected_map = clampi(map_id, 0, maps.size() - 1)
    host_started = started
    _refresh()
    if started:
        _close_lobby()

func _broadcast_player_state() -> void:
    if not multiplayer.is_server():
        return
    _broadcast_lobby_state()

func _broadcast_lobby_state() -> void:
    var state := players.duplicate(true)
    for id in multiplayer.get_peers():
        rpc_id(id, "receive_lobby_state", state, selected_map, host_started)
    _refresh()

func _send_lobby_state(id: int) -> void:
    rpc_id(id, "receive_lobby_state", players.duplicate(true), selected_map, host_started)

func _host_start() -> void:
    if multiplayer.multiplayer_peer == null:
        status_label.text = "استضف اللعبة أولاً من زر استضافة LAN"
        return
    if not multiplayer.is_server():
        status_label.text = "فقط المضيف يستطيع بدء المباراة"
        return
    for data in players.values():
        if not bool(data.get("ready", false)):
            status_label.text = "لا يمكن البدء: يوجد لاعب غير جاهز"
            return
    host_started = true
    _broadcast_lobby_state()
    _close_lobby()

func _close_lobby() -> void:
    lobby_panel.visible = false

func _refresh() -> void:
    if list_label == null:
        return
    var text := "اللاعبون (%d/%d)\n\n" % [players.size(), MAX_PLAYERS]
    for id in players.keys():
        var d: Dictionary = players[id]
        var mark := "✓" if bool(d.get("ready", false)) else "…"
        text += "%s  | فريق %s | %s | %s\n" % [mark, str(d.get("team", 1)), str(d.get("faction", "لبنان")), str(d.get("name", "Player"))]
    list_label.text = text
    map_label.text = "الخريطة: " + maps[selected_map]
    faction_label.text = "الفصيل: " + factions[selected_faction]
    team_label.text = "الفريق: %d" % selected_team

func can_enter_match() -> bool:
    if multiplayer.multiplayer_peer == null:
        return true
    return host_started
