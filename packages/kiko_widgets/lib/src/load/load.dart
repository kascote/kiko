import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

// ═══════════════════════════════════════════════════════════
// LOAD STATE MACHINE
// ═══════════════════════════════════════════════════════════

/// The lifecycle of a single load: not started, in flight, or failed.
///
/// A load starts [idle], turns [loading] when its fetch begins, and ends either
/// back at [idle] once the result is applied, or at [error] if the fetch threw.
enum LoadStatus {
  /// Nothing is loading (and nothing has failed) for this slot.
  idle,

  /// A fetch is in flight.
  loading,

  /// The last fetch failed; the cause is kept in [LoadState.error].
  error,
}

/// A snapshot of one load's state — its [status], plus the [error] if it failed.
///
/// Read it from a [LoadTracker] to drive the UI: show a spinner while
/// [isLoading], an error message while [failed].
@immutable
class LoadState {
  /// Creates a state with the given [status] and, for failures, the [error].
  const LoadState(this.status, [this.error]);

  /// Where this load is in its lifecycle.
  final LoadStatus status;

  /// The failure cause — set only when [status] is [LoadStatus.error].
  final Object? error;

  /// Whether a fetch is in flight.
  bool get isLoading => status == LoadStatus.loading;

  /// Whether the last fetch failed.
  bool get failed => status == LoadStatus.error;

  /// The shared "nothing happening" state.
  static const idle = LoadState(LoadStatus.idle);
}

/// Tracks the state of one or more loads, each identified by a key.
///
/// A widget keeps one of these. Simple widgets track a single load with one key
/// and use the no-argument [isLoading]; widgets that load several things at once
/// — a tree fetching multiple branches, a table paging in both directions —
/// give each its own key and track them independently.
///
/// Call [begin] the moment a fetch is requested, then [complete] it when the
/// data arrives or [fail] it when the fetch throws. A load that never started,
/// or has completed, has no entry: [stateFor] reports it as idle.
class LoadTracker<K> {
  final _slots = <K, LoadState>{};

  /// Marks [key] as loading. Call this as soon as the fetch is requested, so
  /// the same data is never requested twice while it's already on its way.
  void begin(K key) => _slots[key] = const LoadState(LoadStatus.loading);

  /// Clears [key] back to idle once its data has been applied.
  void complete(K key) => _slots.remove(key);

  /// Records that [key]'s fetch failed, keeping [error] so the UI can show it.
  void fail(K key, Object error) => _slots[key] = LoadState(LoadStatus.error, error);

  /// The current state of [key], or [LoadState.idle] if it has no entry.
  LoadState stateFor(K key) => _slots[key] ?? LoadState.idle;

  /// The error recorded for [key], or null if it isn't in the failed state.
  Object? errorFor(K key) => stateFor(key).error;

  /// Whether a fetch is in flight — for [key] if given, otherwise for any key.
  bool isLoading([K? key]) => key == null ? _slots.values.any((s) => s.isLoading) : stateFor(key).isLoading;
}

// ═══════════════════════════════════════════════════════════
// REQUEST / RESULT
// ═══════════════════════════════════════════════════════════

/// A widget asking for data: "fetch what belongs at ([id], [key])".
///
/// A widget returns this from its update rather than fetching anything itself.
/// The app receives it, runs the actual fetch, and sends the outcome back as a
/// [LoadResult] carrying the same [id] and [key]. [id] says which widget asked;
/// [key] says which part of it — a tree branch, a page direction, a list's one
/// slot.
///
/// [key] is typed as [Object] so a single routing path can carry any widget's
/// key; each widget recovers its own key type by pattern-matching on it.
@immutable
class LoadRequest extends Cmd {
  /// Creates a request from the widget [id] for the load named by [key].
  const LoadRequest(this.id, {this.key});

  /// Identifies the widget that needs data.
  final String id;

  /// Names which load within that widget (e.g. [PathKey], [TableLoadKey.forward]).
  final Object? key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LoadRequest && other.id == id && other.key == key;

  @override
  int get hashCode => Object.hash(id, key);

  @override
  String toString() => 'LoadRequest($id, key: $key)';
}

/// The outcome of a load, sent back to the widget that asked for it.
///
/// The app builds this after running the fetch a [LoadRequest] asked for,
/// reusing that request's [id] and [key] so the result lands in the right place.
/// On success [data] holds the loaded items; on failure [error] is set and [ok]
/// is false.
///
/// [D] is the payload type where the app constructs the result, which keeps that
/// site type-safe. The widget consumes it through [Loadable], where the type is
/// erased, so its handler casts [data] to the shape it expects.
@immutable
class LoadResult<D> extends Msg {
  /// Creates a result for ([id], [key]): pass [data] on success, [error] on
  /// failure.
  const LoadResult(this.id, {this.key, this.data, this.error});

  /// Identifies the widget this result is routed to.
  final String id;

  /// The load this result resolves — the same key its request carried.
  final Object? key;

  /// The loaded items (rows, children, a page). Null on failure.
  final D? data;

  /// The failure cause — non-null only when the load failed.
  final Object? error;

  /// Whether the load succeeded.
  bool get ok => error == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadResult<D> && other.id == id && other.key == key && other.data == data && other.error == error;

  @override
  int get hashCode => Object.hash(id, key, data, error);

  @override
  String toString() => 'LoadResult($id, key: $key, data: $data, error: $error)';
}

/// A widget model that can receive loaded data.
///
/// The app keeps these keyed by [id] and routes each [LoadResult] to the
/// matching one. [applyLoad] installs the data (or records the error) and
/// updates the widget's load state.
///
/// The result arrives with its payload type erased — one registry holds many
/// kinds of widget — so [applyLoad] casts [LoadResult.data] to the type it
/// expects, and drops results it no longer wants (a late reply for a branch that
/// was since collapsed, or a query that has moved on).
abstract interface class Loadable {
  /// Stable identity used to route a [LoadResult] to this model.
  String get id;

  /// Installs [result] (its data or its error) and updates the load state.
  void applyLoad(LoadResult<Object?> result);
}

// ═══════════════════════════════════════════════════════════
// LOAD KEYS
// ═══════════════════════════════════════════════════════════

/// Names which tree load a request or result refers to: the root nodes
/// ([RootsKey]) or one node's children ([PathKey]).
@immutable
sealed class TreeLoadKey {
  /// Const base constructor for [RootsKey] and [PathKey].
  const TreeLoadKey();
}

/// The tree's root-level nodes. All instances are equal.
class RootsKey extends TreeLoadKey {
  /// Creates the roots key.
  const RootsKey();

  @override
  bool operator ==(Object other) => other is RootsKey;

  @override
  int get hashCode => (RootsKey).hashCode;

  @override
  String toString() => 'RootsKey()';
}

/// The children of the node at [path].
class PathKey extends TreeLoadKey {
  /// Creates a key for the node at [path].
  const PathKey(this.path);

  /// The node whose children are loading.
  final String path;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PathKey && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'PathKey($path)';
}

/// Names which table page is loading: the next page ([forward]) or the previous
/// one ([backward]).
///
/// The total row count isn't here on purpose — a missing count only leaves the
/// scrollbar indeterminate, so the app fetches it separately without load state.
enum TableLoadKey {
  /// Loading the next page.
  forward,

  /// Loading the previous page.
  backward,
}

/// Names the single load a list has: appending the next page at the end.
enum ListLoadKey {
  /// The list's one load slot.
  self,
}
