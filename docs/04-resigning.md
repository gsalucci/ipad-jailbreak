# 4. The 7-day cycle

[← back to the guide](../README.md)

A free Apple ID issues certificates that last **7 days**. When one expires the
app icon dims and will not launch, and the jailbreak goes with it.

This is a property of the free tier, not of any particular tool. Nothing avoids
it except a paid Apple Developer account, which issues 1-year certificates for
$99/yr. If your time is worth more than that, buying out is the rational answer.

Note this is *separate* from re-running Dopamine after a reboot. Two different
clocks:

| Action | When | Automatable |
|---|---|---|
| Re-run Dopamine | after each reboot | No — needs the app's own UI |
| Re-sign the app | every 7 days | **Yes** |

## The one command

```sh
./resign.sh
```

It signs and installs Dopamine, and it is unattended once the Apple ID session is
cached — no 2FA prompt on a normal run.

Before signing it verifies that `usbmuxd` is up, the device is attached and
paired, the anisette server answers with HTTP 200, and a cached account exists.
It then confirms the install by bundle identifier, so it cannot report success
for an IPA it did not actually install.

Any other IPA:

```sh
./resign.sh tools/WebDriverAgent.ipa
```

Remember the free tier allows **3 active apps**. Dopamine and WebDriverAgent are
two of them.

## Scheduling it

The device must be plugged in when it fires: `usbmuxd` has **no Wi-Fi support**
on Linux, so everything rides the cable.

```sh
0 9 * * 1  cd /path/to/repo && ./resign.sh >> /tmp/resign.log 2>&1
```

Run it well before expiry. Once the certificate lapses the app will not launch,
and if you also reboot in the meantime you are back to doing it by hand.

## On-device refresh

SideStore can refresh apps from the device itself, triggered by a Shortcuts
automation, with no computer involved. It is a real option but a best-effort one:
iOS throttles background execution, it needs an always-on local VPN and a pairing
file, and SideStore's own issue tracker has a long history of refreshes silently
not firing.

It also fails exactly when it matters — once the certificate expires, the app
that was supposed to renew it will not launch either.

If the device sits next to the machine anyway, the cable is deterministic and
this is not worth the moving parts.

---

Next: [5. Controlling the device](05-device-control.md)
