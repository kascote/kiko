import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// These tests exercise the *guarantee* id-addressing exists to provide and
/// that reference-addressing could not (a2.1 §3): with two instances of the
/// same widget, a command carries the emitter's id by value, the app resolves
/// it back to the correct instance, async results route home by id, and a miss
/// is observably logged + dropped rather than silently swallowed.

KeyMsg keyMsg(String key) => KeyMsg(key);

List<Map<String, Object?>> rows(int count) => List.generate(count, (i) => {'id': 'r$i', 'name': 'Name $i'});

List<TableColumn> columns() => [
  TableColumn(field: 'id', label: Line('ID')),
  TableColumn(field: 'name', label: Line('Name')),
];

/// A focused-by-default table with [n] rows already loaded into its cache.
TableViewModel table({String? id, int n = 5, bool focused = true, int loadThreshold = 5}) =>
    TableViewModel(
        dataSource: TableDataSource.fromList(rows(n)),
        keyField: 'id',
        columns: columns(),
        pageSize: 10,
        loadThreshold: loadThreshold,
        id: id,
        focused: focused,
      )
      ..setVisibleDimensions(5, 2)
      ..insertRows(rows(n), 0);

/// App-authored result message that carries the owner's id home (a2.1 §3.4).
class _RowsLoadedMsg extends Msg {
  final String id;
  final List<Map<String, Object?>> rows;
  final int pageNum;
  const _RowsLoadedMsg(this.id, this.rows, this.pageNum);
}

/// A two-instance app that resolves commands/results to their owner by id.
/// A miss is **logged and dropped** — the observable failure references could
/// not give you (a2.1 §3.3, §8).
class _TwoTables {
  final TableViewModel a;
  final TableViewModel b;
  final List<String> log = [];

  _TwoTables(this.a, this.b);

  TableViewModel? resolve(String id) {
    if (id == a.id) return a;
    if (id == b.id) return b;
    log.add('dropped: no owner for id "$id"');
    return null;
  }
}

void main() {
  group('id addressing', () {
    test('widget models are Components addressable by id', () {
      final m = table(id: 't');
      expect(m, isA<Component>());
      expect((m as Component).id, equals('t'));
    });

    group('multi-instance disambiguation', () {
      test('an action command carries its emitter id and resolves to that instance', () {
        final app = _TwoTables(
          table(id: 'tableA', focused: false),
          table(id: 'tableB'),
        );

        final cmd = app.b.update(keyMsg('enter'))! as TableActionCmd;

        expect(cmd.id, equals('tableB'));
        expect(app.resolve(cmd.id), same(app.b));
        expect(app.resolve(cmd.id), isNot(same(app.a)));
      });

      test('the sibling instance resolves to itself, not the other', () {
        final app = _TwoTables(
          table(id: 'tableA'),
          table(id: 'tableB', focused: false),
        );

        final cmd = app.a.update(keyMsg('enter'))! as TableActionCmd;

        expect(cmd.id, equals('tableA'));
        expect(app.resolve(cmd.id), same(app.a));
      });

      test('auto-generated ids still disambiguate two instances', () {
        final a = table(); // no explicit id → autoId
        final b = table(focused: false);

        expect(a.id, isNot(equals(b.id)));

        final cmd = a.update(keyMsg('enter'))! as TableActionCmd;
        expect(cmd.id, equals(a.id));
        expect(cmd.id, isNot(equals(b.id)));
      });
    });

    test('async load result routes home to only the originating instance', () async {
      final srcA = _PaginatedSource(rows(40));
      final a =
          TableViewModel(
              dataSource: srcA,
              keyField: 'id',
              columns: columns(),
              pageSize: 10,
              loadThreshold: 5,
              id: 'A',
              focused: true,
            )
            ..setVisibleDimensions(5, 2)
            ..insertRows(rows(10), 0);
      final b =
          TableViewModel(
              dataSource: _PaginatedSource(rows(40)),
              keyField: 'id',
              columns: columns(),
              pageSize: 10,
              id: 'B',
            )
            ..setVisibleDimensions(5, 2)
            ..insertRows(rows(10), 0);
      final app = _TwoTables(a, b);

      // Drive A's cursor toward the end until it requests more data.
      TableLoadMoreCmd? request;
      for (var i = 0; i < 12 && request == null; i++) {
        final cmd = a.update(keyMsg('down'));
        if (cmd is TableLoadMoreCmd) request = cmd;
      }
      expect(request, isNotNull, reason: 'expected a load request near the end');
      final id = request!.id;
      expect(id, equals('A'));

      // The app turns the request into a Task whose result carries the id home.
      final owner = app.resolve(id)!..isLoading = true;
      final pageNum = owner.nextPageNum;
      final task = Task<List<Map<String, Object?>>>(
        () => srcA.getPage(pageNum, owner.pageSize),
        onSuccess: (loaded) => _RowsLoadedMsg(id, loaded, pageNum),
      );

      final msg = await task.execute() as _RowsLoadedMsg;
      expect(msg.id, equals('A'));

      // On receipt, resolve home by id and install — only A is touched.
      final dest = app.resolve(msg.id)!
        ..insertRows(msg.rows, msg.pageNum)
        ..isLoading = false;
      expect(dest, same(a));

      expect(a.cachedRowCount, greaterThan(10));
      expect(a.isLoading, isFalse);
      expect(b.cachedRowCount, equals(10), reason: 'sibling must be untouched');
      expect(b.isLoading, isFalse);
    });

    test('a result whose id resolves to no owner is dropped and logged', () {
      final app = _TwoTables(table(id: 'A', focused: false), table(id: 'B', focused: false));
      final beforeA = app.a.cachedRowCount;
      final beforeB = app.b.cachedRowCount;

      // A result addressed to an instance that no longer exists (row deleted,
      // tab closed, list rebuilt) — exactly the orphan case references hid.
      final orphan = _RowsLoadedMsg('ghost', rows(3), 0);
      final dest = app.resolve(orphan.id);
      if (dest != null) {
        dest
          ..insertRows(orphan.rows, orphan.pageNum)
          ..isLoading = false;
      }

      expect(dest, isNull);
      expect(app.log, contains('dropped: no owner for id "ghost"'));
      // Nothing mutated — the drop is clean, not a write to the wrong instance.
      expect(app.a.cachedRowCount, equals(beforeA));
      expect(app.b.cachedRowCount, equals(beforeB));
    });
  });
}

/// Test data source with hasMore = true (so a load request can be emitted).
class _PaginatedSource implements TableDataSource {
  final List<Map<String, Object?>> _rows;
  _PaginatedSource(this._rows);

  @override
  Future<List<Map<String, Object?>>> getPage(int pageNum, int pageSize) async {
    final start = pageNum * pageSize;
    if (start >= _rows.length) return [];
    final end = (start + pageSize).clamp(0, _rows.length);
    return _rows.sublist(start, end);
  }

  @override
  bool get hasMore => true;

  @override
  int? get totalCount => _rows.length;
}
