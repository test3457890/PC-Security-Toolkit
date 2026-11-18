# Safety test plan

Date: November 17, 2026. Status: proposed test strategy, not executed Windows evidence.
Review baseline: `24944a89db2c5ed185154ee49850ca535b183b10`.

## Environment boundaries

Do not run profiles or recovery changes on a personal, school, employer or shared
machine for testing. Use disposable, owned/administered Windows VMs with synthetic
accounts and data, a VM checkpoint and a separate recovery console. Hosted CI runs
parsing, mocks and fixtures only, without elevation or security-setting changes.
Do not weaken Defender, application control, Secure Boot, UAC or firewall to make
tests run. A blocked test is evidence of an unsupported capability, not a reason
to bypass policy.

Sandbox can support selected isolated experiments where available. Use dedicated
VMs for host-helper install/uninstall, USB pass-through, boot recovery and effective
domain/MDM-policy behavior. A normal VM result is not physical USB removal evidence.

## Test layers

1. Static checks: Windows PowerShell 5.1 parsing, PSScriptAnalyzer, Python AST,
   appropriate Python lint/security checks, extracted inline JS syntax, dependency
   inventory and documentation references. Parser success is not behavior validation.
2. Pure unit tests: action schemas, compatibility results, unavailable evidence,
   redaction, journal validation/versioning, transitions, policy gates, ownership and
   conflict decisions. Use fake registry/services/files/network adapters/tasks.
3. Non-elevated API tests: isolated loopback servers with synthetic providers and
   temporary data roots; exercise every route's permission and HTTP contract.
   Never import a module that starts the real server or touches real host controls.
4. Windows VM integration: enable one reviewed action at a time, capture actual
   original state independently, preview, apply, verify, restore, then compare
   affected and unaffected state. Revert VM checkpoints between destructive faults.
5. Release acceptance: owner reviews PR, CI and VM evidence, dependency/license
   status, known limitations, recovery/uninstall instructions and checksums.

## Required behavioral cases

| Area | Test cases | Required result |
|---|---|---|
| Guest boundary | Every mutation route and direct entry point, forged UI state, absent/withdrawn consent, standard account | Read-only session never elevates, installs, changes controls, pairs mobile devices, clears logs, starts external utilities or saves data without explicit consent. |
| API protection | Missing/wrong token/Host/Origin, allowed same-origin browser behavior, absent Origin under documented local-client policy, wrong method, malformed JSON, oversized declared and streamed/chunked body, timeouts | Deterministic rejection before action construction or unbounded allocation. No anonymous mutation. |
| Reviewed actions | Unknown action/version, arbitrary script text including Family Plan, unexpected fields, invalid paths/identifiers, changed manifest | Reject before elevation; no browser-supplied PowerShell accepted in ordinary mode. |
| Snapshot gate | Recovery module missing, access denied, incomplete privileged capture, disk full/read-only, drive disappears, truncated/wrong-host/wrong-user/corrupt/unsupported schema | Zero control mutations; precise failure result; an existing filename alone never counts as a verified backup. |
| Transaction faults | Error before/after each persisted intent, OS write and journal acknowledgement; killed worker; corrupt journal; repeated resume/event | Reconcile observed state conservatively; no duplicate changes; visible attention state for ambiguity. |
| Restore ownership | Another actor changes same target after apply; policy refresh; unrelated registry values/ASR/firewall rules added; targets disappear | Preserve external changes and raise conflict; touch only recorded session-owned settings. Never delete shared policy keys as a shortcut. |
| Verification | Cmdlet nonterminating/terminating error, native nonzero exit, CIM nonzero ReturnValue, tamper protection denial, readback mismatch | Machine-readable failure/partial state; never report protection or restore success from attempted commands. |
| Original-state fidelity | Missing vs present registry value, registry type, delayed service start, originally stopped service, DNS v4/v6, exact rule/task definitions, user SID | Exact originals restored where permitted, otherwise precise exception. No assumed Windows defaults. |
| Unplug and crash | Remove before snapshot, during flush, after snapshot, during apply, active, during restore; helper killed; reboot/power loss/sleep/replug | Host journal remains usable without USB; no unexpected network/security degradation; unresolved state blocks new sessions. |
| Privacy | Memory-only session, consented save, redaction of names/SIDs/device IDs/Wi-Fi/paths, retention, encryption success/failure/wrong key/lost USB | No unconsented toolkit persistence; exported data matches disclosed schema; secrets and encryption keys absent from exports/logs. OS artifacts may remain. |
| Stop and uninstall | Browser closes, listener stops, child action still running, helper uninstall during active/failed restore | Distinguish UI closure from completion; do not advise eject until toolkit work/writes finish; preserve recovery state if unresolved. |
| Optional dependencies | Missing/blocked/untrusted binary, offline Ollama, optional external tool/update launch | Useful unavailable states, no automatic downloads or protection bypass; external execution requires separate consent and provenance checks. |
| Sandbox | Unsupported edition/virtualization/policy, disabled feature, mapping/clipboard/network/device settings | Explain capability; do not enable features automatically; no sensitive host mappings or writable USB by default. |

## Minimum compatibility matrix

- Windows 11 Home and Pro, supported builds, standard/admin accounts, plus UAC
  using a different admin account. Record exact editions/builds and effective policy.
- Windows 10 with separate standard-support and verified/unknown ESU information.
  Some editions have different lifecycle dates. Never auto upgrade the host.
- Managed and locked-down simulations: domain/MDM policy, application control,
  constrained language, missing Defender APIs, Defender passive mode and blocked tools.
  Simulations are not proof against all real enterprise configurations.
- Offline, missing optional tools, failed module/API reads, non-English/localized
  output, non-ASCII paths and paths with spaces, multiple USB volumes and changed
  drive letters, read-only/full/detached removable media.
- macOS/Linux supported Python versions for read-only checks, capability flags,
  privacy/HTTP behavior and clean shutdown. Do not claim Windows modification parity.

Use pairwise coverage for routine compatibility combinations, but run every enabled
mutation's rollback and fault cases on each declared supported Windows target.
Document exclusions instead of silently dropping cases.

## Evidence format and release gate

For each elevated action, save test ID, source commit, VM image/build, privilege and
user SID, policy/capabilities, action version/parameters, independent before state,
preview, journal, injected fault, observed applied state, restore result and independent
after state. Include unaffected-control comparisons and reboot results where relevant.
Use synthetic identifiers and redact evidence before publishing. Never include
BitLocker keys, private USB credentials, real users or sensitive host data.

Any unsafe continuation after backup failure, unconsented change, silent restore
conflict, security downgrade or false success blocks enabling the action and blocks
release. A failed action remains unavailable until its defect and regression case
are resolved. CI cannot substitute for elevated VM evidence.

## Evidence available for this review

Only static/source and file checks can be performed in the current Linux workspace.
Windows PowerShell and a disposable Windows VM are unavailable. No Windows runtime,
elevation, effective-policy, USB-loss, restore, code-signing trust or packet-capture
test has been completed. Results of the documentation/inventory checks are recorded
in the review PR; future evidence must identify its actual runtime commit.
