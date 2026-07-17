# Localization

Centra ships ten selectable interface locales:

- `en` English
- `ru` Russian
- `uz` Uzbek Latin
- `uz-Cyrl` Uzbek Cyrillic
- `tr` Turkish
- `kk` Kazakh
- `ky` Kyrgyz
- `tg` Tajik
- `az` Azerbaijani
- `de` German

The first screen intentionally uses a small language-neutral layout and allows mouse or keyboard selection. The selected locale is stored in settings and each profile records the locale used when it was created.

Translations live in `lib/src/i18n/messages.dart`. English is the fallback for missing keys. Tests verify that every shipped locale exposes the critical wizard keys.
