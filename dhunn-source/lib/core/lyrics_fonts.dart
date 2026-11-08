/// Lyrics fonts (v2.33, his request — "buhut saare fonts"):
/// bundled Google Fonts (latin subsets, ~1.1 MB total) the user
/// can pick for the synced-lyrics views. Index 0 = the app
/// default (no family override). The family names here must
/// match the `fonts:` declarations in pubspec.yaml.
class LyricsFonts {
  static const names = <String>[
    'Default',
    'Poppins',
    'Montserrat',
    'Raleway',
    'Rubik',
    'Oswald',
    'Bebas Neue',
    'Anton',
    'Playfair Display',
    'Dancing Script',
    'Pacifico',
    'Lobster',
    'Caveat',
  ];

  /// Flutter fontFamily for a stored index, or null for Default.
  static String? familyOf(int index) =>
      (index <= 0 || index >= names.length) ? null : names[index];
}
