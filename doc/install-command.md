# Installation contract

Centra exposes `bin/centra.dart` through the `executables` section of `pubspec.yaml`. Continuous integration installs the package from its Git URL into an isolated Dart Data Home, adds `DART_DATA_HOME/install/bin` to `PATH`, and runs the resulting global `centra --version` command on Ubuntu, macOS, and Windows.
