# SSH scan performance and safety

Centra prepares a remote SSH source in three visible phases:

1. `ssh-connect` establishes and verifies the pinned SSH connection.
2. `ssh-inventory` walks the selected remote directory and applies exclusion rules before transfer.
3. `ssh-download` transfers accepted files through a bounded SFTP worker pool before local hashing begins.

## Choose the narrowest useful directory

Prefer the actual deployment directory, for example `/srv/application`, `/var/www/site`, or `/opt/service`, instead of the server root `/`. A root scan can contain hundreds of thousands of files and is inherently slower.

When `/` is selected, Centra skips `/proc`, `/sys`, `/dev`, and `/run`. These are virtual Linux filesystems and can expose streams, devices, or changing pseudo-files that are unsuitable for a deterministic integrity manifest.

Selecting one of those directories explicitly remains possible. The automatic skip applies only when scanning `/`.

## Exclusions are applied before transfer

Directory exclusions such as `.git/**`, `node_modules/**`, `_build/**`, `target/**`, and `uploads/**` prune the remote tree before Centra downloads files. This avoids transferring data that cannot appear in the final manifest.

## Bounded parallel transfer

Centra uses the profile worker count for SSH transfer, capped at eight concurrent SFTP channels. The cap prevents a scan from overwhelming the SSH server while still avoiding one-file-at-a-time transfer.

Each remote directory listing and file transfer has a timeout. A stalled pseudo-file or network operation therefore produces a clear error instead of leaving the interface indefinitely on `scanning`.

After transfer, hashing uses the existing bounded local worker pool. Temporary snapshots are removed when the scan completes or fails.
