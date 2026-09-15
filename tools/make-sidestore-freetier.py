#!/usr/bin/env python3
"""Produce tools/SideStore-freetier.ipa: SideStore with App Groups removed.

WHY
---
A free Apple developer account cannot register an App Group. Signing stock SideStore
with one fails at the Apple developer API:

    Developer API error 35: An Application Group with Identifier
    'group.com.SideStore.SideStore.QQ52XUYS37' is not available.

plumesign decides which groups to register from the AltStore-convention Info.plist key
ALTAppGroups (the string is present in the plumesign binary), so removing that key stops
it asking Apple for something a free account is never granted.

WHAT THIS CHANGES
-----------------
1. ALTAppGroups removed from the app's Info.plist.
2. PlugIns/AltWidgetExtension.appex removed entirely. The widget exists to read the
   shared app-group container; with no group it has nothing to read, and as a separate
   bundle id it would consume another App ID against the free tier's 10-per-week limit.

The app binary's own CS_ENTITLEMENTS still names the group, but that blob is discarded
and rebuilt from the new provisioning profile during signing, so it never reaches the
device.

CONSEQUENCE: SideStore falls back to its own container for storage. This is the same
situation as any free-account AltStore install. The home-screen widget is gone.
"""
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'SideStore.ipa')
DST = os.path.join(HERE, 'SideStore-freetier.ipa')


def main():
    if not os.path.isfile(SRC):
        sys.exit('missing %s' % SRC)

    work = tempfile.mkdtemp(prefix='sidestore-freetier-')
    try:
        with zipfile.ZipFile(SRC) as z:
            z.extractall(work)

        app = os.path.join(work, 'Payload', 'SideStore.app')
        if not os.path.isdir(app):
            sys.exit('unexpected IPA layout: %s missing' % app)

        info = os.path.join(app, 'Info.plist')
        d = plistlib.load(open(info, 'rb'))
        groups = d.pop('ALTAppGroups', None)
        plistlib.dump(d, open(info, 'wb'))
        print('removed ALTAppGroups from Info.plist: %s' % groups)

        widget = os.path.join(app, 'PlugIns', 'AltWidgetExtension.appex')
        if os.path.isdir(widget):
            shutil.rmtree(widget)
            print('removed PlugIns/AltWidgetExtension.appex')
        plugins = os.path.join(app, 'PlugIns')
        if os.path.isdir(plugins) and not os.listdir(plugins):
            os.rmdir(plugins)
            print('removed now-empty PlugIns/')

        if os.path.exists(DST):
            os.unlink(DST)
        # Use the zip binary rather than zipfile: it preserves symlinks inside
        # Frameworks/, which Python's ZipFile would flatten into regular files and
        # break the bundle.
        subprocess.run(['zip', '-qry', DST, 'Payload'], cwd=work, check=True)
        print('wrote %s (%.2f MB)' % (DST, os.path.getsize(DST) / 1048576))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
