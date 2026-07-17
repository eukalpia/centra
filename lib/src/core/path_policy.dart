import 'package:path/path.dart' as p;

String normalizeRelativePath(String value) {
  var normalized = value.replaceAll('\\', '/');
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  normalized = p.posix.normalize(normalized);
  if (normalized == '.' || normalized.isEmpty) return '';
  if (normalized.startsWith('/') ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    throw FormatException('Path escapes the source root: $value');
  }
  return normalized;
}

class GlobPattern {
  GlobPattern(this.source) : _expression = RegExp(_toRegex(source));

  final String source;
  final RegExp _expression;

  bool matches(String path) =>
      _expression.hasMatch(normalizeRelativePath(path));

  static String _toRegex(String pattern) {
    final normalized = pattern.replaceAll('\\', '/');
    final buffer = StringBuffer('^');
    var index = 0;
    while (index < normalized.length) {
      final char = normalized[index];
      if (char == '*') {
        final doubleStar =
            index + 1 < normalized.length && normalized[index + 1] == '*';
        if (doubleStar) {
          final followedBySlash =
              index + 2 < normalized.length && normalized[index + 2] == '/';
          buffer.write(followedBySlash ? '(?:.*/)?' : '.*');
          index += followedBySlash ? 3 : 2;
        } else {
          buffer.write('[^/]*');
          index++;
        }
      } else if (char == '?') {
        buffer.write('[^/]');
        index++;
      } else if (char == '[') {
        final end = normalized.indexOf(']', index + 1);
        if (end < 0) {
          buffer.write(r'\[');
          index++;
        } else {
          buffer.write(normalized.substring(index, end + 1));
          index = end + 1;
        }
      } else {
        buffer.write(RegExp.escape(char));
        index++;
      }
    }
    buffer.write(r'$');
    return buffer.toString();
  }
}

class PathPolicy {
  PathPolicy({
    required Iterable<String> includes,
    required Iterable<String> excludes,
    required this.includeHiddenFiles,
  })  : includePatterns = includes.map(GlobPattern.new).toList(growable: false),
        excludePatterns = excludes.map(GlobPattern.new).toList(growable: false);

  final List<GlobPattern> includePatterns;
  final List<GlobPattern> excludePatterns;
  final bool includeHiddenFiles;

  bool allows(String relativePath) {
    final path = normalizeRelativePath(relativePath);
    if (path.isEmpty) return false;
    if (!includeHiddenFiles &&
        path.split('/').any((segment) => segment.startsWith('.'))) {
      return false;
    }
    final included = includePatterns.isEmpty ||
        includePatterns.any((pattern) => pattern.matches(path));
    if (!included) return false;
    return !excludePatterns.any((pattern) => pattern.matches(path));
  }
}

class ProjectDetection {
  const ProjectDetection({
    required this.kind,
    required this.evidence,
    required this.suggestedExcludes,
  });

  final String kind;
  final List<String> evidence;
  final List<String> suggestedExcludes;
}

class ProjectDetector {
  static const _commonSecrets = <String>[
    '**/.env',
    '**/.env.*',
    '**/*.pem',
    '**/*.key',
    '**/*.p12',
    '**/*.pfx',
    '**/*.jks',
    '**/*.keystore',
    '**/*.log',
    '**/logs/**',
    '**/uploads/**',
    '**/backups/**',
    '**/*.sql',
    '**/*.sqlite',
    '**/*.sqlite3',
  ];

  static Future<ProjectDetection> detect(Set<String> rootNames) async {
    final normalized = rootNames.map((name) => name.toLowerCase()).toSet();
    final rules = <({String kind, Set<String> markers, List<String> excludes})>[
      (
        kind: 'flutter',
        markers: {'pubspec.yaml', 'lib', 'android', 'ios'},
        excludes: ['.dart_tool/**', 'build/**', '**/.flutter-plugins*'],
      ),
      (
        kind: 'dart',
        markers: {'pubspec.yaml'},
        excludes: ['.dart_tool/**', 'build/**'],
      ),
      (
        kind: 'node',
        markers: {'package.json'},
        excludes: [
          'node_modules/**',
          '.next/**',
          '.turbo/**',
          'dist/**',
          'coverage/**',
        ],
      ),
      (
        kind: 'python',
        markers: {'pyproject.toml'},
        excludes: [
          '.venv/**',
          'venv/**',
          '__pycache__/**',
          '**/*.pyc',
          '.pytest_cache/**',
        ],
      ),
      (
        kind: 'elixir',
        markers: {'mix.exs'},
        excludes: ['_build/**', 'deps/**', 'cover/**'],
      ),
      (kind: 'rust', markers: {'cargo.toml'}, excludes: ['target/**']),
      (kind: 'go', markers: {'go.mod'}, excludes: ['vendor/**']),
      (
        kind: 'java',
        markers: {'pom.xml'},
        excludes: ['target/**', '.gradle/**', 'build/**'],
      ),
      (
        kind: 'dotnet',
        markers: {'global.json'},
        excludes: ['**/bin/**', '**/obj/**'],
      ),
      (kind: 'php', markers: {'composer.json'}, excludes: ['vendor/**']),
      (
        kind: 'ruby',
        markers: {'gemfile'},
        excludes: ['vendor/bundle/**', '.bundle/**'],
      ),
    ];
    for (final rule in rules) {
      final evidence = rule.markers.where(normalized.contains).toList();
      if (evidence.isNotEmpty &&
          (rule.markers.length == 1 || evidence.length >= 2)) {
        return ProjectDetection(
          kind: rule.kind,
          evidence: evidence,
          suggestedExcludes: <String>{
            '.git/**',
            ..._commonSecrets,
            ...rule.excludes,
          }.toList(),
        );
      }
    }
    return const ProjectDetection(
      kind: 'generic',
      evidence: <String>[],
      suggestedExcludes: <String>['.git/**', ..._commonSecrets],
    );
  }
}
