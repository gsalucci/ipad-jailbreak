# Jailbreaking an iPad from Linux

Install [Dopamine](https://ellekit.space/dopamine/) on an iPad running iPadOS 18.x
using nothing but a Linux machine — no Mac, no Windows, no AltStore, and no
paid Apple Developer account.

The upstream guide at [ios.cfw.guide](https://ios.cfw.guide/installing-dopamine/)
assumes Windows or macOS. This one covers the Linux path end to end: signing the
IPA with your own Apple ID against a self-hosted anisette server, installing it
over USB, and keeping it alive through the 7-day certificate cycle with a single
command.

Written against an iPad 8 (`iPad11,6`, A12) on iPadOS 18.5 and a Void Linux host,
but nothing here is specific to either beyond package names.

---

## The guide

| | |
|---|---|
| [1. Host setup](docs/01-host-setup.md) | packages, `usbmuxd`, getting the device visible |
| [2. Signing](docs/02-signing.md) | anisette, plumesign, signing the IPA with your Apple ID |
| [3. Jailbreaking](docs/03-jailbreak.md) | trust, Developer Mode, running Dopamine, first packages |
| [4. The 7-day cycle](docs/04-resigning.md) | why it exists and how to automate it away |
| [5. Controlling the device](docs/05-device-control.md) | SSH, screenshots, UI automation |
| [6. Troubleshooting](docs/06-troubleshooting.md) | when something goes wrong |
| [Background](docs/background.md) | why TrollStore, AltStore and "untethered" do not apply |

---

## What you end up with

```sh
./preflight.sh        # is the host able to sign? (exit 0 = yes)
./resign.sh           # re-sign Dopamine before the certificate expires
./resign.sh some.ipa  # ...or anything else
```

Plus root SSH to the device over USB *and* Wi-Fi, screenshots, and scripted
taps and typing — see [5. Controlling the device](docs/05-device-control.md).

---

## Requirements

**Host**

- Linux with `usbmuxd`, `libimobiledevice`, Python 3.9+
- Docker or Podman, for the anisette server
- A domain name with a publicly trusted TLS certificate for that server —
  [why](docs/02-signing.md#why-the-certificate-must-be-publicly-trusted)

**Device**

- A jailbreakable iPad or iPhone. Dopamine covers **A8–A13 on iOS/iPadOS
  15.0–18.7.1**, and A14+ only up to 17.3.1. Check your model identifier against
  the right table — `iPad11,1`/`iPad11,2` are the iPad mini 5, while the iPad 8
  is `iPad11,6`.

**Apple ID**

- A free one works. It gives a 7-day certificate, 3 active app slots and 10 new
  App IDs per week. Consider using a throwaway account: every re-sign is another
  sign-in, and the account can get locked.

---

## What this is not

Dopamine is **semi-untethered**: after every reboot you re-open the app and tap
Jailbreak. That is a property of the exploit, not a limitation of this setup, and
no signing trick avoids it. The 7-day cycle is a separate thing and *is*
automated here.

There is no untethered jailbreak for A12+ on iOS 18, and repositories claiming
otherwise are hostile — see [Background](docs/background.md#no-untethered-jailbreak-exists).

---

## Layout

```
preflight.sh     check the host can sign
resign.sh        one-command re-sign
tools/           signing automation, device control, IPA surgery
anisette/        compose file for the anisette server
docs/            the guide
```

Third-party binaries (the Dopamine IPA, plumesign, ldid) are not committed. Each
document says where to get the one it needs.
