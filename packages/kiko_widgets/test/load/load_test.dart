import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Identity passthrough returning a *runtime* (non-const) string, so the
/// commands/messages below are distinct instances and `operator ==` actually
/// runs (const canonicalization would otherwise make equal values identical).
String v(String s) => s;

/// The same passthrough for page numbers, so keys built from it are distinct
/// instances rather than canonicalized constants.
int i(int n) => n;

/// The single-slot specimen the tracker and request/result tests key on.
const page0 = PageKey(0);

void main() {
  group('LoadState', () {
    test('idle snapshot', () {
      expect(LoadState.idle.status, LoadStatus.idle);
      expect(LoadState.idle.isLoading, isFalse);
      expect(LoadState.idle.failed, isFalse);
      expect(LoadState.idle.error, isNull);
    });

    test('loading snapshot', () {
      const s = LoadState(LoadStatus.loading);
      expect(s.isLoading, isTrue);
      expect(s.failed, isFalse);
    });

    test('error snapshot carries the cause', () {
      final cause = Exception('boom');
      final s = LoadState(LoadStatus.error, cause);
      expect(s.failed, isTrue);
      expect(s.isLoading, isFalse);
      expect(s.error, same(cause));
    });
  });

  group('LoadTracker', () {
    test('absent slot reads idle', () {
      final t = LoadTracker<PageKey>();
      expect(t.stateFor(page0).status, LoadStatus.idle);
      expect(t.isLoading(page0), isFalse);
      expect(t.errorFor(page0), isNull);
    });

    test('begin → loading', () {
      final t = LoadTracker<PageKey>()..begin(page0);
      expect(t.stateFor(page0).status, LoadStatus.loading);
      expect(t.isLoading(page0), isTrue);
    });

    test('complete → idle (slot removed)', () {
      final t = LoadTracker<PageKey>()
        ..begin(page0)
        ..complete(page0);
      expect(t.stateFor(page0).status, LoadStatus.idle);
      expect(t.isLoading(page0), isFalse);
    });

    test('fail → error with recorded cause; errorFor reads it', () {
      final cause = Exception('nope');
      final t = LoadTracker<PageKey>()..fail(page0, cause);
      expect(t.stateFor(page0).status, LoadStatus.error);
      expect(t.stateFor(page0).failed, isTrue);
      expect(t.errorFor(page0), same(cause));
      // An errored slot is not "loading".
      expect(t.isLoading(page0), isFalse);
    });

    test('complete clears a prior error', () {
      final t = LoadTracker<PageKey>()
        ..fail(page0, Exception('x'))
        ..complete(page0);
      expect(t.errorFor(page0), isNull);
      expect(t.stateFor(page0).status, LoadStatus.idle);
    });

    group('no-arg isLoading() = any slot', () {
      test('false when no slots', () {
        expect(LoadTracker<TreeLoadKey>().isLoading(), isFalse);
      });

      test('true when any slot is loading', () {
        final t = LoadTracker<TreeLoadKey>()..begin(const PathKey('/a'));
        expect(t.isLoading(), isTrue);
        // ...but a different, untouched key is not loading.
        expect(t.isLoading(const PathKey('/b')), isFalse);
      });

      test('false when the only slot is errored (error is not loading)', () {
        final t = LoadTracker<TreeLoadKey>()..fail(const PathKey('/a'), 'e');
        expect(t.isLoading(), isFalse);
        expect(t.isLoading(const PathKey('/a')), isFalse);
      });
    });

    test('loading lists the in-flight keys and nothing else', () {
      final t = LoadTracker<PageKey>()
        ..begin(PageKey(i(0)))
        ..begin(PageKey(i(2)))
        ..fail(PageKey(i(1)), 'e');
      expect(t.loading, unorderedEquals([const PageKey(0), const PageKey(2)]));
      t.complete(PageKey(i(0)));
      expect(t.loading, [const PageKey(2)]);
      t.complete(PageKey(i(2)));
      expect(t.loading, isEmpty);
    });

    test('per-key isLoading isolates concurrent slots', () {
      final t = LoadTracker<PageKey>()..begin(PageKey(i(0)));
      expect(t.isLoading(PageKey(i(0))), isTrue);
      expect(t.isLoading(PageKey(i(1))), isFalse);
      t.begin(PageKey(i(1)));
      expect(t.isLoading(PageKey(i(0))), isTrue);
      expect(t.isLoading(PageKey(i(1))), isTrue);
      t.complete(PageKey(i(0)));
      expect(t.isLoading(PageKey(i(0))), isFalse);
      expect(t.isLoading(PageKey(i(1))), isTrue);
    });
  });

  group('typed sealed keys', () {
    test('RootsKey: all instances equal', () {
      expect(const RootsKey(), equals(const RootsKey()));
      expect(const RootsKey().hashCode, equals(const RootsKey().hashCode));
      expect(const RootsKey().toString(), 'RootsKey()');
      // Distinct-instance equality (== runs, not just identity) is exercised by
      // the PathKey cases below, which use runtime-string keys.
    });

    test('PathKey: equal by path', () {
      expect(PathKey(v('/a')), equals(PathKey(v('/a'))));
      expect(PathKey(v('/a')).hashCode, equals(PathKey(v('/a')).hashCode));
      expect(PathKey(v('/a')), isNot(equals(PathKey(v('/b')))));
      expect(PathKey(v('/a')).toString(), 'PathKey(/a)');
    });

    test('RootsKey and PathKey are distinct keys', () {
      expect(const RootsKey(), isNot(equals(const PathKey('/a'))));
    });

    test('value equality lets distinct instances address the same slot', () {
      final t = LoadTracker<TreeLoadKey>()..begin(PathKey(v('/a')));
      // A fresh, non-identical PathKey with the same path reads the slot.
      expect(t.isLoading(PathKey(v('/a'))), isTrue);
      t.complete(PathKey(v('/a')));
      expect(t.isLoading(PathKey(v('/a'))), isFalse);
    });

    test('RootsKey and PathKey are independent slots in one tracker', () {
      final t = LoadTracker<TreeLoadKey>()
        ..begin(const RootsKey())
        ..begin(const PathKey('/a'));
      expect(t.isLoading(const RootsKey()), isTrue);
      expect(t.isLoading(const PathKey('/a')), isTrue);
      t.complete(const RootsKey());
      expect(t.isLoading(const RootsKey()), isFalse);
      expect(t.isLoading(const PathKey('/a')), isTrue);
    });
  });

  group('PageKey', () {
    test('equal by page number', () {
      expect(PageKey(i(3)), equals(PageKey(i(3))));
      expect(PageKey(i(3)).hashCode, equals(PageKey(i(3)).hashCode));
      expect(PageKey(i(3)), isNot(equals(PageKey(i(4)))));
      expect(PageKey(i(3)).toString(), 'PageKey(3)');
    });

    test('each page is its own slot, so pages load concurrently', () {
      final t = LoadTracker<PageKey>()
        ..begin(PageKey(i(4)))
        ..begin(PageKey(i(9)));
      expect(t.isLoading(PageKey(i(4))), isTrue);
      expect(t.isLoading(PageKey(i(9))), isTrue);
      expect(t.isLoading(PageKey(i(5))), isFalse);
      t.complete(PageKey(i(4)));
      expect(t.isLoading(PageKey(i(4))), isFalse);
      expect(t.isLoading(PageKey(i(9))), isTrue);
    });
  });

  group('LoadRequest value equality (address: id + key)', () {
    test('equal iff id and key match', () {
      expect(LoadRequest(v('l'), key: page0), equals(LoadRequest(v('l'), key: page0)));
      expect(
        LoadRequest(v('l'), key: page0).hashCode,
        equals(LoadRequest(v('l'), key: page0).hashCode),
      );
      expect(LoadRequest(v('l'), key: page0), isNot(equals(LoadRequest(v('m'), key: page0))));
    });

    test('key disambiguates (same id, different key)', () {
      expect(
        LoadRequest(v('t'), key: PageKey(i(0))),
        isNot(equals(LoadRequest(v('t'), key: PageKey(i(1))))),
      );
    });

    test('typed key value equality flows through the request', () {
      expect(LoadRequest(v('t'), key: PathKey(v('/a'))), equals(LoadRequest(v('t'), key: PathKey(v('/a')))));
      expect(LoadRequest(v('t'), key: PathKey(v('/a'))), isNot(equals(LoadRequest(v('t'), key: PathKey(v('/b'))))));
    });

    test('toString shows id and key', () {
      expect(LoadRequest(v('t'), key: PageKey(i(4))).toString(), 'LoadRequest(t, key: PageKey(4))');
    });
  });

  group('LoadResult value equality', () {
    test('equal iff id, key, data, error match', () {
      final page = [1, 2, 3];
      expect(
        LoadResult<List<int>>(v('l'), key: page0, data: page),
        equals(LoadResult<List<int>>(v('l'), key: page0, data: page)),
      );
      expect(
        LoadResult<List<int>>(v('l'), key: page0, data: page).hashCode,
        equals(LoadResult<List<int>>(v('l'), key: page0, data: page).hashCode),
      );
    });

    test('differs by id, key, or error', () {
      expect(LoadResult<int>(v('a')), isNot(equals(LoadResult<int>(v('b')))));
      expect(
        LoadResult<int>(v('a'), key: PageKey(i(0))),
        isNot(equals(LoadResult<int>(v('a'), key: PageKey(i(1))))),
      );
      expect(LoadResult<int>(v('a'), error: 'x'), isNot(equals(LoadResult<int>(v('a')))));
    });

    test('ok reflects absence of error', () {
      expect(LoadResult<int>(v('a'), data: 1).ok, isTrue);
      expect(LoadResult<int>(v('a'), error: Exception('e')).ok, isFalse);
    });

    test('toString surfaces id/key/data/error', () {
      expect(
        LoadResult<int>(v('a'), key: page0, data: 7).toString(),
        'LoadResult(a, key: PageKey(0), data: 7, error: null)',
      );
    });
  });

  group('LoadResult.cancelled — the third outcome', () {
    test('carries neither data nor error, and is not ok', () {
      final r = LoadResult<List<int>>.cancelled(v('t'), key: PageKey(i(2)));
      expect(r.cancelled, isTrue);
      expect(r.ok, isFalse);
      expect(r.data, isNull);
      expect(r.error, isNull);
    });

    test('is distinct from an empty success', () {
      // An empty page means "the data ends here"; a refusal must teach the
      // widget nothing, so the two can never be the same value.
      expect(
        LoadResult<List<int>>.cancelled(v('t'), key: page0),
        isNot(equals(LoadResult<List<int>>(v('t'), key: page0, data: const []))),
      );
      expect(LoadResult<List<int>>(v('t'), data: const []).ok, isTrue);
    });

    test('a failure is not a refusal', () {
      final failed = LoadResult<int>(v('t'), error: 'boom');
      expect(failed.cancelled, isFalse);
      expect(failed.ok, isFalse);
      expect(failed, isNot(equals(LoadResult<int>.cancelled(v('t')))));
    });

    test('equal by id and key', () {
      expect(
        LoadResult<int>.cancelled(v('t'), key: PageKey(i(2))),
        equals(LoadResult<int>.cancelled(v('t'), key: PageKey(i(2)))),
      );
      expect(
        LoadResult<int>.cancelled(v('t'), key: PageKey(i(2))).hashCode,
        equals(LoadResult<int>.cancelled(v('t'), key: PageKey(i(2))).hashCode),
      );
      expect(
        LoadResult<int>.cancelled(v('t'), key: PageKey(i(2))),
        isNot(equals(LoadResult<int>.cancelled(v('t'), key: PageKey(i(3))))),
      );
    });

    test('toString says it was refused', () {
      expect(
        LoadResult<int>.cancelled(v('t'), key: page0).toString(),
        'LoadResult.cancelled(t, key: PageKey(0))',
      );
    });
  });

  group('declineLoad', () {
    test('with no error, emits a refusal addressed to the request', () {
      final request = LoadRequest(v('table'), key: PageKey(i(7)));
      final cmd = declineLoad(request);
      expect(cmd, isA<Emit>());
      final msg = (cmd as Emit).msg;
      expect(msg, isA<LoadResult<Object?>>());
      final result = msg as LoadResult<Object?>;
      expect(result.id, 'table');
      expect(result.key, PageKey(i(7)));
      expect(result.cancelled, isTrue);
      expect(result.ok, isFalse);
      expect(result.data, isNull);
      expect(result.error, isNull);
    });

    test('with an error, emits a failure instead of a refusal', () {
      final request = LoadRequest(v('table'), key: PageKey(i(7)));
      final result = (declineLoad(request, error: 'no source wired for table') as Emit).msg as LoadResult<Object?>;
      expect(result.cancelled, isFalse);
      expect(result.ok, isFalse);
      expect(result.error, 'no source wired for table');
      expect(result.key, PageKey(i(7)));
    });

    test('threads the request address home for any key type', () {
      final result = (declineLoad(LoadRequest(v('tree'), key: PathKey(v('/a')))) as Emit).msg as LoadResult<Object?>;
      expect(result.id, 'tree');
      expect(result.key, PathKey(v('/a')));
    });
  });

  group('LoadResult erases to LoadResult<Object?> at the routing boundary', () {
    test("a typed result is assignable to the erased form a model's update consumes", () {
      // The covariance routing relies on: LoadResult<List<int>> *is a*
      // LoadResult<Object?>, so the router delivers any result as a Msg and
      // the model's update casts data once.
      final LoadResult<Object?> erased = LoadResult<List<int>>(v('l'), key: page0, data: const [1, 2]);
      expect(erased.id, 'l');
      expect(erased.data, const [1, 2]);
      expect(erased.ok, isTrue);
    });
  });
}
