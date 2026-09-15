# 6. Troubleshooting

[← back to the guide](../README.md)

## Host

**Device invisible / `idevice_id -l` prints nothing**

```sh
sv status usbmuxd && sv up usbmuxd    # runit
ls -l /var/run/usbmuxd
```

Then unlock the device and accept the trust prompt. Plug the device in *before*
launching a signer — on some setups udev restarts usbmuxd on hotplug.

**`Could not connect to lockdownd`** — not paired, locked, or usbmuxd is down.

```sh
pymobiledevice3 lockdown pair
```

**Developer Mode toggle missing** — the device has never had a developer-signed
app installed. Install one first, then look again.

**`Cannot enable developer-mode when passcode is set`** — use the Settings
toggle instead of the headless command.

**RSD tunnel unreachable from a container or VM** — tunnel addresses do not cross
network namespaces. Use `--tunnel UDID@HOST:PORT`, or run the tools on the host
with USB passthrough.

## Signing

**`UnknownIssuer` or `CaUsedAsEndEntity` from the anisette server** — plumesign
uses rustls with `webpki-roots` and ignores the system trust store. Your CA being
correctly installed makes no difference. You need a publicly trusted certificate.
See [why](02-signing.md#why-the-certificate-must-be-publicly-trusted).

**`URL scheme not supported`** — plumesign rewrites `https://` to `wss://` for the
provisioning WebSocket but passes `http://` through unchanged. Use `https://`.

**`invalid type: integer 404, expected struct AnisetteClientInfo`** — the patched
URL has a trailing slash, producing `//v3/client_info`. Remove it.

**`Developer API error 35`** — the IPA declares App Groups and your account is
free. Strip them:

```sh
python3 tools/make-sidestore-freetier.py in.ipa out.ipa
```

**`Device ID <udid> not found`** — plumesign matches usbmux's `UDID` field, but
some usbmuxd builds advertise `SerialNumber`. Omit the device argument and let it
autodetect.

**503 from Apple during sign-in** — Apple's interactive sign-in throttles. The
developer API itself stays healthy, so an already-cached session keeps working.
Wait, or use a cached session.

**Apple ID locked (`SRP -20209`)** — unlock at [iforgot.apple.com](https://iforgot.apple.com).
Expect `-22406` afterwards, which means the password was invalidated by the
unlock: set a new one and update `~/.secrets`. Shared anisette servers are a
documented cause of lockouts; self-hosting reduces the risk.

**2FA code never accepted** — the code is consumed through a pseudo-terminal. Do
not try to write it to the process's `/proc/<pid>/fd/*`: re-opening `/dev/ptmx`
creates a *new* pty rather than writing to the existing one. Use the file the
script names.

**`afc error: Permission denied` during install** — use
`pymobiledevice3 apps install` for that step instead.

## Device

**Respring loop** — force reboot, re-jailbreak with tweak injection disabled,
remove the most recently installed tweak.

**Bootloop** — an Apple logo that survives a force reboot needs a DFU restore.
On a device with no Home button: hold **Side + Volume Down** for 8 seconds,
release **Side**, keep holding **Volume Down**.

**Dopamine fails with `Spawning jbctl failed with error code 85`** — likely the
entitlements stripped during re-signing. A paid Apple Developer account is the
fix; see [2. Signing](02-signing.md#what-re-signing-changes).

**App icon dimmed, will not launch** — the certificate expired. Re-sign:
`./resign.sh`.

---

[Background](background.md) · [back to the guide](../README.md)
