from pathlib import Path

path = Path('lib/src/core/path_policy.dart')
text = path.read_text(encoding='utf-8')
old = '''  bool matches(String path) =>
      _expression.hasMatch(normalizeRelativePath(path));
'''
new = '''  bool matches(String path) =>
      _expression.hasMatch(normalizeRelativePath(path));

  bool matchesDirectory(String path) {
    final normalized = normalizeRelativePath(path);
    return _expression.hasMatch(normalized) ||
        _expression.hasMatch('$normalized/');
  }
'''
if old not in text:
    raise SystemExit('GlobPattern.matches not found')
text = text.replace(old, new, 1)
old = '''    final directoryPath = '$path/';
    return !excludePatterns.any(
      (pattern) => pattern.matches(path) || pattern.matches(directoryPath),
    );
'''
new = '''    return !excludePatterns.any(
      (pattern) => pattern.matchesDirectory(path),
    );
'''
if old not in text:
    raise SystemExit('directory traversal matcher not found')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
