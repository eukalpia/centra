# Contributing

## Local checks

```bash
dart pub get
dart format .
dart analyze
dart test
dart compile exe bin/centra.dart -o build/centra
```

## Design rules

- Keep source acquisition separate from hashing.
- Never add a silent default hash selection.
- Do not hide algorithm security warnings.
- Do not pass untrusted text through a shell.
- Keep manifest output deterministic.
- Add tests for every new algorithm, source adapter, schema change, and path rule.
- Keyboard and mouse interaction must lead to the same action.
- New visible strings should be routed through the localization catalog.

## Commit style

Use short imperative messages that describe the product change.
