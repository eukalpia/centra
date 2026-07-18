# Saved SSH connections

The SSH source chooser opens the connection library before the connection form.

Each saved entry has a human-readable name and stores only non-secret configuration:

- host, port, and user;
- authentication method;
- private-key file path;
- pinned host-key type and SHA-256 fingerprint;
- connection and keepalive timeouts;
- last selected remote directory;
- favorite, tags, and recent-use timestamps.

Passwords and private-key passphrases are session secrets. They are requested when needed, retained only in process memory for the current Centra session, and never written to the SSH library, a profile, a manifest, a report, a log, or an archive.

The library supports adding, naming, opening, duplicating, and deleting entries. A successful connection updates the pinned host fingerprint, last directory, and recent-use timestamp. Connections with a changed pinned host fingerprint fail closed.
