# SSH sources

Centra can connect to an SSH server, browse its filesystem over SFTP, select a remote root, download a temporary snapshot, and run the same integrity pipeline used for local and Docker sources.

The SSH transport is implemented inside Centra. An external `ssh`, `scp`, `sftp`, shell, or `tar` executable is not required on the local computer or the remote server.

## Interactive setup

Choose **SSH folder** as the source and open **Configure SSH**.

The connection screen supports:

- hostname, IPv4, or IPv6 address;
- ports from `1` to `65535`;
- username;
- password authentication;
- private-key authentication;
- password and private key together;
- encrypted private keys with a passphrase;
- configurable connection timeout;
- configurable keepalive interval;
- connection testing before a profile can be saved;
- verified server fingerprints;
- remote directory browsing with keyboard and mouse.

After authentication succeeds, Centra displays:

- the negotiated SSH server version;
- the host-key algorithm;
- the OpenSSH-style SHA-256 fingerprint;
- the current remote directory;
- its child directories.

Keyboard controls in the remote browser:

| Key | Action |
| --- | --- |
| `Up` / `Down` | Move through directories |
| `Enter` / `Right` | Open the selected directory |
| `Backspace` / `Left` | Open the parent directory |
| `Space` | Select the current directory |
| `R` | Refresh the current directory |
| `Esc` | Return to connection settings or cancel |

Mouse selection and directory opening use the same navigation state as keyboard input.

## Host-key verification

Centra uses trust-on-first-use only during the first interactive connection:

1. The server presents its host key.
2. Centra displays the key type and SHA-256 fingerprint.
3. The user reviews the connection and chooses a remote directory.
4. The fingerprint is stored in the profile.
5. Every later scan requires an exact fingerprint match.

If the server key changes, Centra rejects the connection instead of silently accepting the new key. Confirm the change through a trusted channel before creating a new profile or replacing the pinned fingerprint.

## Secrets

Passwords and private-key passphrases are never written to:

- profile JSON;
- manifests;
- reports;
- logs;
- ZIP packages.

During interactive setup, secrets are retained only in application memory for the current Centra process. After Centra is restarted, password-based profiles request credentials again before scanning.

Private-key file paths may be stored because they are configuration, not secret material. The private key itself is never copied into a Centra profile.

## Non-interactive scans

Use environment variables to provide secrets without placing them in command history:

```powershell
$env:CENTRA_SSH_PASSWORD = Read-Host -AsSecureString | ConvertFrom-SecureString -AsPlainText
centra scan --profile production --ssh-password-env CENTRA_SSH_PASSWORD
Remove-Item Env:CENTRA_SSH_PASSWORD
```

For an encrypted private key:

```powershell
$env:CENTRA_SSH_KEY_PASSPHRASE = "temporary-value"
centra scan --profile production `
  --ssh-key-passphrase-env CENTRA_SSH_KEY_PASSPHRASE
Remove-Item Env:CENTRA_SSH_KEY_PASSPHRASE
```

A profile using both methods can provide both options:

```bash
CENTRA_SSH_PASSWORD='temporary-value' \
CENTRA_SSH_KEY_PASSPHRASE='temporary-value' \
centra scan \
  --profile production \
  --ssh-password-env CENTRA_SSH_PASSWORD \
  --ssh-key-passphrase-env CENTRA_SSH_KEY_PASSPHRASE
```

Prefer the secret store provided by the CI platform instead of literal values in workflow files.

## Snapshot behavior

Centra walks the selected remote directory through SFTP and downloads regular files into an isolated temporary directory. It applies safety limits to directory depth and total entry count and rejects unsafe remote names or paths that could escape the snapshot directory.

Symbolic links are recreated when the local platform permits it. If local link creation is unavailable, Centra records the link target in a dedicated fallback file rather than following an untrusted link during transfer.

The temporary snapshot is removed after scanning, whether the scan succeeds or fails.

Remote permission bits and modification times are not currently emitted as local metadata. Centra deliberately omits those values for SSH snapshots rather than reporting timestamps or modes belonging to temporary local files.

## Troubleshooting

Run:

```bash
centra doctor
```

The output reports the built-in SFTP transport. Docker availability is checked separately because Docker sources still require the Docker CLI.

Common failures:

- **Authentication failed:** verify the selected authentication method and credentials.
- **Private key cannot be read:** verify the path, key format, and passphrase.
- **Host fingerprint mismatch:** stop and verify whether the server key changed legitimately.
- **Connection timeout:** verify the address, port, firewall, VPN, and timeout value.
- **Permission denied while browsing:** the SSH account cannot read the selected directory.
- **Connection closed during snapshot:** check keepalive settings and server-side idle limits.
