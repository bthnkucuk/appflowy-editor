import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

/// Read-along viewer ported from a production reader app. The key
/// features mirrored — and the reason this example exists — are:
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
/// 2. **`highlightable: true` + `editorState.tapEvents` stream.**
///    Instead of intercepting pointer events ourselves, we let
///    [MobileHighlightServiceWidget] do the tap routing — its
///    `_onDoubleTapUp` resolves the word boundary at the tap and
///    publishes that selection on `editorState.tapEvents`, a broadcast
///    stream. We subscribe with `.listen` and treat each event as a
///    momentary tap-to-seek. The tap does NOT write the editor's
///    `selection`, so `BlockSelectionArea` does not paint a gray rect
///    on the viewer — important because this page sets
///    `editable: false`.
///
/// 3. **Editor-owned auto-scroll state.** The "back to current" pill
///    drives off `editorState.isAutoScrollHighlightNotifier`, not a
///    local flag. User drags the editor (reverse scroll) → we call
///    `disableAutoScrollHighlight()`. Pill tap →
///    `enableAutoScrollHighlight(editorScrollController)`. The mixin
///    then subscribes to `highlightNotifier` itself, so every
///    `updateHighlight(...)` tick drives a scroll automatically with no
///    extra call at the tick callsite.
///
///    Canonical engage entrypoint: ALWAYS
///    `editorState.enableAutoScrollHighlight(controller)`. The setter
///    `editorState.isAutoScrollHighlight = true` and the direct
///    `isAutoScrollHighlightNotifier.value = true` write only flip the
///    notifier — they do NOT attach the highlight listener that the
///    auto-scroll machinery rides on. Mixing the two is a silent
///    regression: the toggle reads as "engaged" but no scroll actually
///    fires on subsequent highlight changes. Stick to the
///    `enable...`/`disable...` pair end-to-end.
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

/// Build path the demo wires up for its initial `Document`. See
/// `_TtsReaderPageState._sampleDocumentSource` for the full doc.
enum _SampleDocumentSource {
  programmatic('Programmatic (typed factories)'),
  markdown('Markdown → Document'),
  json('JSON → Document');

  const _SampleDocumentSource(this.label);

  final String label;
}

class _TtsReaderPageState extends State<TtsReaderPage> {
  // Word-per-tick at 1.0x speed.
  static const Duration _baseWordDuration = Duration(milliseconds: 350);

  // Cycle order for the speed pill.
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5];

  /// Runtime-switchable build path for the demo's `Document`.
  ///
  /// Mutable (vs. `static const`) so the AppBar overflow menu can hot-
  /// swap the source while the page is mounted — every switch tears
  /// down the current editor state and rebuilds, exercising the
  /// **mid-lifecycle EditorState replacement** pattern downstream
  /// reader apps use in `prepareReader`-style flows (open a new
  /// document → dispose the old `EditorState` / scroll controller →
  /// build new ones → re-subscribe to tap events → reset tokens /
  /// playlist / playback cursor → setState to flush).
  ///
  /// Three build paths the menu can pick:
  ///
  /// - [_SampleDocumentSource.programmatic] — typed-factory tree built
  ///   via `headingNode` / `paragraphNode` / `noteNode`. Best for
  ///   hand-authored content; gets the custom `NoteBlockComponent`
  ///   for free because it lives in the typed factory.
  /// - [_SampleDocumentSource.markdown] — round-trips through
  ///   `markdownToDocument(...)`. The canonical "I have a markdown
  ///   string from disk / network / remote CMS, parse it into a
  ///   Document" path. The standard markdown parsers don't know about
  ///   the custom note block, so the note drops out of the resulting
  ///   document — the same lossy tradeoff a downstream markdown-
  ///   sourced reader makes.
  /// - [_SampleDocumentSource.json] — round-trips through
  ///   `Document.toJson()` + `Document.fromJson(...)`. The canonical
  ///   "load a persisted document from storage" path. JSON is
  ///   lossless across `Node.type` + `Node.attributes` + children, so
  ///   the custom note block survives the round-trip with no
  ///   encoder-side help.
  _SampleDocumentSource _documentSource = _SampleDocumentSource.programmatic;

  // `late` (not `late final`) — the AppBar swap menu rebuilds both on
  // every source switch. The builders + style don't depend on the
  // document tree, so they stay `late final`.
  late EditorState editorState;
  late EditorScrollController editorScrollController;
  late final Map<String, BlockComponentBuilder> _blockComponentBuilders;
  late final EditorStyle _editorStyle;

  /// Pre-computed word selections, in reading order. The static sample
  /// document is read-only so it never drifts.
  final List<Selection> _tokens = [];

  /// Flattened section playlist, each entry pairing a [Section] with
  /// its running character-count prefix in document order. Built via
  /// the package's `mapWithCharacterOffsets` so this example and the
  /// production reader app share one stamping primitive — drift between
  /// the two pipelines is structurally impossible.
  ///
  /// Used here to estimate the document's total reading time; in a real
  /// audio player each entry would become a queue item with timing
  /// metadata projected from `characterOffset`.
  final List<_PlaylistItem> _playlist = [];

  int _totalCharacterCount = 0;

  /// Control-panel + back-pill state held in notifiers so the per-tick
  /// advance doesn't `setState` the whole page — that would rebuild
  /// `AppFlowyEditor` and cascade down through every visible block on
  /// every word. Only the pill and panel `ValueListenableBuilder`s
  /// rebuild on these.
  final ValueNotifier<int> _currentIndex = ValueNotifier(-1);
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  final ValueNotifier<double> _speed = ValueNotifier(1.0);
  Timer? _timer;

  /// Subscription to the editor's one-shot tap-event stream — cancelled
  /// in [dispose] so we don't outlive the editor.
  StreamSubscription<Selection>? _tapEventsSubscription;

  @override
  void initState() {
    super.initState();

    editorState = EditorState(document: _buildInitialDocument());
    editorState.editable = false;
    // Per-Document parser — sections are computed lazily on first
    // read of `node.sections` (no eager tree walk). Scoped to this
    // EditorState, so it can't leak into other example pages.
    editorState.sectionParser = (node) =>
        defaultSentenceSectionParser(node, soft: 50, hard: 500);
    editorScrollController = EditorScrollController(
      editorState: editorState,
      shrinkWrap: false,
    );
    _blockComponentBuilders = _buildBlockComponentBuilders();
    _editorStyle = _buildEditorStyle();
    _tokens.addAll(_computeWordTokens(editorState.document));

    // Build the section playlist exactly the way the production reader
    // app does: flatten `node.sections` across the document, then stamp
    // each section with its running prefix-sum of character counts via
    // the package's `mapWithCharacterOffsets`. First read of
    // `node.sections` here triggers the lazy compute installed above.
    _playlist.addAll(
      editorState.document.root.children
          .map((node) => node.sections)
          .whereType<Sections>()
          .expand((s) => s)
          .mapWithCharacterOffsets(
            (section, characterOffset) => _PlaylistItem(
              section: section,
              characterOffset: characterOffset,
            ),
          ),
    );
    if (_playlist.isNotEmpty) {
      final last = _playlist.last;
      _totalCharacterCount =
          last.characterOffset + last.section.characterCount;
    }

    // The editor's MobileHighlightServiceWidget publishes tap-ups onto
    // editorState.tapEvents (see mobile_highlight_service._onDoubleTapUp).
    // The stream is broadcast and carries only taps, so there's no
    // reason to gate or consume — each event is one tap.
    _tapEventsSubscription = editorState.tapEvents.listen(_onTap);
  }

  /// Mid-lifecycle `EditorState` replacement — the pattern downstream
  /// reader apps use when the user opens a new document while the
  /// reader screen is mounted. Tears down every editor-bound piece of
  /// state in dependency order:
  ///
  /// 1. Halt the playback timer + the tap-event subscription so no
  ///    stray callback fires against the (about-to-be-)disposed editor.
  /// 2. Dispose the scroll controller before the editor state — the
  ///    controller's listener on `editorState.document.root` would
  ///    otherwise survive past its host.
  /// 3. Dispose the editor state. The transaction pipeline closes,
  ///    every notifier (`selectionNotifier`, `highlightNotifier`,
  ///    `tapEvents` stream, the outline notifier, dirty notifier)
  ///    closes / disposes, the document tears down with it.
  /// 4. Reset every reader-local field that was derived from the old
  ///    document — tokens, playlist, character count, the playback
  ///    cursor (`_currentIndex`), the `_playing` flag.
  /// 5. Build the new editor state through `EditorState(document:
  ///    _buildDocumentFor(source))`, re-attach the section parser,
  ///    rebuild the scroll controller, recompute tokens + playlist,
  ///    re-subscribe to the new `tapEvents` stream.
  /// 6. `setState` to flush. The page's `build()` recomputes against
  ///    the new editor state; `AppFlowyEditor` re-receives the new
  ///    state via `didUpdateWidget`; every `AnimatedBuilder` /
  ///    `ValueListenableBuilder` keyed off the editor's notifiers
  ///    re-subscribes to the new ones.
  Future<void> _swapDocumentSource(_SampleDocumentSource source) async {
    if (source == _documentSource) return;

    // Load the new document FIRST. If the asset is missing or markdown
    // parsing throws, we surface the failure before tearing down the
    // current editor — the user keeps reading whatever they had.
    final Document newDocument;
    try {
      newDocument = await _buildDocumentFor(source);
    } catch (error, stack) {
      debugPrint('[H-DBG] swap aborted: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load $source: $error')),
        );
      }
      return;
    }
    if (!mounted) return;

    _timer?.cancel();
    _timer = null;
    _tapEventsSubscription?.cancel();
    _tapEventsSubscription = null;
    editorScrollController.dispose();
    editorState.dispose();

    _tokens.clear();
    _playlist.clear();
    _totalCharacterCount = 0;
    _currentIndex.value = -1;
    _playing.value = false;

    setState(() {
      _documentSource = source;
      editorState = EditorState(document: newDocument);
      editorState.editable = false;
      editorState.sectionParser = (node) =>
          defaultSentenceSectionParser(node, soft: 50, hard: 500);
      editorScrollController = EditorScrollController(
        editorState: editorState,
        shrinkWrap: false,
      );
      _tokens.addAll(_computeWordTokens(editorState.document));
      _playlist.addAll(
        editorState.document.root.children
            .map((node) => node.sections)
            .whereType<Sections>()
            .expand((s) => s)
            .mapWithCharacterOffsets(
              (section, characterOffset) => _PlaylistItem(
                section: section,
                characterOffset: characterOffset,
              ),
            ),
      );
      if (_playlist.isNotEmpty) {
        final last = _playlist.last;
        _totalCharacterCount =
            last.characterOffset + last.section.characterCount;
      }
      _tapEventsSubscription = editorState.tapEvents.listen(_onTap);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tapEventsSubscription?.cancel();
    editorScrollController.dispose();
    editorState.dispose();
    _currentIndex.dispose();
    _playing.dispose();
    _speed.dispose();
    super.dispose();
  }

  /// Build the block-component builder map using the additive pattern a
  /// reader app typically wants: start from the package's
  /// [standardBlockComponentBuilderMap] (so heading, paragraph, quote,
  /// list, image, divider, …, every block type the editor ships,
  /// continues to render out of the box), spread it into a fresh
  /// `{...}` literal (the default is a top-level `final` map of shared
  /// builder instances — mutating a builder in place would leak into
  /// every other editor mounted in the same process), and override
  /// only the entries we actually want to retune for read-along.
  ///
  /// Here we retune paragraph + heading for tighter vertical padding,
  /// disable the inline +/action affordances across the board (a
  /// read-only viewer never needs them), and leave every other block
  /// alone — the same "spread + override" shape downstream reader apps
  /// use to inject custom image / media / divider builders without
  /// re-listing the entire block catalog.
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

    // Spread the standard map FIRST so every package-shipped block keeps
    // working. Override the three we care about with the fresh, tuned
    // instances we built above — for any other block type a downstream
    // reader app needs to retune (e.g. a custom image block or quote
    // styling), construct a new builder instance and add another entry
    // here. Do NOT mutate `.configuration` / `.showActions` on the
    // standard-map instances in place: they're shared `final` references
    // across every editor in the process.
    //
    // The `NoteBlockKeys.type` entry is our custom-block demo: see the
    // bottom of the file for the matching `NoteBlockComponentBuilder` /
    // widget / `SelectableMixin` implementation. This is the same
    // additive pattern a downstream consumer uses to wire in a custom
    // image, audio card, or callout — register the type → renderer
    // mapping here and the editor's renderer resolves it on every node
    // whose `type` matches.
    final note = NoteBlockComponentBuilder()..showActions = (_) => false;
    return <String, BlockComponentBuilder>{
      ...standardBlockComponentBuilderMap,
      PageBlockKeys.type: page,
      ParagraphBlockKeys.type: paragraph,
      HeadingBlockKeys.type: heading,
      NoteBlockKeys.type: note,
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
  ///
  /// Built via [Selection.single] rather than the two-`Position`
  /// constructor: every word lives inside one node, so the path is
  /// shared between start and end. `Selection.single(path:,
  /// startOffset:, endOffset:)` says exactly that, and is the public
  /// shortcut for "same-path range selection". Downstream readers
  /// that compute token streams should use the same idiom — keeps the
  /// hot loop free of redundant `Position` allocations.
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
          Selection.single(
            path: node.path,
            startOffset: m.start,
            endOffset: m.end,
          ),
        );
      }
    }
    return tokens;
  }

  Duration get _tickDuration => Duration(
        milliseconds: (_baseWordDuration.inMilliseconds / _speed.value).round(),
      );

  void _advanceTo(int i) {
    if (i < 0 || i >= _tokens.length) {
      _pause();
      editorState.updateHighlight(null);
      _currentIndex.value = -1;
      return;
    }
    _currentIndex.value = i;
    // The mixin subscribed to `highlightNotifier` when we called
    // `enableAutoScrollHighlight(...)`, so this single write drives
    // both the visual highlight and the auto-scroll. No explicit
    // `highlightChanged(controller)` call is needed.
    editorState.updateHighlight(_tokens[i]);
  }

  void _play() {
    if (_tokens.isEmpty) return;
    if (_currentIndex.value < 0 || _currentIndex.value >= _tokens.length - 1) {
      _currentIndex.value = -1;
    }
    _timer?.cancel();
    // Re-arm auto-scroll on play — like the app does on tap or skip.
    editorState.enableAutoScrollHighlight(editorScrollController);
    _advanceTo(_currentIndex.value + 1);
    _playing.value = true;
    _timer = Timer.periodic(_tickDuration, (_) {
      _advanceTo(_currentIndex.value + 1);
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_playing.value) _playing.value = false;
  }

  void _togglePlay() => _playing.value ? _pause() : _play();

  /// Jump to the start of the next/previous section.
  ///
  /// Sections live on each `Node` after `Node.sectionParser` runs.
  /// "Next" = first section after the one currently under the active
  /// word (crossing node boundaries when needed). "Previous" = the
  /// preceding section the same way. We resolve the target section
  /// first, then map its start back into the token list by node path
  /// and offset so we land on a token the tick loop can advance from.
  void _skipSection({required bool forward}) {
    if (_tokens.isEmpty) return;
    final targetTokenIdx = _findAdjacentSectionStartToken(forward: forward);
    if (targetTokenIdx < 0) return;
    editorState.enableAutoScrollHighlight(editorScrollController);
    _currentIndex.value = targetTokenIdx - 1;
    if (_playing.value) {
      _play();
    } else {
      _advanceTo(targetTokenIdx);
    }
  }

  /// Returns the token index at which the next/previous section starts,
  /// or -1 if we're already at a boundary with nothing to skip to.
  int _findAdjacentSectionStartToken({required bool forward}) {
    final tokens = _tokens;
    final currentIdx = _currentIndex.value < 0 ? 0 : _currentIndex.value;
    final currentToken = tokens[currentIdx];
    final currentPath = currentToken.start.path;
    final currentOffset = currentToken.start.offset;

    // Walk top-level blocks in document order, flattening each block's
    // sections into one sequence; find our position in that sequence
    // and return the start token of the next/previous slot.
    final root = editorState.document.root;
    final sections = <(Path, Section)>[];
    for (var i = 0; i < root.children.length; i++) {
      final node = root.children[i];
      final nodeSections = node.sections;
      if (nodeSections == null) continue;
      for (final s in nodeSections) {
        sections.add((node.path, s));
      }
    }
    if (sections.isEmpty) return -1;

    // Locate the section enclosing the current token. Comparison is
    // (path, offset) so we cope with same-offset sections in adjacent
    // nodes.
    int currentSectionIdx = -1;
    for (var i = 0; i < sections.length; i++) {
      final (path, sec) = sections[i];
      if (!path.equals(currentPath)) continue;
      if (currentOffset >= sec.selection.start.offset &&
          currentOffset < sec.selection.end.offset) {
        currentSectionIdx = i;
        break;
      }
    }
    if (currentSectionIdx < 0) {
      currentSectionIdx = forward ? -1 : sections.length;
    }

    final targetIdx = forward ? currentSectionIdx + 1 : currentSectionIdx - 1;
    if (targetIdx < 0 || targetIdx >= sections.length) {
      // No further section — clamp to first/last token instead so the
      // button doesn't feel dead at the edges.
      return forward ? tokens.length - 1 : 0;
    }

    final (targetPath, targetSection) = sections[targetIdx];
    final targetOffset = targetSection.selection.start.offset;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (!t.start.path.equals(targetPath)) continue;
      if (t.end.offset > targetOffset) return i;
    }
    return -1;
  }

  void _cycleSpeed() {
    final nextIdx = (_speeds.indexOf(_speed.value) + 1) % _speeds.length;
    _speed.value = _speeds[nextIdx];
    if (_playing.value) {
      _timer?.cancel();
      _timer = Timer.periodic(_tickDuration, (_) {
        _advanceTo(_currentIndex.value + 1);
      });
    }
  }

  /// Tap routing via the editor's `tapEvents` stream. Mirrors the
  /// downstream reader app's `tapListener`, modernized: resolve the
  /// enclosing section by offset midpoint, locate the matching token,
  /// seek there, re-arm auto-scroll. The stream carries only taps, so
  /// there is no reason gate and no consume step — each event is one
  /// tap and is delivered exactly once.
  void _onTap(Selection tap) {
    final node = editorState.getNodesInSelection(tap).lastOrNull;
    if (node == null) return;

    // Tap midpoint as a collapsed [Selection]. `Position.copyWith` lets
    // us reuse `tap.start.path` (the tap is single-line so start.path
    // == end.path) and only override the offset; `Selection.collapsed`
    // wraps the resulting point so we have a Selection-typed value to
    // hand to selection-shaped APIs without writing a length-zero
    // range out longhand. Both APIs together are the canonical
    // "convert a tap range into a hit-test point" idiom.
    final tapPoint = tap.start.copyWith(
      offset: (tap.start.offset + tap.end.offset) ~/ 2,
    );
    final collapsedTap = Selection.collapsed(tapPoint);

    // Resolve the section containing the tap — same predicate
    // [BlockHighlightArea._updateSelectionIfNeeded] uses. Pass the
    // collapsed midpoint; `sectionForSelection` would compute the same
    // midpoint internally anyway.
    final section = node.sectionForSelection(collapsedTap);
    if (section == null) return;

    final tokenIdx = _findTokenIndex(node, tapPoint.offset);
    if (tokenIdx < 0) return;

    editorState.enableAutoScrollHighlight(editorScrollController);
    _currentIndex.value = tokenIdx - 1;
    if (_playing.value) {
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

  /// Resume reading at [tokenIndex] — the "open a document at the saved
  /// last-read word" pattern. Used by reader apps that persist the last
  /// position and want to drop the user back where they left off.
  ///
  /// Two pieces of editor API to highlight here:
  ///
  /// 1. `enableAutoScrollHighlight(controller)` is the canonical engage
  ///    point. Direct setter on `isAutoScrollHighlight` would flip the
  ///    notifier without attaching the highlight listener — the toggle
  ///    would read engaged but no scroll would actually fire (see the
  ///    class header §3).
  ///
  /// 2. `scrollToHighlight(..., alignToTop: false)` is the resume-vs-tap
  ///    semantic difference. For taps we land the active word near the
  ///    top of the viewport (default `alignToTop: true`) so the user
  ///    has room to read forward. For resume, we want the saved word
  ///    near the BOTTOM so the user sees the lead-up content above —
  ///    the saved position is where they STOPPED, not where they're
  ///    about to begin. `alignToTop: false` only matters on the
  ///    no-rect fallback path (highlight off-screen at engagement time),
  ///    which is exactly the resume scenario.
  void _resumeAt(int tokenIndex) {
    if (tokenIndex < 0 || tokenIndex >= _tokens.length) return;
    _currentIndex.value = tokenIndex;
    editorState.updateHighlight(_tokens[tokenIndex]);
    editorState.enableAutoScrollHighlight(editorScrollController);
    editorState.scrollToHighlight(
      editorScrollController,
      selection: editorState.highlight,
      alignToTop: false,
    );
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
        actions: [
          IconButton(
            tooltip: 'Resume from middle of document',
            icon: const Icon(Icons.bookmark_rounded),
            onPressed: () {
              if (_tokens.isEmpty) return;
              _resumeAt(_tokens.length ~/ 2);
            },
          ),
          // Mid-lifecycle document swap demo. Downstream reader apps
          // open new documents while the reader screen stays mounted —
          // this menu exercises that path against all three Document
          // factories (programmatic Node tree, markdownToDocument,
          // Document.fromJson) so a refactor that breaks any of them
          // gets caught by manually flipping through the menu.
          PopupMenuButton<_SampleDocumentSource>(
            tooltip: 'Switch sample document source',
            icon: const Icon(Icons.swap_horiz_rounded),
            onSelected: _swapDocumentSource,
            itemBuilder: (context) => [
              for (final source in _SampleDocumentSource.values)
                CheckedPopupMenuItem<_SampleDocumentSource>(
                  value: source,
                  checked: source == _documentSource,
                  child: Text(source.label),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            // User-scroll detection. Disable auto-scroll on either
            // direction so the pill triggers whether the user dragged
            // back to re-read or forward to peek ahead. Idle frames
            // don't count (those fire after the drag releases).
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification &&
                    notification.direction != ScrollDirection.idle) {
                  editorState.disableAutoScrollHighlight();
                }
                return false;
              },
              child: AppFlowyEditor(
                editorState: editorState,
                editable: false,
                // `highlightable: true` wires
                // MobileHighlightServiceWidget — the source of tap
                // events published on editorState.tapEvents. Without
                // this the tap-to-seek path is dead.
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
          // Back-to-current pill. Visibility = "user has an active
          // read position AND has scrolled away from it" → drive off
          // `isAutoScrollHighlightNotifier`, same as the app. We don't
          // gate on viewport intersection because a small drag may
          // leave the word still on-screen but the user has already
          // told the editor to stop following.
          Positioned(
            left: 0,
            right: 0,
            bottom: 124,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                editorState.isAutoScrollHighlightNotifier,
                editorScrollController.visibleRangeNotifier,
                _currentIndex,
              ]),
              builder: (context, _) {
                final autoScroll =
                    editorState.isAutoScrollHighlightNotifier.value;
                final visibleRange =
                    editorScrollController.visibleRangeNotifier.value;
                final currentIndex = _currentIndex.value;
                final show = currentIndex >= 0 && !autoScroll;
                final activeBlock =
                    _tokens.isNotEmpty && currentIndex >= 0
                        ? (_tokens[currentIndex].start.path.firstOrNull ?? 0)
                        : 0;
                // visibleRange.$1 / .$2 are first/last top-level child
                // indices currently rendered by SuperSliverList. Arrow
                // points up if active word is above the visible
                // window, down if below; defaults to down when range
                // is unknown ((-1, -1) or initial (0, 0)).
                final isAbove = visibleRange.$1 >= 0 &&
                    activeBlock < visibleRange.$1;
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
                  child: show
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
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _playing,
                  _speed,
                  _currentIndex,
                ]),
                builder: (context, _) => _ControlPanel(
                  playing: _playing.value,
                  speed: _speed.value,
                  currentIndex: _currentIndex.value,
                  totalTokens: _tokens.length,
                  totalCharacterCount: _totalCharacterCount,
                  onTogglePlay: _togglePlay,
                  onSkipBack: () => _skipSection(forward: false),
                  onSkipForward: () => _skipSection(forward: true),
                  onCycleSpeed: _cycleSpeed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the build path declared by the runtime [_documentSource].
  /// Keeping all three branches reachable from one switch means every
  /// alternative is type-checked and analyzer-visited on every build —
  /// they don't rot into "demo code that compiled three releases ago".
  /// initState builds the initial document synchronously — only the
  /// `programmatic` source is allowed at boot, so this stays sync.
  /// Runtime swaps go through the async [_buildDocumentFor].
  Document _buildInitialDocument() {
    assert(
      _documentSource == _SampleDocumentSource.programmatic,
      'Initial document must be the programmatic source — markdown / '
      'json paths require async asset loads and must go through the '
      'AppBar swap menu.',
    );
    return _buildSampleDocument();
  }

  Future<Document> _buildDocumentFor(_SampleDocumentSource source) async =>
      switch (source) {
        _SampleDocumentSource.programmatic => _buildSampleDocument(),
        _SampleDocumentSource.markdown =>
          await _buildSampleDocumentFromMarkdown(),
        _SampleDocumentSource.json => await _buildSampleDocumentFromJson(),
      };

  /// Loads `assets/sample_article.md` via [rootBundle] and runs it
  /// through `markdownToDocument(...)` — the canonical "I have a
  /// markdown file (on disk, in assets, fetched from the network),
  /// parse it into a Document" path. The editor ships a default set of
  /// block-level markdown parsers (heading, paragraph, list,
  /// blockquote, …) that the call below applies. Custom block types
  /// (like our [NoteBlockComponent]) are NOT in that default set — a
  /// markdown-sourced document loses them, the same tradeoff a
  /// downstream markdown-sourced reader makes. Pass `customParsers:`
  /// to teach the decoder about additional block shapes.
  Future<Document> _buildSampleDocumentFromMarkdown() async {
    final markdown = await rootBundle.loadString('assets/sample_article.md');
    return markdownToDocument(markdown);
  }

  /// Loads `assets/example.json` via [rootBundle] and runs it through
  /// `Document.fromJson(...)` — the canonical "load a persisted
  /// document from storage" path. JSON is lossless across `Node.type`
  /// + `Node.attributes` + children, so any custom block survives the
  /// round-trip with no encoder-side help — the same shape an app uses
  /// to persist user-authored documents to a backend.
  Future<Document> _buildSampleDocumentFromJson() async {
    final raw = await rootBundle.loadString('assets/example.json');
    return Document.fromJson(jsonDecode(raw) as Map<String, Object?>);
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
        // Custom-block demo: a "Note" callout. See the
        // NoteBlockComponent definitions at the bottom of the file —
        // this is the canonical pattern downstream reader apps use to
        // register a custom block (image card, audio cue, callout) into
        // the editor's renderer map. Tap the bookmark icon in the
        // gutter to toggle a `bookmarked` attribute via the transaction
        // API; the text content participates in the read-along stream
        // like any other paragraph, no note-specific code required.
        noteNode(
          text: 'Note: the yellow callout above is a custom block — '
              'tap the bookmark to flip its state through the editor\'s '
              'transaction pipeline. Read-along still tracks each word '
              'inside.',
        ),
        paragraphNode(
          text: 'Tapping is routed through editorState.tapEvents — '
              'MobileHighlightServiceWidget resolves the word boundary at '
              'the tap and publishes that selection on the broadcast '
              'stream. We subscribe with .listen and treat each event as '
              'a one-shot tap-to-seek. This is the exact path the '
              'downstream reader app uses for tap-to-seek into a TTS queue.',
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

/// Playlist item — Section + its running character-count prefix in
/// reading order. Same shape the production reader app's audio
/// `NodedMediaItem` carries; both are constructed from the same
/// `Sections.mapWithCharacterOffsets` helper so this example and the
/// real player can't drift on offset semantics.
class _PlaylistItem {
  const _PlaylistItem({
    required this.section,
    required this.characterOffset,
  });

  final Section section;
  final int characterOffset;
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.playing,
    required this.speed,
    required this.currentIndex,
    required this.totalTokens,
    required this.totalCharacterCount,
    required this.onTogglePlay,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onCycleSpeed,
  });

  final bool playing;
  final double speed;
  final int currentIndex;
  final int totalTokens;

  /// Sum of character counts across every section, computed from the
  /// playlist's last item: `last.characterOffset + last.section.characterCount`.
  /// Used to surface an estimated reading time in the panel — the same
  /// projection the production audio player applies when computing
  /// playlist duration.
  final int totalCharacterCount;

  final VoidCallback onTogglePlay;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onCycleSpeed;

  /// Rough words-per-minute → characters-per-minute projection for
  /// English-ish prose (~228 wpm × 4.33 chars/word ≈ 987). The production
  /// reader carries a per-language table for this; here a single
  /// constant keeps the example focused on the pattern.
  static const int _approxCharsPerMinute = 987;

  String _formatEstimatedTime() {
    if (totalCharacterCount == 0) return '—';
    final minutes = (totalCharacterCount / _approxCharsPerMinute).round();
    if (minutes < 1) return '<1 min';
    return '~$minutes min';
  }

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
                  tooltip: 'Previous section',
                  iconSize: 28,
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: onSkipBack,
                ),
                const SizedBox(width: 8),
                _PlayPauseButton(playing: playing, onTap: onTogglePlay),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Next section',
                  iconSize: 28,
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: onSkipForward,
                ),
                const Spacer(),
                SizedBox(
                  width: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        totalTokens == 0
                            ? '—'
                            : '${currentIndex < 0 ? 0 : currentIndex + 1}/$totalTokens',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      Text(
                        _formatEstimatedTime(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Custom block-component demo: a "Note" callout.
//
// Mirrors the every-day pattern a downstream reader app uses when it
// ships custom block types (images, audio cards, callouts, …):
//
//   1. A `Keys` class with attribute string constants.
//   2. A `nodeName(...)` factory helper that returns a `Node` with the
//      right type + attributes.
//   3. A `BlockComponentBuilder` subclass — the editor's renderer
//      registry looks builders up by `node.type` and calls
//      `build(blockComponentContext)`.
//   4. A `BlockComponentStatefulWidget` subclass for the actual widget.
//   5. The widget's `State` mixes in `SelectableMixin`,
//      `DefaultSelectableMixin` (forwards the selectable contract to an
//      inner `AppFlowyRichText`), and `BlockComponentConfigurable`
//      (gives access to the configuration the builder was set up with).
//   6. The build method wraps everything in `BlockSelectionContainer`
//      so the selection / highlight / remote-cursor paint layers know
//      where this block sits.
//   7. Attribute mutations go through `editorState.transaction
//      ..updateNode(node, {...}); editorState.apply(transaction)` — the
//      canonical write path. Direct attribute writes bypass the
//      transaction broadcast pipeline (history, ToC, dirty tracker)
//      and will quietly desync the editor's reactive state.
//
// Demo behaviour: tap the bookmark icon in the gutter to toggle a
// `bookmarked` flag. The flag flips via the transaction API, which
// triggers a rebuild via the editor's transaction stream, which the
// note widget re-reads on next build to recolour the icon. The text
// content is rendered with `AppFlowyRichText` so it joins the reader's
// highlight stream like any other paragraph — section underlay,
// word-level highlight, tap-to-seek all just work without
// note-specific code.
// ---------------------------------------------------------------------------

class NoteBlockKeys {
  const NoteBlockKeys._();

  static const String type = 'note';

  /// Standard `delta` key — same as paragraph/heading so the package's
  /// `Node.delta` getter resolves the text content with no special
  /// handling. Kept as a constant here to mirror the
  /// `ParagraphBlockKeys`-shape convention downstream codebases use.
  static const String delta = blockComponentDelta;

  /// Custom attribute: `true` when the reader has bookmarked the note.
  static const String bookmarked = 'bookmarked';
}

Node noteNode({String? text, bool bookmarked = false}) {
  return Node(
    type: NoteBlockKeys.type,
    attributes: {
      NoteBlockKeys.delta: (Delta()..insert(text ?? '')).toJson(),
      NoteBlockKeys.bookmarked: bookmarked,
    },
  );
}

class NoteBlockComponentBuilder extends BlockComponentBuilder {
  NoteBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NoteBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }
}

class NoteBlockComponentWidget extends BlockComponentStatefulWidget {
  const NoteBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<NoteBlockComponentWidget> createState() =>
      _NoteBlockComponentWidgetState();
}

class _NoteBlockComponentWidgetState extends State<NoteBlockComponentWidget>
    with SelectableMixin, DefaultSelectableMixin, BlockComponentConfigurable {
  @override
  final forwardKey = GlobalKey(debugLabel: 'note_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: NoteBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  late final editorState = Provider.of<EditorState>(context, listen: false);

  /// Canonical block-attribute mutation. Build a transaction off
  /// `editorState.transaction`, mutate via `updateNode`, hand back to
  /// `editorState.apply(transaction)` — the editor's broadcast pipeline
  /// then notifies history, the dirty tracker, the ToC notifier, and any
  /// downstream `transactionStream` subscribers. Direct
  /// `node.updateAttributes(...)` bypasses every one of those and is the
  /// quickest way to desync state.
  void _toggleBookmark() {
    final current =
        widget.node.attributes[NoteBlockKeys.bookmarked] as bool? ?? false;
    final transaction = editorState.transaction
      ..updateNode(widget.node, {
        NoteBlockKeys.bookmarked: !current,
      });
    editorState.apply(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final bookmarked =
        widget.node.attributes[NoteBlockKeys.bookmarked] as bool? ?? false;

    Widget child = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gutter button — the transaction API demo. Tap to toggle the
        // `bookmarked` flag via the canonical mutation path. IconButton
        // owns its own gesture recognizer; the parent
        // MobileSelectionGestureDetector's onTapUp on the same pointer
        // ALSO fires and seeks playback to whichever word boundary the
        // tap landed on — that's fine, an icon tap lands at offset 0,
        // i.e. the note's first word, which is the intuitive seek
        // target for "user just interacted with this note".
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 4),
          child: IconButton(
            icon: Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline,
              size: 18,
              color: Colors.amber.shade800,
            ),
            tooltip: bookmarked
                ? 'Unbookmark this note'
                : 'Bookmark this note',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(
              width: 28,
              height: 28,
            ),
            padding: EdgeInsets.zero,
            onPressed: _toggleBookmark,
          ),
        ),
        Expanded(
          child: AppFlowyRichText(
            key: forwardKey,
            delegate: this,
            node: widget.node,
            editorState: editorState,
            placeholderText: '',
            textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
              const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Color(0xFF6B5C00),
              ),
            ),
            cursorColor: editorState.editorStyle.cursorColor,
            selectionColor: editorState.editorStyle.selectionColor,
            highlightColor: editorState.editorStyle.highlightColor,
            highlightAreaColor: editorState.editorStyle.highlightAreaColor,
            cursorWidth: editorState.editorStyle.cursorWidth,
          ),
        ),
      ],
    );

    child = Container(
      key: blockComponentKey,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );

    child = BlockSelectionContainer(
      node: widget.node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      highlight: editorState.highlightNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      highlightColor: editorState.editorStyle.highlightColor,
      highlightAreaColor: editorState.editorStyle.highlightAreaColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    return child;
  }
}
