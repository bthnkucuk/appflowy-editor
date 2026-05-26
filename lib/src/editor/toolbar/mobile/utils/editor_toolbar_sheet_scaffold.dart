import 'package:flutter/material.dart';

/// Squircle (Apple-style rounded-corner) shell for mobile toolbar
/// sheets, ported from the editorx project's `EditorToolbarSheetScaffold`.
/// Wraps the sheet body with a `Material(shape: RoundedSuperellipseBorder)`
/// and a 4-direction drop shadow so the sheet looks lifted off the
/// surface beneath it.
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
  });

  final Widget child;
  final EdgeInsets padding;

  static const _shadowOffsets = <Offset>[
    Offset(0, -4),
    Offset(4, 0),
    Offset(0, 4),
    Offset(-4, 0),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The route's child is laid out unbounded; without anchoring, the
    // Material below would stretch to fill the route height and cover
    // the editor. Pin to the bottom via Column.end so the inner
    // Material sizes to the row of buttons instead of the full screen.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: padding,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Material(
              shape: const RoundedSuperellipseBorder(
                borderRadius: .all(.circular(24)),
              ),
              color: theme.cardColor,
              elevation: 8,
              child: child,
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
/// Selected state is *not* rendered by this button. The Phosphor
/// `ToolbarIcon` already swaps to its Fill variant when
/// `selected: true`, and that swap carries the active-state signal.
/// A colored background here would just double the cue (editorx's
/// bright-green was visually loud against AppFlowy's purple brand).
class EditorToolbarMenuButton extends StatelessWidget {
  const EditorToolbarMenuButton({
    super.key,
    required this.iconPadding,
    required this.onTap,
    this.icon,
    this.text,
    this.enabled = true,
    this.backgroundColor,
    this.fontFamily,
    this.textPadding = EdgeInsets.zero,
    required this.isSelected,
  }) : assert(
         (icon == null) != (text == null),
         'Provide exactly one of icon or text',
       );

  final bool enabled;
  final VoidCallback onTap;

  /// Icon widget — typically `ToolbarIcon(icon: ToolbarIcons.X)` so the
  /// Phosphor outline ↔ Fill swap stays consistent with the rest of the
  /// toolbar. Pass any Widget that paints at the requested size.
  final Widget? icon;
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
    if (icon != null) {
      child = icon!;
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
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : backgroundColor,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),

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
