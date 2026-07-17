# Coverage scope

The test suite covers the correctness and security boundaries that can invalidate an integrity baseline. It is intentionally organized by observable guarantees instead of a cosmetic line-coverage target.

Covered areas include digest vectors, profile validation, source adapters, path policy, manifest determinism, comparison semantics, output packaging, audit warnings, signature verification, atomic storage, localization completeness, and cross-platform native builds.

Coverage is expanded whenever a defect reaches CI or a new source, output format, algorithm provider, or security boundary is added.
