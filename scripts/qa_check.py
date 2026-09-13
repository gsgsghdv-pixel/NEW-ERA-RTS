from pathlib import Path
import re, wave, sys
ROOT=Path(__file__).resolve().parents[1]
main=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
errors=[]
funcs=re.findall(r'^func\s+([A-Za-z0-9_]+)\s*\(', main, re.M)
from collections import Counter
for name,count in Counter(funcs).items():
    if count>1: errors.append(f'duplicate function: {name}')
for req in ['project.godot','scenes/main.tscn','scripts/main.gd','export_presets.cfg','BUILD_WINDOWS.bat']:
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
# Detect direct calls to private functions that are not defined (static heuristic).
known=set(funcs)
for call in sorted(set(re.findall(r'(?<!func )\b(_[A-Za-z0-9_]+)\s*\(', main))):
    if call not in known and call not in {'_ready','_process','_unhandled_input'}:
        errors.append(f'undefined function reference: {call}')
# RPC declarations must use an explicit peer/authority mode and transfer mode.
for m in re.finditer(r'@rpc\(([^)]*)\)\s*\nfunc\s+([A-Za-z0-9_]+)', main):
    args=m.group(1)
    if not any(x in args for x in ['authority','any_peer','call_local','call_remote']):
        errors.append(f'RPC missing peer mode: {m.group(2)}')
# Windows preset sanity.
exp=(ROOT/'export_presets.cfg').read_text(encoding='utf-8')
for token in ['name="Windows Desktop"','platform="Windows Desktop"','binary_format/architecture="x86_64"']:
    if token not in exp: errors.append(f'missing export setting: {token}')
if errors:
    print('QA FAIL')
    print('\n'.join(errors))
    sys.exit(1)
print('QA PASS')
print(f'Functions: {len(funcs)} | WAV: {len(list((ROOT/"audio").glob("*.wav")))} | RPC/static/export checks: PASS')
