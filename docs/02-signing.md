# 2. Signing

[← back to the guide](../README.md)

The Dopamine IPA is **ad-hoc signed** and ships no `embedded.mobileprovision`, so
it cannot be installed on a stock device as it comes. Something has to apply a
real signature first. That something is a signer, and on Linux there is exactly
one that works.

## Which signer

| Tool | Verdict |
|---|---|
| **plumesign** (Impactor 2.6.3 fork) | **Works.** Headless, scriptable, native Linux build. |
| Impactor GUI | Works, but manual. plumesign is its CLI core. |
| AltServer-Linux | Dead — last release v0.0.5 (2022); Apple's GSA returns 503. |
| Sideloadly | macOS/Windows only. |
| `ideviceinstaller` | An installer, not a signer. Useful for pushing already-signed IPAs. |

Get plumesign from the [Impactor releases](https://github.com/claration/Impactor/releases)
(the project was renamed from `khcrysalis/PlumeImpactor`).

## Why you need an anisette server

Apple's developer API will not issue a certificate without a set of headers that
identify the machine as a genuine Mac. An **anisette** server fabricates them.

Public anisette servers exist but are shared, rate-limited, and — by SideStore's
own FAQ — *"known to cause locking of Apple ID's."* A real Apple ID authenticates
through this, so run your own.

```sh
cd anisette && docker compose up -d
curl -sf https://your-anisette-host/v3/client_info
```

The compose file in [`anisette/`](../anisette/) runs
[dadoum/anisette-v3-server](https://github.com/Dadoum/anisette-v3-server). Use a
named volume rather than a bind mount: the image runs as uid 1000 and a
root-owned directory sends it into a restart loop.

The service has **no authentication** and is Apple-ID-adjacent. Restrict access
to it accordingly, and keep it up — a re-sign fails if it is unreachable.

### Why the certificate must be publicly trusted

plumesign opens a WebSocket to the anisette server for the provisioning session,
and its TLS stack is **rustls with `webpki-roots`**. That bundle is compiled in.
It **ignores the system trust store completely**, so adding your own CA to
`/etc/ssl/certs` changes nothing — you get `UnknownIssuer` no matter what.

The practical answer is a real certificate: put the server behind a reverse proxy
with Let's Encrypt. A private CA cannot be made to work without rebuilding
plumesign.

## Pointing plumesign at your server

The anisette URL is a **string literal inside the binary**, so it is patched in
place:

```sh
ANISETTE_URL=https://your.anisette.host python3 tools/patch-plumesign.py
```

This writes `tools/plumesign-local`.

The replacement must be **exactly as long as the original**,
`https://ani.sidestore.app` — 25 bytes. A Rust string is a (pointer, length)
pair, and the length is baked into the instruction stream separately from the
bytes, so anything else would need relocation. `https://` is 8 bytes, which
leaves **17 characters for the hostname**. The script refuses to write a binary
if the lengths differ.

Set it once in `.env`:

```sh
cp .env.example .env
$EDITOR .env        # ANISETTE_URL=https://ani.example.co
```

## Credentials

Put your Apple ID in `~/.secrets`:

```sh
APPLE_CREDENTIALS=you@example.com:yourpassword
```

The tooling reads that file and passes the password on **stdin**, never as a
command-line argument — `/proc/<pid>/cmdline` is world-readable.

## Signing and installing

```sh
./resign.sh tools/Dopamine.ipa
```

The first run prompts for a 2FA code. Write it to the file the script names, and
it is picked up automatically. The session is cached afterwards, so later runs
are unattended.

Download the IPA from [ellekit.space/dopamine](https://ellekit.space/dopamine/).

## Free-tier limits

| | Free Apple ID | Paid ($99/yr) |
|---|---|---|
| Certificate life | **7 days** | 1 year |
| Active apps | 3 | effectively unlimited |
| New App IDs | 10 / week | unlimited |

App Store apps do not consume a slot — only sideloaded ones do.

Free accounts also **cannot register App Groups**. Any IPA that declares
`ALTAppGroups` fails with `Developer API error 35`; `tools/make-sidestore-freetier.py`
strips them.

### What re-signing changes

Dopamine's ad-hoc signature claims entitlements no ordinary developer profile
grants — `platform-application`, various `com.apple.private.*`. Re-signing
replaces that blob with whatever your profile actually allows.

This is usually fine, because the jailbreak comes from the kernel exploit rather
than from those entitlements. If Dopamine fails at `Spawning jbctl failed with
error code 85`, stripped entitlements are the first suspect, and a paid account
is the fix.

---

Next: [3. Jailbreaking](03-jailbreak.md)
