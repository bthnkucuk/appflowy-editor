part of '../editor_state.dart';

/// Owns the `documentRules` list + the [_asyncObserver] subscription
/// that runs each rule on every applied transaction.
///
/// Declared as a plain mixin (rather than `on _EditorStateBase`) to
/// avoid a circular-superinterface error — `_EditorStateBase` already
/// applies this mixin in its `with` clause. Abstract dependencies
/// (the async transaction stream) are pulled in via the same getter
/// pattern the other mixins use.
///
/// The [DocumentRule.shouldApply] callback expects a concrete
/// [EditorState] (public API parameter), so we cast `this` once at
/// the callback boundary. Every concrete subclass that applies this
/// mixin is the [EditorState] class itself; the cast can't fail.
mixin _DocumentRulesMixin {
  // ---------------------------------------------------------------------------
  // Abstract dependencies (provided by other mixins on EditorState)
  // ---------------------------------------------------------------------------

  /// Provided by [_TransactionPipelineMixin] — the async broadcast
  /// stream that rule subscriptions listen to.
  StreamController<EditorTransactionValue> get _asyncObserver;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// The rules to apply to the document.
  List<DocumentRule> get documentRules => _documentRules;
  List<DocumentRule> _documentRules = [];

  set documentRules(List<DocumentRule> value) {
    _documentRules = value;

    _subscription?.cancel();
    _subscription = _asyncObserver.stream.listen((value) async {
      for (final rule in _documentRules) {
        if (rule.shouldApply(editorState: this as EditorState, value: value)) {
          await rule.apply(editorState: this as EditorState, value: value);
        }
      }
    });
  }

  StreamSubscription? _subscription;

  void _disposeDocumentRules() {
    _subscription?.cancel();
  }
}
