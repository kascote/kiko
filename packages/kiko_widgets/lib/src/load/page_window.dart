import 'package:meta/meta.dart';

// ═══════════════════════════════════════════════════════════
// PAGE WINDOW
// ═══════════════════════════════════════════════════════════

/// An inclusive run of page numbers, plus the page the viewport starts in.
///
/// A widget builds one of these from where it is looking ([PageWindow.spanFor])
/// and hands it back when asking what is missing or installing a page. [anchor]
/// is the page holding the first visible row: it breaks ties when only some of
/// the missing pages can be requested at once, so the page under the user's eyes
/// is fetched before the ones the threshold merely reaches toward.
@immutable
class PageSpan {
  /// Creates a span covering [first] through [last], anchored at [anchor]
  /// (defaults to [first]).
  const PageSpan(this.first, this.last, {int? anchor}) : anchor = anchor ?? first;

  /// The lowest page in the span.
  final int first;

  /// The highest page in the span, included.
  final int last;

  /// The page holding the first visible row — where fetching starts.
  final int anchor;

  /// How many pages the span covers.
  int get length => last - first + 1;

  /// Whether [page] falls inside the span.
  bool contains(int page) => page >= first && page <= last;

  /// Every page in the span, ascending.
  Iterable<int> get pages sync* {
    for (var p = first; p <= last; p++) {
      yield p;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageSpan && other.first == first && other.last == last && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(first, last, anchor);

  @override
  String toString() => 'PageSpan($first..$last, anchor: $anchor)';
}

/// A sparse cache of fixed-size pages, and the bookkeeping a windowed widget
/// needs around it: which pages are held, which the viewport still needs, which
/// ones to drop, and where the data ends.
///
/// The page is the unit of everything here. Rows are read by absolute index, but
/// nothing is tracked per row: a page is present or it is not, it is fetched
/// whole and evicted whole. That is what keeps the window honest about holes — a
/// cache that has pages 0 and 4 says exactly that, instead of claiming a range
/// from 0 to 4 with rows missing inside it.
///
/// The widget owns the fetching. This class answers "what is missing near the
/// viewport" ([missing]) and "what may I forget" (eviction, run by [install]);
/// it never loads anything and knows nothing about load slots or requests.
///
/// ```dart
/// final window = PageWindow<Row>(pageSize: 50);
/// final span = window.spanFor(firstRow: 480, rowCount: 20, threshold: 10);
/// for (final page in window.missing(span, limit: 3)) {
///   // ...ask the app for `page`
/// }
/// window.install(9, rows, demand: span);
/// ```
///
/// **Retention is relative.** Eviction keeps the pages the span covers plus
/// [keepPages] on each side of it, so a page the viewport is asking for can
/// never be dropped — whatever [keepPages] is set to, including zero. There is
/// no absolute budget to size correctly, and so no way to configure a cache that
/// evicts a page and immediately re-fetches it.
class PageWindow<T> {
  /// Creates an empty window over pages of [pageSize] rows, keeping [keepPages]
  /// pages on each side of the viewport's span when evicting.
  PageWindow({required this.pageSize, this.keepPages = 4})
    : assert(pageSize > 0, 'pageSize must be positive'),
      assert(keepPages >= 0, 'keepPages cannot be negative');

  /// Rows per page. Fixed for the life of the window: page boundaries are index
  /// arithmetic, so nothing a terminal does can renumber them.
  final int pageSize;

  /// How many pages beyond the viewport's span survive eviction, on each side.
  final int keepPages;

  final _pages = <int, List<T>>{};
  int? _lastPage;

  // ─────────────────────────────────────────────
  // Reading
  // ─────────────────────────────────────────────

  /// The page holding row [index].
  int pageOf(int index) => index ~/ pageSize;

  /// The pages currently held, ascending.
  List<int> get present => _pages.keys.toList()..sort();

  /// How many pages are held.
  int get pageCount => _pages.length;

  /// How many rows are held across all pages.
  int get rowCount => _pages.values.fold(0, (n, rows) => n + rows.length);

  /// Whether [page] is held.
  bool has(int page) => _pages.containsKey(page);

  /// The rows of [page], or null if it isn't held.
  List<T>? pageAt(int page) => _pages[page];

  /// The row at absolute [index], or null if its page isn't held (or the page is
  /// held but ends before that row).
  T? rowAt(int index) {
    if (index < 0) return null;
    final rows = _pages[index ~/ pageSize];
    if (rows == null) return null;
    final offset = index % pageSize;
    return offset < rows.length ? rows[offset] : null;
  }

  /// The last page that exists, or null while that isn't known.
  ///
  /// This is knowledge, not a gate: it says which pages are worth asking for,
  /// and never stops a page that does exist from being fetched again after it
  /// was evicted. A value of -1 means the data is empty.
  int? get lastPage => _lastPage;

  /// Whether [page] can exist — false only past a recorded end of data.
  bool exists(int page) => page >= 0 && (_lastPage == null || page <= _lastPage!);

  // ─────────────────────────────────────────────
  // Demand
  // ─────────────────────────────────────────────

  /// The pages a viewport showing [rowCount] rows from [firstRow] needs, reaching
  /// [threshold] rows past each edge.
  ///
  /// The span is where the user is, so it moves with the viewport rather than
  /// following the edge of what is already loaded: a jump lands on the
  /// destination's pages directly. An empty viewport (before the first paint)
  /// still spans the page holding [firstRow], so the first load has something to
  /// ask for.
  PageSpan spanFor({required int firstRow, required int rowCount, int threshold = 0}) {
    final top = firstRow < 0 ? 0 : firstRow;
    final bottom = top + (rowCount < 1 ? 1 : rowCount) - 1;
    final from = top - threshold;
    return PageSpan(pageOf(from < 0 ? 0 : from), pageOf(bottom + threshold), anchor: pageOf(top));
  }

  /// The pages of [span] that are not held, could exist, and are not already on
  /// their way — nearest to the span's anchor first, at most [limit] of them.
  ///
  /// Presence over the whole span is what makes a hole in the middle of the
  /// cache re-requestable: nothing here follows the edge of the loaded range, so
  /// a page missing between two held ones is as visible as one past the end.
  ///
  /// Pass [pending] to skip pages already in flight — normally the load
  /// tracker's own predicate — and [limit] to cap how many fetches the caller is
  /// willing to have outstanding. A truncated list is not a loss: the next
  /// demand pass re-derives whatever is still missing.
  List<int> missing(PageSpan span, {bool Function(int page)? pending, int limit = 1 << 30}) {
    if (limit <= 0) return const [];
    final wanted =
        [
          for (final page in span.pages)
            if (exists(page) && !has(page) && !(pending?.call(page) ?? false)) page,
        ]..sort((a, b) {
          final da = (a - span.anchor).abs();
          final db = (b - span.anchor).abs();
          // Same distance from the anchor: take the one below the viewport first,
          // since the anchor is its first row and the rest of it reads downward.
          return da != db ? da - db : b - a;
        });
    return wanted.length <= limit ? wanted : wanted.sublist(0, limit);
  }

  // ─────────────────────────────────────────────
  // Writing
  // ─────────────────────────────────────────────

  /// Installs [rows] as [page], then evicts whatever [demand] no longer keeps.
  ///
  /// A page shorter than [pageSize] records where the data ends; a full page
  /// past a recorded end withdraws that record, so a source that grew is
  /// reachable again. Installing is idempotent — a page that arrives twice
  /// replaces itself — which is what makes results order-independent.
  void install(int page, List<T> rows, {required PageSpan demand}) {
    _pages[page] = rows;
    if (rows.length < pageSize) {
      _recordEnd(rows.isEmpty ? page - 1 : page);
    } else if (_lastPage != null && page > _lastPage!) {
      _lastPage = null;
    }
    _evict(demand);
  }

  /// Installs [rows] as whole pages starting at [firstPage], evicting nothing.
  ///
  /// This is for rows a caller already holds — a static list, or a first page
  /// fetched before the window existed. The rows are split at [pageSize], and a
  /// short final chunk records where the data ends, exactly as a fetched page
  /// does. Nothing is dropped: a caller handing over data it already has means
  /// to keep it, and there is no viewport to measure retention against.
  void seed(List<T> rows, {int firstPage = 0}) {
    if (rows.isEmpty) {
      _recordEnd(firstPage - 1);
      return;
    }
    for (var offset = 0; offset < rows.length; offset += pageSize) {
      final end = offset + pageSize;
      final chunk = end < rows.length ? rows.sublist(offset, end) : rows.sublist(offset);
      final page = firstPage + offset ~/ pageSize;
      _pages[page] = chunk;
      if (chunk.length < pageSize) {
        _recordEnd(page);
      } else if (_lastPage != null && page > _lastPage!) {
        _lastPage = null;
      }
    }
  }

  /// Records that no page after [page] exists, dropping any held page past it.
  ///
  /// Use it when the source says so outright — a total row count, or an
  /// end-of-data flag on the response — rather than by returning a short page.
  void endAt(int page) => _recordEnd(page);

  /// Drops every page, and forgets where the data ended.
  void clear() {
    _pages.clear();
    _lastPage = null;
  }

  void _recordEnd(int page) {
    _lastPage = page;
    _pages.removeWhere((p, _) => p > page);
  }

  void _evict(PageSpan demand) {
    final low = demand.first - keepPages;
    final high = demand.last + keepPages;
    _pages.removeWhere((page, _) => page < low || page > high);
  }
}
