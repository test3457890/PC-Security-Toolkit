# Download and run

All implementation source and documentation are together on the
`fix/portable-guest-boundary` branch while the owner reviews the PR. Main still
contains the original v3.1 code until an explicit reviewed merge.

## Choose one download

- [Complete preview branch ZIP](https://github.com/test3457890/PC-Security-Toolkit/archive/refs/heads/fix/portable-guest-boundary.zip): contains the entire source tree, including legacy source. Extract everything first and use only START HERE for scan-only mode.
- For a smaller, curated preview, open the latest successful [Guest safety checks run](https://github.com/test3457890/PC-Security-Toolkit/actions?query=branch%3Afix%2Fportable-guest-boundary). Under Artifacts, download `PC Security Toolkit Preview`. GitHub may require sign-in to download artifacts. The outer artifact ZIP contains the application ZIP and SHA256SUMS.txt. Extract both layers.

The curated package contains the three OS launchers, required engine files, dashboard,
all review/status/USB guides and PACKAGE CONTENTS.json in one PC Security Toolkit
folder. It excludes legacy profile/recovery launchers, the legacy dashboard and all
third-party binaries. Their source stays in GitHub for reviewed migration. Do not
mix files from different branches or releases.

The smaller preview has no automatic security helper or bootable OS image. A source
ZIP cannot prepare three working USB products. Those two components remain unbuilt.
No USB formatting, partitioning or imaging tool is provided or invoked.

## Run it from a folder or an existing USB

1. Extract into a new folder on the computer or a USB drive that already has space.
   Copying the folder does not require reformatting the drive. Keep your existing
   files separate. There is no installer.
2. Windows: open START HERE Windows.bat. Windows PowerShell must be available and
   device policy must allow the script. No policy is changed or bypassed by this
   launcher. A blocked script needs an approved administrator option, not disabling
   OS protections. Do not run Guest Mode as administrator.
3. macOS: open START HERE Mac.command, or run it with bash from Terminal if executable
   permissions were not retained by the ZIP extractor. Linux: run
   `bash "START HERE Linux.sh"`. Python 3 must already be available. No dependency
   downloads or package installation occur automatically.
4. The launcher opens the default browser to loopback. If browser opening fails,
   copy the URL printed by the launcher. The server stays in that launcher window.
5. Confirm authorization, then choose Scan this PC. No scan runs merely by opening
   the dashboard. Seven themes are session-only. JSON export is optional and may
   save to the browser's Downloads folder, not automatically to USB.
6. Choose End session and confirm the launcher has finished. Windows may keep a
   Press any key prompt open after the server exits. Close the page and use the OS
   safe-eject action. If End session cannot connect, close/stop the launcher before
   ejecting. Do not pull the drive during extraction or a report download.

Closing the browser tab alone does not stop the toolkit. No code scans, formats,
repairs, partitions or writes raw disks during startup. Read-only scans can still
cause ordinary OS/browser activity records. Physical hardware/USB failures and all
standard-account Windows configurations have not been validated.

## Verify and build

Compare the application's SHA-256 with SHA256SUMS.txt from the same successful run.
On Windows, use `Get-FileHash -Algorithm SHA256` on the application ZIP; on macOS,
`shasum -a 256`; on Linux, `sha256sum`. Hashes detect corruption relative to the
published checksum; they do not authenticate a maliciously replaced checksum.
The manifest records every included file's size/hash, build revision and missing
future components. No real user reports, logs, configuration or backups are packed.

Developers can run `python "Build Preview.py" --output Dist` from the source tree.
An existing archive/checksum is never overwritten. Select a new output directory
for another build. Building needs Python 3; running the Windows package does not.
No binary release/license decision is implied by this source-preview artifact.
