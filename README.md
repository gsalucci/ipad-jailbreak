# iPad 8 jailbreak toolchain — Void Linux host

Jailbreaking an **iPad11,6** (iPad 8, A2270, iPadOS 18.5) with **Dopamine 3.0.9**,
signed and driven entirely from a Linux host. No Mac, no Windows, no AltStore.

Everything here was executed and observed on real hardware. Where something
failed, the failure is recorded next to the fix rather than deleted.

## What is here

| file | what |
|---|---|
| [`JAILBREAK-GUIDE.md`](JAILBREAK-GUIDE.md) | the runbook, including the run that actually worked |
| [`resign.sh`](resign.sh) | one command to re-sign before the 7-day certificate expires |
| [`preflight.sh`](preflight.sh) | check the host is in a state that can sign (exit 0 = good) |
| [`tools/`](tools/) | signing automation, device control, IPA surgery |
| [`anisette/`](anisette/) | compose file for a self-hosted anisette-v3 server |

The second screen work — turning the same iPad into an extra monitor for the
host — lives in its own repository.

## The short version

- **plumesign** (an Impactor 2.6.3 fork) is the only signer that works.
  AltServer-Linux v0.0.5 is dead: Apple's GSA returns 503.
- Signing needs an **anisette** server. The public ones are rate-limited and
  opaque, so `anisette/` runs [dadoum's anisette-v3-server](https://github.com/Dadoum/anisette-v3-server)
  behind a proxy with a publicly-trusted certificate — plumesign's websocket
  stack uses `rustls` + `webpki-roots` and **ignores the system trust store
  entirely**, so a private CA cannot work.
- A **free Apple ID** gives a 7-day certificate, 3 app slots and 10 App IDs per
  week. App Store apps do not consume a slot.
- Free accounts **cannot register App Groups** (`Developer API error 35`), which
  is why `tools/make-sidestore-freetier.py` exists.
- The jailbreak patches AMFI, so **ad-hoc `ldid` signatures are accepted** on
  device — that is how WebDriverAgent's `.xctest` bundle gets to run.

## Re-signing

The certificate lasts 7 days. One command, unattended, no 2FA once the session
is cached:

```sh
./resign.sh                      # Dopamine
./resign.sh tools/Some.ipa       # anything else
```

## Driving the device

Root SSH, screenshots and full UI automation (tap/type/swipe) over USB —
and, as it turns out, **over Wi-Fi too**: the jailbreak's sshd listens on all
interfaces, so no cable is needed for shell access. See `JAILBREAK-GUIDE.md` §11.

```sh
./tools/ipad-up.sh               # usbmuxd, RSD tunnel, DDI, iproxy, WebDriverAgent
./tools/ipad-ssh.sh 'uname -a'
./tools/ipad-shot.sh out.png
./tools/ipad-ctl.sh tap 500 400
```

## Setup this expects

Credentials live in `~/.secrets` and are passed on **stdin, never argv** —
`/proc/<pid>/cmdline` is world-readable, and an earlier `LD_PRELOAD` shim that
tried to scrub argv did not work.

```sh
APPLE_CREDENTIALS=you@example.com:yourpassword
IPAD_ROOT_PWD=...      # the 'mobile' password Dopamine sets, not root's
SUDO_PWD=...
```

Host-specific values live in `.env` (see `.env.example`) — chiefly `ANISETTE_URL`,
which must be **exactly 25 bytes** because it is patched over a Rust string
literal in the plumesign binary and a literal is a (pointer, length) pair.

Device identity (UDID, serial) lives in `device.env` (see `device.env.example`),
which is **not committed**.
Create your own:

```sh
export IPAD_UDID="$(idevice_id -l | head -1)"
```

## Not included

Third-party binaries are gitignored — they are large and not ours to
redistribute. `JAILBREAK-GUIDE.md` says where each one comes from: Dopamine,
plumesign, ldid, WebDriverAgent.
