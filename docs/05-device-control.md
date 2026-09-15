# 5. Controlling the device

[← back to the guide](../README.md)

Four independent channels: a shell, screenshots, UI automation, and installs.

```sh
./tools/ipad-up.sh             # bring everything up; idempotent
./tools/ipad-up.sh --status    # inspect without changing anything
```

| Channel | Command | Needs |
|---|---|---|
| Shell | `./tools/ipad-ssh.sh [--root] '<cmd>'` | `openssh-server` from Sileo, key installed |
| Screenshot | `./tools/ipad-shot.sh [out.png]` | RSD tunnel |
| Tap / swipe / type | `./tools/ipad-ctl.sh …` | RSD tunnel, DDI, WebDriverAgent, UI Automation |
| Install | `./resign.sh [ipa]` | cached Apple session |

## Host side

Lost on every reboot of the host; `ipad-up.sh` does all of it:

```sh
sudo pymobiledevice3 remote tunneld &     # only needed on iOS 17.0-17.3.1
pymobiledevice3 mounter auto-mount        # Developer Disk Image
iproxy 2222 22 &                          # SSH over USB
```

## Device side, once

- **Settings → Developer → Enable UI Automation.** Without it XCUITest starts and
  then dies about 60 seconds later with `initializationForUITestingDidFailWithError`.
- **openssh-server** from Sileo.

## SSH works over Wi-Fi

`usbmuxd` has no Wi-Fi support on Linux, which is why the tooling here forwards
port 22 over USB. That limitation belongs to usbmuxd, not to the device: the
jailbreak's sshd listens on **every** interface.

```sh
ssh -i ~/.ssh/id_ed25519_ipad mobile@<ipad-ip>
```

No cable needed for shell access. WebDriverAgent still needs USB to *start*,
though once running it listens on port 8100 on all interfaces too.

## Three traps

**The password Dopamine sets is `mobile`'s, not root's.** Its settings call it
*"Change 'mobile' password"*. `ssh root@...` answers `UNIX authentication refused`
no matter how correct the password is. Use `mobile`, and `sudo` from there.

**On a rootless jailbreak `$HOME` is `/var/jb/var/mobile`.** Installing an
`authorized_keys` into `/var/mobile/.ssh` succeeds, changes nothing, and leaves
public-key auth failing with no useful error.

**plumesign does not sign nested `.xctest` bundles.** WebDriverAgent's test bundle
arrives unsigned and `dlopen` refuses it:

```
mapped file has no cdhash, completely unsigned? Code has to be at least ad-hoc signed.
```

`tools/make-wda-ipa.py` ad-hoc signs it with `ldid` — and `WebDriverAgentLib.framework`,
which fails next — before packaging. Ad-hoc is enough only because the jailbreak
patches AMFI; on a stock device this needs a real signature covering the plugin.

## WebDriverAgent selectors

`wda tap` defaults to the accessibility-id strategy. `label` is **not** a valid
locator and returns `Invalid locator requested: label`. Dump the tree first:

```sh
./tools/ipad-ctl.sh items
```

Multi-line labels must be passed verbatim, newline included. Selectors are in
whatever language the device UI is set to.

## After a device reboot

The jailbreak is gone until Dopamine is opened and **Jailbreak** tapped. Until
then `/var/jb` does not exist, so **sshd is gone with it** and `ipad-up.sh`
reports the device unreachable. The Developer Disk Image also needs re-mounting.

Screenshots and app installs still work on an unjailbroken device. Shell and
tweaks do not.

---

Next: [6. Troubleshooting](06-troubleshooting.md)
