# 1. Host setup

[← back to the guide](../README.md)

## Packages

On Void Linux:

```sh
sudo xbps-install -S usbmuxd libimobiledevice ideviceinstaller python3-pipx fuse python3-devel
```

Names differ elsewhere; on Debian/Ubuntu the equivalents are `usbmuxd`,
`libimobiledevice6`, `libimobiledevice-utils`, `ideviceinstaller`, `pipx`.

Two Void-specific notes:

- There is **no** `libimobiledevice-utils` package. The `idevice*` command-line
  tools ship inside `libimobiledevice` itself.
- `python3-devel` is required, not optional: `pipx install pymobiledevice3`
  builds a wheel that needs `Python.h`.

## Start usbmuxd

Nothing Apple-related works until this daemon is running.

```sh
sudo ln -s /etc/sv/usbmuxd /var/service/   # runit; use systemctl elsewhere
sv status usbmuxd                          # expect: run: usbmuxd: (pid ...)
ls -l /var/run/usbmuxd                     # the socket must exist
```

## Make the device visible

1. Plug the device in and unlock it.
2. Accept **Trust This Computer?** and enter the passcode.
3. Check it enumerated:

```sh
idevice_id -l          # prints the UDID
ideviceinfo | head
```

Empty output means usbmuxd is down, the device is locked, or the trust prompt
was not accepted. See [troubleshooting](06-troubleshooting.md).

## pymobiledevice3

Used for pairing, mounting the Developer Disk Image, and installing already-signed
IPAs.

```sh
pipx install pymobiledevice3
pymobiledevice3 lockdown pair
```

Useful later:

```sh
pymobiledevice3 mounter auto-mount            # Developer Disk Image
pymobiledevice3 amfi enable-developer-mode    # headless Developer Mode
pymobiledevice3 apps install Signed.ipa       # already-signed IPAs only
```

On iOS 17.4 and later — which includes 18.x — the RSD tunnel comes up
automatically and without root. Only 17.0–17.3.1 needs
`sudo pymobiledevice3 remote tunneld`.

## Check your work

```sh
./preflight.sh
```

Exit 0 means the host is in a state that can sign. It checks the daemon, the
device, pairing, the anisette server and the signer binary, and tells you which
one is wrong.

---

Next: [2. Signing](02-signing.md)
