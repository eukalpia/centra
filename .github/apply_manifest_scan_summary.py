from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Pattern not found: {label}')
    return text.replace(old, new, 1)


path = Path('lib/src/core/manifest.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    '''    this.symlinkTarget,
  });
''',
    '''    this.symlinkTarget,
    this.unstable = false,
    this.attempts = 1,
  });
''',
    'manifest record optional fields',
)
text = replace_once(
    text,
    '''  final String? symlinkTarget;
  final Map<String, String> digests;
''',
    '''  final String? symlinkTarget;
  final Map<String, String> digests;
  final bool unstable;
  final int attempts;
''',
    'manifest record fields',
)
text = replace_once(
    text,
    '''        if (symlinkTarget != null) 'symlinkTarget': symlinkTarget,
        'digests': digests,
''',
    '''        if (symlinkTarget != null) 'symlinkTarget': symlinkTarget,
        if (unstable) 'unstable': true,
        if (attempts > 1) 'attempts': attempts,
        'digests': digests,
''',
    'manifest record json',
)
text = replace_once(
    text,
    '''        symlinkTarget: json['symlinkTarget'] as String?,
        digests: (json['digests']! as Map).cast<String, String>(),
''',
    '''        symlinkTarget: json['symlinkTarget'] as String?,
        unstable: json['unstable'] as bool? ?? false,
        attempts: json['attempts'] as int? ?? 1,
        digests: (json['digests']! as Map).cast<String, String>(),
''',
    'manifest record from json',
)
text = replace_once(
    text,
    '''    required this.totalBytes,
  }) : files = (files.toList()
''',
    '''    required this.totalBytes,
    this.directoriesVisited = 0,
    this.skipped = 0,
    this.unstableFiles = 0,
    this.transferredBytes = 0,
    this.durationMilliseconds = 0,
    this.baseline,
  }) : files = (files.toList()
''',
    'manifest summary constructor',
)
text = replace_once(
    text,
    '''  final int totalBytes;

  Map<String, Object?> toJson() => <String, Object?>{
''',
    '''  final int totalBytes;
  final int directoriesVisited;
  final int skipped;
  final int unstableFiles;
  final int transferredBytes;
  final int durationMilliseconds;
  final Map<String, Object?>? baseline;

  Map<String, Object?> toJson() => <String, Object?>{
''',
    'manifest summary fields',
)
text = replace_once(
    text,
    '''          'readErrorCount': errors.length,
        },
''',
    '''          'readErrorCount': errors.length,
          'directoriesVisited': directoriesVisited,
          'skipped': skipped,
          'unstableFiles': unstableFiles,
          'transferredBytes': transferredBytes,
          'durationMilliseconds': durationMilliseconds,
        },
        if (baseline != null) 'baseline': baseline,
''',
    'manifest summary json',
)
text = replace_once(
    text,
    '''      totalBytes: summary['totalBytes']! as int,
    );
''',
    '''      totalBytes: summary['totalBytes']! as int,
      directoriesVisited: summary['directoriesVisited'] as int? ?? 0,
      skipped: summary['skipped'] as int? ?? 0,
      unstableFiles: summary['unstableFiles'] as int? ?? 0,
      transferredBytes: summary['transferredBytes'] as int? ?? 0,
      durationMilliseconds: summary['durationMilliseconds'] as int? ?? 0,
      baseline: json['baseline'] == null
          ? null
          : (json['baseline']! as Map).cast<String, Object?>(),
    );
''',
    'manifest summary from json',
)
path.write_text(text, encoding='utf-8')
