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

Run the same installation command again to update Centra.

## Dart 3.5 through 3.9

Older supported Dart SDKs can activate the executable through pub:

```bash
dart pub global activate --source git https://github.com/eukalpia/centra.git --overwrite
```

## Installation guarantee

Continuous integration installs Centra from its Git URL and executes `centra --version` through the global `PATH` on Ubuntu, macOS, and Windows. A change cannot pass the installation job when the `executables` entry, Git package activation, generated command wrapper, PATH exposure, or application entrypoint is broken.

## PATH troubleshooting

Dart installs global command wrappers into its system cache. If `centra` is not found after a successful installation, add the cache directory to `PATH`.

### Linux and macOS

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Persist that line in `~/.bashrc`, `~/.zshrc`, or the startup file used by your shell.

### Windows

Add this directory to the user `Path` environment variable:

```text
%LOCALAPPDATA%\Pub\Cache\bin
```

Open a new terminal after changing `Path`.

## Remove Centra

Dart 3.10 or newer:

```bash
dart uninstall centra
```

Older Dart SDKs:

```bash
dart pub global deactivate centra
```
