# Implementation plan

Date: November 17, 2026. Baseline: `24944a89db2c5ed185154ee49850ca535b183b10`.
Status: implementation order approved by the owner. The first scan-only boundary is implemented on a separate review branch; see Preview Validation.md. Remaining runtime work is open.

## Proposed pull request order

Use a separate branch for each pull request. Branch identifiers follow Git's path
conventions; document names use spaces. Each PR names affected OS settings,
permissions, preconditions, preview behavior, validation, limitations, and unresolved
risks. Never merge without the owner's review.

| Order | Proposed branch | Scope | Required evidence |
|---|---|---|---|
| 0 | `review/safety-foundation` | This static review, grouped backlog, local binary inventory and test strategy. No runtime changes. | Check evidence links, hashes, original runtime file identity and absence of host-changing tests. |
| 1 | `fix/consent-and-claims` | Correct README/UI/launcher claims, stop recommending warning bypasses, explain restricted environments, establish read-only default and a server-enforced modification boundary. Direct profile/recovery entry points require owned/administered-device authorization too. | Route classification and negative tests for every mutation, denied consent, managed/unknown policy state, and no persistent data by default. |
| 2 | `fix/reviewed-actions` | Replace arbitrary browser script execution in both Script Builder and Family Plan with reviewed action IDs and schemas; gate unsupported legacy actions explicitly. Enforce HTTP methods, Origin policy, bounded streaming bodies, timeouts, and safe execution-file handling. | Tests reject unknown IDs, extra parameters, script text, wrong method/origin/token/Host, malformed/oversized/chunked inputs, and temporary-file replacement. No elevation in CI. |
| 3 | `fix/verified-transactions` | Durable action-specific original/applied journal, readback verification, user SID binding, strict errors, native/CIM exit checks, crash recovery and conflict-aware restore. Wire all action entry points to it before enabling them. | Failed/incomplete snapshots cause zero mutations; failure injection and restore assertions pass; disposable Windows VM evidence for each enabled action. |
| 4 | `feat/portable-guest-mode` | Explicit Scan this PC consent, collection availability, read-only operation, optional HTML/JSON export, redaction, memory-only state, visible stop and child-process tracking. No elevation, cleanup, mobile pairing or persistence. | All mutation endpoints denied in Guest Mode; filesystem/process/network observations show only declared behavior. |
| 5 | `chore/release-foundation` | Security policy, contribution guide, compatibility/privacy/recovery/uninstall docs, CI, dependency notices and release checksums. License after ownership and component review. | Foundation CI and required VM matrix pass; binary provenance is resolved or distribution remains blocked; owner approves candidate release. |
| 6 | `design/secure-session-usb` | Separate threat model and helper specification before any helper installation code. Distinct second drive, visible pairing/consent, host-durable recovery, supported settings and identity assumptions. | Owner reviews the exact temporary profile, helper privileges, key storage and recovery design. |
| 7 | `feat/secure-session-prototype` | Owned dedicated VMs only. Implement enrolled helper, verified USB credential, serialized transitions, loss detection and recovery. | Unplug/crash/reboot/conflict/adversarial profile tests, external VM checkpoints and restore evidence. No production readiness claim. |
| 8 | `feat/disposable-workspace` | Optional Sandbox launcher only where supported, approved and already enabled. | No sensitive mappings; explicit network/clipboard/device settings; verify workspace disposal and explain host/network log persistence. |

Add pure unit-test fixtures and non-elevated CI with the relevant implementation
PR, rather than waiting until after changes are enabled. Keep unvalidated actions
unavailable in modification mode; present the reason and manual guidance. Retain
legacy feature intent for migration, without exposing unrestricted scripts through
the ordinary dashboard. This is a behavior change that needs explicit release notes.

## Grouped issue list

This is the review's issue list, not a claim that every feature is implemented.
All runtime items are open. IDs match the handoff for traceability.

| Priority | IDs | Work package | Completion gate |
|---|---|---|---|
| P0 | P0-01,04 | Verified snapshots and truthful action outcomes | Missing helper, denied privilege, full/read-only/detached USB, inaccessible state, partial file, and native/CIM failures prevent false completion and unsafe continuation. |
| P0 | P0-02,05 | Restore ownership, conflicts and recovery coverage | Original/applied values recorded per target; third-party changes preserved; defaults separate; unsupported restoration stated precisely. |
| P0 | P0-03,07,12 | Execution, policy and permission boundaries | Both raw-script routes replaced/gated; every mutation covered; restricted application control respected; no silent protection downgrades. |
| P0 | P0-06 | Destructive operations separated | Preview and opt-in required; deletions, app upgrades/removal and network resets barred in Guest/Secure Session. |
| P0 | P0-08 | Evidence and uncertainty | Query failures cannot become protected/healthy; contextual port findings; heuristic score explained. |
| P0 | P0-09,10 | Provenance, license and release trust | Per-file origins, hashes, licenses/notices and redistribution obligations resolved; security policy, CI and release checklist available. |
| P0 | P0-11 | Consent and data protection | No-save mode, explicit retention, redaction, threat model for optional encryption and documented outbound behavior. |
| P1 | P1-01 through 04,07,08 | Read-only dashboard, reviewed actions, journal, capability detection, Guest Mode and test foundation | PRs 1-4 pass the foundation test gates. |
| P1 | P1-05,06,09,10 | Plain-language evidence, HTML/JSON export, release docs and encrypted backup/report option | Export schema/redaction fixtures, license review and encryption/recovery tests. Do not roll custom cryptography. |
| P2 | P2-01 through 04 | Defender/ASR/SmartScreen status, scoped firewall/exposure, updates and inventory | Read-only providers, official references, availability states, and no auto updates. |
| P2 | P2-05 through 08 | Accounts/privileges, startup/tasks, logs/backups/encryption status and signature inspection | No secrets/recovery keys exported; unsigned does not mean malicious; platform-specific fixtures. |
| P2 | P2-09 through 12 | Process connections, consented timeline, opt-in hash reputation and offline knowledge base | No automatic file uploads; privacy/terms preview; dated official references. |
| P3 | P3-01 through 05,08 | Enrollment, credential verification, allowlisted temporary actions, durable recovery and host/USB separation | Dedicated-VM prototype only after transaction foundation and owner-reviewed specification. |
| P3 | P3-06,07 | Sandbox and guest privacy guidance | Capability detection, explicit launch, no zero-trace or Tails equivalence claims. |
| P4 | P4-01,02,09,10 | Honest platform parity, accessibility, independent feature modules and evidence-driven assistant | Capability flags, keyboard/high-contrast tests, separation of health/family/mobile modules, labeled optional AI advice. |
| P4 | P4-03 through 06 | Pester/analyzers, pytest/ruff/bandit where useful, JS checks, CI, signed/verified releases and demonstrations | Appropriate tests pass; elevated evidence comes from disposable VMs, not hosted CI host modifications. |
| P4 | P4-07,08 | Vetted plugin manifests and versioned official baselines | No arbitrary execution by default; trust/update policy and benchmark licensing review. |

## Secure Session design constraints

The prototype must start with no host-changing actions enabled. Defender/firewall
status is best checked continuously; enabling a protection that should remain on
is not automatically a suitable temporary action. A useful first prototype can
validate enrollment, visible session state and recovery with synthetic settings in
a dedicated VM before approving any real security setting.

Ordinary storage with a software secret can be copied. A signed profile alone does
not prove the physical drive's authenticity. Specify the actual threat model:
paired-volume recognition with acknowledged clone risk, or a hardware-backed key
for stronger device proof. Do not promise challenge-response authenticity from
a drive serial number, drive letter or an extractable file. A malicious host/admin
can observe or alter the session; this feature does not protect against that host.

Proposed state sequence: not paired, authorized detected, preparing, active,
restoring, restored, or restoration needs attention. Persist a write-ahead intent
before each change and a verified applied result afterward. Serialize operations;
make recovery idempotent rather than assuming USB events arrive exactly once.
An ambiguous crash window must trigger re-read and conservative reconciliation,
not blind replay. No new session while restoration is unresolved.

Host-durable ACL-protected recovery state is mandatory and must survive drive loss.
USB recovery copies are optional and encrypted only through a reviewed mechanism.
Reject replayed credentials/profiles, revoke enrollment visibly, and provide a
documented uninstall/recovery path. Removal, reboot, sleep and helper restart all
reconcile incomplete journals before another action. Never erase audit logs.

## Decisions still needed before the corresponding implementation

- Root source license and evidence for third-party redistribution rights.
- Exact personally owned test hosts and available Windows VM images.
- Which useful temporary actions merit the additional restore risk.
- USB credential assurance level and clone-risk expectations.
- Encryption/recovery-key handling, optional USB copies and report retention.

Defaults remain a distinct second USB, read-only unprepared hosts, visible opt-in
on owned devices, no deletion/stealth, and no automatically enabled Sandbox feature.
These open decisions do not block documentation, inventory or safe test scaffolding.

## Owner update: three distinct drives

The owner requested a third physical drive for a disposable workspace. See
[Three USB Modes](Three%20USB%20Modes.md) for the updated specification. This separate
live-OS proposal requires authorized external boot and is not a zero-trace Windows
insert feature. The optional Windows Sandbox experience remains a weaker, separate
Windows-hosted option; it is not the third drive or a replacement for live boot.
