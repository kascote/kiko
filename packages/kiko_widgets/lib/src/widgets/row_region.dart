import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

/// A hit region that lives on a data row, exposing which row — information only.
///
/// ListView, TableView and TreeView all paint rows, and several of their parts
/// belong to a row: the row body itself, a tree's expand indicator. Each such
/// part implements `RowScoped` so the shared row arm on `ScrollableModel` can
/// move the cursor and the hover to the right row without knowing which concrete
/// part was hit.
///
/// It carries data, never behavior. What to *do* with the row — activate it,
/// toggle a branch, decline — stays in the widget's own update switch; a shared
/// interface only tells the arm which row a part sits on.
abstract interface class RowScoped implements Region {
  /// The row this region lives on, in the widget's own row space (the same
  /// index its data view and cursor count in).
  int get index;
}

/// The plain body of a data row — the shared region ListView, TableView and
/// TreeView mark for a row that carries nothing more specific.
///
/// A value class with structural equality, like the widgets' typed load keys: a
/// `RowRegion(3)` marked while painting equals the `RowRegion(3)` a model
/// matches in its update, so a switch resolves the row without any object
/// identity to thread through.
@immutable
class RowRegion implements RowScoped {
  /// Names the region on row [index].
  const RowRegion(this.index);

  @override
  final int index;

  @override
  bool operator ==(Object other) => other is RowRegion && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'RowRegion($index)';
}
