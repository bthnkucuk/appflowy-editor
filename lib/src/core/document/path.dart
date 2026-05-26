import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';

typedef Path = List<int>;

extension PathExtensions on Path {
  bool equals(Path other) {
    return listEquals(this, other);
  }

  bool operator >=(Path other) {
    if (equals(other)) {
      return true;
    }

    return this > other;
  }

  bool operator >(Path other) {
    if (equals(other)) {
      return false;
    }
    final length = min(this.length, other.length);
    for (var i = 0; i < length; i++) {
      if (this[i] < other[i]) {
        return false;
      } else if (this[i] > other[i]) {
        return true;
      }
    }
    if (this.length < other.length) {
      return false;
    }

    return true;
  }

  bool operator <=(Path other) {
    if (equals(other)) {
      return true;
    }

    return this < other;
  }

  bool operator <(Path other) {
    if (equals(other)) {
      return false;
    }
    final length = min(this.length, other.length);
    for (var i = 0; i < length; i++) {
      if (this[i] > other[i]) {
        return false;
      } else if (this[i] < other[i]) {
        return true;
      }
    }
    if (this.length > other.length) {
      return false;
    }

    return true;
  }

  Path get next => _withLastShifted(1);

  Path nextNPath(int n) => _withLastShifted(n);

  Path get previous => _withLastShifted(-1);

  Path previousNPath(int n) => _withLastShifted(-n);

  Path child(int index) {
    final len = length;
    final result = List<int>.filled(len + 1, 0, growable: false);
    for (var i = 0; i < len; i++) {
      result[i] = this[i];
    }
    result[len] = index;
    return result;
  }

  Path get parent {
    final len = length;
    if (len == 0) return this;
    return List<int>.generate(len - 1, (i) => this[i], growable: false);
  }

  /// Returns a fresh path with the last segment shifted by [delta]
  /// (clamped at 0 for negative results, matching the previous
  /// `previousNPath` behavior). Empty paths yield an empty path —
  /// callers historically got a `growable: true` empty list here, but
  /// nothing in the codebase mutates the returned path, so an unmodifiable
  /// const-empty avoids the per-call allocation in that corner.
  Path _withLastShifted(int delta) {
    final len = length;
    if (len == 0) return const <int>[];
    final result = List<int>.filled(len, 0, growable: false);
    for (var i = 0; i < len - 1; i++) {
      result[i] = this[i];
    }
    final shifted = this[len - 1] + delta;
    result[len - 1] = shifted < 0 ? 0 : shifted;
    return result;
  }

  bool isAncestorOf(Path other) {
    if (isEmpty) {
      return true;
    }
    if (other.isEmpty) {
      return false;
    }
    if (length >= other.length) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) {
        return false;
      }
    }

    return true;
  }

  // if isSameDepth is true, the path must be the same depth as the selection
  bool inSelection(Selection? selection, {bool isSameDepth = false}) {
    selection = selection?.normalized;
    bool result =
        selection != null &&
        selection.start.path <= this &&
        this <= selection.end.path;
    if (isSameDepth) {
      return result && selection.start.path.length == length;
    }

    return result;
  }
}
