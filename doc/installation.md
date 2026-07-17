# Installation

Centra is a Dart command-line application. You do not need to clone the repository or compile an executable manually.

## Dart 3.10 or newer

Install the current release from the Git repository:

```bash
dart install https://github.com/eukalpia/centra.git --overwrite
```

Start the interactive interface from any directory:

```bash
centra
```

Check the installed version:

```bash
centra --version
```

Run the same installation command again to update Centra. No repository checkout or manual native build is involved.

## Dart 3.5 through 3.9

Older supported Dart SDKs can activate the executable through pub:

```bash
dart pub global activate --source git https://github.com/eukalpia/centra.git --overwrite
```

## PATH troubleshooting

If installation succeeds but `centra` is not found, add the correct executable directory to `PATH`. The modern `dart install` command and legacy `dart pub global activate` use different locations.

### Dart 3.10 or newer

Linux:

```bash
export PATH="$PATH:${XDG_STATE_HOME:-$HOME/.local/state}/Dart/install/bin"
```

macOS:

```bash
export PATH="$PATH:$HOME/Library/Application Support/Dart/install/bin"
```

Windows:

```text
%LOCALAPPDATA%\Dart\install\bin
```

The modern install root can be overridden with the `DART_DATA_HOME` environment variable. In that case, add `%DART_DATA_HOME%\install\bin` on Windows or `$DART_DATA_HOME/install/bin` on Linux and macOS.

### Dart 3.5 through 3.9

Linux and macOS:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Windows:

```text
%LOCALAPPDATA%\Pub\Cache\bin
```

Persist the applicable path in your shell startup file or user environment variables, then open a new terminal.

## Remove Centra

Dart 3.10 or newer:

```bash
dart uninstall centra
```

Older Dart SDKs:

```bash
dart pub global deactivate centra
```
