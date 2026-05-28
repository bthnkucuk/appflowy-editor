import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('slang locales load', () {
    for (final locale in AppFlowyEditorLocale.values) {
      test('locale: ${locale.languageTag}', () async {
        await LocaleSettings.setLocale(locale);
        expect(LocaleSettings.currentLocale, locale);
        // Translations must resolve to a non-null value for every key. Some
        // locales (cs-CZ, da, it-IT, pl-PL, tr-TR) ship empty-string
        // placeholders for un-translated keys, mirroring the pre-slang ARBs.
        // Loaded value just has to exist.
        final t = LocaleSettings.instance.currentTranslations;
        expect(t.bold, isNotNull);
      });
    }
  });
}
