#!/usr/bin/env python3
"""Makes the zip files for distribution: one for each machine, in build/dist/.

  tools/make_dist.py [machine ...]       (`make dist` builds the machines first)

Each zip has the machine's files and a README.txt, made from dist/README.common.txt (what the game is, the credits, how it is
played) and the machine's own part (dist/<machine>.txt: how to run it and its keys).  The version is the Makefile's VERSION.
The zips are made the same each time (the files are stamped 1980-01-01), so a rebuild that changes nothing gives the same zip.
"""
import os
import re
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

# What may go in a zip: the files a person runs, and nothing the build leaves beside them (maps, listings, objects, the pieces
# a disk image is made of).  Each machine's files are named below, and checked against this and, afterwards, against the zip.
RUNNABLE = {'.aqx', '.bin', '.epr', '.app', '.ap0', '.ap1', '.a5p', '.cas', '.d88', '.mgt', '.nex'}

# machine: (name for the people, [files in build/ to include])
MACHINES = {
    'aqplus': ('Aquarius+', ['aqplus/simcity.aqx', 'aqplus/simcity.bin']),
    'z88': ('Cambridge Z88', ['z88rom/simcity.epr', 'z88rom/simcity.app', 'z88rom/simcity.ap0', 'z88rom/simcity.ap1', 'z88rom/simcity.a5p']),
    'multi8': ('Mitsubishi Multi 8', ['multi8/simcity.cas']),
    'pc88': ('NEC PC-8801', ['pc88/simcity.d88']),
    'sam': ('SAM Coupe', ['sam/simcity.mgt']),
    'zxn': ('ZX Spectrum Next', ['zxn/simcity.nex']),
}


def version():
    m = re.search(r'^VERSION\s*\?=\s*(\S+)', open(os.path.join(ROOT, 'Makefile')).read(), re.M)
    return m.group(1)


def readme(machine, title, files, ver):
    common = open(os.path.join(ROOT, 'dist', 'README.common.txt')).read()
    section = open(os.path.join(ROOT, 'dist', machine + '.txt')).read()
    listing = '\n'.join(f'  {os.path.basename(f):<14} {size_text(f)}' for f in files) + '\n  README.txt     this file'
    return common.replace('@TITLE@', title).replace('@VERSION@', 'v' + ver).replace('@FILES@', listing).replace('@SECTION@', section.rstrip('\n') + '\n')


def size_text(f):
    return f'{os.path.getsize(os.path.join(ROOT, "build", f)):,} bytes'


def main():
    ver = version()
    wanted = sys.argv[1:] or list(MACHINES)
    out = os.path.join(ROOT, 'build', 'dist')
    os.makedirs(out, exist_ok=True)
    status = 0
    for machine in wanted:
        title, files = MACHINES[machine]
        odd = [f for f in files if os.path.splitext(f)[1] not in RUNNABLE or f.endswith(('_BSS.bin', '_BOOTSTRAP.bin', '.map', '.63'))]
        if odd:
            sys.exit(f'{machine}: {", ".join(odd)} is not something to hand out')
        missing = [f for f in files if not os.path.exists(os.path.join(ROOT, 'build', f))]
        if missing:
            print(f'{machine}: not built ({", ".join(missing)})')
            status = 1
            continue
        path = os.path.join(out, f'simcity-{machine}-v{ver}.zip')
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
            for f in files:
                info = zipfile.ZipInfo(os.path.basename(f), (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(info, open(os.path.join(ROOT, 'build', f), 'rb').read())
            info = zipfile.ZipInfo('README.txt', (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, readme(machine, title, files, ver))
        with zipfile.ZipFile(path) as z:
            names = sorted(z.namelist())
        want = sorted([os.path.basename(f) for f in files] + ['README.txt'])
        if names != want:
            sys.exit(f'{path} has {names}, not {want}')
        print(f'{os.path.relpath(path, ROOT)}: {os.path.getsize(path):,} bytes: {", ".join(names)}')
    return status


if __name__ == '__main__':
    sys.exit(main())
