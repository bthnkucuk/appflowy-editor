import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Read-along viewer: walks the document one word at a time, driving
/// `editorState.updateHighlight` so `BlockHighlightArea` paints the
/// active word. Tap any word to seek there; the bottom control panel
/// has play/pause, skip ±5 words, and a speed selector. A "back to
/// current" pill appears when the user has scrolled the active word
/// off-screen.
///
/// Patterned after a production TTS app's reader screen — bottom-anchored
/// player UI over an `editable: false` editor, with the highlight
/// re-centered each tick.
class TtsReaderPage extends StatefulWidget {
  const TtsReaderPage({super.key});

  @override
  State<TtsReaderPage> createState() => _TtsReaderPageState();
}

class _TtsReaderPageState extends State<TtsReaderPage> {
  // Word-per-tick at 1.0x speed. 350 ms ≈ a brisk reading cadence —
  // long enough to register the highlight visually, short enough to
  // sound like speech.
  static const Duration _baseWordDuration = Duration(milliseconds: 350);

  // Skip distance for the back/forward buttons.
  static const int _skipAmount = 5;

  // Tap-vs-scroll threshold for the outer Listener. 10 px is the
  // default Flutter TapGestureRecognizer uses.
  static const double _tapSlop = 10;

  // Cycle order for the speed pill.
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5];

  late final EditorState editorState;
  late final EditorScrollController editorScrollController;
  late final Map<String, BlockComponentBuilder> _blockComponentBuilders;
  late final EditorStyle _editorStyle;

  /// Pre-computed word selections, in reading order. Computed once from
  /// the static sample document — editor is read-only so it never
  /// drifts.
  final List<Selection> _tokens = [];

  int _currentIndex = -1;
  Timer? _timer;
  bool _playing = false;
  double _speed = 1.0;

  /// Raw-pointer state for the outer Listener (see [build]).
  Offset? _pointerDownAt;

  /// True if our most recent scroll-to-highlight call is still in
  /// flight, so we can ignore the resulting [_onScrollViewScrolled]
  /// callback and not falsely flag "user scrolled away".
  bool _suppressNextScrollEvent = false;

  /// Becomes true when the user manually drags the document while
  /// playback is active. While true, auto-scroll is paused and the
  /// "back to current" pill is shown. Reset by tapping the pill.
  bool _userScrolledAway = false;

  /// Mirror of `editorScrollController.visibleRangeNotifier.value`,
  /// updated via a postFrame defer. SuperSliverList fires its visible
  /// range notifier from inside `RenderSuperSliverList.performLayout`,
  /// which would assert if we drove a `setState` directly off it (build
  /// scheduled during frame).
  (int, int) _visibleRange = (0, 0);
  bool _visibleRangeUpdatePending = false;

  @override
  void initState() {
    super.initState();
    editorState = EditorState(document: _buildSampleDocument());
    editorState.editable = false;
    editorScrollController = EditorScrollController(
      editorState: editorState,
      shrinkWrap: false,
    );
    _blockComponentBuilders = _buildBlockComponentBuilders();
    _editorStyle = _buildEditorStyle();
    _tokens.addAll(_computeWordTokens(editorState.document));

    // Scroll listener — tells us when the user manually drags.
    editorState.addScrollViewScrolledListener(_onScrollViewScrolled);
    // Mirror the visible range out of the layout phase.
    editorScrollController.visibleRangeNotifier.addListener(
      _onVisibleRangeChanged,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    editorState.removeScrollViewScrolledListener(_onScrollViewScrolled);
    editorScrollController.visibleRangeNotifier.removeListener(
      _onVisibleRangeChanged,
    );
    // Intentionally no `selectionService.unregisterGestureInterceptor`
    // call — the child SelectionServiceWidget unmounts before us, so
    // touching `editorState.selectionService` here asserts. We don't
    // register one anymore (tap goes through Listener).
    editorScrollController.dispose();
    editorState.dispose();
    super.dispose();
  }

  /// Build a FRESH map of block component builders. The default
  /// [standardBlockComponentBuilderMap] is a top-level `final` map of
  /// shared builder instances — mutating their `.configuration` would
  /// leak into every other example that mounts an editor. We construct
  /// new builders for paragraph + heading (the only blocks this sample
  /// document uses) with tight vertical padding so consecutive
  /// paragraphs sit close together.
  ///
  /// Spacing source map (so future tweaks know what to touch):
  /// - inter-block gap → [BlockComponentConfiguration.padding] (each
  ///   block wraps its child in `Container(padding: ...)`).
  /// - intra-paragraph line spacing →
  ///   [TextStyleConfiguration.lineHeight], set in [_buildEditorStyle].
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

  /// The default [TextStyleConfiguration.lineHeight] is 1.5, which at
  /// fontSize 16 produces 24-px line boxes — fine for editing, but
  /// makes multi-line paragraphs in a viewer feel airy enough that
  /// users read the gap between visual lines as "huge spacing between
  /// paragraphs". Tightening to 1.35 collapses that visual gap without
  /// crushing readability.
  EditorStyle _buildEditorStyle() {
    return EditorStyle.mobile(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 160, // room for the bottom control panel
      ),
      cursorColor: Colors.transparent,
      selectionColor: const Color(0x33000000),
      textStyleConfiguration: const TextStyleConfiguration(
        text: TextStyle(fontSize: 17, color: Colors.black87),
        lineHeight: 1.35,
      ),
    );
  }

  /// Walks every block in reading order, splits its plain text on
  /// non-whitespace runs, and stores each run as a `Selection`. Runs
  /// matched with `\S+` so punctuation rides along with the adjacent
  /// word ("world!" is one token) — close enough to how a screen reader
  /// pronounces a sentence.
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

  void _onScrollViewScrolled() {
    if (_suppressNextScrollEvent) {
      _suppressNextScrollEvent = false;
      return;
    }
    // Any scroll not originated from our auto-scroll is treated as the
    // user dragging away. Pause auto-scroll until they tap "back to
    // current" — yanking them back every word would feel hostile.
    if (!_userScrolledAway && _playing) {
      setState(() => _userScrolledAway = true);
    }
  }

  /// SuperSliverList's `visibleRangeNotifier` fires from inside its
  /// `performLayout`, so a `setState` driven directly off it asserts
  /// "Build scheduled during frame." Coalesce updates to one postFrame
  /// callback per layout pass and re-emit on the next frame.
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

  void _scrollHighlightIntoView() {
    // Pre-set the suppress flag so the scroll callback this triggers
    // doesn't immediately mark the user as having scrolled away.
    _suppressNextScrollEvent = true;
    editorState.scrollToHighlight(editorScrollController);
  }

  void _advanceTo(int i) {
    if (i < 0 || i >= _tokens.length) {
      _pause();
      // Done — clear highlight so the last word doesn't stay lit.
      editorState.updateHighlight(null);
      setState(() => _currentIndex = -1);
      return;
    }
    setState(() => _currentIndex = i);
    editorState.updateHighlight(_tokens[i]);
    if (!_userScrolledAway) {
      _scrollHighlightIntoView();
    }
  }

  void _play() {
    if (_tokens.isEmpty) return;
    if (_currentIndex < 0 || _currentIndex >= _tokens.length - 1) {
      _currentIndex = -1;
    }
    _timer?.cancel();
    _userScrolledAway = false;
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
    _userScrolledAway = false;
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

  void _onTapWord(Offset globalOffset) {
    final pos = editorState.selectionService.getPositionInOffset(globalOffset);
    if (pos == null) return;
    final tapIdx = _findTokenIndex(pos);
    if (tapIdx < 0) {
      // Tap landed in whitespace / outside any token. Suppress keyboard
      // anyway — the editor's own tap may have placed a cursor.
      _suppressKeyboardAfterTap();
      return;
    }
    _userScrolledAway = false;
    _currentIndex = tapIdx - 1;
    if (_playing) {
      _play();
    } else {
      _advanceTo(tapIdx);
    }
    _suppressKeyboardAfterTap();
  }

  /// The editor's own tap recognizer fires alongside our Listener and
  /// places a collapsed selection at the tap, which makes the keyboard
  /// service attach the IME (it gates on selection update, not on
  /// `editorState.editable`). Defer one microtask so the editor's
  /// handler has run, then close the keyboard, clear the selection,
  /// and yield focus back to the platform.
  void _suppressKeyboardAfterTap() {
    scheduleMicrotask(() {
      if (!mounted) return;
      editorState.keyboardService?.closeKeyboard();
      try {
        editorState.selectionService.clearSelection();
      } catch (_) {
        // Selection service may not be mounted yet on the very first
        // tap; safe to ignore — there's nothing to clear.
      }
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  int _findTokenIndex(Position pos) {
    for (var i = 0; i < _tokens.length; i++) {
      final t = _tokens[i];
      if (!t.start.path.equals(pos.path)) continue;
      if (pos.offset >= t.start.offset && pos.offset <= t.end.offset) {
        return i;
      }
    }
    return -1;
  }

  void _returnToCurrent() {
    setState(() => _userScrolledAway = false);
    _scrollHighlightIntoView();
  }

  /// True when the active word's top-level block is fully outside the
  /// currently visible range. Used as the trigger for the
  /// "back to current" pill.
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
      // Prevent the framework from auto-resizing for the keyboard if it
      // does manage to slip through — the body should never reflow.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Read-Along'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Raw-pointer Listener bypasses the gesture arena and the
          // editor's tap-disabled-in-readonly behavior. Down/up distance
          // < _tapSlop is treated as a tap; anything bigger is a scroll
          // and gets ignored.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) => _pointerDownAt = event.position,
              onPointerUp: (event) {
                final start = _pointerDownAt;
                _pointerDownAt = null;
                if (start == null) return;
                if ((event.position - start).distance > _tapSlop) return;
                _onTapWord(event.position);
              },
              child: AppFlowyEditor(
                editorState: editorState,
                editable: false,
                // Belt: keep the keyboard service off entirely for the
                // viewer, on top of the editor's own `editable:false`
                // gate. The example user is testing on Android where
                // any IME attach causes the keyboard to flash up.
                disableKeyboardService: true,
                showMagnifier: false,
                editorScrollController: editorScrollController,
                blockComponentBuilders: _blockComponentBuilders,
                editorStyle: _editorStyle,
              ),
            ),
          ),
          // "Back to current" pill — shows when the user has scrolled
          // the active word off-screen. Drives off the mirrored
          // [_visibleRange] (updated postFrame) so we don't rebuild
          // during SuperSliverList's layout phase.
          Positioned(
            left: 0,
            right: 0,
            bottom: 124,
            child: Builder(
              builder: (context) {
                final outOfView = _userScrolledAway &&
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
          // Bottom control panel — rounded card with circular play, skip
          // ±5 words, and a speed pill.
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
              'aloud. The highlight is driven by editorState.updateHighlight, '
              'which paints through the same BlockHighlightArea that powers '
              'normal selection rendering.',
        ),
        headingNode(level: 2, text: 'How to use it'),
        paragraphNode(
          text: 'Press play to start from the beginning. Use the skip '
              'buttons to jump five words at a time. Tap the speed pill to '
              'cycle through 0.75x, 1x, 1.25x, and 1.5x. Tap any word in '
              'the document to seek directly there.',
        ),
        paragraphNode(
          text: 'Because the editor is mounted with editable: false, the '
              'document acts purely as a viewer — no caret, no keyboard. '
              'A raw-pointer Listener catches taps and turns them into '
              '"seek to this word" events without enabling editing.',
        ),
        headingNode(level: 2, text: 'Why it matters'),
        paragraphNode(
          text: 'BlockHighlightArea is decoupled from the cursor pipeline. '
              'Anything that produces a Selection can drive it: a real TTS '
              'engine emitting word boundary events, a karaoke player '
              'aligning lyrics to audio, a collaborative cursor from a '
              'remote peer, or a tutor that walks a learner through a '
              'passage. The editor stays read-only; the highlight does the '
              'work, and the page snaps the active word back into view '
              'unless the user has chosen to scroll away.',
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

  /// True if the active word is above the visible range (user scrolled
  /// down past it). Drives the arrow direction.
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
