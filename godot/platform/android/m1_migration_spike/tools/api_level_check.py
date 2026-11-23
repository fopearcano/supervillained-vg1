"""M1 migration spike: static minSdk check of the compiled plugin.

Lists every Android framework class, method and field the plugin's bytecode references (every
Class/Methodref/InterfaceMethodref/Fieldref entry of the constant pools printed by `javap -v`, so
lambda and method-reference targets are included) with the API level it appeared in (the SDK's
platforms/android-NN/data/api-versions.xml, following superclasses and interfaces), and fails when
one is newer than --min-sdk unless it is in --guarded (calls the source only makes behind a
Build.VERSION.SDK_INT check, reviewed by hand).

Usage: python api_level_check.py --javap <javap.exe> --classes <dir> --api-versions <xml>
                                 --min-sdk 24 [--guarded <owner.name> ...]
"""
import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ap = argparse.ArgumentParser()
ap.add_argument('--javap', required=True)
ap.add_argument('--classes', required=True)
ap.add_argument('--api-versions', required=True)
ap.add_argument('--min-sdk', type=int, required=True)
ap.add_argument('--guarded', nargs='*', default=[])
a = ap.parse_args()

classes = {}
for c in ET.parse(a.api_versions).getroot().iter('class'):
    classes[c.get('name')] = {
        'since': int(c.get('since', '1')),
        'supers': [e.get('name') for e in c if e.tag in ('extends', 'implements')],
        'members': {m.get('name'): int(m.get('since', c.get('since', '1'))) for m in c if m.tag in ('method', 'field')},
    }


def member_since(owner, name, seen=None):
    seen = seen or set()
    if owner in seen or owner not in classes:
        return None
    seen.add(owner)
    c = classes[owner]
    if name in c['members']:
        return c['members'][name]
    for s in c['supers']:
        v = member_since(s, name, seen)
        if v is not None:
            return v
    return None


refs = set()
kinds = {'Class': 'class', 'Methodref': 'Method', 'InterfaceMethodref': 'InterfaceMethod', 'Fieldref': 'Field'}
pat = re.compile(r'^\s*#\d+ = (Class|Methodref|InterfaceMethodref|Fieldref)\s+\S+\s+//\s+(\S+)', re.M)
for root, _, files in os.walk(a.classes):
    for f in files:
        if f.endswith('.class'):
            out = subprocess.run([a.javap, '-v', '-p', os.path.join(root, f)], capture_output=True, text=True).stdout
            for kind, ref in pat.findall(out):
                if ref.startswith('android/'):
                    refs.add((kinds[kind], ref.strip('"')))

rows, bad = [], []
for kind, ref in sorted(refs):
    if not ref.startswith('android/'):
        continue
    if kind == 'class':
        owner, name, since = ref, None, classes.get(ref, {}).get('since')
    else:
        owner, member = ref.split('.', 1)
        mname, _, desc = member.partition(':')
        key = mname.strip('"') + (desc if kind != 'Field' else '')
        since = member_since(owner, key)
        name = key
    label = owner + ('' if name is None else '.' + name)
    short = owner + ('' if name is None else '.' + name.split('(')[0])
    status = 'ok'
    if since is None:
        status = 'unknown'
        bad.append(label)
    elif since > a.min_sdk:
        status = 'guarded' if short in a.guarded else 'TOO NEW'
        if status == 'TOO NEW':
            bad.append(label)
    rows.append(f'{since if since is not None else "?":>4}  {status:8} {kind:15} {label}')
print('\n'.join(rows))
print(f'{len(rows)} Android references; min SDK {a.min_sdk}; guarded: {", ".join(a.guarded) or "none"}')
if bad:
    print('FAIL: ' + '; '.join(bad))
    sys.exit(1)
print('OK: every Android reference is available at the min SDK or explicitly guarded')
