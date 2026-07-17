# Manifest format

Canonical manifests use schema `centra.manifest.v1`.

Top-level fields:

- `schema` — format identifier.
- `id` — unique manifest identifier.
- `generatedAt` — UTC timestamp.
- `tool` — Centra name and version.
- `profile` — profile identity and detected project type.
- `source` — source type and non-secret source metadata.
- `algorithms` — selected descriptors, status, and warnings.
- `policy` — include and exclude patterns.
- `summary` — file count, bytes, and read error count.
- `files` — sorted file records.
- `errors` — explicit non-fatal read failures.

A file record contains:

- Normalized relative path.
- Size.
- Optional modification time.
- Optional numeric mode.
- Optional symlink target.
- Digest map keyed by algorithm ID.

Canonical encoding sorts JSON map keys and file paths. Detached signatures sign the exact manifest bytes, so a manifest must not be reformatted after signing.

Compatibility text output follows the common form:

```text
<hex digest><two spaces><relative path>
```

When one algorithm is selected, the file is named `hash_values.txt`. With several algorithms, Centra writes `hash_values.<algorithm>.txt` for each algorithm.
