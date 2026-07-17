# Security policy

## Reporting a vulnerability

Do not publish exploit details in a public issue. Send a private report through GitHub's security advisory interface for this repository. Include the affected version, platform, reproduction steps, expected behavior, actual behavior, and security impact.

## Trust boundaries

Centra processes untrusted filenames, directory structures, archive entries, command output, profile files, and manifest files. The project treats these as data rather than shell fragments.

Key rules:

- External processes are started with argument arrays and `runInShell: false`.
- Custom hash commands require an explicit executable and argument list.
- Archive paths are normalized and traversal entries are rejected.
- Passwords are not accepted as CLI values.
- ZIP passwords are supplied at execution time and are not persisted.
- SSH authentication is delegated to OpenSSH.
- Private signing keys are written with restrictive permissions on Unix-like systems.
- Digest comparison uses constant-time string comparison.
- Remote sources are materialized into disposable temporary directories.
- Temporary source directories are removed after scanning, including failure paths.

## Algorithm warnings

Availability does not imply security suitability.

MD2, MD4, and MD5 are marked obsolete. SHA-1, RIPEMD-160, and Tiger are marked legacy. CRC-32 and Adler-32 are marked non-cryptographic checksums. Centra preserves these options for compatibility but does not suppress their warnings.

For intentional tamper detection, use a modern digest and sign the canonical manifest. A bare digest list does not authenticate who created the baseline.

## Supported versions

Until the first stable release, security fixes are applied to the latest development version on the default branch.
