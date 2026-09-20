import 'package:kiko_log/kiko_log.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../support/load.dart';

/// Collects every record written, so a test can assert on warnings.
class _CapturingOutput implements LogOutput {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

/// A loader under test, with the live request for every page it asked for,
/// so a test answers by page number the way the app answers by request.
class _Asked {
  _Asked({
    required int Function() firstRow,
    required int Function() visibleRows,
    int pageSize = 10,
    int maxConcurrentLoads = 3,
  }) : loader = PageLoader<String>(
         id: 'w',
         widgetName: 'TestWidget',
         firstRow: firstRow,
         visibleRows: visibleRows,
         pageSize: pageSize,
         maxConcurrentLoads: maxConcurrentLoads,
       );

  final PageLoader<String> loader;
  final _live = RequestLog();

  /// Runs a demand pass, remembering what it asked for.
  void demand() {
    _live.note(loader.demand());
  }

  /// Asks for the first page, remembering the request.
  void loadFirstPage() {
    _live.note(loader.loadFirstPage());
  }

  /// Answers the live request for [page] with [rows].
  void answer(int page, List<String> rows, {int? totalCount, bool? hasMore}) {
    loader.apply(
      LoadResult<PageResult<String>>.ok(
        _live[PageKey(page)],
        PageResult(rows, totalCount: totalCount, hasMore: hasMore),
      ),
    );
  }

  /// Answers the live request for [page] with a failure.
  void fail(int page, Object error) => loader.apply(LoadResult<PageResult<String>>.failed(_live[PageKey(page)], error));

  /// Answers the live request for [page] with a payload of any shape.
  bool answerWith(int page, Object? payload) => loader.apply(LoadResult<Object?>.ok(_live[PageKey(page)], payload));
}

List<String> _page(int page, {int size = 10}) => List.generate(size, (i) => 'row${page * size + i}');

void main() {
  group('PageLoader short page vs end-of-data flag', () {
    test('a short page ends the data even when hasMore says more rows follow', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8)
        ..loadFirstPage()
        ..answer(0, _page(0, size: 4), hasMore: true);
      final loader = asked.loader;

      expect(loader.knownRowCount, equals(4));
      expect(loader.demand(), isEmpty, reason: 'no page past the recorded end is asked for');
    });
  });

  group('PageLoader out-of-order empty probes', () {
    test('empty results from concurrent probes keep the recorded end', () {
      final output = _CapturingOutput();
      var first = 0;
      final asked = _Asked(firstRow: () => first, visibleRows: () => 8);
      final loader = asked.loader;
      late final bool probedBoth;
      Log(output: output, level: LogLevel.warn).runZoned(() {
        loader.seed([for (var p = 0; p < 5; p++) ..._page(p)]); // 50 rows, end unknown
        first = 45;
        asked.demand(); // the viewport reaches past the data: probes pages 5 and 6
        probedBoth = loader.isLoading(const PageKey(5)) && loader.isLoading(const PageKey(6));
        asked
          ..answer(5, const []) // records the end at page 4
          ..answer(6, const []); // must not move it to page 5
      });

      expect(probedBoth, isTrue, reason: 'both probes must be in flight at once');
      expect(loader.knownRowCount, equals(50));
      expect(loader.rowLimit, equals(50));
      expect(loader.demand(), isEmpty, reason: 'no page past the end is asked for again');
      expect(output.records, isEmpty, reason: 'probing past the end is routine, not a contradiction');
    });
  });

  group('PageLoader contradictory short page warning', () {
    test('a short page while a later page is held warns, naming the widget', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _Asked(firstRow: () => 0, visibleRows: () => 8)
          ..demand() // requests pages 0 and 1
          ..answer(1, _page(1))
          ..answer(0, _page(0, size: 4));
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.message, contains('TestWidget "w"'));
      expect(output.records.single.message, contains('page 1 is already loaded'));
    });

    test('a short page while a later page is in flight warns', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _Asked(firstRow: () => 0, visibleRows: () => 8)
          ..demand() // requests pages 0 and 1
          ..answer(0, _page(0, size: 4));
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.message, contains('page 1 is still being fetched'));
    });

    test('an empty page while a later probe is in flight warns nothing', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        var first = 0;
        final asked = _Asked(firstRow: () => first, visibleRows: () => 8);
        asked.loader.seed([for (var p = 0; p < 5; p++) ..._page(p)]);
        first = 45;
        asked
          ..demand() // probes pages 5 and 6
          ..answer(5, const []);
      });

      expect(output.records, isEmpty, reason: 'probes past the end normally all come back empty');
    });

    test('a short page against a known count warns; the count still sets the end', () {
      final output = _CapturingOutput();
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
      Log(output: output, level: LogLevel.warn).runZoned(() {
        asked
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4), totalCount: 100);
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.message, contains('row count (100)'));
      expect(asked.loader.knownRowCount, equals(100), reason: 'the count re-records the end past the short page');
    });

    test('the warning is said once, not once per contradiction', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
        asked.loader.totalCount = 100;
        asked
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4)); // contradicts the count: warns
        asked.loader
          ..reset()
          ..totalCount = 100; // the new count re-opens the data past the short page
        asked
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4)); // the same contradiction, said nothing
      });

      expect(output.records, hasLength(1));
    });

    test('a legitimate final short page warns nothing', () {
      final output = _CapturingOutput();
      final counted = _Asked(firstRow: () => 0, visibleRows: () => 8);
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _Asked(firstRow: () => 0, visibleRows: () => 8)
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4));

        counted.loader.totalCount = 14;
        counted
          ..demand() // requests pages 0 and 1
          ..answer(0, _page(0))
          ..answer(1, _page(1, size: 4));
      });

      expect(counted.loader.knownRowCount, equals(14));

      expect(output.records, isEmpty, reason: 'a short last page is how the end normally arrives');
    });
  });

  group('PageLoader stale count vs recorded end', () {
    // Several of these contradictions also warn. The warning is pinned above;
    // here the capturing zone only keeps it out of the test output.
    test('a short page tightens an earlier count to the end it recorded', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
      final loader = asked.loader;
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader.totalCount = 100;
        asked
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4));
      });

      expect(loader.totalCount, equals(4));
      expect(loader.knownRowCount, equals(4));
      expect(loader.rowLimit, equals(4));
      expect(loader.demand(), isEmpty, reason: 'no placeholder row is left that no pass will fill');
    });

    test('the end-of-data flag tightens an earlier count', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
      final loader = asked.loader..totalCount = 100;
      asked
        ..loadFirstPage()
        ..answer(0, _page(0), hasMore: false);

      expect(loader.totalCount, equals(10));
      expect(loader.knownRowCount, equals(10));
      expect(loader.rowLimit, equals(10));
      expect(loader.demand(), isEmpty);
    });

    test('an empty first page tightens an earlier count to zero', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
      final loader = asked.loader;
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader.totalCount = 100;
        asked
          ..loadFirstPage()
          ..answer(0, const []);
      });

      expect(loader.totalCount, equals(0));
      expect(loader.knownRowCount, equals(0));
      expect(loader.rowLimit, equals(0));
      expect(loader.demand(), isEmpty);
    });

    test('an empty page far out tightens the count only to the pages still fetchable', () {
      final asked = _Asked(firstRow: () => 50, visibleRows: () => 8);
      final loader = asked.loader;
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader.totalCount = 100;
        asked
          ..demand() // requests pages 4, 5 and 6
          ..answer(5, const []); // ends the data at page 4, still unfetched
      });

      expect(loader.totalCount, equals(50), reason: 'pages 0..4 can still be fetched whole');
      expect(loader.knownRowCount, equals(50));
    });

    test('a short final seed chunk tightens an earlier count', () {
      final loader = _Asked(firstRow: () => 0, visibleRows: () => 8).loader
        ..totalCount = 100
        ..seed(_page(0) + _page(1, size: 4));

      expect(loader.totalCount, equals(14));
      expect(loader.knownRowCount, equals(14));
      expect(loader.rowLimit, equals(14));
      expect(loader.demand(), isEmpty);
    });

    test('a count arriving after the short evidence re-opens the data', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
      final loader = asked.loader;
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader.totalCount = 100;
        asked
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4));
        loader.totalCount = 100;
      });

      expect(loader.totalCount, equals(100));
      expect(loader.knownRowCount, equals(100));
      expect(loader.demand(), isNotEmpty, reason: 'the pages past the short page are fetchable again');
    });
  });

  group('PageLoader grown source', () {
    test('a refresh rediscovers a grown source the app never re-measured', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8);
      final loader = asked.loader;
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader.totalCount = 100;
        asked
          ..loadFirstPage()
          ..answer(0, _page(0, size: 4)); // the data ends at 4; the count tightens
      });
      expect(loader.totalCount, equals(4));

      loader.reset(); // the refresh: from scratch
      expect(loader.totalCount, isNull, reason: 'the conclusion does not outlive its evidence');
      expect(loader.knownRowCount, isNull);

      asked
        ..loadFirstPage()
        ..answer(0, _page(0)) // the source grew: page 0 is full now
        ..demand();
      expect(loader.isLoading(const PageKey(1)), isTrue, reason: 'a full first page keeps the demand pass probing');

      asked.answer(1, _page(1, size: 3));
      expect(loader.knownRowCount, equals(13), reason: 'the refresh found the grown size on its own');
      expect(loader.demand(), isEmpty);
    });

    test('a full page on the recorded end page past the count re-opens the data', () {
      final asked = _Asked(firstRow: () => 5, visibleRows: () => 8);
      final loader = asked.loader..totalCount = 15; // the end: page 1
      asked
        ..demand() // requests pages 0 and 1; page 2 does not exist yet
        ..answer(1, _page(1)); // the source grew: the end page is full

      expect(loader.totalCount, isNull, reason: 'the page holds rows the count said do not exist');
      expect(loader.knownRowCount, isNull, reason: 'where the data ends is unknown again');
      asked.demand();
      expect(loader.isLoading(const PageKey(2)), isTrue, reason: 'page 2 is fetchable again');

      asked.answer(2, _page(2, size: 3));
      expect(loader.knownRowCount, equals(23), reason: 'the grown end is rediscovered');
    });

    test('a full end page that only reaches the count leaves the end standing', () {
      var first = 0;
      final asked = _Asked(firstRow: () => first, visibleRows: () => 8);
      final loader = asked.loader..totalCount = 20; // two exact pages
      asked
        ..demand() // requests pages 0 and 1
        ..answer(0, _page(0))
        ..answer(1, _page(1)); // full, and exactly what the count allows

      first = 12; // the viewport's demand span now covers page 2
      expect(loader.totalCount, equals(20));
      expect(loader.demand(), isEmpty, reason: 'a consistent end pays no probe past it');
    });

    test('a full page past the recorded end clears the stale count with the record', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8)..demand(); // requests pages 0 and 1, end unknown
      final loader = asked.loader..totalCount = 5; // a count lands while page 1 is still in flight
      asked.answer(1, _page(1)); // and page 1 comes home full

      expect(loader.totalCount, isNull, reason: 'the rows in hand refute the count');
      expect(loader.knownRowCount, isNull);
      expect(loader.rowLimit, equals(20), reason: 'the held rows are addressable');
    });

    test('a short page past the count replaces it with the end it proves', () {
      final asked = _Asked(firstRow: () => 5, visibleRows: () => 8);
      final loader = asked.loader..totalCount = 12; // the end: page 1
      asked
        ..demand() // requests pages 0 and 1
        ..answer(1, _page(1, size: 8)); // 18 rows proved; the count said 12

      expect(loader.totalCount, isNull);
      expect(loader.knownRowCount, equals(18), reason: 'the short page is the newest end evidence');
      expect(loader.demand(), isEmpty, reason: 'nothing exists past the end it recorded');
    });
  });

  group('PageLoader reset', () {
    test('a reset forgets a failed slot along with everything else', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8)
        ..loadFirstPage()
        ..fail(0, 'boom');
      final loader = asked.loader;
      expect(loader.errorFor(const PageKey(0)), equals('boom'));
      expect(loader.viewportStatus, SliceStatus.failed);

      loader.reset();

      expect(
        loader.errorFor(const PageKey(0)),
        isNull,
        reason: 'a reset is a cold start; the failure does not outlive it',
      );
      expect(loader.viewportStatus, SliceStatus.stalled, reason: 'nothing held, nothing in flight, nothing failed');
      expect(loader.isLoading(), isFalse);
    });
  });

  group('PageLoader payload mismatch', () {
    test('a wrong-shaped success fails the slot and records no end-of-data', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8)..demand(); // requests page 0
      final loader = asked.loader;

      final installed = asked.answerWith(0, const <int>[1, 2, 3]);

      expect(installed, isFalse);
      expect(loader.isLoading(const PageKey(0)), isFalse, reason: 'the slot resolved');
      expect(loader.errorFor(const PageKey(0)), isA<PayloadMismatch>());
      expect(loader.viewportStatus, SliceStatus.failed, reason: 'the mismatch paints as a failure');
      expect(loader.cachedPages, isEmpty, reason: 'nothing installed');
      expect(loader.knownRowCount, isNull, reason: 'a mismatch is not a short page: no end recorded');
      expect(loader.demand(), isNotEmpty, reason: 'the page is still missing and still fetchable');
    });

    test('a null payload on a successful result is a mismatch', () {
      final asked = _Asked(firstRow: () => 0, visibleRows: () => 8)..demand();
      final loader = asked.loader;

      final installed = asked.answerWith(0, null);

      expect(installed, isFalse);
      final error = loader.errorFor(const PageKey(0));
      expect(error, isA<PayloadMismatch>());
      expect('$error', contains('carried null'));
      expect(loader.cachedPages, isEmpty);
      expect(loader.knownRowCount, isNull, reason: 'null is not an empty page');
    });

    test('the mismatch is logged once, naming the widget, key, and both shapes', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.error).runZoned(() {
        _Asked(firstRow: () => 0, visibleRows: () => 8)
          ..demand()
          ..answerWith(0, const <int>[1]);
      });

      expect(output.records, hasLength(1));
      final message = output.records.single.message;
      expect(output.records.single.level, LogLevel.error);
      expect(message, contains('TestWidget "w"'));
      expect(message, contains('PageKey(0)'));
      expect(message, contains('expected List<String> or PageResult<String>'));
      expect(message, contains('carried List<int>'));
    });
  });
}
