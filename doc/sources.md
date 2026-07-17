# Source adapters

## Local directory

The selected directory is scanned directly. Project detection runs before the profile is saved and proposes exclusions. The operator can edit every proposed rule.

## SSH directory

Centra invokes the installed `ssh` client with strict argument separation and runs `tar` on the remote host. Standard OpenSSH configuration, host-key checking, keys and hardware tokens remain under OpenSSH control.

Centra does not store SSH passwords.

## Running Docker container

Centra invokes `docker exec` and streams a tar archive of the selected path into a local temporary snapshot.

## Docker image

Centra creates a temporary container without starting the image's entrypoint, copies the selected path as a snapshot, and removes the temporary container.

## Docker Compose service

Centra resolves the requested service using `docker compose`. A custom compose file and Docker context can be selected in the profile.

## Snapshot safety

Archive entries are normalized before extraction. Absolute paths, parent-directory traversal, and malformed segments are rejected. The temporary snapshot is removed after the scan.

Snapshots reduce inconsistency but do not provide filesystem-level atomicity. Databases and frequently changing runtime data should be excluded or captured through application-specific backup/snapshot mechanisms.
