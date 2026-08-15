import 'package:meta/meta.dart';

import '../plume/tagged.dart';
import 'hit_map.dart';

/// A hit tag: the value kiko stamps into plume's opaque `tag` slot.
///
/// The vocabulary has two cases. An [IdTag] makes its node addressable by a
/// stable id. A [ScopeTag] marks its node as a scope, which qualifies every
/// tag beneath it. A node carries one case or the other, never both.
///
/// Apps keep passing strings. The stamping sites — [Tagged] and the widget
/// `build` methods that self-tag — wrap them, and [HitMap] reads the slot
/// back. Nothing else touches this type.
///
/// A hit path joins segments with [separator]. Use [leafOf] and [isPrefix]
/// instead of spelling the character.
@immutable
sealed class HitTag {
  /// The separator between the segments of a hit path.
  static const separator = '/';

  /// The one path segment this tag contributes.
  String get segment;

  /// Returns the last segment of [path].
  static String leafOf(String path) {
    final cut = path.lastIndexOf(separator);
    return cut < 0 ? path : path.substring(cut + 1);
  }

  /// Whether [prefix] is the path [of] itself, or an ancestor on it.
  ///
  /// Matching stops at segment boundaries: `isPrefix('cb', of: 'cb/field')`
  /// and `isPrefix('cb', of: 'cb')` are true; `isPrefix('cb', of: 'cbx')` is
  /// false.
  static bool isPrefix(String prefix, {required String of}) => of == prefix || of.startsWith('$prefix$separator');

  /// Joins an enclosing scope [prefix] with an inner [segment] into one path.
  ///
  /// A node with no enclosing scope passes an empty [prefix] and gets back
  /// [segment] unchanged, with no leading separator — a flat widget's id
  /// stays a bare id.
  static String join(String prefix, String segment) => prefix.isEmpty ? segment : '$prefix$separator$segment';

  /// Returns the id in [registered] that answers for [path], or `null` when
  /// none does.
  ///
  /// Use this to deliver a hit path to whichever registered component owns
  /// it: a router resolves the path a pointer landed on against the ids it
  /// knows, and dispatches to the answer. An exact match in [registered]
  /// wins outright. Otherwise the search climbs [path] one segment at a time
  /// toward the root, and the first prefix found in [registered] wins — a
  /// registration under a fuller path beats a shorter one further out. An
  /// unscoped id has no segment to climb to, so it matches only when [path]
  /// equals it exactly.
  static String? resolve(String path, Set<String> registered) {
    var candidate = path;
    while (true) {
      if (registered.contains(candidate)) return candidate;
      final cut = candidate.lastIndexOf(separator);
      if (cut < 0) return null;
      candidate = candidate.substring(0, cut);
    }
  }
}

/// The tag of an addressable node: the id pointer events resolve to.
///
/// Stamped by [Tagged] and by widgets that self-tag with their model id.
final class IdTag implements HitTag {
  /// Tags the carrying node with [id].
  IdTag(this.id)
    : assert(
        !id.contains(HitTag.separator),
        'Hit tag id "$id" contains the path separator "${HitTag.separator}". '
        'A segment must not contain it, or the path it joins is ambiguous.',
      );

  /// The stable id the node answers to.
  final String id;

  @override
  String get segment => id;

  @override
  bool operator ==(Object other) => identical(this, other) || other is IdTag && other.id == id;

  @override
  int get hashCode => Object.hash(IdTag, id);

  @override
  String toString() => 'IdTag($id)';
}

/// The tag of a scope: a node whose name qualifies every tag beneath it.
///
/// An id under scopes resolves as the path `scope/.../id`. A scope name is a
/// qualifier, not an addressable id, so it may sit on several nodes in one
/// frame.
final class ScopeTag implements HitTag {
  /// Marks the carrying node as the scope [name].
  ScopeTag(this.name)
    : assert(
        !name.contains(HitTag.separator),
        'Hit tag scope "$name" contains the path separator '
        '"${HitTag.separator}". A segment must not contain it, or the path it '
        'joins is ambiguous.',
      );

  /// The scope's name, one path segment.
  final String name;

  @override
  String get segment => name;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ScopeTag && other.name == name;

  @override
  int get hashCode => Object.hash(ScopeTag, name);

  @override
  String toString() => 'ScopeTag($name)';
}
