# Background

[← back to the guide](../README.md)

Why the obvious alternatives do not apply, and what to be careful of.

## No untethered jailbreak exists

There are two routes to surviving a reboot, and both are closed for A12 and newer
on iOS 18:

1. **A bootrom exploit.** The only public one is **checkm8**, which covers A5–A11.
   There is no public A12/A13 bootrom exploit.
2. **A code-signing bypass** that keeps the jailbreak app installed — TrollStore's
   route. TrollStore caps at iOS 17.0; upstream states that 16.7.x (non-RC) and
   17.0.1+ *"will NEVER be supported."*

So untethered is not something to wait for. It needs a new bug class.

> **Do not install "untethered iOS 18 jailbreaks."**
>
> Searching turns up several repositories claiming exactly that. They are fake or
> malicious. One widely linked example ships exploit sources copied verbatim from
> **Fugu15** — which only ever worked on iOS 15.0–15.4.1 — points its "download"
> at a monetised blog rather than a project site, and contradicts itself about
> which versions it supports. Others in the same family follow the same pattern.
>
> Treat every such result as hostile until proven otherwise. A working
> code-signing bypass on 18.x would also contradict TrollStore's own position.

## What does not apply on iOS 18

| Method | Why not |
|---|---|
| **TrollStore** | The CoreTrust/AMFI bug was fixed in 16.7/17.0.1. Maximum is iOS 17.0. The SparseRestore variant stops at 18.0.1. |
| **AltStore / AltServer-Linux** | Last release v0.0.5 (2022). Apple's GSA returns 503. |
| **Sideloadly** | No Linux build. |
| **jailbreaks.app** | Enterprise-certificate distribution; that certificate has been revoked. Not a refresh mechanism in any case — an enterprise certificate can be pulled at any time. |
| **Permasigning** | Depends on TrollStore, so unavailable above 17.0. |

## Semi-untethered, explained

Dopamine is semi-untethered: the exploit runs from an app, and after every reboot
you re-open that app and tap **Jailbreak**. No computer is involved.

That is separate from the **7-day certificate**, which is a free-Apple-ID limit
and *is* automated here. People conflate the two constantly. See
[4. The 7-day cycle](04-resigning.md).

## Model identifiers

Check the model string against the right table — the iPad 8 is commonly
mis-identified:

| Identifier | Device | SoC |
|---|---|---|
| `iPad11,1` / `iPad11,2` | iPad mini 5 | A12 |
| `iPad11,3` / `iPad11,4` | iPad Air 3 | A12 |
| `iPad11,6` | **iPad 8th gen, Wi-Fi** | A12 |
| `iPad11,7` | iPad 8th gen, Wi-Fi + Cellular | A12 |

Read yours with `ideviceinfo -k ProductType`. Dopamine supports A8–A13 on
15.0–18.7.1, and A14+ only up to 17.3.1.

## Before you start

- Remove **rootful palera1n** first if it is installed.
- Remove **nathanlr**, **Relaxin**, **Serotonin** or **Bootstrap** fully first.
  If those names mean nothing to you, this does not apply.
- Find My does **not** need to be disabled. That requirement belongs to the
  TrollRestore path, not this one.
