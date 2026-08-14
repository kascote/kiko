import 'package:kiko_log/kiko_log.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Collects every record written, so a test can assert on warnings.
class _CapturingOutput implements LogOutput {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
}

PageLoader<String> _loader({
  required int Function() firstRow,
  required int Function() visibleRows,
  int pageSize = 10,
  int maxConcurrentLoads = 3,
}) => PageLoader<String>(
  id: 'w',
  widgetName: 'TestWidget',
  firstRow: firstRow,
  visibleRows: visibleRows,
  pageSize: pageSize,
  maxConcurrentLoads: maxConcurrentLoads,
);

List<String> _page(int page, {int size = 10}) => List.generate(size, (i) => 'row${page * size + i}');

LoadResult<PageResult<String>> _result(int page, List<String> rows, {int? totalCount, bool? hasMore}) => LoadResult(
  'w',
  key: PageKey(page),
  data: PageResult(rows, totalCount: totalCount, hasMore: hasMore),
);

void main() {
  group('PageLoader pump warning', () {
    test('a widget with nothing to request never counts toward the warning', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        var rows = 0;
        final loader = _loader(firstRow: () => 0, visibleRows: () => rows)
          ..seed(_page(0) + _page(1, size: 3)); // short tail records the end
        rows = 8;
        for (var i = 0; i < 80; i++) {
          loader.notePaint();
        }
      });

      expect(output.records, isEmpty, reason: 'every page that exists is held, so no arm is missing');
    });

    test('demand left armed over a requestable page warns once', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        var rows = 0;
        final loader = _loader(firstRow: () => 0, visibleRows: () => rows)..totalCount = 100;
        rows = 8;
        for (var i = 0; i < 80; i++) {
          loader.notePaint();
        }
      });

      expect(output.records, hasLength(1), reason: 'said once, not once per paint');
      expect(output.records.single.message, contains('TestWidget "w"'));
      expect(output.records.single.message, contains('demandIfDirty'));
    });

    test('a fetch in flight against the cap does not count as a missing pump', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        var rows = 0;
        final loader = _loader(firstRow: () => 0, visibleRows: () => rows, maxConcurrentLoads: 1)..totalCount = 100;
        rows = 8;
        loader.demand(); // takes the one slot; the visible page is on its way
        for (var i = 0; i < 80; i++) {
          loader.notePaint();
        }
      });

      expect(output.records, isEmpty, reason: 'nothing is requestable while the cap is spent');
    });
  });

  group('PageLoader short page vs end-of-data flag', () {
    test('a short page ends the data even when hasMore says more rows follow', () {
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8)
        ..loadFirstPage()
        ..apply(_result(0, _page(0, size: 4), hasMore: true));

      expect(loader.knownRowCount, equals(4));
      expect(loader.demand(), isNull, reason: 'no page past the recorded end is asked for');
    });
  });

  group('PageLoader out-of-order empty probes', () {
    // Log.runZoned guards uncaught errors, which would swallow a failed
    // expectation: act inside the zone, assert outside it.
    test('empty results from concurrent probes keep the recorded end', () {
      final output = _CapturingOutput();
      var first = 0;
      final loader = _loader(firstRow: () => first, visibleRows: () => 8);
      late final bool probedBoth;
      Log(output: output, level: LogLevel.warn).runZoned(() {
        loader.seed([for (var p = 0; p < 5; p++) ..._page(p)]); // 50 rows, end unknown
        first = 45;
        loader.demand(); // the viewport reaches past the data: probes pages 5 and 6
        probedBoth = loader.isLoading(const PageKey(5)) && loader.isLoading(const PageKey(6));
        loader
          ..apply(_result(5, const [])) // records the end at page 4
          ..apply(_result(6, const [])); // must not move it to page 5
      });

      expect(probedBoth, isTrue, reason: 'both probes must be in flight at once');
      expect(loader.knownRowCount, equals(50));
      expect(loader.rowLimit, equals(50));
      expect(loader.demand(), isNull, reason: 'no page past the end is asked for again');
      expect(output.records, isEmpty, reason: 'probing past the end is routine, not a contradiction');
    });
  });

  group('PageLoader contradictory short page warning', () {
    test('a short page while a later page is held warns, naming the widget', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _loader(firstRow: () => 0, visibleRows: () => 8)
          ..demand() // requests pages 0 and 1
          ..apply(_result(1, _page(1)))
          ..apply(_result(0, _page(0, size: 4)));
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.message, contains('TestWidget "w"'));
      expect(output.records.single.message, contains('page 1 is already loaded'));
    });

    test('a short page while a later page is in flight warns', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _loader(firstRow: () => 0, visibleRows: () => 8)
          ..demand() // requests pages 0 and 1
          ..apply(_result(0, _page(0, size: 4)));
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.message, contains('page 1 is still being fetched'));
    });

    test('an empty page while a later probe is in flight warns nothing', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        var first = 0;
        final loader = _loader(firstRow: () => first, visibleRows: () => 8)
          ..seed([for (var p = 0; p < 5; p++) ..._page(p)]);
        first = 45;
        loader
          ..demand() // probes pages 5 and 6
          ..apply(_result(5, const []));
      });

      expect(output.records, isEmpty, reason: 'probes past the end normally all come back empty');
    });

    test('a short page against a known count warns; the count still sets the end', () {
      final output = _CapturingOutput();
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8);
      Log(output: output, level: LogLevel.warn).runZoned(() {
        loader
          ..loadFirstPage()
          ..apply(_result(0, _page(0, size: 4), totalCount: 100));
      });

      expect(output.records, hasLength(1));
      expect(output.records.single.message, contains('row count (100)'));
      expect(loader.knownRowCount, equals(100), reason: 'the count re-records the end past the short page');
    });

    test('the warning is said once, not once per contradiction', () {
      final output = _CapturingOutput();
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _loader(firstRow: () => 0, visibleRows: () => 8)
          ..totalCount = 100
          ..loadFirstPage()
          ..apply(_result(0, _page(0, size: 4))) // contradicts the count: warns
          ..reset()
          ..totalCount =
              100 // the new count re-opens the data past the short page
          ..loadFirstPage()
          ..apply(_result(0, _page(0, size: 4))); // the same contradiction, said nothing
      });

      expect(output.records, hasLength(1));
    });

    test('a legitimate final short page warns nothing', () {
      final output = _CapturingOutput();
      final counted = _loader(firstRow: () => 0, visibleRows: () => 8);
      Log(output: output, level: LogLevel.warn).runZoned(() {
        _loader(firstRow: () => 0, visibleRows: () => 8)
          ..loadFirstPage()
          ..apply(_result(0, _page(0, size: 4)));

        counted
          ..totalCount = 14
          ..demand() // requests pages 0 and 1
          ..apply(_result(0, _page(0)))
          ..apply(_result(1, _page(1, size: 4)));
      });

      expect(counted.knownRowCount, equals(14));

      expect(output.records, isEmpty, reason: 'a short last page is how the end normally arrives');
    });
  });

  group('PageLoader stale count vs recorded end', () {
    // Several of these contradictions also warn. The warning is pinned above;
    // here the capturing zone only keeps it out of the test output.
    // Log.runZoned guards uncaught errors, which would swallow a failed
    // expectation: act inside the zone, assert outside it.
    test('a short page tightens an earlier count to the end it recorded', () {
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8);
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader
          ..totalCount = 100
          ..loadFirstPage()
          ..apply(_result(0, _page(0, size: 4)));
      });

      expect(loader.totalCount, equals(4));
      expect(loader.knownRowCount, equals(4));
      expect(loader.rowLimit, equals(4));
      expect(loader.demand(), isNull, reason: 'no placeholder row is left that no pass will fill');
    });

    test('the end-of-data flag tightens an earlier count', () {
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8)
        ..totalCount = 100
        ..loadFirstPage()
        ..apply(_result(0, _page(0), hasMore: false));

      expect(loader.totalCount, equals(10));
      expect(loader.knownRowCount, equals(10));
      expect(loader.rowLimit, equals(10));
      expect(loader.demand(), isNull);
    });

    test('an empty first page tightens an earlier count to zero', () {
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8);
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader
          ..totalCount = 100
          ..loadFirstPage()
          ..apply(_result(0, const []));
      });

      expect(loader.totalCount, equals(0));
      expect(loader.knownRowCount, equals(0));
      expect(loader.rowLimit, equals(0));
      expect(loader.demand(), isNull);
    });

    test('an empty page far out tightens the count only to the pages still fetchable', () {
      final loader = _loader(firstRow: () => 50, visibleRows: () => 8);
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader
          ..totalCount = 100
          ..demand() // requests pages 4, 5 and 6
          ..apply(_result(5, const [])); // ends the data at page 4, still unfetched
      });

      expect(loader.totalCount, equals(50), reason: 'pages 0..4 can still be fetched whole');
      expect(loader.knownRowCount, equals(50));
    });

    test('a short final seed chunk tightens an earlier count', () {
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8)
        ..totalCount = 100
        ..seed(_page(0) + _page(1, size: 4));

      expect(loader.totalCount, equals(14));
      expect(loader.knownRowCount, equals(14));
      expect(loader.rowLimit, equals(14));
      expect(loader.demand(), isNull);
    });

    test('a count arriving after the short evidence re-opens the data', () {
      final loader = _loader(firstRow: () => 0, visibleRows: () => 8);
      Log(output: _CapturingOutput(), level: LogLevel.warn).runZoned(() {
        loader
          ..totalCount = 100
          ..loadFirstPage()
          ..apply(_result(0, _page(0, size: 4)))
          ..totalCount = 100;
      });

      expect(loader.totalCount, equals(100));
      expect(loader.knownRowCount, equals(100));
      expect(loader.demand(), isNotNull, reason: 'the pages past the short page are fetchable again');
    });
  });
}
