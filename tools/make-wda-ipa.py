#!/usr/bin/env python3
"""Build tools/WebDriverAgent.ipa from the upstream WebDriverAgentRunner-Runner.zip.

WHY THIS IS NOT JUST `zip -r`
-----------------------------
plumesign signs the .app and its Frameworks but NOT the nested
PlugIns/WebDriverAgentRunner.xctest bundle. XCTest then cannot dlopen it and the run dies
at `didFailToBootstrapWithError`, with this in the device log:

    PlugIns/WebDriverAgentRunner.xctest/WebDriverAgentRunner
      ... mapped file has no cdhash, completely unsigned?
      Code has to be at least ad-hoc signed.

So the xctest binary is ad-hoc signed with ldid here, before packaging. Ad-hoc is enough
because the device is jailbroken (Dopamine patches AMFI); on a stock device this would
need a real signature covering the plugin.

The .dSYM is dropped -- debug symbols are useless on device and trip the signer.

    python3 tools/make-wda-ipa.py [path/to/WebDriverAgentRunner-Runner.zip]

Then: ./resign.sh tools/WebDriverAgent.ipa
"""
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
LDID = os.path.join(HERE, 'ldid')
DST = os.path.join(HERE, 'WebDriverAgent.ipa')
DEFAULT_ZIP = os.path.join(HERE, 'WebDriverAgentRunner-Runner.zip')


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ZIP
    if not os.path.isfile(src):
        sys.exit('missing runner zip: %s\n'
                 'get it from https://github.com/appium/WebDriverAgent/releases '
                 '(WebDriverAgentRunner-Runner.zip)' % src)
    if not os.access(LDID, os.X_OK):
        sys.exit('missing %s -- download ldid_linux_x86_64 from '
                 'https://github.com/ProcursusTeam/ldid/releases' % LDID)

    work = tempfile.mkdtemp(prefix='wda-ipa-')
    try:
        with zipfile.ZipFile(src) as z:
            z.extractall(work)
        app = os.path.join(work, 'WebDriverAgentRunner-Runner.app')
        if not os.path.isdir(app):
            sys.exit('unexpected zip layout: %s missing' % app)

        dsym = os.path.join(app, 'PlugIns', 'WebDriverAgentRunner.xctest.dSYM')
        if os.path.isdir(dsym):
            shutil.rmtree(dsym)
            print('dropped WebDriverAgentRunner.xctest.dSYM')

        xctest_bin = os.path.join(app, 'PlugIns', 'WebDriverAgentRunner.xctest',
                                  'WebDriverAgentRunner')
        if not os.path.isfile(xctest_bin):
            sys.exit('missing xctest binary: %s' % xctest_bin)
        subprocess.run([LDID, '-S', xctest_bin], check=True)
        print('ad-hoc signed PlugIns/WebDriverAgentRunner.xctest/WebDriverAgentRunner')

        # Any other Mach-O inside the xctest bundle needs the same treatment.
        xctest_dir = os.path.dirname(xctest_bin)
        for root, _, files in os.walk(xctest_dir):
            for fn in files:
                path = os.path.join(root, fn)
                if path == xctest_bin:
                    continue
                with open(path, 'rb') as fh:
                    magic = fh.read(4)
                if magic in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe'):
                    subprocess.run([LDID, '-S', path], check=True)
                    print('ad-hoc signed %s' % os.path.relpath(path, app))

        stage = os.path.join(work, 'ipa')
        os.makedirs(os.path.join(stage, 'Payload'))
        shutil.copytree(app, os.path.join(stage, 'Payload',
                                          'WebDriverAgentRunner-Runner.app'), symlinks=True)
        if os.path.exists(DST):
            os.unlink(DST)
        subprocess.run(['zip', '-qry', DST, 'Payload'], cwd=stage, check=True)
        print('wrote %s (%.2f MB)' % (DST, os.path.getsize(DST) / 1048576))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
