import 'package:centra/centra.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('CentraManifest', () {
    test('sorts file records and emits deterministic canonical JSON', () {
      final manifest = testManifest(
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'z.txt',
            size: 1,
            digests: <String, String>{'sha256': '02'},
          ),
          ManifestFileRecord(
            path: 'a.txt',
            size: 1,
            digests: <String, String>{'sha256': '01'},
          ),
        ],
      );
      expect(manifest.files.map((file) => file.path), <String>[
        'a.txt',
        'z.txt',
      ]);
      expect(manifest.encodeCanonical(), manifest.encodeCanonical());
      final decoded = CentraManifest.fromJson(manifest.toJson());
      expect(decoded.encodeCanonical(), manifest.encodeCanonical());
    });

    test('preserves algorithm security status in the manifest', () {
      final manifest = testManifest(
        algorithms: <HashAlgorithmDescriptor>[
          AlgorithmRegistry().descriptor('sha256'),
          AlgorithmRegistry().descriptor('md5'),
        ],
      );
      final algorithms = manifest.toJson()['algorithms']! as List<Object?>;
      final md5 = (algorithms.last! as Map).cast<String, Object?>();
      expect(md5['status'], 'obsolete');
      expect(md5['warning'], isNotNull);
    });
  });

  group('ManifestComparator', () {
    const comparator = ManifestComparator();

    test('classifies added, removed, modified and unchanged paths', () {
      final before = testManifest(
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'removed.txt',
            size: 1,
            digests: <String, String>{'sha256': '01'},
          ),
          ManifestFileRecord(
            path: 'modified.txt',
            size: 1,
            digests: <String, String>{'sha256': '02'},
          ),
          ManifestFileRecord(
            path: 'same.txt',
            size: 1,
            digests: <String, String>{'sha256': '03'},
          ),
        ],
      );
      final after = testManifest(
        id: 'manifest-2',
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'added.txt',
            size: 1,
            digests: <String, String>{'sha256': '04'},
          ),
          ManifestFileRecord(
            path: 'modified.txt',
            size: 1,
            digests: <String, String>{'sha256': 'ff'},
          ),
          ManifestFileRecord(
            path: 'same.txt',
            size: 1,
            digests: <String, String>{'sha256': '03'},
          ),
        ],
      );
      final diff = comparator.compare(before, after);
      expect(diff.count(ManifestChangeType.added), 1);
      expect(diff.count(ManifestChangeType.removed), 1);
      expect(diff.count(ManifestChangeType.modified), 1);
      expect(diff.count(ManifestChangeType.unchanged), 1);
      expect(diff.hasIntegrityChanges, isTrue);
      expect(
        diff.changes
            .singleWhere((change) => change.path == 'modified.txt')
            .changedAlgorithms,
        <String>['sha256'],
      );
    });

    test('separates metadata-only changes from content changes', () {
      final before = testManifest(
        files: <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'file.txt',
            size: 1,
            modifiedAt: DateTime.utc(2026, 7, 17),
            mode: 420,
            digests: const <String, String>{'sha256': 'aa'},
          ),
        ],
      );
      final after = testManifest(
        id: 'manifest-2',
        files: <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'file.txt',
            size: 1,
            modifiedAt: DateTime.utc(2026, 7, 18),
            mode: 384,
            digests: const <String, String>{'sha256': 'aa'},
          ),
        ],
      );
      final diff = comparator.compare(before, after);
      expect(diff.count(ManifestChangeType.metadata), 1);
      expect(diff.hasIntegrityChanges, isFalse);
    });

    test('treats a missing algorithm result as modification', () {
      final before = testManifest(
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'file.txt',
            size: 1,
            digests: <String, String>{'sha256': 'aa', 'md5': 'bb'},
          ),
        ],
      );
      final after = testManifest(
        id: 'manifest-2',
        files: const <ManifestFileRecord>[
          ManifestFileRecord(
            path: 'file.txt',
            size: 1,
            digests: <String, String>{'sha256': 'aa'},
          ),
        ],
      );
      final change = comparator.compare(before, after).changes.single;
      expect(change.type, ManifestChangeType.modified);
      expect(change.changedAlgorithms, <String>['md5']);
    });
  });
}
