from pathlib import Path
import hashlib
import sys

root = Path(sys.argv[1]).resolve()
files = sorted(p for p in root.iterdir() if p.is_file() and p.suffix in {'.dmg', '.exe', '.zip'})
if not files:
    raise SystemExit('No release packages found')
lines = [f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}' for p in files]
(root / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines))
