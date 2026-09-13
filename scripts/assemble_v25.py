from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARTS = ROOT / "scripts" / "v25_main_parts"
MAIN = ROOT / "scripts" / "main.gd"
parts = sorted(PARTS.glob("part*.txt"))
if not parts:
    raise SystemExit("No v25 main.gd parts found")
text = "".join(p.read_text(encoding="utf-8") for p in parts)
MAIN.write_text(text, encoding="utf-8", newline="\n")
print(f"Assembled {len(parts)} parts -> {MAIN} ({len(text)} chars)")
