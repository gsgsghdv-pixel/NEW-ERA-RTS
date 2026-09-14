from pathlib import Path
import re, sys

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
guard = (ROOT / "scripts/network_guard.gd").read_text(encoding="utf-8")
scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
map_safe = (ROOT / "scripts/map_safety.gd").read_text(encoding="utf-8")

errors = []
checks = []

def require(condition, message):
    if condition:
        checks.append("PASS: " + message)
    else:
        errors.append("FAIL: " + message)

require('res://scripts/network_guard.gd' in scene, "NetworkGuard scene integration")
require('res://scripts/map_safety.gd' in scene, "MapSafety scene integration")
require('const PROTOCOL_VERSION := "NEWERA-RTS-LAN-1"' in guard, "fixed LAN protocol version")
require('@rpc("any_peer", "reliable")' in guard, "reliable peer handshake")
require('_protocol_challenge' in guard and '_protocol_accepted' in guard and '_protocol_rejected' in guard, "mismatch rejection path")
require('can_start_match' in guard, "match gate exists")
require('clamp(' in map_safe and 'obj.position' in map_safe, "world-object boundary clamp")
require('cam.size = SAFE_CAMERA_SIZE' in map_safe, "safe camera framing")
require('multiplayer' in main and 'ENetMultiplayerPeer' in main, "LAN transport present")
require('create_server(PORT,8)' in main and 'create_client(ip_edit.text.strip_edges(),PORT)' in main, "host/join transport paths")
rpc_funcs = re.findall(r'@rpc\(([^)]*)\)\s*\nfunc\s+([A-Za-z0-9_]+)', main)
require(len(rpc_funcs) > 0, "gameplay RPC routes present")
require(any('snapshot' in name.lower() or 'sync' in name.lower() for _, name in rpc_funcs), "state synchronization RPC present")
require(any('request' in name.lower() for _, name in rpc_funcs), "client request RPC present")
require('NetworkGuard' in scene, "LAN guard node named in scene")
# Catch the known entity-id off-by-one pattern.
require(not ('u.set_meta("id",next_id)' in main and 'next_id += 1' in main), "unit entity IDs do not use post-incremented value")
require('JSON.parse_string' in main and 'TYPE_DICTIONARY' in main, "save/load JSON validation")
require('map_index=int(d.get("map",map_index))' in main, "map index persisted")

if errors:
    print("DEEP SYSTEM QA FAIL")
    print("\n".join(checks + errors))
    sys.exit(1)
print("DEEP SYSTEM QA PASS")
print("\n".join(checks))
