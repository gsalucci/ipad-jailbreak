#!/usr/bin/env python3
"""Rebuild tools/plumesign-local: stock plumesign pointed at our own anisette server.

WHY THIS EXISTS
---------------
plumesign's anisette endpoints are compile-time constants -- there is no flag, no env
var and no config file that overrides them (~/.config/PlumeImpactor is empty even after
a successful login). The two baked-in URLs are:

    https://ani.f1sh.me/        (20 bytes)  -- DOWN as of 2026-09-14, connect fails
    https://ani.sidestore.app   (25 bytes)  -- shared public server, the one it uses

Both are shared instances. SideStore's own FAQ: "Older Anisette servers that are used by
many users are known to cause locking of Apple ID's." That is not theoretical -- it
happened to this account on 2026-09-14 (SRP error -20209, account locked, iForgot
required) after a handful of failed logins through the public server.

WHY A BINARY PATCH AND NOT A PROXY
----------------------------------
Two earlier approaches were tried and both are dead ends:

  * Plain http:// to the LAN server. plumesign derives the provisioning websocket URL
    from the anisette URL by swapping the https:// prefix for wss://. An http:// URL is
    left untouched and tungstenite rejects it: "URL scheme not supported".
  * Local TLS terminator (socat) with a private CA installed in the system trust store.
    Rejected with "invalid peer certificate: UnknownIssuer" even though the CA was
    verifiably present in /etc/ssl/certs/ca-certificates.crt. plumesign's websocket
    stack is rustls with webpki-roots -- compiled-in Mozilla roots, system store ignored.
    No locally-issued certificate can ever be trusted on that code path.

So the server must present a publicly-trusted certificate, which means a real domain.
The anisette host is served by Nginx Proxy Manager on a second machine with a Let's Encrypt cert,
proxying to the anisette container, firewalled by an NPM access list to LAN + this WAN IP
(the ACME challenge location keeps "allow all" so renewals still work).

THE LENGTH CONSTRAINT
---------------------
Rust string literals are (pointer, length) pairs -- the length is an immediate in the
code, not a NUL terminator in the data. An in-place overwrite is therefore only safe if
the replacement is EXACTLY the same byte length. That is why the host was chosen as it
was:

    https://ani.sidestore.app  = 25 bytes
    https://<your-host>        = must be EXACTLY 25 bytes too

A Rust string literal is a (pointer, length) pair, so the length is baked into
the instruction stream separately from the bytes. Patching in place therefore
requires an exact byte-length match; anything else needs relocation, which is
why the check below is fatal rather than a warning. Pick a hostname that makes
the whole URL 25 bytes -- e.g. https:// (8) + a 17-character host.

A trailing slash to pad a shorter URL does NOT work: it produces a doubled separator
("//v3/client_info") which the server answers with 404, surfacing as
"invalid type: integer 404, expected struct AnisetteClientInfo".

The f1sh URL is left alone: there is no publicly-trusted 12-character host to fit its
20-byte slot, and plumesign does not fall back to it in practice.
"""
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'plumesign-linux-x86_64')
DST = os.path.join(HERE, 'plumesign-local')

OLD = b'https://ani.sidestore.app'
# Your anisette server. Set ANISETTE_URL in the environment or in .env; it must
# be exactly as long as OLD (see the note above).
NEW = (os.environ.get('ANISETTE_URL') or '').encode() or None
if NEW is None:
    raise SystemExit('ANISETTE_URL is not set -- copy .env.example to .env')

# Upstream v2.6.3 artefact. If this changes, re-verify the offsets before trusting the
# patch -- a new build may lay the strings out differently.
EXPECTED_SRC_SHA256 = '445edd8bb131ab2c67dafb51966c1a1d1f00f7e697967902cf717b35ed53b41c'


def main():
    if len(OLD) != len(NEW):
        sys.exit('refusing: replacement is %d bytes, original is %d -- in-place patching '
                 'requires an exact length match' % (len(NEW), len(OLD)))
    if not os.path.isfile(SRC):
        sys.exit('missing %s' % SRC)

    data = open(SRC, 'rb').read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED_SRC_SHA256:
        print('WARNING: %s sha256 is %s, expected %s' % (os.path.basename(SRC), digest,
                                                         EXPECTED_SRC_SHA256))
        print('         upstream binary changed -- verify the patch still applies cleanly')

    count = data.count(OLD)
    if count != 1:
        sys.exit('expected exactly 1 occurrence of %s, found %d' % (OLD.decode(), count))

    open(DST, 'wb').write(data.replace(OLD, NEW))
    os.chmod(DST, 0o755)
    print('%s -> %s' % (OLD.decode(), NEW.decode()))
    print('wrote %s (sha256 %s)' % (DST, hashlib.sha256(open(DST, 'rb').read()).hexdigest()))


if __name__ == '__main__':
    main()
