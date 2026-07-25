import 'package:kiko/kiko.dart';
import 'package:meta/meta.dart';

import 'load.dart';

// ═══════════════════════════════════════════════════════════
// PAGE SOURCE
// ═══════════════════════════════════════════════════════════

/// What a source returns for one page: the rows, and whatever else its response
/// happened to say.
///
/// [totalCount] and [hasMore] are optional because most sources do not know
/// them. A source whose envelope carries a count saves the app a separate count
/// fetch; one that says outright whether more data follows saves the widget
/// having to infer it from a short page.
@immutable
class PageResult<T> {
  /// Creates a result carrying [items], and the count or end-of-data flag if the
  /// response knew them.
  const PageResult(this.items, {this.totalCount, this.hasMore});

  /// The rows of the page, in index order.
  final List<T> items;

  /// How many rows exist in total, if the response said.
  final int? totalCount;

  /// Whether more rows follow this page, if the response said. Null means the
  /// source did not say, and a short page is the only clue.
  final bool? hasMore;

  @override
  String toString() => 'PageResult(${items.length} items, totalCount: $totalCount, hasMore: $hasMore)';
}

/// Where a windowed widget's rows come from — addressed by page index, owning
/// the page size.
///
/// The widget speaks index pages: fixed-size windows over row indexes, which
/// cursors, viewports and scrollbars all need. A real backend speaks something
/// else — an offset query, a token chain, a file read of whatever size suits it.
/// This interface is the boundary between the two, and the shipped adapters are
/// the translation.
///
/// The page size lives here rather than on the widget so the two cannot
/// disagree: the app wires `TableViewModel(pageSize: source.pageSize, …)` and
/// there is one number. It also puts the page size out of reach of the viewport,
/// which is what makes a terminal resize harmless — page boundaries stay index
/// arithmetic that no window size takes part in.
///
/// Implement it directly for anything the adapters do not cover, and wrap it to
/// add retries, backoff or caching: those stay app-side, because only the app
/// can say which failures are worth retrying.
///
/// ```dart
/// final products = PageSource.offset<Row>(
///   pageSize: 50,
///   read: (offset, limit) => api.products(offset: offset, limit: limit),
/// );
/// ```
abstract interface class PageSource<T> {
  /// Rows per page — the fixed index unit the widget windows over.
  int get pageSize;

  /// The rows of [page]: indexes `[page * pageSize, page * pageSize + pageSize)`.
  ///
  /// A short list means the data ends there. Throwing is legal: [fetchInto]
  /// turns a thrown read into a failed load rather than an unhandled error.
  Future<PageResult<T>> read(int page);

  /// A source over an offset-and-limit query — SQL, most REST endpoints, record
  /// files.
  ///
  /// [read] is called with the row offset and the page size. Pass [totalCount]
  /// when it is known up front and does not need its own fetch.
  static PageSource<T> offset<T>({
    required int pageSize,
    required Future<List<T>> Function(int offset, int limit) read,
    int? totalCount,
  }) => _OffsetSource<T>(pageSize, read, totalCount);

  /// A source over a token chain, where fetching a page needs the previous
  /// page's token.
  ///
  /// [first] fetches the head of the chain; [next] fetches what follows a token.
  /// The adapter does the three things such an API forces on a caller, so no app
  /// has to get them right: it **caches the token** at every page boundary it
  /// passes, so a page visited once is random-access afterwards, backward as
  /// well as forward; it **serializes** its own fetches, because a chain cannot
  /// be walked in parallel; and it **re-chunks**, buffering whatever row counts
  /// the server returns and slicing fixed index pages out of them.
  ///
  /// A cold jump to page 9 walks the chain once. Every later visit to pages 0
  /// through 9 starts from the nearest cached token instead.
  ///
  /// ```dart
  /// final logs = PageSource.cursor<Entry, String>(
  ///   pageSize: 50,
  ///   first: () async => (await api.logs()).chunk,
  ///   next: (token) async => (await api.logs(after: token)).chunk,
  /// );
  /// ```
  static PageSource<T> cursor<T, C>({
    required int pageSize,
    required Future<CursorChunk<T, C>> Function() first,
    required Future<CursorChunk<T, C>> Function(C token) next,
  }) => _CursorSource<T, C>(pageSize, first, next);
}

/// One response from a token-chain API: the rows it returned, and the token that
/// fetches whatever follows them.
///
/// The row count is whatever the server felt like sending — the cursor adapter
/// re-chunks it into index pages.
@immutable
class CursorChunk<T, C> {
  /// Creates a chunk of [items], followed by [nextToken] (null at the end of the
  /// chain).
  const CursorChunk(this.items, {this.nextToken, this.totalCount});

  /// The rows this response carried.
  final List<T> items;

  /// The token that fetches the next chunk, or null if the chain ends here.
  final C? nextToken;

  /// How many rows exist in total, if the response said.
  final int? totalCount;
}

/// Builds the command that fetches [request] from [source] and routes the
/// outcome home.
///
/// It threads the request's id and key into the result, which is the rule this
/// contract is most likely to lose: forget it and an app is silently
/// single-instance-only, because every result lands on whichever widget happens
/// to match first. Doing it here makes forgetting impossible.
///
/// It also carries the resolve-every-request obligation. A [PageSource.read]
/// that throws — including an app's own retrying wrapper rethrowing after its
/// last attempt — becomes a failed load, never an unhandled asynchronous error
/// that leaves the page loading forever. Its refusing counterpart is
/// [declineLoad].
///
/// ```dart
/// Cmd fetchFor(AppModel m, LoadRequest r) {
///   if (r.id == m.products.id) return fetchInto(r, m.productsSource);
///   return declineLoad(r, error: 'no source wired for ${r.id}');
/// }
/// ```
Cmd fetchInto<T>(LoadRequest request, PageSource<T> source) {
  final key = request.key;
  if (key is! TablePageKey) {
    return declineLoad(request, error: 'fetchInto: ${request.key} does not name a page');
  }
  return Task<PageResult<T>>(
    () => source.read(key.page),
    onSuccess: (result) => LoadResult<PageResult<T>>(request.id, key: key, data: result),
    onError: (error) => LoadResult<PageResult<T>>(request.id, key: key, error: error),
  );
}

// ─────────────────────────────────────────────
// Adapters
// ─────────────────────────────────────────────

class _OffsetSource<T> implements PageSource<T> {
  _OffsetSource(this.pageSize, this._read, this._totalCount);

  @override
  final int pageSize;

  final Future<List<T>> Function(int offset, int limit) _read;
  final int? _totalCount;

  @override
  Future<PageResult<T>> read(int page) async {
    final items = await _read(page * pageSize, pageSize);
    return PageResult<T>(items, totalCount: _totalCount);
  }
}

/// Where a page starts inside the chain: fetching with [token] returns a chunk
/// whose row at offset [skip] is the page's first row.
class _Anchor<C> {
  const _Anchor(this.token, this.skip);

  /// The token that fetches the chunk containing the page's first row, or null
  /// for the head of the chain.
  final C? token;

  /// How many rows of that chunk come before the page's first row.
  final int skip;
}

class _CursorSource<T, C> implements PageSource<T> {
  _CursorSource(this.pageSize, this._first, this._next) {
    _anchors[0] = _Anchor<C>(null, 0);
  }

  @override
  final int pageSize;

  final Future<CursorChunk<T, C>> Function() _first;
  final Future<CursorChunk<T, C>> Function(C token) _next;

  /// Page number to where its first row sits in the chain. Tokens are small and
  /// never dropped, which is what turns a walked chain into random access.
  final Map<int, _Anchor<C>> _anchors = {};

  /// Reads run one at a time: a chain cannot be walked in parallel, and two
  /// concurrent walks would fetch the same chunks twice.
  Future<void> _queue = Future<void>.value();

  @override
  Future<PageResult<T>> read(int page) {
    final next = _queue.then((_) => _walk(page));
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  /// Walks the chain from the nearest cached anchor at or before [page], caching
  /// every page boundary it passes and collecting the rows of [page].
  Future<PageResult<T>> _walk(int page) async {
    final want = page * pageSize;
    final start = _nearestAnchor(page);
    var token = _anchors[start]!.token;
    var absolute = start * pageSize - _anchors[start]!.skip;
    final collected = <T>[];
    int? totalCount;
    var ended = false;

    while (true) {
      final chunk = token == null ? await _first() : await _next(token);
      totalCount ??= chunk.totalCount;

      for (var i = 0; i < chunk.items.length; i++) {
        final index = absolute + i;
        if (index % pageSize == 0) {
          _anchors.putIfAbsent(index ~/ pageSize, () => _Anchor<C>(token, i));
        }
        if (index >= want && index < want + pageSize) collected.add(chunk.items[i]);
      }
      absolute += chunk.items.length;

      final following = chunk.nextToken;
      if (following == null) {
        ended = true;
        break;
      }
      // A chunk that ends exactly on a page boundary names that page's anchor
      // without anything having to fetch it: it is the token that follows.
      if (absolute % pageSize == 0) {
        _anchors.putIfAbsent(absolute ~/ pageSize, () => _Anchor<C>(following, 0));
      }
      if (absolute >= want + pageSize) break;
      token = following;
    }

    // A chain that ended has just told us exactly how many rows there are: the
    // absolute index we walked to.
    return PageResult<T>(collected, totalCount: ended ? absolute : totalCount, hasMore: !ended);
  }

  int _nearestAnchor(int page) {
    var best = 0;
    for (final cached in _anchors.keys) {
      if (cached <= page && cached > best) best = cached;
    }
    return best;
  }
}
