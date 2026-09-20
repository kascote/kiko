import 'package:kiko/kiko.dart';
import 'package:kiko_log/kiko_log.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../support/load.dart';

/// Collects every record written, so a test can assert on a debug line.
class _CapturingOutput implements LogOutput {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

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

    test('clear drops every slot, in flight and failed alike', () {
      final t = LoadTracker<PageKey>()
        ..begin(PageKey(i(0)))
        ..fail(PageKey(i(1)), 'e')
        ..clear();
      expect(t.loading, isEmpty);
      expect(t.isLoading(), isFalse);
      expect(t.stateFor(PageKey(i(0))).status, LoadStatus.idle);
      expect(t.stateFor(PageKey(i(1))).status, LoadStatus.idle);
      expect(t.errorFor(PageKey(i(1))), isNull);
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

  group('LoadTicket', () {
    test('begin mints a fresh ticket for every asking, numbered in order', () {
      final t = LoadTracker<PageKey>();
      final first = t.begin(page0);
      final second = t.begin(page0);

      expect(identical(first, second), isFalse, reason: 'two askings, two identities');
      expect(first.sequence, 1);
      expect(second.sequence, 2);
      expect('$second', 'LoadTicket#2');
      expect(t.stateFor(page0).ticket, same(second), reason: 'the slot holds the newest asking');
    });

    test('a ticket equals only itself, never another with the same number', () {
      final a = LoadTracker<PageKey>().begin(page0);
      final b = LoadTracker<PageKey>().begin(page0);

      expect(a.sequence, equals(b.sequence));
      expect(a, isNot(equals(b)), reason: 'trackers number independently, so numbers never identify');
      expect(a, equals(a));
    });

    test('resolves accepts the live asking and drops an older one for the same key', () {
      final t = LoadTracker<PageKey>();
      final old = LoadRequest(v('l'), key: page0, ticket: t.begin(page0));
      final live = LoadRequest(v('l'), key: page0, ticket: t.begin(page0));

      expect(t.resolves(LoadResult<int>.ok(old, 1)), isFalse, reason: 'the slot moved on to a newer asking');
      expect(t.isLoading(page0), isTrue, reason: 'a dropped result never touches the live slot');
      expect(t.resolves(LoadResult<int>.ok(live, 1)), isTrue);
    });

    test('resolves drops a result for an idle key, a foreign key type, and a completed asking', () {
      final t = LoadTracker<PageKey>();
      final request = LoadRequest(v('l'), key: page0, ticket: t.begin(page0));

      expect(t.resolves(LoadResult<int>.ok(requestFor('l', key: PageKey(i(1))), 1)), isFalse, reason: 'idle key');
      expect(t.resolves(LoadResult<int>.ok(requestFor('l', key: 'not a page'), 1)), isFalse, reason: 'foreign key');
      t.complete(page0);
      expect(t.resolves(LoadResult<int>.ok(request, 1)), isFalse, reason: 'the asking already resolved');
    });

    test('a stale result is logged at debug level, naming both tickets', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.debug).runZoned(() {
        final t = LoadTracker<PageKey>();
        final old = LoadRequest(v('l'), key: page0, ticket: t.begin(page0));
        t
          ..begin(page0)
          ..resolves(LoadResult<int>.ok(old, 1));
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.level, LogLevel.debug);
      expect(output.records.single.message, contains('LoadTicket#1'));
      expect(output.records.single.message, contains('LoadTicket#2'));
    });
  });

  group('LoadRequest value equality (address: id + key + ticket)', () {
    test('equal iff id, key and ticket match', () {
      final ticket = LoadTracker<PageKey>().begin(page0);
      expect(LoadRequest(v('l'), key: page0, ticket: ticket), equals(LoadRequest(v('l'), key: page0, ticket: ticket)));
      expect(
        LoadRequest(v('l'), key: page0, ticket: ticket).hashCode,
        equals(LoadRequest(v('l'), key: page0, ticket: ticket).hashCode),
      );
      expect(
        LoadRequest(v('l'), key: page0, ticket: ticket),
        isNot(equals(LoadRequest(v('m'), key: page0, ticket: ticket))),
      );
    });

    test('key disambiguates (same id, different key)', () {
      final ticket = LoadTracker<PageKey>().begin(page0);
      expect(
        LoadRequest(v('t'), key: PageKey(i(0)), ticket: ticket),
        isNot(equals(LoadRequest(v('t'), key: PageKey(i(1)), ticket: ticket))),
      );
    });

    test('the ticket disambiguates two askings for one address', () {
      final t = LoadTracker<PageKey>();
      expect(
        LoadRequest(v('t'), key: page0, ticket: t.begin(page0)),
        isNot(equals(LoadRequest(v('t'), key: page0, ticket: t.begin(page0)))),
      );
    });

    test('typed key value equality flows through the request', () {
      final ticket = LoadTracker<PathKey>().begin(PathKey(v('/a')));
      expect(
        LoadRequest(v('t'), key: PathKey(v('/a')), ticket: ticket),
        equals(LoadRequest(v('t'), key: PathKey(v('/a')), ticket: ticket)),
      );
      expect(
        LoadRequest(v('t'), key: PathKey(v('/a')), ticket: ticket),
        isNot(equals(LoadRequest(v('t'), key: PathKey(v('/b')), ticket: ticket))),
      );
    });

    test('toString shows id, key and ticket', () {
      final request = LoadRequest(v('t'), key: PageKey(i(4)), ticket: LoadTracker<PageKey>().begin(PageKey(i(4))));
      expect(request.toString(), 'LoadRequest(t, key: PageKey(4), LoadTicket#1)');
    });
  });

  group('LoadResult is built from its request', () {
    test('ok carries the request address and ticket, and the data', () {
      final request = requestFor('l', key: page0);
      final result = LoadResult<List<int>>.ok(request, const [1, 2]);

      expect(result.id, 'l');
      expect(result.key, page0);
      expect(result.ticket, same(request.ticket));
      expect(result.data, const [1, 2]);
      expect(result.error, isNull);
      expect(result.ok, isTrue);
      expect(result.cancelled, isFalse);
    });

    test('failed carries the error and is not ok', () {
      final result = LoadResult<int>.failed(requestFor('a'), Exception('e'));
      expect(result.ok, isFalse);
      expect(result.cancelled, isFalse);
      expect(result.data, isNull);
      expect(result.error, isA<Exception>());
    });

    test('equal iff request, data and error match', () {
      final request = requestFor('l', key: page0);
      final page = [1, 2, 3];
      expect(LoadResult<List<int>>.ok(request, page), equals(LoadResult<List<int>>.ok(request, page)));
      expect(
        LoadResult<List<int>>.ok(request, page).hashCode,
        equals(LoadResult<List<int>>.ok(request, page).hashCode),
      );
    });

    test('differs by id, key, ticket, or error', () {
      expect(LoadResult<int>.ok(requestFor('a'), 1), isNot(equals(LoadResult<int>.ok(requestFor('b'), 1))));
      expect(
        LoadResult<int>.ok(requestFor('a', key: PageKey(i(0))), 1),
        isNot(equals(LoadResult<int>.ok(requestFor('a', key: PageKey(i(1))), 1))),
      );
      final t = LoadTracker<PageKey>();
      expect(
        LoadResult<int>.ok(LoadRequest(v('a'), key: page0, ticket: t.begin(page0)), 1),
        isNot(equals(LoadResult<int>.ok(LoadRequest(v('a'), key: page0, ticket: t.begin(page0)), 1))),
        reason: 'two askings, two results',
      );
      final request = requestFor('a');
      expect(LoadResult<int>.failed(request, 'x'), isNot(equals(LoadResult<int>.ok(request, 1))));
    });

    test('toString surfaces id/key/ticket/data/error', () {
      expect(
        LoadResult<int>.ok(requestFor('a', key: page0), 7).toString(),
        'LoadResult(a, key: PageKey(0), LoadTicket#1, data: 7, error: null)',
      );
    });
  });

  group('LoadResult.cancelled — the third outcome', () {
    test('carries neither data nor error, and is not ok', () {
      final r = LoadResult<List<int>>.cancelled(requestFor('t', key: PageKey(i(2))));
      expect(r.cancelled, isTrue);
      expect(r.ok, isFalse);
      expect(r.data, isNull);
      expect(r.error, isNull);
    });

    test('is distinct from an empty success', () {
      // An empty page means "the data ends here"; a refusal must teach the
      // widget nothing, so the two can never be the same value.
      final request = requestFor('t', key: page0);
      expect(LoadResult<List<int>>.cancelled(request), isNot(equals(LoadResult<List<int>>.ok(request, const []))));
      expect(LoadResult<List<int>>.ok(request, const []).ok, isTrue);
    });

    test('a failure is not a refusal', () {
      final request = requestFor('t');
      final failed = LoadResult<int>.failed(request, 'boom');
      expect(failed.cancelled, isFalse);
      expect(failed.ok, isFalse);
      expect(failed, isNot(equals(LoadResult<int>.cancelled(request))));
    });

    test('equal by request', () {
      final request = requestFor('t', key: PageKey(i(2)));
      expect(LoadResult<int>.cancelled(request), equals(LoadResult<int>.cancelled(request)));
      expect(LoadResult<int>.cancelled(request).hashCode, equals(LoadResult<int>.cancelled(request).hashCode));
      expect(
        LoadResult<int>.cancelled(request),
        isNot(equals(LoadResult<int>.cancelled(requestFor('t', key: PageKey(i(3)))))),
      );
    });

    test('toString says it was refused', () {
      expect(
        LoadResult<int>.cancelled(requestFor('t', key: page0)).toString(),
        'LoadResult.cancelled(t, key: PageKey(0), LoadTicket#1)',
      );
    });
  });

  group('declineLoad', () {
    test('with no error, emits a refusal addressed to the request', () {
      final request = requestFor('table', key: PageKey(i(7)));
      final cmd = declineLoad(request);
      expect(cmd, isA<Emit>());
      final msg = (cmd as Emit).msg;
      expect(msg, isA<LoadResult<Object?>>());
      final result = msg as LoadResult<Object?>;
      expect(result.id, 'table');
      expect(result.key, PageKey(i(7)));
      expect(result.ticket, same(request.ticket));
      expect(result.cancelled, isTrue);
      expect(result.ok, isFalse);
      expect(result.data, isNull);
      expect(result.error, isNull);
    });

    test('with an error, emits a failure instead of a refusal', () {
      final request = requestFor('table', key: PageKey(i(7)));
      final result = (declineLoad(request, error: 'no source wired for table') as Emit).msg as LoadResult<Object?>;
      expect(result.cancelled, isFalse);
      expect(result.ok, isFalse);
      expect(result.error, 'no source wired for table');
      expect(result.key, PageKey(i(7)));
      expect(result.ticket, same(request.ticket));
    });

    test('carries the request home for any key type', () {
      final request = requestFor('tree', key: PathKey(v('/a')));
      final result = (declineLoad(request) as Emit).msg as LoadResult<Object?>;
      expect(result.id, 'tree');
      expect(result.key, PathKey(v('/a')));
      expect(result.ticket, same(request.ticket));
    });
  });

  group('LoadResult erases to LoadResult<Object?> at the routing boundary', () {
    test("a typed result is assignable to the erased form a model's update consumes", () {
      // The covariance routing relies on: LoadResult<List<int>> *is a*
      // LoadResult<Object?>, so the router delivers any result as a Msg and
      // the model's update casts data once.
      final LoadResult<Object?> erased = LoadResult<List<int>>.ok(requestFor('l', key: page0), const [1, 2]);
      expect(erased.id, 'l');
      expect(erased.data, const [1, 2]);
      expect(erased.ok, isTrue);
    });
  });
}
