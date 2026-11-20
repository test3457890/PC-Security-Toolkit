# Windows verification checklist

Prepared November 19, 2026 for owner and Claude testing beginning November 25.
November 27 is optional owner availability, not a completed test date.
Every row starts Not tested. Record the exact commit, Windows build, account type,
browser, actual result and private evidence. Do not publish host identifiers or keys.

Use the curated preview from the exact successful CI run. Use a standard account
on an owned disposable Windows VM first, then an owned physical PC for USB checks.
Keep unrelated files backed up. Do not weaken execution policy, antivirus, firewall,
Secure Boot or managed-device policy to run the software. Never format a drive here.

## Preview acceptance

| Test | Steps and expected result | Initial status |
|---|---|---|
| Package | Verify ZIP SHA-256, extract both artifact layers, inspect manifest. Launchers and dashboard are together; no bundled executables or recovery launcher. | Not tested |
| Normal launch | Double-click START HERE Windows.bat as a standard user. No UAC prompt, installation, enrollment or OS changes. Page says Scan only. | Not tested |
| Extraction path | Repeat from a folder with spaces and a non-English character, then existing USB storage. No format/partition prompts. | Not tested |
| Policy denial | On an already restricted VM, launch without changing policy. Stop with accurate guidance; no attempt to bypass restrictions. | Not tested |
| Incomplete package | In a disposable copy remove Guest Policy.ps1, then separately Guest Dashboard.html. Launch fails before a listener opens. | Not tested |
| Port conflict | With another benign local service occupying 8765, launch. A different loopback URL opens, or an existing preview is recognized. | Not tested |
| No consent | Open the page, then press Scan this PC with permission unchecked. No scan starts. Keyboard and screen reader identify the permission field and status. | Not tested |
| Actual scan | Check permission and press Scan this PC. Buttons disable while collecting; readable results appear or failure is reported. No elevation or automatic saved toolkit data. | Not tested |
| Evidence accuracy | Compare Defender, firewall profiles, UAC, BitLocker and Secure Boot against Windows tools. Missing permission/API data appears Unknown, never a false pass. Legacy fields outside the selected table still need separate review. | Not tested |
| Listening services | Known authorized listener appears for review; a port alone is not classified as proof of compromise or reachable from outside. | Not tested |
| Repeat/failure | Scan again, then use a disposable test fixture to fail the provider. Old findings, raw evidence and export disappear on failed or malformed results. Do not disable OS protections to create a failure. | Not tested |
| Evidence disclosure | Expand and collapse Show collected evidence using mouse and keyboard. Text is readable and contains no injected HTML. Keep this view private. | Not tested |
| Seven themes | Try Classic Midnight, Hacker Terminal, Cyberpunk Neon, Retro Amber, Deep Ocean, Daylight and High Contrast. Check text, focus outlines, checkbox and table. Reload resets theme. | Not tested |
| Layout/accessibility | Test 320px and 1280px viewport widths, 200% zoom, keyboard Tab/Space/Enter, screen reader labels and live status. No clipped controls. | Not tested |
| Restricted export | Leave restricted summary checked; click Export JSON report. Cancel first, then approve. Only approved action downloads valid JSON; no identifiers/raw evidence/free text. | Not tested |
| Full export | Uncheck restricted summary; inspect warning, cancel, then approve in the VM. JSON matches current evidence. Store privately and check the browser's actual download location. | Not tested |
| Persistence | Compare toolkit tree before/after launch, scan, theme and shutdown. No new Config, Logs, Reports or Backups. Explicit browser export and ordinary Windows/browser records are separate. | Not tested |
| API denials | Run Python suite with Python 3 and Node available, plus Tests/Guest Policy Tests.ps1. Repeat extracted server tests on the exact checkout. Legacy mutation, cleanup, family, mobile and recovery routes stay denied. | Not tested |
| End session | Press End session. Evidence clears, controls disable, launcher finishes. Confirm listener closes before safe ejection. Closing the tab alone does not stop the server. | Not tested |
| Interrupted session | Close launcher or stop VM during a scan; restart preview. No automatic changes, restore, enrollment or scan. Safely eject only after process exit. | Not tested |
| USB removal | On a disposable VM/test USB with no valuable data, stop server and safely eject. Test removal/failure during active use only with an expendable copy; record failure behavior without promising recovery. | Not tested |

## Legacy and future components

Do not run the legacy hardening profiles, Script Builder scripts, Family Plan,
mobile mutations, cleanup or Recovery on the owner's production PC. They remain
outside the preview safety boundary. A separate reviewed implementation must first
cover verified backup write/readback, action-specific original/applied values,
conflict-aware restore, native command failures, managed-device gates, different
UAC administrator accounts, interrupted writes and USB loss in a snapshotted VM.
Current snapshots do not establish complete recovery and cannot undo deleted files.

Secure Session USB is unbuilt: insertion autoactivation, enrollment, host helper,
removal handling and temporary setting restoration cannot be accepted as working.
Disposable Workspace USB has no boot image: external boot, disk isolation, RAM
storage, network behavior and disposal cannot be accepted as working. Neither
product is provided by copying the preview folder to a USB.

Stop a test on unexpected host changes, elevation or policy bypass. Record the
failure privately, restore the disposable VM and report a sanitized reproduction.
Real screenshots must identify OS and commit; fixture images must say SIMULATED.
