// Page sources are shared load machinery, not table machinery: this suite
// imports them directly and constructs no widget.
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/src/load/load.dart';
import 'package:kiko_widgets/src/load/page_source.dart';
import 'package:test/test.dart';

/// Rows `r0`, `r1`, … up to [count].
List<String> rows(int count) => [for (var i = 0; i < count; i++) 'r$i'];

/// A token-chain server: hands out [chunkSizes] rows at a time (cycling through
/// the list), each response carrying the token for the next one, and counts how
/// many times it was asked.
class _Chain {
  _Chain(this.total, this.chunkSizes);

  final int total;
  final List<int> chunkSizes;
  int fetches = 0;

  CursorChunk<String, String> _from(int start, int sizeIndex) {
    fetches++;
    final size = chunkSizes[sizeIndex % chunkSizes.length];
    final end = (start + size) > total ? total : start + size;
    final items = rows(total).sublist(start, end);
    return CursorChunk<String, String>(items, nextToken: end >= total ? null : 'at:$end:${sizeIndex + 1}');
  }

  Future<CursorChunk<String, String>> first() async => _from(0, 0);

  Future<CursorChunk<String, String>> next(String token) async {
    final parts = token.split(':');
    return _from(int.parse(parts[1]), int.parse(parts[2]));
  }

  PageSource<String> source({int pageSize = 10}) =>
      PageSource.cursor<String, String>(pageSize: pageSize, first: first, next: next);
}

void main() {
  group('PageSource.offset', () {
    test('reads a page as an offset and a limit', () async {
      final calls = <(int, int)>[];
      final source = PageSource.offset<String>(
        pageSize: 10,
        read: (offset, limit) async {
          calls.add((offset, limit));
          return rows(25).skip(offset).take(limit).toList();
        },
      );

      expect((await source.read(0)).items, equals(rows(10)));
      expect((await source.read(2)).items, equals(['r20', 'r21', 'r22', 'r23', 'r24']));
      expect(calls, equals([(0, 10), (20, 10)]));
      expect(source.pageSize, equals(10));
    });

    test('a page past the end reads empty', () async {
      final source = PageSource.offset<String>(
        pageSize: 10,
        read: (offset, limit) async => rows(25).skip(offset).take(limit).toList(),
      );
      expect((await source.read(9)).items, isEmpty);
    });

    test('carries a known total count through', () async {
      final source = PageSource.offset<String>(
        pageSize: 10,
        read: (offset, limit) async => rows(25).skip(offset).take(limit).toList(),
        totalCount: 25,
      );
      expect((await source.read(0)).totalCount, equals(25));
    });
  });

  group('PageSource.cursor', () {
    test('a cold page walks the chain once', () async {
      final chain = _Chain(100, [10]);
      final source = chain.source();

      final page3 = await source.read(3);

      expect(page3.items, equals(['r30', 'r31', 'r32', 'r33', 'r34', 'r35', 'r36', 'r37', 'r38', 'r39']));
      expect(chain.fetches, equals(4), reason: 'pages 0 through 3, one fetch each');
    });

    test('a later visit — including a backward one — starts from a cached token', () async {
      final chain = _Chain(100, [10]);
      final source = chain.source();

      await source.read(5);
      final afterWalk = chain.fetches;

      // Backward, to a page the walk passed through: the token for it is cached,
      // so this is one fetch rather than another walk from the head.
      final page2 = await source.read(2);
      expect(page2.items.first, equals('r20'));
      expect(chain.fetches - afterWalk, equals(1), reason: 'random access after the chain was walked once');

      // Forward again, over ground already covered: still one fetch.
      final page4 = await source.read(4);
      expect(page4.items.first, equals('r40'));
      expect(chain.fetches - afterWalk, equals(2));
    });

    test('re-chunks whatever row counts the server returns into fixed pages', () async {
      // Chunks of 3, 11, 1 and 7 rows: no boundary lines up with a page.
      final chain = _Chain(60, [3, 11, 1, 7]);
      final source = chain.source();

      expect((await source.read(0)).items, equals(rows(10)));
      expect((await source.read(1)).items, equals([for (var i = 10; i < 20; i++) 'r$i']));
      expect((await source.read(4)).items, equals([for (var i = 40; i < 50; i++) 'r$i']));
    });

    test('an anchor mid-chunk is honored, not rounded to the chunk', () async {
      final chain = _Chain(60, [7]);
      final source = chain.source();

      await source.read(3);
      final afterWalk = chain.fetches;

      // Page 1 starts at row 10, which sits inside the chunk beginning at row 7.
      final page1 = await source.read(1);
      expect(page1.items, equals([for (var i = 10; i < 20; i++) 'r$i']));
      expect(chain.fetches - afterWalk, lessThan(3), reason: 'resumed near the page, not from the head');
    });

    test('the end of the chain reports no more, and how many rows there were', () async {
      final chain = _Chain(25, [10]);
      final source = chain.source();

      final last = await source.read(2);
      expect(last.items, equals(['r20', 'r21', 'r22', 'r23', 'r24']));
      expect(last.hasMore, isFalse);
      expect(last.totalCount, equals(25), reason: 'a walked-out chain has counted itself');

      final past = await source.read(3);
      expect(past.items, isEmpty);
      expect(past.hasMore, isFalse);
    });

    test('a page inside the chain does not claim the data ends', () async {
      final chain = _Chain(100, [10]);
      expect((await chain.source().read(1)).hasMore, isTrue);
    });

    test('concurrent reads serialize instead of racing the same chunks', () async {
      final chain = _Chain(100, [10]);
      final source = chain.source();

      final results = await Future.wait([source.read(2), source.read(3)]);

      expect(results[0].items.first, equals('r20'));
      expect(results[1].items.first, equals('r30'));
      // A single walk to page 3 costs four fetches; the second read resumes from
      // the tokens the first cached rather than walking again.
      expect(chain.fetches, equals(4));
    });
  });

  group('fetchInto', () {
    LoadRequest request(int page) => LoadRequest('products', key: PageKey(page));

    Future<Msg?> run(Cmd cmd) => (cmd as Task<Object?>).execute();

    test('threads the request id and key into the result', () async {
      final source = PageSource.offset<String>(
        pageSize: 10,
        read: (offset, limit) async => rows(25).skip(offset).take(limit).toList(),
      );

      final msg = await run(fetchInto(request(1), source));

      expect(msg, isA<LoadResult<PageResult<String>>>());
      final result = msg! as LoadResult<PageResult<String>>;
      expect(result.id, equals('products'));
      expect(result.key, equals(const PageKey(1)));
      expect(result.ok, isTrue);
      expect(result.data!.items.first, equals('r10'));
    });

    test('a read that throws becomes a failed load, not an unhandled error', () async {
      final boom = StateError('the connection died');
      final source = PageSource.offset<String>(
        pageSize: 10,
        read: (offset, limit) async => throw boom,
      );

      final result = (await run(fetchInto(request(2), source)))! as LoadResult<Object?>;

      expect(result.ok, isFalse, reason: 'the page resolves as failed rather than staying in flight');
      expect(result.cancelled, isFalse);
      expect(result.error, same(boom));
      expect(result.id, equals('products'));
      expect(result.key, equals(const PageKey(2)));
    });

    test('a request whose key names no page fails visibly', () async {
      final source = PageSource.offset<String>(pageSize: 10, read: (offset, limit) async => rows(10));

      final cmd = fetchInto(const LoadRequest('products', key: RootsKey()), source);

      expect(cmd, isA<Emit>());
      final result = (cmd as Emit).msg as LoadResult<Object?>;
      expect(result.ok, isFalse);
      expect(result.cancelled, isFalse, reason: 'a request nothing can answer is a wiring bug, not a refusal');
      expect(result.error, contains('does not name a page'));
    });
  });
}
