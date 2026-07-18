# Production scan workflow

Centra treats a scan as a controlled, cancellable operation rather than a single blocking command.

## Lifecycle

1. Connect to the selected source.
2. Build one reusable inventory and estimate.
3. Show file count, byte size, exclusions, safety warnings, and an estimated duration.
4. Wait for explicit confirmation.
5. Stream accepted file contents through all selected hash algorithms.
6. Detect files that change while being read.
7. Write the manifest and selected artifacts.
8. Show a structured result with errors and unstable files.

Cancelling is cooperative across directory traversal, SFTP transfer, hashing, external hash commands, Docker snapshot commands, and artifact preparation. Cancellation closes active SSH/SFTP resources and removes temporary files.

## Verification modes

`full` reads and hashes every accepted file.

`fast` reuses a trusted baseline digest only when all requested algorithms are present and the current size, modification time, mode, and symbolic-link target match the baseline. Fast verification is weaker than full verification and must be presented as such in the interface.

## Remote streaming

SSH files are hashed directly from their SFTP stream. Centra does not create a complete remote snapshot first. A temporary per-file mirror is created only when an explicitly configured external hash command requires a local file path, and that mirror is removed immediately after the file is processed.

Standard SFTP metadata does not provide a portable inode or filesystem device identifier. Remote changed-during-scan checks therefore compare size, modification time, and mode before and after reading. The one-filesystem option is best effort for SSH sources; Linux virtual filesystems are excluded from root scans.

## Trusted baselines

A profile may reference a canonical manifest, its Ed25519 signature document, and a trusted public key document. Centra verifies both the signature and the embedded public key before using the manifest for comparison or fast verification. Signer, release commit, and build metadata are recorded in the resulting manifest.

## Saved SSH connections

The SSH library stores named endpoints, ports, users, authentication method, private-key path, pinned host fingerprint, last remote directory, tags, favorite state, and recent-use timestamps. Passwords and private-key passphrases are never serialized and are requested for the current session only.
