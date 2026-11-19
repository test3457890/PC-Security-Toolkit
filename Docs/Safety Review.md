# Safety review

Review date: November 17, 2026 (America/Phoenix).
Baseline: `24944a89db2c5ed185154ee49850ca535b183b10`, default branch `main`.
Scope: static source review and local file inventory. No Windows security action,
bundled executable, profile, recovery operation, or toolkit server was run.

This review does not demonstrate exploitation, certify safety, validate rollback,
or verify the origin of bundled dependencies. Runtime fixes are still pending.

## Repository state

- GitHub reported push permission, one branch (`main`, reported unprotected), no
  open issues or pull requests, and no published releases at review start.
- There are 55 tracked files. The console identifies v3.1; the Windows server's
  header says v3.0 and the snapshot format uses Version 3. Keep these distinct.
- No root LICENSE, SECURITY.md, CONTRIBUTING.md, CI workflow, or automated test
  suite is present. No documented release policy was found in the reviewed files.
- `review/safety-foundation` is a review branch from the exact baseline above.
  This review changes documentation and inventory only. Main is unchanged.

## Verified findings

Paths and line numbers below refer to the baseline commit, not future edits.

| Handoff ID | Result and evidence | Consequence and required correction |
|---|---|---|
| P0-01 | Confirmed. `Engine/Toolkit Server.ps1:118-137` prepends an optional snapshot, discards its output, and launches the action without checking success. Missing Recovery.ps1 skips the snapshot. All four `Profiles/*.ps1:11-13` do the same. `Engine/Recovery.ps1:313-318` returns a path without reading the saved file back. | Missing, partial, inaccessible, or detached backups do not reliably stop changes. Validate complete action-specific state and durable write/readback before the first mutation; fail closed. |
| P0-02 | Confirmed. `README.md:3-5` promises every change can be undone. `Engine/Recovery.ps1:512-561` implements defaults, distinct from original state. Cache deletion, app updates and removals have no equivalent recovery. | Replace absolute claims throughout README, launcher guidance, UI, script output, and repository description. Label reversibility per action. Defaults must never be presented as undo. |
| P0-03 | Confirmed and broader than the handoff. `/api/execute` at `Engine/Toolkit Server.ps1:728-732` and `/api/family-apply:911-915` both accept caller-provided script text. `Start-Elevated:119-133` writes predictable filenames in TEMP before UAC launch. | Both paths need reviewed server-side actions, not trusted browser-generated scripts. Review writable-path replacement/races. Host and token checks exist at 648-666, but there is no Origin check, per-route method enforcement, or bounded body read at 107-114. This is an attack surface finding, not a demonstrated remote exploit. |
| P0-04 | Confirmed. Global `SilentlyContinue` is set in the Windows engine, recovery, and profiles. `/api/block-port:755-762` suppresses rule errors but prints success; `/api/clean-caches:783-789` always reports success. Recovery `Step:105-109` counts attempts and does not check native exit codes. | Use structured outcomes with failed/unknown/skipped states, explicit preconditions, native/CIM result checks, and readback verification. A launched process is not a completed action. |
| P0-05 | Confirmed. `Engine/Recovery.ps1:324-470` restores differences from a broad snapshot without a per-action applied-state journal or conflict detection. Registry keys at 66,84-93 are treated as toolkit-owned, including shared browser policies. ASR rules added after the snapshot may be removed at 436-438. | Track original and verified applied values for each target. Restore only session-owned changes after policy/conflict checks. Never infer ownership from a key name, display-name prefix, or an old snapshot. |
| P0-06 | Confirmed. All profiles delete caches. `Engine/Live Toolkit.html:1107-1108` combines Storage Sense configuration with deletion; `Engine/Toolkit Server.ps1:749` deletes extension files, and 783-789 deletes user caches without a snapshot. | Separate deletion from hardening, default it off, preview exact paths and sizes, and exclude it from Guest Mode and Secure Session. Registry backups cannot recover files. |
| P0-07 | Confirmed. `Profiles/2 School Laptop.ps1` self-elevates, writes HKLM policies, stops services, changes network settings, and deletes files. No managed-device modification gate exists in the route dispatcher or these profiles. | Distinguish a personally owned student laptop from a managed campus PC. Server-side permission and policy gates must cover every mutation entry point, direct scripts, and recovery. Detection uncertainty must block automated changes. |
| P0-08 | Confirmed. `Engine/Toolkit Server.ps1:347-425` uses fixed point deductions, labels selected listening ports CRITICAL without effective firewall analysis, and returns Boolean protection states even when a query failed. In particular, empty firewall results make `firewallOn` true. | Report evidence and availability separately, distinguish suspected/confirmed/not measurable/not applicable, and explain legitimate use. A score is a heuristic, not a protection percentage. |
| P0-09 | Partly confirmed; provenance remains unverified. 34 PE files are bundled. `Tools/libimobiledevice/ABOUT THESE FILES.txt` lists versions and asserts MSYS2 signature checks, but contains no package hashes, signature/key evidence, exact package URLs, or complete notices/source compliance record. | See `Bundled Binary Inventory.json`. Local hashes identify these bytes only. Verify package provenance and per-component redistribution obligations before selecting a root license or releasing binaries. |
| P0-10 | Confirmed. Missing root license/security policy/tests/CI; README recommends Run anyway and makes absolute localhost safety claims. | Add accurate security and release documentation, compatible licensing after provenance review, checksums, and non-elevated CI. Do not instruct users to override OS warnings indiscriminately. |
| P0-11 | Confirmed privacy gap; no telemetry assurance established. Windows startup creates logs and prunes old toolkit logs at 43-44 before collection consent. Scan output includes host/user/network data, and snapshots store readable hosts/account/settings data. Python also writes/prunes logs. | Add memory-only display, explicit save consent, redacted export and retention controls. Gitignore is not encryption. Static inspection found local Ollama requests and explicit external-launch/update options; packet capture is still required to assess outbound behavior, including optional tools. |
| P0-12 | Mixed. The reviewed primary profile actions aim to enable Defender; no direct Smart App Control disable, Secure Boot disable, or automatic Windows version upgrade was found there. However `Engine/Recovery.ps1:431-444` can restore weaker PUA/network/ASR settings, and defaults removes protection policies at 516-550. Constrained-language messages at `Engine/Toolkit Server.ps1:14-24` and `Engine/Recovery.ps1:718-722` assume a ZIP cause and suggest unblocking. | Do not bypass application control. Restricted language may be enforced by policy. Recovery needs an explicit safeguard against silent security downgrades. Report OS support separately from scan capability and ESU status; never infer support from Windows 10/11 alone. |

## Additional defects and incomplete recovery coverage

1. Snapshot capture misses actions already exposed by the product. Travel writes
   `fDenyTSConnections` and user AutoPlay state (`Profiles/1 Travel Hardening.ps1:38-42`),
   but those values are absent from `$Tracked`. Profiles change power settings;
   the snapshot has no power plan state. Work writes AllowTelemetry, also absent.
2. Generated actions (`Engine/Live Toolkit.html:1111-1153`) enable firewall
   profiles, disable Guest, remove unrelated vendor firewall rules, change existing
   lab firewall profiles, pin/update apps, and alter OneDrive attributes. Snapshot
   records toolkit firewall rule IDs only, not original rule bodies/profile enable
   state, Guest state, app versions, pins, or cloud-file attributes. All are excluded
   from any claim of reversible operation until covered or separately classified.
3. Service restore restarts previously running services but does not stop a service
   that was originally stopped and subsequently started (Recovery.ps1:373-382).
   Tasks are recorded as names, not full definitions. Existing task replacement
   and removed firewall rules cannot be reconstructed from those records.
4. HKCU is captured in whichever account runs PowerShell. Over-the-shoulder UAC
   using a different administrator account can target that account's settings.
   Journal and helper design must bind user targets to SIDs and test this case.
5. Exported Script Builder files use `PS_HEADER` but contain no toolkit snapshot
   prerequisite (`Live Toolkit.html:1093-1101,1158-1161`). Fixing only the server
   wrapper would leave downloaded standalone scripts outside the safety boundary.
6. Stop Server closes the listener, not the elevated child processes. The UI
   announces safe ejection (`Live Toolkit.html:957-963`) without child completion
   tracking. Closing a browser tab does not itself stop the server. Track children
   and outstanding writes before advising safe removal.
7. Python is read-oriented for OS checks, but is not a no-write Guest Mode. It
   persists logs, themes, and reports (`Mac and Linux Server.py:54-75,423-459`).
   Its request body is read before any report size check, too. Capability and
   privacy gates must be explicit on each platform.

## Existing safeguards to preserve

The listeners bind to loopback. Both servers check Host and a per-run API token.
Windows HTML has no-store and frame-denial headers. Several routes validate
identifiers and filenames, recovery supports dry-run and rejects another computer's
snapshot by name unless forced, and Defender recovery intentionally avoids turning
real-time protection off. These safeguards are useful but do not close the gaps above.

Preserve the dashboard, themes, report/checklist functionality, cross-platform
read-oriented checks, mobile tools, family tools and independent recovery launcher
while putting modification capabilities behind explicit boundaries. Preserve
intentional features, not misleading success or unsupported safety claims.

## License and release decision

No license has been chosen or added by this review. The repository is public but
does not currently provide a root software license. Apache-2.0 is a possible owner
choice for original code, subject to ownership and compatibility review; it would
not replace third-party licenses. Keep binary redistribution blocked until package
sources, exact notices, license versions, and source/relinking obligations are resolved.
Do not treat the existing summary note as independent provenance evidence.

Keep v3.1 as the current documented baseline. Propose v3.2 prerelease only after
foundation checks and VM evidence pass. Secure Session USB remains a design proposal.

## References

- [Implementation order and grouped backlog](Implementation%20Plan.md)
- [Safety testing strategy](Safety%20Test%20Plan.md)
- [Binary inventory](Bundled%20Binary%20Inventory.json)
- [Microsoft PowerShell language modes](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_language_modes)
- [Microsoft Windows Sandbox configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file)
- [Windows 10 support lifecycle](https://www.microsoft.com/en-us/windows/end-of-support)
- [GitHub repository licensing](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)

Official references explain platform boundaries; repository findings above derive
from the pinned source. This review is not a completed runtime fix or release approval.
