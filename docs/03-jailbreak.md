# 3. Jailbreaking

[← back to the guide](../README.md)

Everything here happens on the device. Once Dopamine is installed, the computer
is not needed again until the certificate expires.

## Trust the certificate

**Settings → General → VPN & Device Management → your Apple Account → Trust**

The Dopamine icon becomes launchable.

## Enable Developer Mode

Required on iOS/iPadOS 16 and later.

**Settings → Privacy & Security → Developer Mode → on**

The device reboots.

If the toggle is missing, the device has never had a developer-signed app
installed. Install one first — the order matters — or set it headlessly:

```sh
pymobiledevice3 amfi enable-developer-mode
```

That fails with `Cannot enable developer-mode when passcode is set`; in that
case use the Settings toggle.

## Run Dopamine

1. Reboot the device.
2. Open Dopamine immediately afterwards.
3. Tap **Jailbreak**.

On A12 and A13 devices running 16.6+, **the screen briefly turns off and on**
during the exploit. That is normal — one of the stages requires it. Do not touch
the device.

If Dopamine asks for a respring first, let it, then start again from step 2.

If it crashes or the device restarts without jailbreaking, reboot and run it
again. The exploit is not deterministic and sometimes needs a few attempts.

**You are done when Sileo appears on the home screen.**

## First packages

In Sileo:

1. **Sources** → the ElleKit repository → **All Categories** → **ElleKit** → **Get**
2. **Search** → **PreferenceLoader** → **Get**
3. Tap the **Queued** bar → **Confirm**
4. **Reboot Device** when it finishes

ElleKit takes a while on `Processing triggers for org.coolstar.sileo` — let it.

That **Reboot Device** button performs a *userspace* reboot, so you stay
jailbroken. That is intended.

To install anything else: Sileo → search → **Get** → **Queued** → **Confirm** →
**Respring**. To add a repository: **Sources** → **+** → paste the URL.

## After a real reboot

The jailbreak does not survive a full power cycle. Open Dopamine and tap
**Jailbreak** again. Nothing needs re-signing — that is a separate 7-day clock.

## Optional: SSH

Install `openssh-server` from Sileo if you want shell access. See
[5. Controlling the device](05-device-control.md), which covers the two traps:
Dopamine sets the **`mobile`** password rather than root's, and on a rootless
jailbreak `mobile`'s home is `/var/jb/var/mobile`, not `/var/mobile`.

---

Next: [4. The 7-day cycle](04-resigning.md)
