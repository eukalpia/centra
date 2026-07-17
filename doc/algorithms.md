# Algorithm policy

Centra exposes an algorithm registry rather than a single hard-coded digest. A profile must select at least one entry.

## Built-in status groups

### Recommended

SHA-256, SHA-384, SHA-512, SHA-512/256, SHA3-256, SHA3-384, SHA3-512, BLAKE2b-256, and BLAKE2b-512.

### Acceptable / interoperability

SHA-224, SHA-512/224, SHA3-224, SM3, Whirlpool, RIPEMD-256, and RIPEMD-320.

### Legacy

SHA-1, RIPEMD-160, and Tiger. These remain available for existing procedures and should be paired with a modern algorithm.

### Obsolete

MD2, MD4, and MD5. These are available only because external systems may require their text format. Centra marks them as obsolete in the TUI, CLI, JSON manifest, and report.

### Checksums

CRC-32 and Adler-32 detect accidental corruption. They are not cryptographic integrity controls.

## Custom algorithms

The wizard can register an external command with:

- Stable ID.
- Display name.
- Executable path/name.
- JSON argument array containing `{file}`.
- Output regular expression.
- Capture group.
- Output bit length.
- Timeout.

Example conceptual configuration:

```json
{
  "id": "organization-hash",
  "displayName": "Organization Hash",
  "executable": "/opt/security/hash-tool",
  "arguments": ["--format", "hex", "{file}"],
  "outputPattern": "^([0-9a-fA-F]+)",
  "outputGroup": 1,
  "outputBits": 256,
  "timeoutSeconds": 60
}
```

The executable is launched directly, not through a shell. Output must resolve to hexadecimal text.
