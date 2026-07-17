import 'package:centra/src/i18n/messages.dart';
import 'package:test/test.dart';

void main() {
  group('CentraStrings', () {
    test('ships exactly ten unique interface languages', () {
      expect(CentraStrings.locales, hasLength(10));
      expect(CentraStrings.locales.map((locale) => locale.code).toSet(),
          hasLength(10));
      expect(
        CentraStrings.locales.map((locale) => locale.code),
        containsAll(<String>[
          'en',
          'ru',
          'uz',
          'uz-Cyrl',
          'tr',
          'kk',
          'ky',
          'tg',
          'az',
          'de',
        ]),
      );
    });

    test('every locale exposes critical setup and safety messages', () {
      const keys = <String>[
        'tagline',
        'chooseLanguage',
        'chooseSource',
        'chooseAlgorithms',
        'noAlgorithmDefault',
        'obsolete',
        'md5Warning',
        'outputHelp',
        'requireZipPassword',
        'keyboardHelp',
      ];

      for (final locale in CentraStrings.locales) {
        final strings = CentraStrings(locale.code);
        for (final key in keys) {
          final value = strings(key);
          expect(value.trim(), isNotEmpty,
              reason: '${locale.code} must define $key');
          expect(value, isNot(key),
              reason: '${locale.code} must resolve $key');
        }
      }
    });

    test('unknown locales and unknown keys have predictable fallbacks', () {
      expect(CentraStrings('unknown')('tagline'),
          CentraStrings('en')('tagline'));
      expect(CentraStrings('en')('missing-key'), 'missing-key');
    });

    test('MD5 remains visibly obsolete in every language', () {
      for (final locale in CentraStrings.locales) {
        final strings = CentraStrings(locale.code);
        expect(strings('obsolete').trim(), isNotEmpty);
        expect(strings('md5Warning').trim(), isNotEmpty);
      }
    });
  });
}
