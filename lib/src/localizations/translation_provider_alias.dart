import 'strings.g.dart' show TranslationProvider;

/// Public re-export of the slang-generated `TranslationProvider` under a
/// package-prefixed name so consumer apps that also use slang don't have to
/// `hide` ours to avoid a name clash. Usage:
///
/// ```dart
/// runApp(AppFlowyTranslationProvider(child: const MyApp()));
/// ```
typedef AppFlowyTranslationProvider = TranslationProvider;
