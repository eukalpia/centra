# Threat model

## Assets

- Approved deployment baseline.
- Manifest authenticity.
- Signing private keys.
- Archive passwords.
- Source credentials and SSH configuration.
- Integrity history and audit evidence.

## Adversaries

- An attacker who modified production files.
- A malicious or compromised account with filesystem access.
- A compromised remote host that can falsify its own snapshot.
- A crafted archive containing traversal paths.
- A crafted profile attempting argument or shell injection.
- A crafted filename attempting terminal control output.

## Controls

- Generate authoritative baselines from reviewed build artifacts where possible.
- Sign canonical manifests and keep trusted public keys off the monitored host.
- Start subprocesses without a shell.
- Treat filenames and process output as untrusted display data.
- Normalize paths and reject archive traversal.
- Never persist ZIP passwords.
- Store signing private keys separately from manifests and monitored systems.
- Record exclusions in every manifest.
- Surface read failures rather than silently omitting files.
- Mark weak algorithms and checksums visibly.

## Limitations

- A baseline generated from a compromised source can faithfully describe compromised files.
- A remote host can potentially falsify data returned through its own operating system and tools.
- File hashing does not inspect memory-only malware, kernel compromise, database rows, or external services.
- A tar-based snapshot is not necessarily atomic while files are actively changing.
- Password-protected ZIP files are transport protection, not identity proof. Use signatures for authenticity.
