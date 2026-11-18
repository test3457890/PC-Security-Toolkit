# PC Security Toolkit

A local, portable security assessment project for computer owners and learners.
Current branch: scan-only safety preview, based on the documented v3.1 source.
This is not a released v3.2 build or a validated hardening/recovery product.

## Start a read-only scan

Download or clone this branch, extract it, and open the launcher for your OS:

| System | Launcher | Requirement |
|---|---|---|
| Windows | `START HERE Windows.bat` | Windows PowerShell; basic checks use current-user permissions |
| macOS | `START HERE Mac.command` | Python 3 |
| Linux | `bash "START HERE Linux.sh"` | Python 3 |

The launcher opens a local dashboard. Confirm that you own the computer or have
permission to inspect it and that its policies allow this software, then choose
Scan this PC. No scan starts automatically. Do not run as administrator for Guest
Mode. If application controls block execution, stop and ask the administrator for
an approved option. Do not disable Defender, Smart App Control, Secure Boot, firewall,
UAC, updates or organization controls to run this project.

The preview does not change OS controls, run elevated actions, install helpers,
launch external tools or automatically save toolkit logs/config/reports. Themes
last only for the page session. Export JSON report is an explicit browser download;
the browser chooses its location. The restricted summary excludes raw evidence and
free-text findings by allowlist. Review every export before sharing it.

Choose End session, confirm the launcher finishes, close the page and safely eject
the drive. Closing a browser tab alone does not stop the server. OS/browser/network
records can remain. This software makes no zero-trace or anonymity guarantee.

## Three separate USB roles

| USB | Intended experience | Status |
|---|---|---|
| Toolkit USB | Open launcher, confirm permission, scan an authorized PC | Implemented as a preview; Windows runtime evidence pending |
| Secure Session USB | Insert into an owned, enrolled Windows machine; a visible, deliberately installed helper verifies the credential and starts a reviewed temporary profile | Design only; no host helper or automatic activation included |
| Disposable Workspace USB | Restart an authorized computer and boot a separate, nonpersistent live OS from USB | Design only; no boot image included |

[Read the three USB specification](Docs/Three%20USB%20Modes.md). The third role is
a separately booted OS proposal inspired by disposable live systems. It is not a
Windows insert-and-erase feature. An ordinary USB cannot replace the running OS
on insertion. No mode promises to erase audit logs or bypass managed-device rules.

## What changed from v3.1

The ordinary launchers now serve `Engine/Guest Dashboard.html`. Servers enforce a
small route allowlist before the legacy dispatch code, require scan consent, check
methods and browser Origin, and bound JSON request sizes. APIs for arbitrary scripts,
cleanup, family/mobile changes, recovery, persistent reports/settings, external tools
and AI are unavailable in this preview, including requests from the old dashboard.

The legacy dashboard, profiles, recovery engine and optional feature code remain in
the source for controlled migration. Their presence does not make them validated.
Standalone profiles and the legacy Recovery launcher still modify Windows and are
outside Guest Mode. Do not use them on borrowed/managed machines or rely on their
snapshots for complete rollback. Broad snapshot restoration can overwrite later
changes; deletions, software updates and several settings have incomplete/no undo.
Back to Windows defaults is not restoration of the user's original configuration.

## Results and known limitations

Existing checks are heuristic. Missing APIs/permissions can still produce incomplete
or misleading legacy findings; the preview explicitly displays that limitation and
does not present the old score as a protection percentage. A port or unsigned binary
is not proof of malware. Some Windows queries require elevation; unavailable data
must not be treated as a passed check. Improving per-check evidence and availability
is a subsequent priority.

Windows 10 standard support ended October 14, 2025. Edition-specific lifecycles and
Extended Security Updates need separate verification. Scan capability does not imply
OS support. The toolkit does not automatically upgrade Windows.

The server binds to loopback and uses a fresh per-run API token. These reduce exposure,
but do not establish that the project is invulnerable. Local processes/browser
extensions and a compromised host remain relevant threats. Do not expose the server
through port forwarding, a proxy or public hosting.

No Windows VM restoration, physical USB-loss or elevated-action test evidence is
available for this preview. The new Windows policy can be parsed and fixture-tested
without changing security settings. CI checks are not a substitute for VM evidence.

## Privacy and dependencies

Scans read system settings, identifiers, processes, ports, startup entries, extension
metadata and file names/sizes. They do not request document contents or BitLocker
recovery keys. Results stay in the running page unless explicitly exported. OS and
browser caches/logs are outside that promise. Do not clear logs to conceal activity.
This preview does not invoke optional Ollama/mobile/proprietary utilities through
the dashboard. Outbound behavior of the complete legacy toolkit and optional tools
has not been independently packet-capture validated.

The 34 bundled Windows binaries have a [local byte inventory](Docs/Bundled%20Binary%20Inventory.json).
Upstream package provenance, licenses, notices and redistribution obligations remain
unverified. No root software license has been selected. Public availability alone
does not resolve redistribution rights. Do not publish a binary release until those
questions and the required safety gates are resolved.

## Development and review

- [Verified source review](Docs/Safety%20Review.md)
- [Implementation order and grouped backlog](Docs/Implementation%20Plan.md)
- [Safety testing and VM requirements](Docs/Safety%20Test%20Plan.md)
- [Current preview validation and remaining work](Docs/Preview%20Validation.md)
- [Security reporting](SECURITY.md)
- [Contributing](CONTRIBUTING.md)

Run `python -m unittest discover -s Tests -p "test_*.py" -v` with Python 3 and Node
available. On Windows, run `powershell -NoProfile -File "Tests/Guest Policy Tests.ps1"`.
These tests use fixture scans/pure request policies and do not modify OS controls.
Runtime changes need the separately documented disposable-VM evidence before release.

Keep security updates, endpoint protection, backups and disk encryption in place.
The toolkit is a learning and assessment aid, not a replacement for those controls.

## Platform references

- [Windows 10 lifecycle](https://www.microsoft.com/en-us/windows/end-of-support)
- [Microsoft AutoRun](https://learn.microsoft.com/en-us/windows/win32/shell/autoplay-reg)
- [Debian Live](https://live-team.pages.debian.net/live-manual/html/live-manual.en.html)
- [Tails limitations](https://tails.net/doc/about/warnings/index.en.html)
