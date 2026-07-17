# Testing strategy

Centra's test suite is organized around the failure modes that can invalidate an integrity baseline.

## Unit tests

- Standard digest vectors for built-in cryptographic algorithms.
- Permanent `obsolete` classification and warnings for MD5.
- Glob matching, path normalization, hidden files, and secret exclusions.
- Profile validation and versioned JSON round-trips.
- First-run wizard state with no implicit algorithm or output selection.
- Deterministic manifest encoding and file ordering.
- Added, removed, modified, metadata-only, and unchanged comparisons.

## Integration tests

- Multi-algorithm scanning of temporary projects.
- Exclusion enforcement during real directory traversal.
- Worker-count determinism.
- Symlink recording policy.
- External command algorithms through a fake command runner.
- SSH, Docker container, Docker image, and Compose command construction.
- Safe tar extraction and traversal rejection.
- Canonical JSON, compatibility text, audit report, and encrypted ZIP outputs.
- Ed25519 key generation, signing, verification, and tamper rejection.
- Atomic settings and profile persistence.

## CI matrix

Every push to `main` and every pull request runs formatting, static analysis, tests, and native executable compilation on:

- Ubuntu
- macOS
- Windows

The quality gate requires all three operating systems to pass before a release is tagged. A release tag builds native executables and SHA-256 checksum files for all supported runner platforms.
