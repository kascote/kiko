import 'package:kiko/kiko.dart';
import 'package:kiko_log/kiko_log.dart';
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

  /// Drops every slot, in flight and failed alike, so every key reads idle.
  ///
  /// Call it on a cold start: a result for a fetch that was in flight is
  /// stale afterwards, and a widget's staleness guard drops it.
  void clear() => _slots.clear();

  /// The current state of [key], or [LoadState.idle] if it has no entry.
  LoadState stateFor(K key) => _slots[key] ?? LoadState.idle;

  /// The error recorded for [key], or null if it isn't in the failed state.
  Object? errorFor(K key) => stateFor(key).error;

  /// Whether a fetch is in flight — for [key] if given, otherwise for any key.
  bool isLoading([K? key]) => key == null ? loading.isNotEmpty : stateFor(key).isLoading;

  /// The keys whose fetch is in flight, in no particular order.
  ///
  /// A lazy view over the tracker: snapshot it before calling [complete] or
  /// [fail] while iterating.
  Iterable<K> get loading => _slots.entries.where((e) => e.value.isLoading).map((e) => e.key);
}

// ═══════════════════════════════════════════════════════════
// REQUEST / RESULT
// ═══════════════════════════════════════════════════════════

/// A widget asking for data: "fetch what belongs at ([id], [key])".
///
/// A widget returns this from its update rather than fetching anything itself.
/// The app receives it, runs the actual fetch, and sends the outcome back as a
/// [LoadResult] carrying the same [id] and [key]. [id] says which widget asked;
/// [key] says which part of it — a tree branch, a table page, a list's one
/// slot.
///
/// [key] is typed as [Object] so a single routing path can carry any widget's
/// key; each widget recovers its own key type by pattern-matching on it.
@immutable
class LoadRequest extends WidgetEvent {
  /// Creates a request from the widget [id] for the load named by [key].
  const LoadRequest(this.id, {this.key});

  /// Identifies the widget that needs data.
  @override
  final String id;

  /// Names which load within that widget (e.g. [PathKey], [PageKey]).
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
/// There are exactly three outcomes, and every request must end in one of them:
/// [data] carrying the loaded items, [error] carrying the failure, or
/// [LoadResult.cancelled] — a refusal that resolves the slot without fetching.
/// Answering a request with nothing at all leaves whatever asked for it waiting
/// forever, since the widget will not ask again while it believes the load is
/// still on its way.
///
/// A cancel is a distinct shape rather than an empty success because an empty
/// page means "the data ends here". A refusal must teach the widget nothing: it
/// keeps its placeholders, records no failure, and asks again on the next demand
/// pass. Build one through [declineLoad] rather than by hand.
///
/// [D] is the payload type where the app constructs the result, which keeps that
/// site type-safe. The result is an [Addressed] message: a router delivers it
/// to the widget model whose id it carries, and that model's `update` installs
/// it with the type erased, checking that [data] is the shape it installs. A
/// successful result carrying any other shape, or a null [data], fails the slot
/// the way a failed fetch does (see [payloadMismatch]).
@immutable
class LoadResult<D> extends Msg implements Addressed {
  /// Creates a result for ([id], [key]): pass [data] on success, [error] on
  /// failure.
  const LoadResult(this.id, {this.key, this.data, this.error}) : cancelled = false;

  /// Creates a refusal for ([id], [key]): the load was never run, so the slot
  /// returns to idle carrying neither data nor a failure.
  const LoadResult.cancelled(this.id, {this.key}) : data = null, error = null, cancelled = true;

  /// Identifies the widget this result is routed to.
  @override
  final String id;

  /// The load this result resolves — the same key its request carried.
  final Object? key;

  /// The loaded items (rows, children, a page). Null on failure or refusal.
  ///
  /// On success it is never null: an empty result is an empty list.
  final D? data;

  /// The failure cause — non-null only when the load failed.
  final Object? error;

  /// Whether the request was refused instead of run.
  ///
  /// A widget receiving this clears the slot to idle and installs nothing — no
  /// rows, no error, no end-of-data.
  final bool cancelled;

  /// Whether the load ran and succeeded, so [data] is worth installing.
  ///
  /// False for both a failure and a refusal: neither carries data, and treating
  /// a refusal as an empty success would tell the widget its data ends here.
  bool get ok => error == null && !cancelled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadResult<D> &&
          other.id == id &&
          other.key == key &&
          other.data == data &&
          other.error == error &&
          other.cancelled == cancelled;

  @override
  int get hashCode => Object.hash(id, key, data, error, cancelled);

  @override
  String toString() =>
      cancelled ? 'LoadResult.cancelled($id, key: $key)' : 'LoadResult($id, key: $key, data: $data, error: $error)';
}

/// Builds the command that resolves [request] without fetching anything: a
/// refusal with no [error], a failure with one.
///
/// This is the answer for a request an app will not run. A widget marks its slot
/// loading the moment it emits the request and skips it while it believes it is
/// in flight, so a request left unanswered paints its placeholder forever — the
/// same permanently-unloadable state a widget's own bookkeeping must never
/// produce, arriving from the app instead. The fall-through of a request handler
/// therefore reads `return declineLoad(r)`, never `return null`.
///
/// Which of the two to use:
///
/// - **No error — a refusal on policy.** "Do not fetch orders while a sync is
///   running." Nothing failed, so nothing paints an error: the widget keeps its
///   placeholders and asks again on its next demand pass. Recovery is the app's
///   to trigger when its own gate lifts.
/// - **With an error — nothing is wired to answer.** A request whose id matches
///   no source is a wiring bug, and it fails visibly rather than leaving a
///   placeholder no one will ever fill.
///
/// ```dart
/// Cmd fetchFor(AppModel m, LoadRequest r) {
///   if (r.id == m.products.id) return fetchInto(r, m.productsSource);
///   if (r.id == m.orders.id) {
///     if (m.syncing) return declineLoad(r); // policy, where you would look for it
///     return fetchInto(r, m.ordersSource);
///   }
///   return declineLoad(r, error: 'no source wired for ${r.id}');
/// }
/// ```
///
/// It handles one request and never iterates over an app's sources: an app that
/// needs different treatment for one widget writes a different branch, and
/// simply does not call this there.
Cmd declineLoad(LoadRequest request, {Object? error}) => Emit(
  error == null
      ? LoadResult<Object?>.cancelled(request.id, key: request.key)
      : LoadResult<Object?>(request.id, key: request.key, error: error),
);

// ═══════════════════════════════════════════════════════════
// PAYLOAD SHAPE
// ═══════════════════════════════════════════════════════════

/// The error a widget records when a successful [LoadResult] carries a payload
/// it cannot install.
///
/// A widget never throws this. It fails the slot with it, through the same path
/// a failed fetch takes, so the mismatch paints where that widget paints its
/// failures. Build one through [payloadMismatch].
@immutable
class PayloadMismatch implements Exception {
  /// Creates the error for the load at ([id], [key]) on [widget], which
  /// installs [expected] but received [received].
  const PayloadMismatch({
    required this.widget,
    required this.id,
    required this.key,
    required this.expected,
    required this.received,
  });

  /// The receiving widget's type name.
  final String widget;

  /// The receiving widget's id.
  final String id;

  /// The load the result resolved.
  final Object? key;

  /// The shape the widget installs, as it reads in code.
  final String expected;

  /// The runtime type the result carried, or `null`.
  final String received;

  @override
  String toString() => '$widget "$id": load $key carried $received, expected $expected';
}

/// Checks that a successful [result] carries the shape its receiver installs.
///
/// Returns null when [accepts] holds for [LoadResult.data], and the receiver
/// installs the payload. Otherwise it logs the mismatch once and returns the
/// [PayloadMismatch] the receiver fails its slot with. A null payload never
/// passes: an empty result is an empty list. Call it only for a result whose
/// [LoadResult.ok] is true.
///
/// ```dart
/// final mismatch = payloadMismatch(
///   result,
///   widget: 'TreeView',
///   expected: 'List<TreeNode<$T>>',
///   accepts: (data) => data is List<TreeNode<T>>,
/// );
/// if (mismatch != null) {
///   _loads.fail(key, mismatch);
///   return;
/// }
/// final children = result.data! as List<TreeNode<T>>;
/// ```
///
/// [expected] is the shape as it reads in code, for the error message. It is
/// not derived from [accepts], which can admit more than one shape.
PayloadMismatch? payloadMismatch(
  LoadResult<Object?> result, {
  required String widget,
  required String expected,
  required bool Function(Object data) accepts,
}) {
  final data = result.data;
  if (data != null && accepts(data)) return null;
  final mismatch = PayloadMismatch(
    widget: widget,
    id: result.id,
    key: result.key,
    expected: expected,
    received: data == null ? 'null' : '${data.runtimeType}',
  );
  Log.error(
    '$mismatch. A successful LoadResult must carry the shape its widget '
    'installs; an empty result is an empty list, never null. The slot is '
    'failed and nothing is installed.',
  );
  return mismatch;
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

/// Names which page is loading, by its page number.
///
/// A windowed widget names the thing it is loading the way the tree names a
/// branch with a [PathKey]: the key carries the page, so each page gets its own
/// slot, several pages can be in flight at once, and a result places itself
/// without the model having to remember which page it reserved for which
/// direction.
///
/// The total row count isn't a key here on purpose — a missing count only leaves
/// the scrollbar indeterminate, so the app fetches it separately without load
/// state.
@immutable
class PageKey {
  /// Creates a key for the page numbered [page], counting from zero.
  const PageKey(this.page);

  /// The page being loaded — rows `[page * pageSize, page * pageSize + pageSize)`.
  final int page;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PageKey && other.page == page;

  @override
  int get hashCode => page.hashCode;

  @override
  String toString() => 'PageKey($page)';
}

/// Names which remote query a load refers to, by the text that was typed
/// when it was asked.
///
/// A combobox names its remote load the way a windowed widget names a page
/// with a [PageKey]: the key carries the query text, so each query gets its
/// own slot, several can be in flight at once, and an answer places itself
/// without the model having to remember what it last asked.
@immutable
class QueryKey {
  /// Creates a key for the query [query].
  const QueryKey(this.query);

  /// The field's text when this query was asked.
  final String query;

  @override
  bool operator ==(Object other) => identical(this, other) || other is QueryKey && other.query == query;

  @override
  int get hashCode => query.hashCode;

  @override
  String toString() => 'QueryKey($query)';
}

// ═══════════════════════════════════════════════════════════
// SLICE STATUS
// ═══════════════════════════════════════════════════════════

/// What a view can say about the part of its data it is about to paint.
enum SliceStatus {
  /// Everything is here; paint it.
  ready,

  /// Something is missing and a fetch is on its way.
  filling,

  /// Something is missing and nothing is coming for it.
  ///
  /// This is the shape of every permanent failure in a windowed widget — a tail
  /// that never reloads, a hole nothing re-requests, a request the app dropped,
  /// a request the in-flight cap starved. It is deliberately not an error and
  /// never a debug assertion: an app that refuses a load on policy grounds
  /// produces this state legitimately, and an assertion would fire on correct
  /// code. It is reported, logged and tested against instead.
  stalled,

  /// A fetch for something missing failed.
  failed,
}

/// The status of the [keys] a view is about to paint: whether they are all
/// here, on their way, failed, or missing with nothing coming.
///
/// A pure function of two inputs — what [loads] says is in flight or failed, and
/// what [isPresent] says is already held. Key-shaped like [LoadTracker] itself,
/// so a table passes page keys and a tree could pass path keys without a second
/// implementation.
///
/// A failure outranks a fetch in flight: if one missing key failed while another
/// is still loading, reporting [SliceStatus.filling] would promise the failed
/// one is coming.
///
/// ```dart
/// final status = statusFor(
///   visiblePages.map(PageKey.new),
///   loads,
///   (key) => window.has(key.page),
/// );
/// ```
SliceStatus statusFor<K>(Iterable<K> keys, LoadTracker<K> loads, bool Function(K key) isPresent) {
  var loading = false;
  var missing = false;
  for (final key in keys) {
    if (isPresent(key)) continue;
    missing = true;
    final state = loads.stateFor(key);
    if (state.failed) return SliceStatus.failed;
    if (state.isLoading) loading = true;
  }
  if (!missing) return SliceStatus.ready;
  return loading ? SliceStatus.filling : SliceStatus.stalled;
}
