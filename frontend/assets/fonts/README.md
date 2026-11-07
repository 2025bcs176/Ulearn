# Bundled fonts

| File | Family | Source |
| --- | --- | --- |
| `Inter-Variable.ttf` | Inter | <https://github.com/rsms/inter> |
| `Sora-Variable.ttf` | Sora | <https://github.com/sora-xor/sora-font> |

Both are licensed under the SIL Open Font License, Version 1.1
(<https://openfontlicense.org>). The OFL permits bundling and redistribution
inside an application; it requires that the fonts not be sold on their own and
that a modified font not use the reserved family name.

These are the upstream variable files, unmodified. They are declared once per
weight in `pubspec.yaml` so that font matching selects the requested weight
instead of synthesising a bold from the default instance. The styles in
`lib/core/theme/app_typography.dart` also set the `wght` variation explicitly.

Both files are subset-complete Latin plus punctuation, which covers the pilot's
copy. If a future locale needs another script, add a subset rather than a second
full family.
