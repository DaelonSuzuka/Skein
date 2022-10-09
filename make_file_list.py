from pathlib import Path
import hashlib
import json


files = Path('addons/diagraph').rglob('*.*')

data = []

for f in files:
    data.append({
        'path': f.as_posix(),
        'hash': hashlib.sha1(f.read_bytes()).hexdigest(),
    })

with open('file_list.json', 'w') as f:
    f.write(json.dumps(data, indent=4))
