import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Curated subset of Google Fonts shown in [FontsMobileSheet]. Picked
/// for readability across serif / sans-serif / geometric / humanist
/// categories rather than including every family.
const List<String> _curatedFontFamilies = <String>[
  'Atkinson Hyperlegible',
  'Crimson Text',
  'DM Sans',
  'Domine',
  'EB Garamond',
  'Fira Sans',
  'IBM Plex Sans',
  'IBM Plex Serif',
  'Inter',
  'Karla',
  'Lexend',
  'Libre Baskerville',
  'Lora',
  'Merriweather',
  'Noto Sans',
  'Noto Serif',
  'Nunito',
  'Nunito Sans',
  'Open Sans',
  'Poppins',
  'PT Sans',
  'PT Serif',
  'Quicksand',
  'Raleway',
  'Roboto',
  'Source Sans 3',
  'Source Serif 4',
  'Spectral',
  'Tinos',
  'Work Sans',
];

/// Mobile fonts picker — vertical list of font families, each row
/// rendered in the family it represents. Tapping a row swaps the
/// editor's body `fontFamily` (via `GoogleFonts.getFont`) and bumps
/// [editorAppearanceTick]. The current size / weight / color from the
/// existing body style are preserved.
class FontsMobileSheet extends StatefulWidget {
  const FontsMobileSheet({super.key, required this.editorState});

  final EditorState editorState;

  @override
  State<FontsMobileSheet> createState() => _FontsMobileSheetState();
}

class _FontsMobileSheetState extends State<FontsMobileSheet> {
  String? get _currentFamily => widget
      .editorState.editorStyle.textStyleConfiguration.text.fontFamily
      ?.split('_')
      .first;

  void _select(String family) {
    final style = widget.editorState.editorStyle;
    final text = style.textStyleConfiguration.text;
    widget.editorState.editorStyle = style.copyWith(
      textStyleConfiguration: style.textStyleConfiguration.copyWith(
        text: GoogleFonts.getFont(
          family,
          fontSize: text.fontSize,
          fontWeight: text.fontWeight,
          color: text.color,
        ),
      ),
    );
    setState(() {});
    editorAppearanceTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _currentFamily;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Font', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 16, thickness: 0.5),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _curatedFontFamilies.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 0.5, indent: 12),
              itemBuilder: (context, index) {
                final family = _curatedFontFamilies[index];
                TextStyle preview;
                try {
                  preview = GoogleFonts.getFont(family, fontSize: 17);
                } catch (_) {
                  preview = TextStyle(fontFamily: family, fontSize: 17);
                }
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  title: Text(family, style: preview),
                  trailing: family == selected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => _select(family),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
