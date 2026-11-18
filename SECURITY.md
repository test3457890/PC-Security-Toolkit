# Security reporting

This project is an experimental security assessment utility. Only the scan-only
preview boundary is being tested. Legacy modifications/recovery and the proposed
host helper/live workspace have not passed the required VM validation.

For a suspected vulnerability, use GitHub's private Report a vulnerability option
if available. If private reporting is unavailable, open an issue asking for a private
contact without exploit details or sensitive data. Never post tokens, device reports,
host/user identifiers, backups, family PIN data, credentials or recovery keys publicly.

Include the commit/version, affected platform, minimal fixture reproduction, expected
and actual behavior, and whether any host setting or data was affected. Test using
disposable environments and synthetic data. Do not test on systems without permission.

No response-time SLA, security certification or supported production release is
currently offered. Review the known gaps in Docs/Safety Review.md. A security-tool
label does not make arbitrary scripts, binaries, modifications or rollback trustworthy.
