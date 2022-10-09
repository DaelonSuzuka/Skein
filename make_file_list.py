from pathlib import Path


files = Path('addons/diagraph').rglob('*.*')

with open('file_list.txt', 'w') as f:
    f.write('\n'.join(file.as_posix() for file in files))