"""Measure the actual signed APK; no APK mutation or rebuild."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile
from collections import defaultdict

apk = Path(sys.argv[1])
summary = Path(sys.argv[2])
with zipfile.ZipFile(apk) as archive:
    assert archive.testzip() is None
    entries = []
    groups = defaultdict(lambda: {'storedBytes': 0, 'expandedBytes': 0})
    for item in archive.infolist():
        name = item.filename
        category = ('Flutter native' if name.endswith('/libflutter.so') else
                    'Native libraries' if name.startswith('lib/') else
                    'Flutter debug runtime' if name.endswith(('kernel_blob.bin','vm_snapshot_data','isolate_snapshot_data')) else
                    'Images' if name.endswith(('.webp','.png','.jpg','.jpeg')) else
                    'Fonts' if name.endswith(('.ttf','.otf')) else
                    'Video' if name.endswith('.mp4') else
                    'DEX' if name.endswith('.dex') else
                    'Resources' if name.startswith('res/') or name == 'resources.arsc' else 'Other')
        groups[category]['storedBytes'] += item.compress_size
        groups[category]['expandedBytes'] += item.file_size
        entries.append({'path': name,'storedBytes': item.compress_size,'expandedBytes': item.file_size})
size = apk.stat().st_size
result = {'apkBytes': size,'MB': size/1_000_000,'MiB': size/1_048_576,
          'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(), 'groups': dict(groups),
          'largestEntries': sorted(entries,key=lambda x:x['storedBytes'],reverse=True)[:40],
          'note': 'Stored sums exclude ZIP structures/signature block/alignment padding.'}
summary.write_text(json.dumps(result,indent=2)+'\n')
print('::notice title=Exact signed APK size/hash::'+json.dumps({k: result[k] for k in ['apkBytes','MB','MiB','sha256']}))
