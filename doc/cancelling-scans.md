# Cancelling scans

A running Centra scan can be stopped from the progress panel or with `Esc`.

Cancellation is cooperative across source inventory, SSH authentication, SFTP directory traversal, SFTP file streams, local hashing, external checksum commands, Docker snapshot commands, and output preparation. Active SSH/SFTP channels and managed child processes are closed, prepared sources are disposed, and temporary snapshots or per-file mirrors are removed.

`Stop scan` returns to the selected profile. `Stop and change directory` performs the same cleanup and then opens the source picker so another local, SSH, Docker, image, or Compose directory can be selected without recreating the profile.
