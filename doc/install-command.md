# Installation contract

Centra exposes `bin/centra.dart` through the `executables` section of `pubspec.yaml`. Continuous integration configures an isolated Dart Data Home at runtime, installs the package from its Git URL, adds `DART_DATA_HOME/install/bin` to `PATH`, and runs the resulting global `centra --version` command in Bash on Ubuntu and macOS and in PowerShell on Windows.
