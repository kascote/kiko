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
}
