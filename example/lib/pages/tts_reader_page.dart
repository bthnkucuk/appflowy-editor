import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// Read-along viewer ported from the production tuSpeech app's reader
/// screen. The key features mirrored from the app — and the reason this
/// example exists — are:
///
/// 1. **Section parser.** `Node.sectionParser` is installed BEFORE the
///    document is constructed (Node populates `sections` lazily in its
///    constructor — line 55 of [Node]). Every paragraph/heading is then
///    split into sentence-sized "sections", which [BlockHighlightArea]
///    paints in [EditorStyle.highlightAreaColor] behind the word-level
///    highlight, automatically — we don't paint anything ourselves; we
///    only drive `updateHighlight(wordSelection)` and the section
///    underlay follows because BHA derives the enclosing section from
///    the highlight's offset midpoint (lines 324-327 of
///    block_highlight_area.dart).
///
/// 2. **`highlightable: true` + `tapNotifier`.** Instead of intercepting
///    pointer events ourselves, we let
///    [MobileHighlightServiceWidget] do the tap routing — its
///    `_onDoubleTapUp` resolves the word boundary at the tap and calls
///    `editorState.updateTap(selection)`. We listen on
///    `editorState.tapNotifier` to seek. Exact same path the app uses
///    (`document_details_listener_mixin.tapListener`).
///
/// 3. **Editor-owned auto-scroll state.** The "back to current" pill
///    drives off `editorState.isAutoScrollHighlightNotifier`, not a
///    local flag. User drags the editor (reverse scroll) → we call
///    `disableAutoScrollHighlight()`. Pill tap →
///    `enableAutoScrollHighlight(editorScrollController)`. Each tick
///    calls `highlightChanged(controller)` which scrolls iff the
///    notifier is true.
///
/// 4. **Section-midpoint lookup on tap.** Tap → find which section of
///    `node.sections` contains the offset midpoint
///    `(tap.start + tap.end) ~/ 2`. Same predicate
///    `BlockHighlightArea._updateSelectionIfNeeded` uses — keeping this
///    in sync is what prevents the "highlight paints in the wrong
///    place" class of bug.
///
/// Tokens here are pre-computed word selections in reading order; one
/// tick == one word, the section underlay is derived. In the real app
/// tokens come from the audio handler's `AudioSection` stream
/// (sub-section word-aligned ranges); from the editor's point of view
/// the contract is identical: highlight a small selection inside a
/// section, the section paints automatically.
class TtsReaderPage extends StatefulWidget {
  const TtsReaderPage({super.key});

  @override
  State<TtsReaderPage> createState() => _TtsReaderPageState();
}

class _TtsReaderPageState extends State<TtsReaderPage> {
  // Word-per-tick at 1.0x speed.
  static const Duration _baseWordDuration = Duration(milliseconds: 350);

  // Skip distance for the back/forward buttons.
  static const int _skipAmount = 5;

  // Cycle order for the speed pill.
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5];

  late final EditorState editorState;
  late final EditorScrollController editorScrollController;
  late final Map<String, BlockComponentBuilder> _blockComponentBuilders;
  late final EditorStyle _editorStyle;

  /// Pre-computed word selections, in reading order. The static sample
  /// document is read-only so it never drifts.
  final List<Selection> _tokens = [];

  /// Saved so we can restore on dispose — `Node.sectionParser` is a
  /// global static and shouldn't leak into other example pages that
  /// pop in after this one.
  Sections? Function(Node)? _previousSectionParser;

  int _currentIndex = -1;
  Timer? _timer;
  bool _playing = false;
  double _speed = 1.0;

  /// Mirror of `editorScrollController.visibleRangeNotifier.value`,
  /// updated via a postFrame defer. SuperSliverList fires its visible
  /// range notifier from inside `RenderSuperSliverList.performLayout`,
  /// which would assert if we drove a `setState` directly off it.
  (int, int) _visibleRange = (0, 0);
  bool _visibleRangeUpdatePending = false;

  @override
  void initState() {
    super.initState();

    // Install the section parser. Order doesn't matter — `Node`
    // bumps the path generation after wiring children's parents in
    // its constructor / `fromJson`, so any path the parser reads at
    // construction time is invalidated by the time the editor
    // mounts. Sections are stored on each node and consumed by
    // [BlockHighlightArea] to paint the active sentence underlay
    // behind the word highlight.
    _previousSectionParser = Node.sectionParser;
    Node.sectionParser = _defaultNodeSectionParser;

    editorState = EditorState(document: _buildSampleDocument());
    editorState.editable = false;
    editorScrollController = EditorScrollController(
      editorState: editorState,
      shrinkWrap: false,
    );
    _blockComponentBuilders = _buildBlockComponentBuilders();
    _editorStyle = _buildEditorStyle();
    _tokens.addAll(_computeWordTokens(editorState.document));

    // The editor's MobileHighlightServiceWidget fires tapNotifier on every
    // tap-up (see mobile_highlight_service.dart:129 → updateTap). We seek
    // to whichever word the tap landed in.
    editorState.tapNotifier.addListener(_onTapNotifier);

    editorScrollController.visibleRangeNotifier.addListener(
      _onVisibleRangeChanged,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    editorState.tapNotifier.removeListener(_onTapNotifier);
    editorScrollController.visibleRangeNotifier.removeListener(
      _onVisibleRangeChanged,
    );
    editorScrollController.dispose();
    editorState.dispose();
    Node.sectionParser = _previousSectionParser;
    super.dispose();
  }

  /// Build a FRESH map of block component builders. The default
  /// [standardBlockComponentBuilderMap] is a top-level `final` map of
  /// shared builder instances — mutating their `.configuration` would
  /// leak into every other example that mounts an editor.
  Map<String, BlockComponentBuilder> _buildBlockComponentBuilders() {
    EdgeInsets paragraphPadding(Node _) =>
        const EdgeInsets.symmetric(vertical: 2);
    EdgeInsets headingPadding(Node _) =>
        const EdgeInsets.only(top: 12, bottom: 2);

    final paragraph = ParagraphBlockComponentBuilder(
      configuration: const BlockComponentConfiguration().copyWith(
        padding: paragraphPadding,
        placeholderText: (_) => '',
      ),
    )..showActions = (_) => false;

    final heading = HeadingBlockComponentBuilder(
      configuration: const BlockComponentConfiguration().copyWith(
        padding: headingPadding,
        placeholderText: (_) => '',
      ),
    )..showActions = (_) => false;

    final page = PageBlockComponentBuilder()..showActions = (_) => false;

    return {
      PageBlockKeys.type: page,
      ParagraphBlockKeys.type: paragraph,
      HeadingBlockKeys.type: heading,
    };
  }

  /// Highlight colors are what makes the section/word distinction
  /// visible. `highlightAreaColor` is the underlay BHA paints for the
  /// enclosing section; `highlightColor` is the foreground word.
  EditorStyle _buildEditorStyle() {
    return EditorStyle.mobile(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 160,
      ),
      cursorColor: Colors.transparent,
      selectionColor: const Color(0x33000000),
      highlightColor: const Color(0x553B82F6),
      highlightAreaColor: const Color(0x223B82F6),
      textStyleConfiguration: const TextStyleConfiguration(
        text: TextStyle(fontSize: 17, color: Colors.black87),
        lineHeight: 1.35,
      ),
    );
  }

  /// Word tokens — one per `\S+` run, in reading order.
  static List<Selection> _computeWordTokens(Document doc) {
    final tokens = <Selection>[];
    final iter = NodeIterator(document: doc, startNode: doc.root);
    final regex = RegExp(r'\S+');
    while (iter.moveNext()) {
      final node = iter.current;
      final text = node.delta?.toPlainText();
      if (text == null || text.isEmpty) continue;
      for (final m in regex.allMatches(text)) {
        tokens.add(
          Selection(
            start: Position(path: node.path, offset: m.start),
            end: Position(path: node.path, offset: m.end),
          ),
        );
      }
    }
    return tokens;
  }

  Duration get _tickDuration => Duration(
        milliseconds: (_baseWordDuration.inMilliseconds / _speed).round(),
      );

  /// SuperSliverList's `visibleRangeNotifier` fires from inside its
  /// `performLayout`. Coalesce updates to one postFrame callback per
  /// layout pass.
  void _onVisibleRangeChanged() {
    final next = editorScrollController.visibleRangeNotifier.value;
    if (next == _visibleRange) return;
    if (_visibleRangeUpdatePending) {
      _visibleRange = next;
      return;
    }
    _visibleRangeUpdatePending = true;
    _visibleRange = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleRangeUpdatePending = false;
      if (!mounted) return;
      setState(() {});
    });
  }

  void _advanceTo(int i) {
    if (i < 0 || i >= _tokens.length) {
      _pause();
      editorState.updateHighlight(null);
      setState(() => _currentIndex = -1);
      return;
    }
    setState(() => _currentIndex = i);
    editorState.updateHighlight(_tokens[i]);
    // Drives `scrollToHighlight` iff `isAutoScrollHighlightNotifier` is
    // true. Mirrors the app's mixin call from
    // `_skipSubscription.listen` (document_details_listener_mixin:35).
    editorState.highlightChanged(editorScrollController);
  }

  void _play() {
    if (_tokens.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= _tokens.length - 1) {
      _currentIndex = -1;
    }
    _timer?.cancel();
    // Re-arm auto-scroll on play — like the app does on tap or skip.
    editorState.enableAutoScrollHighlight(editorScrollController);
    _advanceTo(_currentIndex + 1);
    setState(() => _playing = true);
    _timer = Timer.periodic(_tickDuration, (_) {
      _advanceTo(_currentIndex + 1);
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing) setState(() => _playing = false);
  }

  void _togglePlay() => _playing ? _pause() : _play();

  void _skip(int delta) {
    if (_tokens.isEmpty) return;
    final next = (_currentIndex + delta).clamp(0, _tokens.length - 1);
    editorState.enableAutoScrollHighlight(editorScrollController);
    _currentIndex = next - 1;
    if (_playing) {
      _play();
    } else {
      _advanceTo(next);
    }
  }

  void _cycleSpeed() {
    final nextIdx = (_speeds.indexOf(_speed) + 1) % _speeds.length;
    setState(() => _speed = _speeds[nextIdx]);
    if (_playing) {
      _timer?.cancel();
      _timer = Timer.periodic(_tickDuration, (_) {
        _advanceTo(_currentIndex + 1);
      });
    }
  }

  /// Tap routing via `tapNotifier`. Mirrors the app's `tapListener`:
  /// resolve the enclosing section by offset midpoint, locate the
  /// matching token, seek there, re-arm auto-scroll.
  void _onTapNotifier() {
    final tap = editorState.tapNotifier.value;
    if (tap == null) return;
    // Consume the tap immediately — the app's flow clears it via the
    // highlight stream; here we don't have one, so do it explicitly.
    editorState.tapNotifier.value = null;

    final node = editorState.getNodesInSelection(tap).lastOrNull;
    if (node == null) return;

    final mid = (tap.end.offset + tap.start.offset) ~/ 2;

    // Resolve the section containing the tap — same predicate
    // [BlockHighlightArea._updateSelectionIfNeeded] uses.
    final section = node.sections?.firstWhereOrNull(
      (s) => s.selection.end.offset >= mid,
    );
    if (section == null) return;

    final tokenIdx = _findTokenIndex(node, mid);
    if (tokenIdx < 0) return;

    editorState.enableAutoScrollHighlight(editorScrollController);
    _currentIndex = tokenIdx - 1;
    if (_playing) {
      _play();
    } else {
      _advanceTo(tokenIdx);
    }
  }

  int _findTokenIndex(Node node, int offset) {
    for (var i = 0; i < _tokens.length; i++) {
      final t = _tokens[i];
      if (!t.start.path.equals(node.path)) continue;
      if (offset >= t.start.offset && offset <= t.end.offset) {
        return i;
      }
    }
    // Fallback: closest token in this node.
    int? best;
    int bestDelta = 1 << 30;
    for (var i = 0; i < _tokens.length; i++) {
      final t = _tokens[i];
      if (!t.start.path.equals(node.path)) continue;
      final mid = (t.start.offset + t.end.offset) ~/ 2;
      final d = (mid - offset).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = i;
      }
    }
    return best ?? -1;
  }

  void _returnToCurrent() {
    editorState.enableAutoScrollHighlight(editorScrollController);
  }

  /// True when the active word's top-level block is fully outside the
  /// currently visible range. Used as the trigger for the
  /// "back to current" pill (in conjunction with the auto-scroll flag).
  bool _activeWordOutsideViewport((int, int) visibleRange) {
    if (_currentIndex < 0 || _tokens.isEmpty) return false;
    final topIdx = _tokens[_currentIndex].start.path.firstOrNull;
    if (topIdx == null) return false;
    return topIdx < visibleRange.$1 || topIdx > visibleRange.$2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Read-Along'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // User-reverse-scroll detection: the app does this in
            // editorx's `_AppFlowyEditorX` via `onScrollReverse` →
            // `editorState.disableAutoScrollHighlight()`. We inline it.
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification &&
                    notification.direction == ScrollDirection.reverse) {
                  editorState.disableAutoScrollHighlight();
                }
                return false;
              },
              child: AppFlowyEditor(
                editorState: editorState,
                editable: false,
                // `highlightable: true` wires
                // MobileHighlightServiceWidget — the source of tap
                // events we consume via tapNotifier. Without this the
                // tap-to-seek path is dead.
                highlightable: true,
                disableSelectionService: true,
                disableKeyboardService: true,
                showMagnifier: false,
                editorScrollController: editorScrollController,
                blockComponentBuilders: _blockComponentBuilders,
                editorStyle: _editorStyle,
              ),
            ),
          ),
          // Back-to-current pill. Visibility driven by the editor-owned
          // `isAutoScrollHighlightNotifier` (false → user has scrolled
          // away) AND the active word being outside the viewport.
          Positioned(
            left: 0,
            right: 0,
            bottom: 124,
            child: ValueListenableBuilder<bool>(
              valueListenable: editorState.isAutoScrollHighlightNotifier,
              builder: (context, autoScroll, _) {
                final outOfView = !autoScroll &&
                    _activeWordOutsideViewport(_visibleRange);
                final isAbove = _tokens.isNotEmpty &&
                    _currentIndex >= 0 &&
                    (_tokens[_currentIndex].start.path.firstOrNull ?? 0) <
                        _visibleRange.$1;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: anim.drive(
                        Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                  child: outOfView
                      ? _BackToCurrentPill(
                          onTap: _returnToCurrent,
                          isAbove: isAbove,
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _ControlPanel(
                playing: _playing,
                speed: _speed,
                currentIndex: _currentIndex,
                totalTokens: _tokens.length,
                onTogglePlay: _togglePlay,
                onSkipBack: () => _skip(-_skipAmount),
                onSkipForward: () => _skip(_skipAmount),
                onCycleSpeed: _cycleSpeed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Document _buildSampleDocument() {
    final root = Node(
      type: 'page',
      children: [
        headingNode(level: 1, text: 'Read-Along Demo'),
        paragraphNode(
          text: 'This page walks through the document one word at a time, '
              'highlighting each word as if a screen reader were reading it '
              'aloud. The word highlight is driven by editorState.updateHighlight; '
              'the surrounding section underlay is painted by '
              'BlockHighlightArea automatically, derived from Node.sectionParser.',
        ),
        headingNode(level: 2, text: 'How to use it'),
        paragraphNode(
          text: 'Press play to start from the beginning. Use the skip '
              'buttons to jump five words at a time. Tap the speed pill to '
              'cycle through 0.75x, 1x, 1.25x, and 1.5x. Tap any word in '
              'the document to seek directly there.',
        ),
        paragraphNode(
          text: 'Tapping is routed through editorState.tapNotifier — '
              'MobileHighlightServiceWidget resolves the word boundary at '
              'the tap and fires updateTap; we listen and seek to that '
              'word. This is the exact path the production app uses for '
              'tap-to-seek into a TTS queue.',
        ),
        headingNode(level: 2, text: 'Sections vs words'),
        paragraphNode(
          text: 'BlockHighlightArea derives the enclosing section from the '
              'midpoint of the active highlight selection. So a tiny '
              'word-sized selection lights up both the word (in '
              'highlightColor) and the surrounding sentence (in '
              'highlightAreaColor). Section boundaries come from a unicode-aware '
              'sentence boundary regex installed as Node.sectionParser.',
        ),
        headingNode(level: 3, text: 'Try this'),
        paragraphNode(
          text: 'Tap the last word of this sentence to start from there. '
              'Then scroll up and watch the "Back to current" pill appear. '
              'Tap it to snap back to the live word.',
        ),
        paragraphNode(
          text: 'A long passage helps demonstrate auto-scroll. Keep reading '
              'and the highlight will travel from the top of the document '
              'down past the fold; the editor scrolls each new word into '
              'view automatically. Pause, scroll up, and the back-to-current '
              'pill appears. The pause/play, skip and speed controls live '
              'in the floating panel at the bottom of the screen.',
        ),
        paragraphNode(
          text: 'Adding more text here so the document is long enough that '
              'the auto-scroll behavior becomes obvious on phone-sized '
              'viewports. Imagine this is a chapter from a book, or a long '
              'article from a magazine, or a study passage in a learning '
              'app. The reader walks word by word, the highlight follows, '
              'and the editor keeps the line under reading anchored near '
              'the top of the visible area.',
        ),
        paragraphNode(
          text: 'Finally, tap any word above to start reading from that '
              'point. Tap again while playing to seek without stopping.',
        ),
      ],
    );
    return Document(root: root);
  }
}

// ---------------------------------------------------------------------------
// Section parser — ported from tuSpeech/core/default_node_section_parser.dart.
//
// Splits each node's plain text into sentence-sized "sections". A section
// boundary is preferred wherever the unicode sentence-end regex matches
// within the [soft, hard] window from the cursor; otherwise we cut at the
// hard limit. The regex is intentionally broad — Western, RTL (Arabic,
// Hebrew, Persian), Indic (Devanagari, Bengali), CJK, Thai, etc. — so a
// multilingual document still gets meaningful sections.
// ---------------------------------------------------------------------------

final RegExp _sentenceEnd = RegExp(
  r'(?<=[.!?…‽¡¿؟۔।॥։。！？⸘⸮])\s*(?=[\p{Lu}\p{Lt}\p{Pi}\p{Ps}\p{Nd}]|[一-鿿぀-ヿ가-힯฀-๿֐-׿؀-ۿऀ-ॿঀ-৿])',
  unicode: true,
);

Sections? _defaultNodeSectionParser(Node node) {
  final paragraph = node.delta?.toPlainText();
  if (paragraph == null) return null;

  final parts = _splitSubtexts(paragraph);
  if (parts.isEmpty) return null;

  var startOffset = 0;
  final result = <Section>[];
  for (var index = 0; index < parts.length; index++) {
    final text = parts[index];
    result.add(
      Section(
        index: index,
        text: text,
        selection: Selection(
          start: Position(path: node.path, offset: startOffset),
          end: Position(path: node.path, offset: startOffset + text.length),
        ),
        parent: node,
      ),
    );
    startOffset += text.length;
  }
  return Sections(result);
}

/// Sentence boundaries beyond `soft` characters trigger a split as soon
/// as one is found; if none lands inside [soft, hard], we hard-cut at
/// `hard`. Tuned smaller than the app's defaults for the example so
/// sections light up multiple times per paragraph.
List<String> _splitSubtexts(String text, {int soft = 50, int hard = 500}) {
  if (text.isEmpty) return const [];
  final parts = <String>[];
  var cursor = 0;
  while (cursor < text.length) {
    if (cursor + soft >= text.length) {
      parts.add(text.substring(cursor));
      break;
    }
    final searchEnd = (cursor + hard).clamp(0, text.length);
    final window = text.substring(cursor + soft, searchEnd);
    final m = _sentenceEnd.firstMatch(window);
    final cut = m != null ? cursor + soft + m.end : searchEnd;
    parts.add(text.substring(cursor, cut));
    cursor = cut;
  }
  return parts;
}

extension _IterableX<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.playing,
    required this.speed,
    required this.currentIndex,
    required this.totalTokens,
    required this.onTogglePlay,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onCycleSpeed,
  });

  final bool playing;
  final double speed;
  final int currentIndex;
  final int totalTokens;
  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onCycleSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalTokens == 0
        ? 0.0
        : ((currentIndex + 1) / totalTokens).clamp(0.0, 1.0);
    final speedLabel = '${speed.toStringAsFixed(speed == 1.0 ? 0 : 2)}x';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SpeedPill(label: speedLabel, onTap: onCycleSpeed),
                const Spacer(),
                IconButton(
                  tooltip: 'Skip back',
                  iconSize: 28,
                  icon: const Icon(Icons.replay_5_rounded),
                  onPressed: onSkipBack,
                ),
                const SizedBox(width: 8),
                _PlayPauseButton(playing: playing, onTap: onTogglePlay),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Skip forward',
                  iconSize: 28,
                  icon: const Icon(Icons.forward_5_rounded),
                  onPressed: onSkipForward,
                ),
                const Spacer(),
                SizedBox(
                  width: 56,
                  child: Text(
                    totalTokens == 0
                        ? '—'
                        : '${currentIndex < 0 ? 0 : currentIndex + 1}/$totalTokens',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 56,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey<bool>(playing),
              size: 30,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BackToCurrentPill extends StatelessWidget {
  const _BackToCurrentPill({required this.onTap, required this.isAbove});

  final VoidCallback onTap;
  final bool isAbove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Material(
        elevation: 4,
        color: theme.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAbove
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: theme.colorScheme.onInverseSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  'Back to current',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
