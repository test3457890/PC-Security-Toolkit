# Scan-only preview validation

This branch implements the first runtime boundary after the source review. It is
not completion of the entire backlog. Main must remain unchanged until owner review.

## Implemented

- Dedicated scan-only dashboard, explicit collection/authorization consent, seven
  session-only themes, optional full/restricted JSON export and visible stop request.
- Default Windows/macOS/Linux server allowlists. Legacy mutation, script, cleanup,
  mobile/family, external-tool, persistent-report/config and Ollama routes are denied
  before dispatch. No hidden owner/developer switch bypasses this boundary.
- Per-route methods, same-origin browser POSTs, token/Host checks, 4096-byte JSON
  request limits, malformed-body errors and body read timeouts.
- No automatic toolkit log/config/report writes or log pruning in the served mode.
- Accurate README/start instructions and a three-USB design with explicit status.

## Validation scope

The Python HTTP suite runs a real loopback fixture server with both scan providers
mocked. It checks every legacy Windows route discovered in source, denied writes,
permission/token/Host/Origin/method checks, oversized/invalid JSON, no toolkit
persistence/pruning, dashboard delivery and shutdown. It parses Python and checks
dashboard JavaScript syntax. It never runs a real scan or OS-changing command.

Windows checks parse all PowerShell files and execute only the pure Guest Policy
functions with route/method/consent fixtures. Integration placement is checked without
starting the Windows engine in that policy test. A separate package integration test
builds and extracts the curated ZIP into a path with spaces and a non-English character,
starts the actual platform server without opening a browser, checks denied mutations
and pre-scan consent, then shuts it down. It verifies that toolkit file bytes and the
file list are unchanged. It never calls the real OS scan or an elevated action.

Package tests verify file completeness, ZIP integrity, every manifest hash, reproducible
bytes, omission of legacy launchers/binaries, missing-file failure before startup, and
refusal to overwrite an existing build. CI runs these on Windows/macOS/Linux. A package
artifact is uploaded only after all platform suites and PowerShell checks pass. Inspect
the matching CI run rather than assuming success from workflow presence. Standard-user
Windows runtime, actual scans, physical media and elevated VM evidence remain unavailable.

## Remaining release blockers

1. Legacy standalone profiles, downloaded/generated legacy scripts and Recovery
   entry points still have the verified snapshot, conflict and coverage gaps. Their
   source is retained; they must not be treated as part of the safe Guest boundary.
2. Windows standard-user permissions and actual scan behavior need dedicated-VM
   verification. Hosted-runner startup/API checks do not prove all host configurations
   or scan providers have no unintended OS effects.
3. Legacy findings still need explicit availability states and evidence review. The
   new UI discloses this and does not display the custom score as a security grade.
4. No temporary OS-change action registry or verified transaction engine is shipped
   yet. Thus no Secure Session helper, USB enrollment, autoactivation or crash recovery.
5. No live OS image is built. The third USB's RAM storage, host-disk isolation, boot
   compatibility, network behavior and disposal properties remain unverified goals.
6. License, upstream binary provenance/obligations, encryption design, code signing,
   complete redacted HTML export and packet-capture review are still pending.

No runtime security action is enabled merely because this PR or CI passes. Follow
the reviewed implementation order and obtain owner review before each merge/release.
