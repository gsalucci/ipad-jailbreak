# iPad 8 Jailbreak Runbook — Dopamine on iPadOS 18.5, driven from Void Linux (x570)

Adapted from <https://ios.cfw.guide/installing-dopamine/> for the actual hardware on both ends.
The upstream guide assumes Windows/macOS + AltStore/Sideloadly. **Both assumptions are stale**: the
guide now uses **Impactor** (ex-*PlumeImpactor*), and it ships a first-class Linux build.

---

## 0. Facts this runbook is built on

### Target device — **verified by connection, not assumed**

First attached 2026-09-14, read with `ideviceinfo` / `pymobiledevice3 usbmux list`:

| Field | Observed value |
|---|---|
| ProductType | **`iPad11,6`** |
| ProductVersion / Build | **18.5 / 22F76** |
| CPUArchitecture | **arm64e** |
| Model number | `MYL92` (region `TY/A` — Italy) |
| Device name | `<device name>` |
| UniqueDeviceID | see `device.env` (kept out of this file) |
| Paired | ✅ `SUCCESS: Validated pairing` |

**Identifier correction — an easy, dangerous mix-up:** the earlier draft of this runbook said the iPad 8
was `iPad11,1`/`iPad11,2`. **That is wrong.** Confirmed against AppleDB, EveryMac, TheAppleWiki and the
IPSWDL spec sheets:

| Identifier | Actual device | SoC |
|---|---|---|
| `iPad11,1` / `iPad11,2` | **iPad mini 5** | A12 |
| `iPad11,3` / `iPad11,4` | iPad Air 3 | A12 |
| **`iPad11,6`** | **iPad 8th gen, WiFi (A2270)** ← *this device* | A12 |
| `iPad11,7` | iPad 8th gen, WiFi+Cellular (A2428/A2429/A2430) | A12 |

All of A12s above are within Dopamine's A8–A13 support window, so the mix-up was not fatal here — but
checking the model string against the *right* table is what caught it. The device reports `arm64e`,
confirming the A12 Bionic.

| | |
|---|---|
| Model | iPad 8th generation (2020) — A12 Bionic, **`iPad11,6`**, **arm64e** |
| OS | iPadOS **18.5** (build 22F76) |
| RAM | 3 GB |
| Jailbreak | **Dopamine** — *semi-untethered*: the app must be re-run after every reboot |
| Support | Dopamine supports A8–A13 on iOS/iPadOS **15.0 – 18.7.1** (A14+ only ≤ 17.3.1) → **in scope** ✅ |
| Not the shipped OS | iPad 8 shipped with iPadOS 14.x → the guide's "preinstalled firmware" DANGER does **not** apply ✅ |

### Is there an untethered jailbreak? **No.** — settled, stop looking

| Concept | Meaning | Status for this device |
|---|---|---|
| **Untethered** | Survives reboot with nothing to do | ❌ **impossible** — see below |
| **Semi-untethered** | After a reboot, re-tap the app; **no computer needed** | ✅ this is what Dopamine is |
| **7-day re-sign** | Certificate expiry — *separate* from tetheredness | ⚠️ mandatory on a free Apple ID |

There are exactly two routes to reboot-persistence, and **both are closed for A12**:

1. **Bootrom exploit** (unpatchable, permanent). The only public one is **checkm8**, which covers
   **A5–A11**. This device is **A12** → not applicable. No public A12/A13 bootrom exploit exists.
2. **Code-signing bypass** to keep the jailbreak app installed across reboots — TrollStore's route.
   TrollStore caps at **iOS 17.0**; upstream states 16.7.x (non-RC) and 17.0.1+ **"will NEVER be
   supported"**.

So "untethered" is not something to wait for — it needs a new bug class. The only escape from the
7-day cycle is a **paid Apple Developer account** ($99/yr → 1-year certificates). See §7.

> **SECURITY — do not install "untethered iOS 18 jailbreaks".**
> Searching for this turns up several repos claiming exactly that. **They are fake or malicious.**
> Verified as false: `FuguJailbreak/Fugu18-Jailbreak`, which claims a "fully-untethered permasigned"
> jailbreak for iOS 18.x. Its exploit sources (`oobPCI.c`, `badRecovery.c`, `tlbFail.c`, `xprr.h`) are
> **verbatim copies from Fugu15** — an exploit that only ever worked on **iOS 15.0–15.4.1**. Its
> "download" link points at a monetised blog, not a project site, and its README contradicts itself
> (title says 18.0–18.3, tested-devices list says 18.4.1). A working code-signing bypass on 18.x would
> also contradict TrollStore's own stated position.
> Other repos in the same family — `DSPloit`, `usbliter8ra1n`, `4pple-pls-ser0tonin` — exhibit the same
> pattern. **Treat every "untethered iOS 18 jailbreak" result as hostile until proven otherwise.**

### Host machine (`x570`)
| | |
|---|---|
| OS | Void Linux **glibc** x86_64, **runit** (no systemd), **xbps**, kernel `7.2.2-znver2_1` |
| Hardware | Ryzen 9 3900X, 62 GiB RAM, RTX 2080 SUPER + RTX 3060 |
| User | unprivileged user in `wheel` (both `doas` and `sudo` configured) |
| Python | 3.14.6 via `uv`; `python3-pipx` in repos |
| **Currently installed** | **nothing Apple-related** — no `usbmuxd`, no `libimobiledevice`, no `pymobiledevice3` |

### Pre-flight DANGERs from the guide
- If the device currently runs **rootful palera1n** → remove it first.
- If it currently has **nathanlr / Relaxin / Serotonin / Bootstrap** → remove fully first. (If you don't
  recognise those names, ignore.)
- iCloud **Find My** is *not* mentioned in the standard Dopamine guide — that requirement belongs to the
  TrollStore/TrollRestore path, which does not apply here.

---

## 1. Choose the path

```
Is jailbreaks.app currently serving a signed Dopamine build for iPadOS 18.5?
│
├─ YES → Path A: install straight from Safari on the iPad. No computer, no Apple ID, no Developer Mode.
│         Fastest. Downside: signing is transient — expect to fall back to Path B eventually.
│
└─ NO  → Path B: Impactor on x570 (Linux AppImage). Durable, official, repeatable every 7 days.
```

> Path A note: the guide explicitly says Developer Mode is only required *"if you did not use
> jailbreaks.app"*. So Path A genuinely skips §4.
> Path A caveat: the signing is not under your control, and it rides an abused enterprise
> certificate. Read the certificate warning below before installing.

### Path A — WAS AVAILABLE, NOW REVOKED (checked from x570, 2026-09-14)

> ### ⛔ STATUS 2026-09-14: THE CERTIFICATE IS REVOKED — PATH A DOES NOT WORK
>
> An OCSP query against the leaf certificate's own AIA responder
> (`http://ocsp.apple.com/ocsp03-wwdrg301`) for
> `UID=<team-id>, CN=iPhone Distribution: <org>` (serial
> `<serial>`) returns:
>
> ```
> Cert Status:       revoked
> Revocation Time:   Aug 25 04:12:00 2026 GMT
> Revocation Reason: certificateHold (0x6)
> ```
>
> **`certificateHold` is a temporary suspension, not a permanent revocation** — Apple can lift it, but
> in practice these stay held forever. `certificateHold` is precisely the state Apple applies to abused
> enterprise certificates.
>
> Reproduced end-to-end on-device the same day: the manifest loads, iTunes.app offers the install, the
> home-screen icon appears, and then tapping it fails with **"App not downloaded — unable to verify
> authenticity"**. Retrying cannot work: re-checked on 2026-09-14, jailbreaks.app is still serving the
> **same IPA** (sha256 `c794f37107bc2ae7b9c4a5a849e3da040fc43ccc2f1d5a9b7e4baa35715b19e6`, unchanged) signed
> with that same revoked certificate. The site has not re-signed since **2026-08-25**.
>
> **Consequence: Path A is dead. Path B or Path C is the only route.**


jailbreaks.app is serving **Dopamine v3.0.9** (`apps.json` description: *"iOS 15.0 – 18.7.1 /
26.0 – 26.0.1 (A8-A13)"*), which covers this device (`iPad11,6` / A12 / iPadOS 18.5). The
JS-gating that made this unverifiable from Linux is bypassable — the site's popup calls
`api.jailbreaks.app/install/<app>/<version>`, and that backend is plain HTTP.

#### The link to use

```
https://api.jailbreaks.app/install/Dopamine
```

**Not** the homepage button, and **not** the versioned form. Verified 2026-09-14:

| URL | Result |
|---|---|
| `api.jailbreaks.app/install/Dopamine` | **302** → `itms-services://?action=download-manifest&url=https://jailbreaks.app/cdn/plists/Dopamine.plist` |
| `api.jailbreaks.app/install/Dopamine/v3.0.9` | 302 → `.../Dopamine309.plist` → **HTTP 404** (dead) |

#### What is actually served

| | |
|---|---|
| Manifest | `https://jailbreaks.app/cdn/plists/Dopamine.plist` (1082 B, XML plist, HTTP 200) |
| Package | `https://jailbreaks.app/cdn/ipas/Dopamine-resigned.ipa` |
| Size / sha256 | 55,560,622 B / `c794f37107bc2ae7b9c4a5a849e3da040fc43ccc2f1d5a9b7e4baa35715b19e6` |
| Bundle | `com.44802.91614`, display name "Dopamine - jailbreaks.app" (renamed from `com.opa334.Dopamine`) |
| `CFBundleShortVersionString` | **3.0.9** |

#### Integrity audit — the code is genuine upstream

Full-IPA comparison against upstream 3.0.9 (`tools/Dopamine.ipa`, sha256
`ad0c4ea182b232346470df10439cfa2c1b7952e6b586113edfbc2720e455b201`): **96 files upstream vs 97
resigned; 70 byte-identical.** In every one of the 14 differing Mach-O slices — main binary,
`libjailbreak.dylib`, `libxpf.dylib`, `libchoma.dylib`, `kfd`, `Titan`, `ClearSword`, `DarkSword`,
`badRecovery`, `dmaFail`, `momentarius`, `multicast_bytecopy`, `weightBufs`, both fat slices each —
**only 5—8 bytes differ, all inside load commands**: `LC_SEGMENT_64` (__LINKEDIT size) and
`LC_CODE_SIGNATURE` (signature size). `Info.plist` differs in 3 keys (bundle ID + name). Everything
else is `_CodeSignature/CodeResources`, the added `embedded.mobileprovision`, and the signature blobs.

> **Conclusion: no executable byte was modified.** It is upstream Dopamine, re-signed and renamed.

#### The signature — read this before installing

| Field | Value |
|---|---|
| `TeamName` | **<org>** |
| `Name` | `<reverse.dns.bundle.id> InHouse` |
| Team prefix | `<team-id>` (also the profile's `application-identifier` prefix) |
| `ExpirationDate` | **2027-05-04** |
| `ProvisionsAllDevices` | `True` |

An **enterprise / in-house certificate belonging to a bank, used without authorisation** — not a
jailbreaks.app certificate. Consequences:

- Installing requires **Settings → General → VPN & Device Management → trust the enterprise developer**,
  i.e. granting that corporate certificate permission to run code on the device.
- Apple revokes abused enterprise certs on sight, at an unpredictable time. On revocation the app stops
  launching — **"Unable to Verify App"** — and nothing on the device can fix it.
- The 7-day clock does **not** apply to this install (the profile nominally runs to 2027-05-04). The real
  risk is revocation, not expiry.
- Dopamine's own entitlements are gone (the binary carries the host app's instead). This is **normal for
  any re-sign** and not specific to jailbreaks.app — the jailbreak gets its privilege from the kernel
  exploit, not from the app's entitlements.

#### Install sequence

1. Safari → `https://api.jailbreaks.app/install/Dopamine` → tap **Install** when the
   "Install 'Dopamine - jailbreaks.app'" prompt appears.
2. Wait for the ~55 MB download; a greyed-out icon appears on the home screen.
3. Tap the greyed icon → *"Untrusted Enterprise Developer"* → Cancel.
4. **Settings → General → VPN & Device Management → the enterprise developer → Trust → Trust.**
5. Tap **Dopamine**. It opens. **Developer Mode is not required** on this path.
6. Tap **Jailbreak**. On A12 at 16.6+ the screen **flickers** — that is the exploit, not a fault.
7. Respring. **Sileo** appears. Install **ElleKit** + **PreferenceLoader**.

> Path A is a **transient** foothold. Build the Path B signature **before** you need it — if the cert
> is ever revoked, Path A is gone and a reboot leaves the device un-jailbreakable until Path B exists.

### ⚠️ Decide the installer **before** you install — this cannot be cleanly reversed

There are **three** viable architectures, and they diverge at *installation* time:

| | Installer | The 7-day re-sign happens… | Needs |
|---|---|---|---|
| **A** | jailbreaks.app (Safari, on the iPad) | wherever the signature comes from — not under your control | iPad only (**verified available**, §1) |
| **B** | Impactor on x570 | re-run Impactor, **USB attached** | iPad + cable |
| **C** | **SideStore first**, then install Dopamine *through* SideStore | **on the iPad**, triggered by a Shortcuts automation | one-time computer step |

**Why this matters:** the Shortcuts/SideStore automation in §7 only refreshes apps **SideStore knows
about**. If Dopamine arrives via Impactor or jailbreaks.app, SideStore is not in the loop and a
Shortcut that refreshes SideStore will do **nothing** for Dopamine's certificate. That is a day-one
architecture decision, not a bolt-on.

§7 compares all three against the plain "pay $99/yr and stop thinking about it" option, with the
reliability caveats stated bluntly.

---

Both paths diverge only for *installation*. From §5 (running Dopamine) onward they are identical.

---

## 2. What does **not** apply (do not waste time)

| Method | Verdict for iPadOS 18.5 |
|---|---|
| **TrollStore** | ❌ Dead. The CoreTrust/AMFI bug was fixed in 16.7/17.0.1. Max is iOS 17.0; upstream states 16.7.x (non-RC) and 17.0.1+ **"will NEVER be supported"**. The SparseRestore 3-app bypass also stops at 18.0.1. Consequence: **no permanent signing of Dopamine on 18.5** — you live with the 7-day cycle. |
| **Installing Dopamine (TrollStore)** sub-guide | ❌ N/A — its own page says 17.0.1–18.7.1 users should follow the standard guide instead. |
| **AltStore / AltServer-Linux** | ❌ Do not use. `NyaMisty/AltServer-Linux` last release is **v0.0.5 (Apr 2022)**. (That `anisette-v3-server` is *compatible* with AltServer-Linux, per §7.2, is not an endorsement of AltServer-Linux itself.) |
| **Sideloadly** | ❌ No Linux distribution exists (macOS/Windows only). |
| **ideviceinstaller alone** | ⚠️ Installer only, **not a signer**. Can push an *already-signed* IPA. Useful as a fallback/second-opinion. |
| **Permasign / TrollStore persistence** | ❌ Unavailable on 18.5 (max iOS 17.0) — see the TrollStore row above. |
| **"Untethered iOS 18" jailbreaks** | ❌ **Fake/malicious.** See the §0 security note before touching any of them. |

---

## 3. Path B — Impactor on x570 (the validated Linux path)

Impactor is the exact tool the official guide uses. It is open-source (Rust), actively maintained
(v2.6.3 released 2026-09), and publishes `Impactor-linux-x86_64.appimage` + a Flathub package.

> Repo name: the project moved from `khcrysalis/PlumeImpactor` to **`claration/Impactor`** (same project,
> renamed). Both paths redirect to the same releases.

### 3.1 Install the prerequisite stack

```bash
sudo xbps-install -Syu
sudo xbps-install -S usbmuxd libimobiledevice ideviceinstaller python3-pipx fuse
sudo ln -s /etc/sv/usbmuxd /var/service/     # Void's usbmuxd package ships a runit service
sv status usbmuxd                            # expect: "run: usbmuxd: (pid …)"
ls -l /var/run/usbmuxd                       # socket must exist
```

> **Void package names verified against the live remote repo** (do not substitute an
> `libimobiledevice-utils` package — it does not exist on Void; the `idevice*` CLI tools are shipped
> *inside* `libimobiledevice`): `usbmuxd-1.1.1_1`, `libimobiledevice-1.3.0_8` (provides
> `/usr/bin/idevice_id`, `idevicepair`, `ideviceinfo`, …), `ideviceinstaller-1.1.1_1`,
> `python3-pipx-1.15.0_1`, `fuse-2.9.9_1` (provides `/usr/lib/libfuse.so.2`, which AppImages need),
> `flatpak-1.18.2_1`. The runit service lives at `/etc/sv/usbmuxd/run`.

**Checkpoint:** `sv status usbmuxd` says `run`. Nothing Apple-related will work until it does.

### 3.2 Get the iPad visible

1. Plug the iPad in. Unlock it. Accept the **"Trust This Computer?"** prompt, enter the passcode.
2. Verify enumeration:
   ```bash
   idevice_id -l                      # expect the UDID
   pymobiledevice3 usbmux list        # richer view (after §3.3 pipx install)
   ```
   If empty → see §7 *usbmuxd not running* / *device not detected*.

### 3.3 (Optional but recommended) pymobiledevice3 for headless operations

```bash
pipx install pymobiledevice3
pymobiledevice3 lockdown pair                # accepts the pairing prompt on the iPad
```

Useful helpers:
```bash
pymobiledevice3 mounter auto-mount           # mount Developer Disk Image (auto-download)
pymobiledevice3 amfi enable-developer-mode   # headless Developer Mode enable + reboot
pymobiledevice3 apps install Signed.ipa      # installs ALREADY-SIGNED ipas only
```
**iOS 17.4+ (i.e. 18.5) on Linux:** the RSD tunnel is brought up **automatically and without root**.
Only iOS 17.0–17.3.1 needs `sudo pymobiledevice3 remote tunneld`. Plain app install needs no tunnel at all.

### 3.4 Run Impactor

```bash
curl -LO https://github.com/claration/Impactor/releases/latest/download/Impactor-linux-x86_64.appimage
chmod +x Impactor-linux-x86_64.appimage
./Impactor-linux-x86_64.appimage
# If FUSE is unavailable:
./Impactor-linux-x86_64.appimage --appimage-extract-and-run
# Or, avoiding AppImages entirely:
flatpak install flathub dev.khcrysalis.PlumeImpactor
```

Then, following the upstream steps verbatim:

1. Plug the iPad into x570 ← **do this before launching Impactor** (a known Linux udev-timing quirk).
2. Confirm the computer is trusted and can view device contents.
3. Open Impactor.
4. `Settings` → `Sign In`.
5. Enter your **Apple ID / Apple Account + password**.
6. Close the Settings and Sign In windows.
7. **Drag and drop the Dopamine `.ipa` into Impactor.**
8. Click `Install`.
9. The app installs to the iPad.

Dopamine IPA: <https://ellekit.space/dopamine/> or the GitHub releases page.

> **Already staged on x570** at `tools/Dopamine.ipa` — Dopamine **3.0.9** (52.84 MB),
> sha256 `ad0c4ea182b232346470df10439cfa2c1b7952e6b586113edfbc2720e455b201`, verified
> `com.opa334.Dopamine` / `MinimumOSVersion 15.0` / no `UISupportedDevices` restriction.
> Drag that file into Impactor — no need to re-download.

> **Once Dopamine is installed, the computer is no longer needed for the rest of the guide.**

---

### 3.5 Signing with your own Apple ID — read this before re-signing

The upstream IPA is **ad-hoc signed**: `tools/Dopamine.ipa` contains **no `embedded.mobileprovision`** at
all (verified — that file is not in the archive). It is therefore **not installable on a stock device as
shipped**; anything that puts it on the iPad must first apply a real signature. That is exactly what
jailbreaks.app existed to do: take the *same code* and re-sign it with an enterprise certificate
(§1).

What the ad-hoc signature *claims* in its entitlements blob (`CS_ENTITLEMENTS`, slot type `0x5`):

| Entitlement | Note |
|---|---|
| `platform-application` | platform entitlement |
| `com.apple.private.security.no-sandbox` | unsandboxed |
| `com.apple.private.mobileinstall.allowedSPI` | Install / Uninstall / UpdatePlaceholderMetadata |
| `com.apple.private.persona-mgmt` | |
| `com.apple.private.tcc.allow` | `kTCCServiceSystemPolicyAllFiles` |
| `com.apple.private.security.storage-exempt.heritable`, `...storage.AppBundles` | |
| `com.apple.springboard.CFUserNotification`, `...launchapplications` | |
| `com.apple.security.network.client` | ordinary |
| `com.apple.security.exception.iokit-user-client-class` | AGX / IOSurface / H11ANE / IOMobileFramebuffer |
| `com.apple.developer.kernel.extended-virtual-addressing`, `...increased-memory-limit` | ordinary-ish |

**No provisioning profile issued to a normal developer — free or paid — grants
`platform-application` or `com.apple.private.*`.** When any sideloading tool re-signs this IPA it replaces
that blob with whatever the profile actually allows.

The jailbreak itself comes from the kernel exploit, not from these entitlements, so a stripped signature is
*not* automatically fatal. But the following are on record upstream and must be treated as live risks until
tested on this device:

- `opa334/Dopamine#792` — *"Spawning jbctl failed with error code 85"* when Dopamine 2.5b2 was installed
  via SideStore, with the reporter explicitly noting **the same IPA worked with a non-SideStore
  certificate** and attributing it to *"signing entitlements or how SideStore signs the app"*.
- `SideStore/SideStore#1333` — *"[BUG] Dopamine installed via SideStore is not functioning correctly"*.

> **Verification plan:** sign `tools/Dopamine.ipa` with our own Apple ID (§3.6) and launch it. If
> Dopamine reports the device/bootchain unsupported, or the jailbreak dies spawning `jbctl`, the cause is
> most likely the stripped entitlements, and the answers are a **paid** Apple Developer account (whose
> profiles carry more) or a fresh enterprise-signed mirror. This is an **empirical** question — it costs
> one USB session to answer.

### 3.6 Free-tier limits that now apply

Once the app is signed by *your* Apple ID instead of a bank's:

| | Free Apple ID | Paid Developer Program ($99/yr) |
|---|---|---|
| Certificate life | **7 days** | 1 year |
| Active apps | 3 | effectively unlimited |
| New App IDs | 10 / week | unlimited |
| Developer Mode | **required** (iOS 16+) | required |
| Reboot re-tap | still required | still required |

## 4. Trust the app + enable Developer Mode (on the iPad)

**Only if you did NOT use Path A (jailbreaks.app).**

1. `Settings` → `General` → `Device Management` → *your Apple Account*
   *(on some versions labelled `Profiles and Device Management`)*
2. Tap **`Trust "<Your Apple Account>"`**.
3. The Dopamine icon is now launchable.

Then, **required on iOS/iPadOS 16.0+** — which includes 18.5:

4. `Settings` → `Privacy & Security` → scroll → **`Developer Mode`** → toggle **on** → follow the
   on-screen instructions (this triggers a reboot).

If the `Developer Mode` toggle is missing entirely: make sure a developer-signed app install was
actually attempted, or set it headlessly with
`pymobiledevice3 amfi enable-developer-mode` (§3.3) and reboot.

---

## 5. Run Dopamine (on the iPad)

> **TIP for this exact device:** A12(X/Z) and A13 devices on 16.6+ will see the **screen briefly turn
> off and on** during the jailbreak. This is **perfectly normal** — one of the exploits requires it.
> Do not panic, do not touch the device.

1. **Reboot the iPad.** Not strictly necessary, but recommended by the guide.
2. Open the Dopamine app **immediately afterwards**.
3. Tap **`Jailbreak`**.

If Dopamine says it needs a **respring** first, let it — then redo steps 2–3.
(The guide scopes that pre-respring requirement to 2 GB-RAM devices; the iPad 8 has 3 GB, so you
probably won't see it. The app tells you if you will.)

Expected complications, all documented:
- **Crash / unexpected restart / jailbreak not installed** → reboot and re-run the exploit until it takes.
- **Replacement screen?** Touch may die after the userspace reboot into a jailbroken state. Not a
  Dopamine bug.

**Success criteria:** **Sileo** appears on the home screen.

---

## 6. Post-jailbreak: bootstrap packages (on the iPad)

1. Open **Sileo**.
2. **`Sources`** tab.
3. Tap the **ElleKit** repository → **`All Categories`**.
4. Tap **ElleKit** → **`Get`**.
5. **`Search`** tab → search **PreferenceLoader**.
6. Tap **PreferenceLoader** → **`Get`**.
7. Tap the **`Queued`** bar at the bottom.
8. Tap **`Confirm`**.
9. When finished, tap **`Reboot Device`**.

> **The `Reboot Device` button here does NOT fully reboot the device.** It is a *userspace* reboot, so
> you remain in the jailbroken state. This is intended.

### Next Steps on 18.5
The guide's firmware tab covering **17.0.1–18.7.1** (yours) says:

> **"There are no additional steps that can be completed on your current firmware version."**

So the TrollStore-persistence section (TrollStore Helper → TrollHelper → Persistence Helper →
permanently sign Dopamine) **is unavailable on iPadOS 18.5**. It only applies to 15.0–16.6.1,
16.7 RC, and 17.0.

To install tweaks: Sileo → search → `Get` → `Queued` bar → `Confirm` → `Respring`.
To add repos: `Sources` → `+` → paste repo URL → `Add Source`.

---

## 7. Living with the 7-day signature

iPadOS 16.7+ (excluding 17.0) requires the app to be **re-signed every 7 days** — free Apple ID
provisioning expires. After 7 days the Dopamine icon dims and will not launch.

**Why it is 7 days, exactly:** Dopamine is **semi-untethered**. ios.cfw.guide states it outright —
*"If you are on iOS/iPadOS 16.7 or later (excluding iOS/iPadOS 17.0), due to how semi-untethered
jailbreaks work, the app will need to be re-signed once every 7 days."* This is a property of the
model, not a limitation of any particular tool. No signing trick escapes it (see §0).

Free Apple ID limits: **7 days per signature, 3 active apps at once, 10 App IDs per week.**

### Two different "taps" — only one is a recurring chore

| Action | When it is needed | Automatable? |
|---|---|---|
| Re-run Dopamine to re-apply the exploit | after each **reboot** | ❌ no — needs Dopamine's own UI + kernel exploit. Rarely needed anyway. |
| **Re-sign the app** | every **7 days** | ✅ **yes** — see below |

### The three architectures, honestly rated

| Option | Determinism | Cost | Requires |
|---|---|---|---|
| **Paid Apple Developer Program** | **absolute** — 1-year certs, problem deleted | **$99/yr** | nothing |
| **SideStore + Shortcuts automation (on-device)** | best-effort, **silent-failure modes** | $0 | SideStore-first install, always-on VPN, pairing file, self-hosted anisette |
| **Impactor / cron from x570 (desktop)** | **deterministic** at a scheduled time | $0 | iPad **plugged in over USB** when it fires |

**Buying out of it is a legitimate answer.** $99/yr removes the 7-day cycle entirely. If the hourly
value of your time exceeds that, automation is the more expensive option. Saying so plainly is part of
the honest answer.

### 7.1 On-device — Shortcuts + SideStore (no computer, best-effort)

Both halves are real and documented:

- **Shortcuts → Personal Automation.** Apple's own docs: *"Some personal automations can run without
  asking you for confirmation when they're triggered."* Since iOS 17 the trigger modes are
  **"Run Immediately"** vs *"Run After Confirmation"* — a **Time of Day** trigger fires unattended
  (notification banner only).
- **SideStore exposes a `Refresh All Apps` Shortcuts action**, unlocked in
  **SideStore Settings → "Allow Siri to refresh apps"**. Pair it with the automation above.

**Setup order:** install SideStore once from the computer via **iloader** (`nab138/iloader`, Linux
AppImage) or Impactor → keep the pairing file in place → on the iPad connect **LocalDevVPN** → then
install Dopamine *through SideStore* (§1, day-one decision). The old **WireGuard + StosVPN** workflow is
**deprecated**; it is **LocalDevVPN** now.

**Caveats — best-effort, not a guarantee. Do not treat this as dependable:**

1. iOS throttles background execution, so nothing time-based is guaranteed. SideStore's own refresh bug
   history says the same: *"Background refresh not working … seems to not refresh in the background,
   resulting in the 7 day limit ending and having to reinstall it manually"* (#496); *"Background
   refresh broken on iOS 17 — investigate new JIT impact"* (#1124); *"Refreshing apps works
   unreliably"* (#669); *"Shortcut for Refresh fails with 'the operation took too long to
   complete'"* (#431); *"Refresh all apps iOS shortcut always fails"* (#347).
2. **The VPN must stay connected** — it is what makes the install path work. VPN off / Low Power Mode /
   Background App Refresh off → silent failure. An always-on VPN has a battery cost.
3. **SideStore must be the installer** (§1).
4. **It fails exactly when it matters.** Once the certificate expires the app will not launch, so the
   automation must succeed *before* expiry. Miss one cycle → back to the cable.
5. Shortcuts **cannot** authenticate to Apple, obtain a certificate, or install anything. It only
   *triggers* SideStore's existing refresh.

### 7.2 Self-hosting the anisette server (recommended on either route)

The **anisette server** is SideStore's one genuine hosted dependency — a remote service that fabricates
the fake-Mac device-identity headers Apple's developer API demands at login. It has real outages
(SideStore #690 *"Anisette errors"*, plus repeated *"unable to refresh apps or sign in"*). Their FAQ
concedes it: *"the most common issue is a temporary Anisette server downtime. You can currently change
the Anisette server on your device's Settings app in SideStore under 'Anisette URL'."*

Self-hosting is officially supported — `docs.sidestore.io/docs/advanced/anisette`. It is **running on
ideapad** as `$HOME/Server/stacks/anisette/compose.yaml` (copy kept in this repo at
`anisette/compose.yaml`):

```bash
cd $HOME/Server/stacks/anisette && docker compose up -d
curl -sf http://<host>:6969/           # smoke test
# then on the iPad: SideStore → Settings → "Anisette URL" → http://<host>:6969
```

Equivalent upstream one-liner:
```bash
docker run -d --restart always --name anisette-v3 -p 6969:6969 \
  --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/lib/ dadoum/anisette-v3-server
```

**Two reasons this is a win rather than a hedge:**

- **It is a security improvement.** SideStore's FAQ: *"Older Anisette servers that are used by many
  users are known to cause locking of Apple ID's."* Official advice is *"use one of the official
  Anisette servers, or **host your own**."* A real Apple ID authenticates here — private beats shared.
- **One container covers both routes.** `anisette-v3-server` is explicitly compatible with
  **AltServer-Linux**, and plumesign's `--apple-id` live issuance needs the same headers. The
  desktop-signer and on-device paths share it.

> 🔒 The service has **no authentication** and is Apple-ID-adjacent — treat its exposed port as being
> as sensitive as the Apple ID itself.

> ⏰ The anisette host must be **up exactly when a refresh fires**, or the refresh fails. Do not run it
> on anything that sleeps or is regularly powered off.

**What is *not* a hosted dependency:** the "VPN" (`LocalDevVPN`, ex `em_proxy`/StosVPN) runs **on the
iPad** and tunnels only to the device itself — SideStore's docs: *"No remote servers are used."* There
is nothing to host and nothing to go down. Only distribution risk (App Store); both are open source.

### 7.3 Desktop refresh from x570 (deterministic fallback)

Re-run Impactor (§3.4) with the same IPA.

- Impactor's **auto-refresh only fires while the iPad is plugged in over USB** — `usbmuxd` has **no
  Wi-Fi support** on Linux. A "Wi-Fi refresh from the PC" is not a thing here.

### 7.4 jailbreaks.app

**DEAD as of 2026-09-14** — the enterprise certificate behind this route has been revoked by
Apple (see the verdict at the top of §1). For the record, the link was
`https://api.jailbreaks.app/install/Dopamine` (§1). Zero
friction when it works, but you do not control the signing, and re-installing means trusting the
profile again.

> This is **not** a 7-day refresh mechanism — the signature is an enterprise certificate with a
> much longer nominal life, and it can be revoked at any moment. It is a *fallback re-install*, not a
> schedule.

> The upstream guide's "re-signed" link points to `/resigning-apps`, which is currently a **404**.
> Discord `discord.gg/jb` is the escalation path.

---

## 8. Troubleshooting

### usbmuxd not running / device invisible
```bash
sv status usbmuxd
sv up usbmuxd
ls -l /var/run/usbmuxd
```
Void runs it as `usbmuxd -f -u`; `-u` means a dedicated usbmux user — if permissions look wrong,
check the socket's ownership.

### Impactor doesn't see the device
Plug the iPad in **before** launching Impactor. On some setups udev stops usbmuxd on hotplug.
(The "run `sudo update-crypto-policies`" advice from the README is for crypto-policy distros and
does **not** apply to Void.)

### `Could not connect to lockdownd`
The device is not paired/trusted, is locked, or usbmuxd is down.
```bash
pymobiledevice3 lockdown pair     # or: idevicepair pair
```
Unlock the screen and accept the Trust dialog.

### Developer Mode toggle missing
See §4. Try `pymobiledevice3 amfi enable-developer-mode` (needs the DDI mounted;
`pymobiledevice3 mounter auto-mount`). On 18.5 the no-root userspace tunnel is automatic; if it fails,
`sudo pymobiledevice3 remote tunneld` and retry.

### Tunneld inside containers / VMs
RSD tunnel addresses are not reachable across network namespaces (e.g. docker bridge). Use the
websocket form `--tunnel UDID@HOST:PORT`, or run the tools on the host with USB passthrough.

### Python 3.14
`pymobiledevice3` needs ≥3.9 and is pure Python; current `cryptography` (50.x) supports 3.14. If a wheel
misbehaves: `pipx install --python python3 pymobiledevice3`, or use a 3.13 venv.

### Anisette failures — login or refresh fails, Apple ID lockouts
Shared anisette servers go down, and **shared servers are a documented Apple-ID lockout risk**.
Fix: self-host (§7.2) and point **SideStore → Settings → "Anisette URL"** at it, or switch to another
official server from the list at <https://servers.sidestore.io/servers.json>.

### Respring loop (device stuck respringing)
Force reboot → re-jailbreak with tweak injection **disabled** → remove the most recently installed
tweak. Last resort: restore rootFS.

### Bootloop
Constant Apple logo even after a force reboot → needs a **DFU restore**.
DFU entry for this chassis family (no Home button): connect to the computer, hold **Side + Volume Down**
for 8 s, release **Side**, keep holding **Volume Down**. Verify with `idevice_id -l` / Impactor detecting
a recovery device.

---

## 9. The run that worked — 2026-09-15

Path A was dead (revoked cert, §1) and Path B's Impactor GUI was never needed: the whole
install was driven headlessly from x570 with `plumesign`. This section is the record of
what actually happened, in order, so the next run does not rediscover it.

### 9.1 Sequence

| # | Step | Command / action |
|---|---|---|
| 1 | Apple ID login (once; session then cached) | `python3 tools/apple-login.py` + code to `/tmp/2fa_code` |
| 2 | Sign + install Dopamine | `./resign.sh` |
| 3 | Trust the certificate | iPad: Settings → General → VPN & Device Management → *Apple Development: …* → Trust |
| 4 | Developer Mode | Settings → Privacy & Security → Developer Mode → on → Restart → Turn On + passcode |
| 5 | Run the exploit | Dopamine → **Jailbreak** (screen flickers on A12 — normal) |
| 6 | Bootstrap | Sileo → ElleKit, then PreferenceLoader → respring |

Result: **Sileo on the home screen**, ElleKit and PreferenceLoader installed.

### 9.2 Things the upstream guide does not tell you

- **Developer Mode cannot be enabled headlessly when a passcode is set.**
  `pymobiledevice3 amfi enable-developer-mode` fails with
  `Cannot enable developer-mode when passcode is set`. Do it in Settings instead — the
  toggle only appears *after* a developer-signed app has been installed, so the order is
  install → toggle, not toggle → install.
- **`Processing triggers for org.coolstar.sileo` is not a hang.** That is `uicache`
  rescanning every installed app; 2–5 minutes on an iPad 8 is normal. Interrupting it
  leaves dpkg half-configured. Wait.
- **Userspace reboot ≠ reboot.** Dopamine → *Userspace Reboot*, or Sileo's *Reboot Device*
  button. The hardware power button drops the jailbreak and forces re-running the exploit.
- **PreferenceLoader** is `preferenceloader` (lowercase, one word) in the Procursus
  bootstrap Dopamine ships. Searching the CamelCase name in Sileo finds nothing.
- The installed bundle id is **team-suffixed** — `com.opa334.Dopamine.QQ52XUYS37`. Normal
  for a free-tier re-sign; scripts matching a bare `com.opa334.Dopamine` will miss it.

### 9.3 The 7-day re-sign

```bash
./resign.sh                      # Dopamine
./resign.sh tools/SideStore.ipa  # or any other IPA
```

Unattended — no 2FA, the Apple session is cached in plumesign's `accounts.json`. Preflight
checks usbmuxd, device presence, pairing, anisette reachability and a cached account before
touching Apple, then verifies the install against the device by bundle id.

Requires the iPad **plugged in over USB**: `usbmuxd` has no Wi-Fi support on Linux, so
"refresh over Wi-Fi from the PC" does not exist here.

If the cached session has expired, re-run `python3 tools/apple-login.py` with the iPad
nearby for the 2FA code.

### 9.4 Apple ID safety — learned the hard way

The account was **locked mid-session** (`SRP error -20209`) after a run of failed logins
through tools that were never going to work, two of them via the shared public anisette
server. Recovery needed iForgot, and the unlock invalidated the stored password, which then
produced a *different* error (`-22406`) that looks like a second lockout.

- **One failed login = stop and diagnose.** Do not retry blind.
- Prefer a **throwaway Apple ID** for signing. The 7-day cycle guarantees repeated
  sign-ins; each one is a chance to lock the account that holds your purchases and iCloud.
- Self-hosted anisette (`anisette.example.com`, §7.2) removes the shared-server lock vector.
  See §7 for why it has to be publicly-trusted TLS and cannot be a LAN
  address with a private CA.

---

## 10. SideStore (Path C) — built, then deliberately removed (2026-09-15)

**Decision: Path C is rejected. The cable path (§9.3) is the mechanism.** SideStore was
installed, wired up and then uninstalled the same night. This section records why, and
what to restore if the decision is ever revisited.

### 10.1 Why it was dropped

SideStore's only real value is refreshing the certificate **without a computer**. The iPad
lives at the desk beside x570 (it is also being used as a second display), so `./resign.sh`
already covers the 7-day cycle deterministically. That makes SideStore a fragile layer
solving a problem that no longer exists, and it costs:

- an **Apple ID sign-in surface** — the mechanism that locked this account on 2026-09-14
- an **always-on VPN** (LocalDevVPN) with its battery draw
- **its own weekly re-sign** — SideStore is sideloaded too, it is not free to keep
- one of the **3 free-tier app slots** (Dopamine, SideStore, WebDriverAgent was 3 of 3)
- a LAN-only anisette dependency, so refreshes only worked at home anyway
- documented silent-failure modes (SideStore #496, #1124, #669, #431, #347) that fail
  precisely when the certificate expires

It does **not** change reboot behaviour either way: Dopamine is semi-untethered, so after
any reboot you open it and tap **Jailbreak** regardless.

**The one scenario that would justify bringing it back:** the iPad spends a week away from
x570 *and* reboots. The certificate expires mid-absence, Dopamine will not launch, and the
device stays unjailbroken until it is back at the cable.

### 10.2 What was removed

| Thing | Action |
|---|---|
| SideStore app | uninstalled (`ideviceinstaller -U com.SideStore.SideStore.QQ52XUYS37`) — its container, pairing file and staged IPA went with it |
| `anisette-ipad` stack | `docker compose down -v`, stack directory deleted, named volume removed |
| NPM proxy host 49 (`anisette2.example.com`) | deleted |
| Let's Encrypt cert 54 | deleted |
| `/servers.json` catalog on host 48 | advanced config cleared |

**Kept:** `anisette.example.com` (host 48, cert 53, access list 7) — plumesign on x570 needs
it. Verified after teardown: `/v3/client_info` → 200, `ani2` unresolvable,
`/servers.json` → 404, and a full `./resign.sh` run still succeeds.

### 10.3 What it took to get working, if it is ever revisited

Everything below was solved and verified; only the final Apple sign-in was not.

- **Free accounts cannot register App Groups.** Signing stock SideStore fails with
  `Developer API error 35: An Application Group with Identifier
  'group.com.SideStore.SideStore.QQ52XUYS37' is not available`. plumesign decides what to
  register from the AltStore-convention Info.plist key `ALTAppGroups`;
  `tools/make-sidestore-freetier.py` strips it and drops
  `PlugIns/AltWidgetExtension.appex`. The prepared IPA is kept at
  `tools/SideStore-freetier.ipa` — reinstalling is `./resign.sh tools/SideStore-freetier.ipa`.
- **Pairing file.** `plumesign device --pairing` fails with `afc error: Permission denied`;
  `pymobiledevice3 apps afc <bundle>` writes to the same container fine. Push
  `/var/lib/lockdown/<UDID>.plist` (root-owned, has the EscrowBag) to
  `Documents/ALTPairingFile.mobiledevicepairing`.
- **SideStore 0.6 dropped the free-text Anisette URL** in favour of a server *catalog*;
  only the catalog URL is editable. Self-host it as an nginx `location = /servers.json`
  returning `{"servers":[{"name":…,"address":…}]}`.
- **The blocker: Apple returned 503 at sign-in.** Not an anisette fault — the catalog
  (200), provisioning websocket (**101**) and `/v3/get_headers` (200) all succeeded from
  the device, and SideStore's *on-device* anisette, which bypasses our servers entirely,
  failed identically. Ruled out: stale SideStore (0.6.4 was six days old), and a machine
  identity collision with x570 (anisette rotates `X-Mme-Device-Id` per session; a
  dedicated second instance was built to isolate this and made no difference).
  Remaining hypothesis: developer-API rate limiting after a session in which the account
  absorbed a lockout, an unlock, a password change, several failed SRP attempts, a
  successful login and three App ID registrations. Signing kept working throughout —
  WebDriverAgent was signed and installed **after** the 503s began — so the throttle, if
  that is what it is, is specific to interactive sign-in.

## 11. Driving the device from x570

Four independent channels, all verified working on 2026-09-15. Bring them all up with:

```bash
./tools/ipad-up.sh            # idempotent; --status to inspect without changing anything
```

| Channel | Tool | Needs |
|---|---|---|
| Root / user shell | `./tools/ipad-ssh.sh [--root] '<cmd>'` | openssh-server (Sileo), key in device `$HOME/.ssh` |
| Screenshot | `./tools/ipad-shot.sh [out.png]` | RSD tunnel |
| Tap / swipe / type / launch | `./tools/ipad-ctl.sh …` | RSD tunnel + DDI + WebDriverAgent + UI Automation |
| Install / re-sign | `./resign.sh [ipa]` | cached Apple session |

### 11.1 Host-side prerequisites (lost on every x570 reboot)

```bash
sudo pymobiledevice3 remote tunneld &     # iOS 17+ RemoteServiceDiscovery
pymobiledevice3 mounter auto-mount        # DeveloperDiskImage (lost on DEVICE reboot too)
iproxy 2222 22 &                          # SSH over USB
```

`ipad-up.sh` does all three, plus starts WebDriverAgent.

**`usbmuxd` has no Wi-Fi support on Linux**, so every channel rides USB. There is no
"ssh to the iPad's IP" while working this way.

### 11.2 Device-side, one-time

- **Settings → Developer → Enable UI Automation.** Without it XCUITest bootstraps and
  then dies 60 s later with `initializationForUITestingDidFailWithError`.
- **openssh-server** from Sileo (Procursus). Pulls in `openssh-client` and
  `openssh-sftp-server` — 3 packages.

### 11.3 Three traps that cost real time

1. **The password Dopamine sets is `mobile`'s, not `root`'s.** Its settings say
   *"Cambia password 'mobile'"*. `ssh root@…` answers `UNIX authentication refused`
   however correct the password is. (`IPAD_ROOT_PWD` in `~/.secrets` is a misnomer; the
   name is kept for compatibility, and `ipad-ssh.sh --root` uses it via `sudo -S`, feeding
   it on **stdin** so it never lands in `ps`.)
2. **Rootless means `$HOME` is `/var/jb/var/mobile`, not `/var/mobile`.** Installing an
   authorized_keys file to `/var/mobile/.ssh` succeeds, changes nothing, and leaves
   pubkey auth failing with no useful error.
3. **plumesign does not sign nested `.xctest` bundles.** WebDriverAgent's test bundle
   arrives completely unsigned and `dlopen` refuses it:
   `mapped file has no cdhash, completely unsigned? Code has to be at least ad-hoc
   signed.` `tools/make-wda-ipa.py` ad-hoc signs it (and `WebDriverAgentLib.framework`,
   which fails next) with `ldid` before packaging. Ad-hoc suffices only because Dopamine
   patches AMFI — on a stock device this needs a real signature covering the plugin.

### 11.4 WDA selectors

`wda tap` defaults to the `accessibility id` strategy, and `label` is **not** a valid
locator (`Invalid locator requested: label`). Multi-line labels must be passed verbatim,
newline included:

```bash
./tools/ipad-ctl.sh items                     # dump elements first
pymobiledevice3 developer wda tap "In coda
3 Pacchetti"
```

The device UI is **Italian**, so selectors are Italian strings (`Conferma`, `Cerca`,
`OTTIENI`, `Fatto`).

### 11.5 After an iPad reboot

The jailbreak is gone until Dopamine is opened and **Jailbreak** tapped. Until then
`/var/jb` does not exist, so **sshd is gone too** — `ipad-up.sh` will report
`ssh mobile@ipad unreachable`. The DeveloperDiskImage also needs re-mounting.
Screenshots and app installs still work unjailbroken; shell and tweaks do not.

---

## 12. Appendix — reality-checked details

- **Dopamine version current at time of writing:** 3.0.9 (Aug 2026).
- **Developer Mode** is the classic blocking step on 16+: it only becomes visible after a
  developer-signed install, and the toggle triggers its own reboot.
- **Screen flicker during exploit** on A12/A13 is expected, not a fault.
- ~~**No SSH server on x570**~~ — superseded: see §11, root shell over USB works.
- **(historical)** No SSH server on x570 — if you intend to drive the device remotely, that is a separate setup step;
  `sshd` is not enabled on the host.
- **Verified on x570:** `libimobiledevice`, `usbmuxd`, `ideviceinstaller`, `pymobiledevice3`, `ifuse`
  are **all absent** — §3.1 installs them from scratch.
- **Sudo:** the host currently uses a temporary password; prefer `sudo -S` for non-interactive steps.
- **Dopamine is semi-untethered by definition** — re-applied by the app after each reboot. Untethered
  is impossible on A12: checkm8 (the only public bootrom exploit) is A5–A11, and the codesign-bypass
  route (TrollStore) is dead above iOS 17.0.
- **Only one dependency in the SideStore route is actually hosted** (the anisette server) — and that is
  the one we self-host. The VPN is on-device and remote-server-free.

### Sources
- Main guide (adapted): <https://ios.cfw.guide/installing-dopamine/>
- Sileo usage: <https://ios.cfw.guide/installing-dopamine/using-sileo.html>
- Troubleshooting / DFU: <https://ios.cfw.guide/troubleshooting/>
- Jailbreak types (semi-untethered): <https://ios.cfw.guide/types-of-jailbreak/>
- Impactor (Linux AppImage + Flathub): <https://github.com/claration/Impactor>
- pymobiledevice3: <https://doronz88.github.io/pymobiledevice3/> (esp. `/guides/ios17-tunnels/`, `/cli/apps/`)
- SideStore + iloader: <https://docs.sidestore.io/docs/installation/install>, <https://github.com/nab138/iloader>
- TrollStore (why it's dead here): <https://github.com/opa334/TrollStore>
- Dopamine: <https://ellekit.space/dopamine/>, <https://github.com/opa334/Dopamine/releases>
- jailbreaks.app (no-computer route): <https://jailbreaks.app/>
- Shortcuts personal automations ("Run Immediately"): <https://support.apple.com/guide/shortcuts/enable-or-disable-a-personal-automation-apd602971e63/ios>
- SideStore FAQ: <https://docs.sidestore.io/docs/faq> · self-hosted anisette: <https://docs.sidestore.io/docs/advanced/anisette>
- anisette-v3-server (Docker): <https://github.com/Dadoum/anisette-v3-server> · server list: <https://github.com/SideStore/anisette-servers>
- On-device VPN (what it is / that it is local): <https://github.com/jkcoxson/LocalDevVPN>, <https://github.com/SideStore/em_proxy>
- Jailbreak types (untethered vs semi-untethered): <https://ios.cfw.guide/types-of-jailbreak/>
