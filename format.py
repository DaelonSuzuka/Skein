from pathlib import Path
import subprocess

files = ' '.join([f.as_posix() for f in Path('.').rglob('*.gd')])
subprocess.call(f"gdformat {files}", shell=True)