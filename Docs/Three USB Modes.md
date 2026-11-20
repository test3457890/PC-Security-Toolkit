# Three USB design

Owner direction: three distinct physical drives. Status: Toolkit USB has a
scan-only safety preview; the other two roles are specifications, not working products.

| Drive | User action | Environment | Persistence and limits |
|---|---|---|---|
| Toolkit USB | Open START HERE for the OS, confirm permission, choose Scan this PC | Existing Windows/macOS/Linux session | No automatic toolkit report/log/config writes. Explicit browser report export is optional. OS/browser records can remain. |
| Secure Session USB | Insert into a personally owned or explicitly administered, enrolled Windows computer | Existing Windows session plus separately installed, visible host helper | Durable host recovery data is required. Temporary reviewed controls only after verified snapshots; later conflicting changes must be preserved. Planned. |
| Disposable Workspace USB | Insert, restart, choose the drive from an authorized boot menu | Separate live Linux OS, with a proposed Debian Live base | RAM-backed session state and no persistence by default are design goals requiring verification. Host disks remain untouched by design. No boot image included yet. |

## Toolkit USB implementation boundary

The ordinary launchers now serve Guest Dashboard.html. The server uses an allowlist
before dispatch, even when an old UI sends arbitrary script text. Both script
execution routes, cleanup, family/mobile changes, recovery actions, saved reports,
theme writes, external tools, and Ollama requests are unavailable through this preview.
Only metadata, consent, read-only scan, Windows cache sizes and shutdown are allowed.
The page has seven session-only themes and explicit JSON export. The restricted
sharing export excludes identifiers, raw evidence and free-text findings by allowlist.

Legacy feature source remains for migration. Standalone Profiles scripts and the
legacy Recovery launcher remain unaudited modification entry points, outside Guest
Mode; do not run them on borrowed/managed machines. This PR does not fix their
rollback limitations. Do not describe all P0 concerns as resolved.

## Secure Session USB acceptance requirements

No helper, autorun.inf or insert-trigger installation is included. Windows USB
insertion cannot simply run arbitrary programs on an unprepared computer. Enroll
owned test VMs explicitly before considering a real host installation.

The reviewed helper specification must include a protected installation path and
keys, visible status, revocation, restricted privileges, authenticated profiles,
host-durable per-action originals/applied state, conflict-aware idempotent recovery,
and an independent recovery/uninstall route. Storage-only credentials can be copied;
choose whether that clone risk is accepted or hardware-backed proof is required.
Do not label a serial number or drive letter as cryptographic authentication.

Prototype lifecycle first using synthetic VM settings; no automatic DNS changes,
service disabling, policy resets, file deletion, OS upgrade, or log clearing. Never
disable protections to make the toolkit work. Validate unplug, sleep, restart,
replay, disk full, corrupt profile, worker crash and competing administrator changes.

## Disposable Workspace USB specification

This is a separate OS project. It is not a Windows program that becomes amnesic on
USB insertion, and it cannot automatically boot while Windows is running. External
boot requires hardware/firmware support and administrator authorization. Do not
disable Secure Boot, change firmware policy or bypass managed-device restrictions.

Proposed base: a maintained Debian Live desktop with an original toolkit interface.
This is a proposal, not an evaluated substitute for Tails. Debian live-boot supports
nonpersistent sessions; that alone is not a privacy-hardened distribution.

Required before any image is distributed:

1. Pin source packages and build configuration, resolve toolkit/component licenses,
   generate an SBOM/checksums and document a timely image update process.
2. Disable persistence by default. Use RAM-backed writable session state, no host
   swap, no hibernation, no crash dumps to host disks and no host-disk automounting.
   Ensure disks are not mounted by background desktop/indexing services.
3. Do not include an installer or grant automatic access to host data. Any explicit
   import/export must disclose that it persists data. External storage export is a
   separate opt-in and is outside the disposable-state claim.
4. Boot/network/browser isolation must be separately threat-modeled. A nonpersistent
   OS is not automatically anonymous. Do not implement an ad hoc Tor firewall or
   claim Tor routing merely because Tor Browser is available. Any optional Tor
   integration needs vendor guidance and leak tests, including DNS/IPv6 and failures.
5. No log wiping or concealment. Session-local logs may live in RAM. Network services,
   routers, accounts, firmware and hardware can retain evidence; compromised hardware
   or firmware and live memory acquisition are outside the proposed protection.
6. Test boot/shutdown/reboot/power-loss in disposable VMs with instrumented internal
   disks. Verify no unintended host-disk writes, no persistent session state, no
   unapproved network connections and documented boot/firmware effects. Test real
   authorized hardware only after VM gates pass. Do not infer these properties from
   a boot parameter or a successful desktop launch.
7. Verify Secure Boot support rather than assuming every custom image will boot.
   If the approved host cannot boot it, report unsupported instead of changing policy.

Safe user-facing claim after testing: a separately booted workspace designed to
discard session state at shutdown, with documented exceptions. Never claim no
traces, full anonymity, hardware trust, or equivalence to Tails.

## Sources and validation

Reviewed November 17, 2026. Platform sources inform these proposals; they do not
validate this project's unbuilt helper or live image.

- [Microsoft AutoRun](https://learn.microsoft.com/en-us/windows/win32/shell/autoplay-reg)
- [Microsoft AutoRun changes for removable media](https://www.microsoft.com/en-us/msrc/blog/2009/04/changes-in-windows-to-meet-changes-in-threat-landscape)
- [Debian Live manual](https://live-team.pages.debian.net/live-manual/html/live-manual.en.html)
- [Debian live-boot manual](https://manpages.debian.org/unstable/live-boot-doc/live-boot.7.en.html)
- [Tails limitations](https://tails.net/doc/about/warnings/index.en.html)
- [Foundation safety test plan](Safety%20Test%20Plan.md)
