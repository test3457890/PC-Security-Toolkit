# Scan-only preview validation

Main implements the first runtime boundary after the source review. This is
not completion of the entire backlog or validation of the older changing features.

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

## November 19 engineering update

The branch incorporates main's documentation and nine historical fixture images.
The gallery is retained and explicitly labeled legacy/SIMULATED. No historical
files were deleted or moved; references remain valid.

Runtime changes distinguish missing/unrecognized/failed selected scan observations
from false values. Windows firewall needs all three readable profiles; selected
Defender/UAC/BitLocker/Secure Boot flags preserve unknowns. macOS command failures
remain unknown. Linux does not infer root encryption from another encrypted device,
infer effective firewall rules from service presence, or declare automatic updates
disabled merely because no known service is active. Port findings request review.
Other legacy fields still have incomplete availability semantics.

The page displays selected control observations and clears old evidence on failed
or malformed rescans. Server errors omit internal exception text. Origin checks
match the validated Host, including localhost, without allowing cross-host origins.

Local actual execution: 19 Python tests pass, including fixture HTTP, JavaScript VM,
failure/unknown-state tests, package checks and extracted-server startup/shutdown.
Fixtures do not constitute actual Windows/macOS scan execution. Windows parsing,
pure policy/observation functions and extracted Windows startup require exact-commit
CI confirmation. Real Windows scans, UI and hardware remain Not tested.

An actual Linux container scan also completed in an isolated Python environment
using an empty temporary HOME. All five selected control states were unknown and
no findings were returned; this is incomplete coverage, not a clean security result.
Toolkit file timestamps/list remained unchanged by the scan (Python bytecode
caches excluded). This does not establish behavior on a normal desktop or prove
the absence of operating-system traces or network activity.

A local credential-pattern scan found zero matches across 105 historical Git
blobs for private-key headers and selected GitHub/OpenAI/AWS key formats. This is
a limited static scan, not a guarantee against secrets or personal information.
All 34 bundled PE file sizes/hashes match the existing inventory; their origin,
Authenticode trust, licenses and vulnerability status remain unverified. Runtime
preview dependencies are Python standard library and Windows PowerShell; Node is
needed for tests. No third-party package manifest/lockfile is present to audit.

## November 20 visual update

[Hosted Chromium run 44852281840](https://github.com/test3457890/PC-Security-Toolkit/actions/runs/44852281840)
loaded the preview server, checked the consent gate and sample rendered controls,
and captured three images for the [preview gallery](Screenshots/Preview/README.md).
The sample results were intercepted with a visibly labeled CI test fixture. The
mobile capture led to a readable stacked layout for the USB roles. These checks
do not establish real Windows scanner, hardware, or USB behavior. The local browser
could not access the executor's loopback server, so the hosted run was used for
visual evidence. The main-branch guest safety check passed after the earlier
preview merge. Device-specific testing remains in the
[Windows checklist](Windows%20Testing%20Checklist.md).

Repository visibility is public, default branch main, and no root license or
binary release approval is implied. GitHub branch-protection details were not
fully readable through the connector during the earlier review. Bundled binary
provenance and redistribution obligations remain unresolved.

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

No runtime security action is enabled merely because CI passes. Follow the
implementation order and complete device-specific review before any release.
