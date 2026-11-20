# Contributing

Use a feature branch and a small pull request. The owner reviews every PR before
merge. Preserve useful feature intent while migrating legacy actions behind reviewed
permissions and verified recovery. Do not add arbitrary script execution or promise
full protection, full rollback, anonymity or zero traces.

For runtime changes, explain the trigger, resulting behavior, affected host settings,
permissions, preconditions, preview/dry-run, structured failures and limitations.
Backup failure must stop reversible-mode mutations. Restore must preserve later
external changes. Follow Docs/Safety Test Plan.md for disposable-VM evidence.

Run fixture Python/HTTP/JavaScript checks and Windows pure policy/parser checks as
described in README.md. These may run in CI. Do not execute elevated profiles or
change runner security settings as integration tests. Use dedicated VMs instead.

Do not upload real reports, logs, snapshots, credentials, keys or user/device data.
Use spaces in readable document/script names when platform conventions permit.
Keep conventional Python test/workflow names where required for tool discovery.

License and bundled-binary provenance decisions remain unresolved. Do not add a
blanket source license over dependencies, redistribute optional proprietary tools,
or publish a release archive without resolving component obligations.
