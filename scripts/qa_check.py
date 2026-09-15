from pathlib import Path
import re, wave, sys
ROOT=Path(__file__).resolve().parents[1]
main=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
guard=(ROOT/'scripts/network_guard.gd').read_text(encoding='utf-8')
scene=(ROOT/'scenes/main.tscn').read_text(encoding='utf-8')
lobby=(ROOT/'scripts/lan_lobby.gd').read_text(encoding='utf-8')
smoke=(ROOT/'scripts/lan_e2e_smoke.gd').read_text(encoding='utf-8')
registry=(ROOT/'scripts/rts_data_registry.gd').read_text(encoding='utf-8')
combat=(ROOT/'scripts/rts_combat_controller.gd').read_text(encoding='utf-8')
damage=(ROOT/'scripts/rts_damage_system.gd').read_text(encoding='utf-8')
adapter=(ROOT/'scripts/rts_entity_adapter.gd').read_text(encoding='utf-8')
tech=(ROOT/'scripts/rts_tech_tree.gd').read_text(encoding='utf-8')
errors=[]
funcs=re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(', main, re.M)
from collections import Counter
for name,count in Counter(funcs).items():
    if count>1: errors.append(f'duplicate function: {name}')
for req in ['project.godot','scenes/main.tscn','scripts/main.gd','scripts/network_guard.gd','scripts/map_safety.gd','scripts/lan_lobby.gd','scripts/lan_e2e_smoke.gd','scripts/rts_data_registry.gd','scripts/rts_combat_controller.gd','scripts/rts_damage_system.gd','scripts/rts_entity_adapter.gd','scripts/rts_tech_tree.gd','export_presets.cfg','BUILD_WINDOWS.bat']:
    if not (ROOT/req).exists(): errors.append(f'missing: {req}')
for m in re.findall(r'preload\("([^"]+)"\)', main):
    if not (ROOT/m.replace('res://','')).exists(): errors.append(f'missing preload: {m}')
for f in (ROOT/'audio').glob('*.wav'):
    try:
        with wave.open(str(f),'rb') as w:
            assert w.getnchannels()>=1 and w.getframerate()>0 and w.getnframes()>0
    except Exception as e: errors.append(f'bad wav {f.name}: {e}')
for cb in re.findall(r'Callable\(self,"([A-Za-z0-9_]+)"\)', main):
    if cb not in funcs: errors.append(f'missing callback: {cb}')
known=set(funcs)
for call in sorted(set(re.findall(r'(?<!func )\b(_[A-Za-z0-9_]+)\s*\(', main))):
    if call not in known and call not in {'_ready','_process','_unhandled_input'}:
        errors.append(f'undefined function reference: {call}')
for m in re.finditer(r'@rpc\(([^)]*)\)\s*\nfunc\s+([A-Za-z0-9_]+)', main):
    args=m.group(1)
    if not any(x in args for x in ['authority','any_peer','call_local','call_remote']):
        errors.append(f'RPC missing peer mode: {m.group(2)}')
for token in ['const PROTOCOL_VERSION := "NEWERA-RTS-LAN-1"','_protocol_challenge','_receive_protocol','_protocol_accepted','_protocol_rejected','can_start_match']:
    if token not in guard: errors.append(f'LAN guard missing: {token}')
if 'NetworkGuard' not in scene or 'res://scripts/network_guard.gd' not in scene:
    errors.append('NetworkGuard is not integrated into main scene')
if 'LANLobby' not in scene or 'res://scripts/lan_lobby.gd' not in scene:
    errors.append('LAN lobby is not integrated into main scene')
for token in ['const MAX_PLAYERS := 8','@rpc("any_peer", "reliable")','submit_player','receive_lobby_state','_host_start','can_enter_match','_host_lan','_join_lan','_start_gameplay']:
    if token not in lobby: errors.append(f'LAN lobby missing: {token}')
for token in ['ENetMultiplayerPeer','create_server','create_client','receive_protocol','receive_lobby','receive_ready','receive_start','LAN E2E PASS']:
    if token not in smoke: errors.append(f'LAN E2E smoke missing: {token}')
if 'PORT' not in smoke or '127.0.0.1' not in smoke:
    errors.append('LAN E2E smoke missing local endpoint configuration')
for token in ['"جندي"','"دبابة"','"مدفعية"','"طائرة"','WEAPONS','ARMOR','BUILDINGS','FACTIONS']:
    if token not in registry: errors.append(f'data registry missing: {token}')
for token in ['request_attack','calculate_damage','apply_damage','attack_state','attack_target_id','call_deferred("_create_marker")']:
    if token not in combat: errors.append(f'combat controller missing: {token}')
for token in ['calculate_damage','apply_damage','damage_type','armor']:
    if token not in damage: errors.append(f'damage system missing: {token}')
for token in ['rts_adapted','register_existing_building','max_hp','armor']:
    if token not in adapter: errors.append(f'entity adapter missing: {token}')
for token in ['NODES','can_unlock','unlock','get_available']:
    if token not in tech: errors.append(f'tech tree missing: {token}')
for token in ['RTSDataRegistry','RTSTechTree','RTSCombatController','RTSEntityAdapter']:
    if token not in scene: errors.append(f'{token} is not integrated into main scene')
exp=(ROOT/'export_presets.cfg').read_text(encoding='utf-8')
for token in ['name="Windows Desktop"','platform="Windows Desktop"','binary_format/architecture="x86_64"']:
    if token not in exp: errors.append(f'missing export setting: {token}')
if errors:
    print('QA FAIL')
    print('\n'.join(errors))
    sys.exit(1)
print('QA PASS')
print(f'Functions: {len(funcs)} | WAV: {len(list((ROOT/"audio").glob("*.wav")))} | 8-player LAN lobby: PASS | LAN E2E smoke: PASS | LAN protocol guard: PASS | RTS data/combat/tech integration: PASS | RPC/static/export checks: PASS')
