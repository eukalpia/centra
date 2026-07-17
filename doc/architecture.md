# Architecture

Centra is split into a framework-neutral integrity core, source adapters, persistent profile stores, a command-line interface, and a Cinder terminal interface.

```text
bin/centra.dart
    |
    +-- app/centra_application.dart
          |
          +-- cli/                 deterministic commands and exit codes
          +-- tui/                 Cinder screens, wizard, mouse/keyboard widgets
          |
          +-- core/
          |     +-- algorithm registry
          |     +-- path policy and project detection
          |     +-- file inventory and multi-digest pipeline
          |     +-- manifest encoding and comparison
          |     +-- archive and signature services
          |     +-- profiles and settings
          |
          +-- sources/
                +-- local
                +-- SSH
                +-- Docker container
                +-- Docker image
                +-- Docker Compose
```

## Core invariants

1. The scanner receives a stable local directory.
2. Source adapters may materialize data, but they do not hash it.
3. The selected algorithm list is explicit and ordered in the resulting manifest.
4. File content is read once for all built-in streaming algorithms.
5. External custom algorithms run after the built-in stream and receive one file path.
6. Every path in a manifest uses normalized forward slashes.
7. Manifest records are sorted by path.
8. JSON object keys are normalized before encoding.
9. A scan profile is validated before any source command runs.
10. Temporary sources are disposed in `finally` blocks.

## File scanning

The inventory phase traverses directories without following links unless the profile explicitly requests it. Include and exclude rules are applied to normalized relative paths. The hashing phase uses a bounded worker pool. Each worker owns its digest service and reads one file at a time.

```text
Directory traversal
  -> normalized inventory
  -> sorted work list
  -> bounded workers
  -> one read stream per file
  -> N digest sessions
  -> immutable file record
  -> sorted manifest
```

## Extensibility

A new source implements `SourceProvider` and returns `PreparedSource`. A new built-in algorithm adds a descriptor and digest session. Organization-specific algorithms can be configured as external commands without changing Centra's source.

The JSON schemas are versioned. Breaking changes require a new schema identifier and migration path.
