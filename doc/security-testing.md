# Security regression coverage

Centra treats file-system boundaries, integrity metadata, archive handling, and signing keys as security-sensitive code.

The regression suite verifies:

- profile IDs cannot escape the profile storage directory;
- archive entries cannot escape extraction destinations;
- required ZIP passwords are enforced before packaging;
- obsolete algorithms remain visibly classified in audit output;
- signatures fail after manifest tampering or trusted-key substitution;
- generated private keys receive restricted permissions where supported;
- local, SSH, container, image, and Compose sources use argument-separated process execution;
- all interface locales retain setup and safety warnings.

These checks run on Ubuntu, macOS, and Windows together with formatting, static analysis, all tests, and native executable compilation.
