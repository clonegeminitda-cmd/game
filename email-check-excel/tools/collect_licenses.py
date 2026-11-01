from importlib import metadata
from pathlib import Path
import shutil
import sys
import urllib.request

root = Path(sys.argv[1])
root.mkdir(parents=True, exist_ok=True)
for dist in metadata.distributions():
    name = dist.metadata.get('Name', 'package')
    target = root / name
    for file in dist.files or []:
        label = file.name.lower()
        if any(word in label for word in ('license','copying','notice')) and file.suffix.lower() in ('','.txt','.md','.rst'):
            path = Path(dist.locate_file(file))
            if path.is_file() and path.stat().st_size < 1000000:
                target.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target / file.name)
    text = dist.metadata.get('License')
    if text and text != 'UNKNOWN':
        target.mkdir(parents=True, exist_ok=True)
        (target/'METADATA-LICENSE.txt').write_text(text, encoding='utf-8')
for name in ('LGPL-3.0-only.txt','GPL-3.0-only.txt'):
    url = 'https://raw.githubusercontent.com/qt/qtbase/v6.8.3/LICENSES/' + name
    with urllib.request.urlopen(url,timeout=30) as response:
        (root/name).write_bytes(response.read())
for candidate in [Path(sys.base_prefix)/'LICENSE.txt',Path(sys.base_prefix)/'LICENSE']:
    if candidate.exists():
        shutil.copyfile(candidate, root/'CPython-LICENSE.txt')
        break
