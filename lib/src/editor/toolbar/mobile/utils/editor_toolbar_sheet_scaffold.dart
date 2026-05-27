import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../infra/mobile/editor_icons.dart'
    show ToolbarIcon, ToolbarIcons;

/// Squircle (Apple-style rounded-corner) shell for mobile toolbar
/// sheets, ported from the editorx project's `EditorToolbarSheetScaffold`.
///
/// The sheet itself is frosted: a [BackdropFilter] clipped to the
/// sheet's squircle shape blurs the editor content that sits directly
/// beneath the sheet, while the rest of the screen (the editor above
/// the sheet) stays crisp. Combined with a translucent overlay color
/// it gives an iOS-style "glass" panel.
///
/// Used by sheet variants of mobile toolbar items
/// ([textDecorationMobileToolbarItemV2Sheet] et al.). Composes naturally
/// with `StupidSimpleSheetRoute`, which provides the slide-up gesture
/// but no visual chrome of its own.
class EditorToolbarSheetScaffold extends StatelessWidget {
  const EditorToolbarSheetScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
    this.blur = 20.0,
    this.tintOpacity = 0.6,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Sigma for the [ImageFilter.blur] that frosts the editor beneath
  /// the sheet. `0` disables the frosted-glass effect (the sheet shows
  /// a solid `cardColor` background instead).
  final double blur;

  /// Alpha applied to `cardColor` when frosted — lets some of the
  /// blurred editor bleed through so the sheet feels translucent. Set
  /// to `1.0` for a fully opaque sheet (matches the pre-blur look).
  final double tintOpacity;

  static const _shape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  @override
  Widget build(BuildContext context) {
    // Pin the sheet to the bottom; the rest of the route stays
    // pass-through so the editor remains tappable / visible.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: padding,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            // ClipPath limits the BackdropFilter to the sheet's squircle
            // shape, so only the area directly under the sheet is blurred.
            child: ClipPath(
              clipper: const ShapeBorderClipper(shape: _shape),
              child: BackdropFilter(
                filter: blur > 0
                    ? ImageFilter.blur(sigmaX: blur, sigmaY: blur)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: Offset(-4, -8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: Offset(4, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    shape: _shape,
                    color: Colors.transparent,
                    type: MaterialType.transparency,
                    elevation: 8,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon-or-text squircle button used inside [EditorToolbarSheetScaffold]
/// menu rows. Ported from editorx's `MobileToolbarMenuItemWrapper`.
///
/// Pass either [icon] (a built widget — typically a `ToolbarIcon` for
/// Phosphor consistency) or [text]; passing both throws. The button
/// renders a squircle background (`RoundedSuperellipseBorder`) and is
/// gesture-locked when [enabled] is false.
///
/// When [isSelected] is true a subtle primary tint + outline border
/// highlights the button. The Phosphor `ToolbarIcon` separately swaps
/// to its Fill variant for the same state — both layers reinforce the
/// "this attribute is active" signal without the editorx-era saturated
/// green background.
class EditorToolbarMenuButton extends StatelessWidget {
  const EditorToolbarMenuButton({
    super.key,
    required this.iconPadding,
    required this.onTap,
    required this.isSelected,
    this.icon,
    this.text,
    this.enabled = true,
    this.backgroundColor,
    this.fontFamily,
    this.textPadding = EdgeInsets.zero,
  }) : assert(
         (icon == null) != (text == null),
         'Provide exactly one of icon or text',
       );

  final bool enabled;
  final VoidCallback onTap;

  /// Icon widget — typically `ToolbarIcon(icon: ToolbarIcons.X)` so the
  /// Phosphor outline ↔ Fill swap stays consistent with the rest of the
  /// toolbar. Pass any Widget that paints at the requested size.
  final ToolbarIcons? icon;
  final String? text;
  final Color? backgroundColor;
  final String? fontFamily;
  final EdgeInsets iconPadding;
  final EdgeInsets textPadding;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = enabled ? null : theme.colorScheme.outline;

    final Widget child;
    if (icon case final ToolbarIcons icon) {
      child = ToolbarIcon(
        icon: icon,
        selected: isSelected,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      );
    } else {
      child = Padding(
        padding: textPadding,
        child: Text(
          text!,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            color: effectiveTextColor,
            fontFamily: fontFamily,
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: text != null ? Alignment.centerLeft : Alignment.center,
        decoration: ShapeDecoration(
          color: isSelected
              ? theme.scaffoldBackgroundColor.withValues(alpha: 0.1)
              : backgroundColor,
          shape: RoundedSuperellipseBorder(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            side: isSelected
                ? BorderSide(color: theme.colorScheme.outline)
                : BorderSide.none,
          ),
        ),
        padding: iconPadding,
        child: child,
      ),
    );
  }
}
