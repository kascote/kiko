import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Identity passthrough returning a *runtime* (non-const) string, so the
/// commands/messages below are distinct instances and `operator ==` actually
/// runs (const canonicalization would otherwise make equal values identical).
String v(String s) => s;

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
      final t = LoadTracker<ListLoadKey>();
      expect(t.stateFor(ListLoadKey.self).status, LoadStatus.idle);
      expect(t.isLoading(ListLoadKey.self), isFalse);
      expect(t.errorFor(ListLoadKey.self), isNull);
    });

    test('begin → loading', () {
      final t = LoadTracker<ListLoadKey>()..begin(ListLoadKey.self);
      expect(t.stateFor(ListLoadKey.self).status, LoadStatus.loading);
      expect(t.isLoading(ListLoadKey.self), isTrue);
    });

    test('complete → idle (slot removed)', () {
      final t = LoadTracker<ListLoadKey>()
        ..begin(ListLoadKey.self)
        ..complete(ListLoadKey.self);
      expect(t.stateFor(ListLoadKey.self).status, LoadStatus.idle);
      expect(t.isLoading(ListLoadKey.self), isFalse);
    });

    test('fail → error with recorded cause; errorFor reads it', () {
      final cause = Exception('nope');
      final t = LoadTracker<ListLoadKey>()..fail(ListLoadKey.self, cause);
      expect(t.stateFor(ListLoadKey.self).status, LoadStatus.error);
      expect(t.stateFor(ListLoadKey.self).failed, isTrue);
      expect(t.errorFor(ListLoadKey.self), same(cause));
      // An errored slot is not "loading".
      expect(t.isLoading(ListLoadKey.self), isFalse);
    });

    test('complete clears a prior error', () {
      final t = LoadTracker<ListLoadKey>()
        ..fail(ListLoadKey.self, Exception('x'))
        ..complete(ListLoadKey.self);
      expect(t.errorFor(ListLoadKey.self), isNull);
      expect(t.stateFor(ListLoadKey.self).status, LoadStatus.idle);
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

    test('per-key isLoading isolates concurrent slots', () {
      final t = LoadTracker<TableLoadKey>()..begin(TableLoadKey.forward);
      expect(t.isLoading(TableLoadKey.forward), isTrue);
      expect(t.isLoading(TableLoadKey.backward), isFalse);
      t.begin(TableLoadKey.backward);
      expect(t.isLoading(TableLoadKey.forward), isTrue);
      expect(t.isLoading(TableLoadKey.backward), isTrue);
      t.complete(TableLoadKey.forward);
      expect(t.isLoading(TableLoadKey.forward), isFalse);
      expect(t.isLoading(TableLoadKey.backward), isTrue);
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

  group('LoadRequest value equality (address: id + key)', () {
    test('equal iff id and key match', () {
      expect(LoadRequest(v('l'), key: ListLoadKey.self), equals(LoadRequest(v('l'), key: ListLoadKey.self)));
      expect(
        LoadRequest(v('l'), key: ListLoadKey.self).hashCode,
        equals(LoadRequest(v('l'), key: ListLoadKey.self).hashCode),
      );
      expect(LoadRequest(v('l'), key: ListLoadKey.self), isNot(equals(LoadRequest(v('m'), key: ListLoadKey.self))));
    });

    test('key disambiguates (same id, different key)', () {
      expect(
        LoadRequest(v('t'), key: TableLoadKey.forward),
        isNot(equals(LoadRequest(v('t'), key: TableLoadKey.backward))),
      );
    });

    test('typed key value equality flows through the request', () {
      expect(LoadRequest(v('t'), key: PathKey(v('/a'))), equals(LoadRequest(v('t'), key: PathKey(v('/a')))));
      expect(LoadRequest(v('t'), key: PathKey(v('/a'))), isNot(equals(LoadRequest(v('t'), key: PathKey(v('/b'))))));
    });

    test('toString shows id and key', () {
      expect(LoadRequest(v('t'), key: TableLoadKey.forward).toString(), 'LoadRequest(t, key: TableLoadKey.forward)');
    });
  });

  group('LoadResult value equality', () {
    test('equal iff id, key, data, error match', () {
      final page = [1, 2, 3];
      expect(
        LoadResult<List<int>>(v('l'), key: ListLoadKey.self, data: page),
        equals(LoadResult<List<int>>(v('l'), key: ListLoadKey.self, data: page)),
      );
      expect(
        LoadResult<List<int>>(v('l'), key: ListLoadKey.self, data: page).hashCode,
        equals(LoadResult<List<int>>(v('l'), key: ListLoadKey.self, data: page).hashCode),
      );
    });

    test('differs by id, key, or error', () {
      expect(LoadResult<int>(v('a')), isNot(equals(LoadResult<int>(v('b')))));
      expect(
        LoadResult<int>(v('a'), key: TableLoadKey.forward),
        isNot(equals(LoadResult<int>(v('a'), key: TableLoadKey.backward))),
      );
      expect(LoadResult<int>(v('a'), error: 'x'), isNot(equals(LoadResult<int>(v('a')))));
    });

    test('ok reflects absence of error', () {
      expect(LoadResult<int>(v('a'), data: 1).ok, isTrue);
      expect(LoadResult<int>(v('a'), error: Exception('e')).ok, isFalse);
    });

    test('toString surfaces id/key/data/error', () {
      expect(
        LoadResult<int>(v('a'), key: ListLoadKey.self, data: 7).toString(),
        'LoadResult(a, key: ListLoadKey.self, data: 7, error: null)',
      );
    });
  });

  group('LoadResult erases to LoadResult<Object?> at the registry boundary', () {
    test('a typed result is assignable to the erased form Loadable consumes', () {
      // The covariance the registry relies on (A7 #1): LoadResult<List<int>>
      // *is a* LoadResult<Object?>, so a heterogeneous registry routes it and
      // applyLoad casts data once.
      final LoadResult<Object?> erased = LoadResult<List<int>>(v('l'), key: ListLoadKey.self, data: const [1, 2]);
      expect(erased.id, 'l');
      expect(erased.data, const [1, 2]);
      expect(erased.ok, isTrue);
    });
  });
}
