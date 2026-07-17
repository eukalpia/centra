<div align="center">

# Centra

**File integrity, deployment verification, and manifest management for local, remote, and containerized systems.**

[![CI](https://github.com/eukalpia/centra/actions/workflows/ci.yml/badge.svg)](https://github.com/eukalpia/centra/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-64D8CB.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.5-0175C2?logo=dart)](https://dart.dev)
[![Cinder](https://img.shields.io/badge/TUI-Cinder-11161D)](https://github.com/eukalpia/cinder)

</div>

Centra creates reproducible integrity manifests, verifies deployed files against approved baselines, packages compatibility reports, and signs manifests. It has an interactive Cinder interface for operators and a deterministic command-line interface for automation.

Centra does **not** silently choose a hash algorithm. The first-run wizard requires an explicit source, algorithm set, exclusion policy, and output format.

## Install

No cloning or manual compilation is required. With Dart 3.10 or newer:

```bash
dart install https://github.com/eukalpia/centra.git --overwrite
```

Then launch Centra from any directory:

```bash
centra
```

For Dart 3.5 through 3.9:

```bash
dart pub global activate --source git https://github.com/eukalpia/centra.git --overwrite
```

Run the same installation command again to update Centra. See [Installation](doc/installation.md) for PATH troubleshooting and uninstall commands.

## What Centra handles

- Local directories.
- Remote directories over OpenSSH.
- Running Docker containers.
- Docker images through isolated temporary containers.
- Docker Compose services.
- Multi-algorithm hashing in one file read.
- Canonical JSON manifests and compatibility text manifests.
- Password-protected ZIP packages.
- Ed25519 manifest signatures.
- Added, removed, modified, and metadata-only file changes.
- Project-aware exclusions for Dart, Flutter, Node.js, Python, Elixir, Rust, Go, Java, .NET, PHP, Ruby, Git, and Docker.
- External command-based hash implementations for organization-specific algorithms.
- Keyboard and mouse interaction.
- Ten interface languages: English, Russian, Uzbek Latin, Uzbek Cyrillic, Turkish, Kazakh, Kyrgyz, Tajik, Azerbaijani, and German.

## First launch

The setup wizard asks for:

1. Interface language.
2. Source type.
3. Source path and connection or container details.
4. One or more hash/checksum algorithms.
5. Exclusion rules.
6. Manifest formats and archive settings.
7. Final profile review.

Nothing is preselected for the hash algorithm or manifest format.

```text
 CENTRA  Create first integrity profile                          4/7
 File integrity and deployment verification

 ┌ Setup ───────────────┐ ╔ Choose hash algorithms ═════════════════════════╗
 │ ✓ Language           │ ║ [ ] SHA-256 · 256-bit              RECOMMENDED ║
 │ ✓ Source             │ ║ [ ] SHA3-256 · 256-bit             RECOMMENDED ║
 │ ✓ Details            │ ║ [ ] BLAKE2b-512 · 512-bit          RECOMMENDED ║
 │ › Algorithms         │ ║ [ ] MD5 · 128-bit                     OBSOLETE ║
 │ · Exclusions         │ ║     MD5 is collision-broken. Compatibility only.║
 │ · Output             │ ║ [ ] CRC-32 · 32-bit                   CHECKSUM ║
 │ · Review             │ ║                                                    ║
 └──────────────────────┘ ╚════════════════════════════════════════════════════╝

 ↑↓ move  Space select  Enter continue  Esc back  Mouse supported
```

## Commands

```bash
centra                         # open the TUI
centra init                    # open the profile wizard
centra algorithms              # list algorithms and security status
centra profiles list
centra scan --profile <id>
centra verify --profile <id> --manifest approved.centra.json
centra diff before.centra.json after.centra.json
centra doctor
```

For an encrypted output package, pass the password through an environment variable rather than a command-line value:

```bash
export CENTRA_ZIP_PASSWORD='use-a-long-random-password'
centra scan --profile production --password-env CENTRA_ZIP_PASSWORD
```

Generate and use an Ed25519 signing key:

```bash
centra keygen \
  --id production-release \
  --private .centra/production.private.json \
  --public .centra/production.public.json

centra sign \
  --manifest output/application.centra.json \
  --key .centra/production.private.json \
  --output output/application.centra.sig.json

centra verify-signature \
  --manifest output/application.centra.json \
  --signature output/application.centra.sig.json \
  --public-key .centra/production.public.json
```

## Algorithm policy

Centra separates algorithm availability from algorithm suitability.

| Status | Meaning |
| --- | --- |
| `recommended` | Suitable modern baseline for new integrity manifests. |
| `acceptable` | Supported for interoperability; review organizational requirements. |
| `legacy` | Retained for existing procedures; should be paired with a modern algorithm. |
| `obsolete` | Cryptographically broken; compatibility only. |
| `checksum` | Detects accidental corruption, not deliberate modification. |
| `custom` | External implementation configured by the operator. |

MD5 is supported because some procedures still require it, but every Centra surface labels it **obsolete** and carries a collision warning. Centra allows an MD5-only compatibility profile, but it never presents that profile as cryptographic proof.

Built-in families include SHA-2, SHA-3, BLAKE2b, SM3, Whirlpool, RIPEMD, Tiger, MD2/4/5, CRC-32, and Adler-32. See [Algorithm policy](doc/algorithms.md).

## Sources

Centra never hashes a changing remote stream directly. Remote and container sources are first materialized into a temporary snapshot and then passed to the same scanner used for local directories.

```text
Local folder ──────────────────────────┐
SSH + tar ─────── temporary snapshot ──┤
Docker container ─ temporary snapshot ─┼─> policy -> inventory -> multi-hash -> manifest
Docker image ───── temporary snapshot ─┤
Compose service ── temporary snapshot ─┘
```

Source passwords are not stored in profiles. SSH uses the installed OpenSSH client and standard key handling. Docker access uses the installed Docker CLI and the selected Docker context.

See [Source adapters](doc/sources.md).

## Manifest outputs

Centra can produce:

- `*.centra.json` — canonical structured manifest.
- `hash_values.txt` — compatibility output when one algorithm is selected.
- `hash_values.<algorithm>.txt` — one text file per algorithm when several are selected.
- `*.report.json` — human/audit metadata report.
- `*.zip` — password-protected package containing selected outputs.
- `*.sig.json` — detached Ed25519 signature.

Every algorithm entry records its status and warning. Exclusions, source type, root, project type, file count, total bytes, read errors, permissions, modification times, and symlink policy are preserved where configured.

See [Manifest format](doc/manifest-format.md).

## Profiles and configuration

Centra stores profiles in the operating system's application configuration directory:

- Linux: `$XDG_CONFIG_HOME/centra` or `~/.config/centra`
- macOS: `~/Library/Application Support/Centra`
- Windows: `%APPDATA%\Centra`

A profile contains policy and non-secret connection metadata. It does not contain:

- SSH passwords.
- ZIP passwords.
- Private key material unless the operator explicitly chooses a separate key file.
- Environment files or application credentials.

## Automation

CLI commands use stable exit codes:

| Code | Meaning |
| ---: | --- |
| `0` | Success / verified. |
| `2` | Invalid command usage. |
| `3` | Integrity differences found. |
| `4` | Invalid profile or manifest configuration. |
| `5` | Source command unavailable or failed. |
| `6` | File-system error. |
| `7` | Invalid signature. |
| `70` | Unexpected internal failure. |

Example pipeline:

```bash
centra scan --profile release --json > scan-result.json
centra verify --profile production --manifest approved.centra.json --json
```

## Security model

An integrity manifest only has value when its baseline is trusted. The preferred workflow is:

```text
reviewed source -> reproducible build -> Centra manifest -> signature -> deployment
                                                     ↓
                                      later production verification
```

Creating a baseline from an already-compromised server merely records the compromised state. Keep approved manifests and public verification keys outside the monitored host.

Read [SECURITY.md](SECURITY.md) and [Threat model](doc/threat-model.md) before using Centra for authoritative controls.

## Development

```bash
dart pub get
dart analyze
dart test
dart compile exe bin/centra.dart -o build/centra
```

Architecture is documented in [doc/architecture.md](doc/architecture.md).

## License

MIT. See [LICENSE](LICENSE).
