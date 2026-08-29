import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';
import '../support/viewport.dart';

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
TableViewModel table({String? id, int n = 5, bool focused = true, int loadThreshold = 5}) => TableViewModel(
  rows: rows(n),
  keyField: 'id',
  columns: columns(),
  pageSize: 10,
  loadThreshold: loadThreshold,
  id: id,
  focused: focused,
)..viewport(rows: 5, cols: 2);

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

        final cmd = (app.b.update(keyMsg('enter')) as Handled).cmd! as TableActivateEvent;

        expect(cmd.id, equals('tableB'));
        expect(app.resolve(cmd.id), same(app.b));
        expect(app.resolve(cmd.id), isNot(same(app.a)));
      });

      test('the sibling instance resolves to itself, not the other', () {
        final app = _TwoTables(
          table(id: 'tableA'),
          table(id: 'tableB', focused: false),
        );

        final cmd = (app.a.update(keyMsg('enter')) as Handled).cmd! as TableActivateEvent;

        expect(cmd.id, equals('tableA'));
        expect(app.resolve(cmd.id), same(app.a));
      });

      test('auto-generated ids still disambiguate two instances', () {
        final a = table(); // no explicit id → autoId
        final b = table(focused: false);

        expect(a.id, isNot(equals(b.id)));

        final cmd = (a.update(keyMsg('enter')) as Handled).cmd! as TableActivateEvent;
        expect(cmd.id, equals(a.id));
        expect(cmd.id, isNot(equals(b.id)));
      });
    });

    test('async load result routes home to only the originating instance', () async {
      // Both tables hold their first page of a 40-row table; A is the one the
      // keyboard drives, so only A should ever see the result.
      final srcA = PageSource.offset<Map<String, Object?>>(
        pageSize: 10,
        read: (offset, limit) async => rows(40).skip(offset).take(limit).toList(),
      );
      final a = TableViewModel(
        rows: rows(10),
        totalCount: 40,
        keyField: 'id',
        columns: columns(),
        pageSize: 10,
        loadThreshold: 5,
        id: 'A',
        focused: true,
      )..viewport(rows: 5, cols: 2);
      // No threshold, so B's own viewport report asks for nothing: anything
      // B loads below can only have come from a result aimed at it.
      final b = TableViewModel(
        rows: rows(10),
        totalCount: 40,
        keyField: 'id',
        columns: columns(),
        pageSize: 10,
        loadThreshold: 0,
        id: 'B',
      )..viewport(rows: 5, cols: 2);
      final app = _TwoTables(a, b);

      // Drive A's cursor toward the end until it requests more data. The widget
      // marks its own forward slot loading as it emits the request.
      LoadRequest? request;
      for (var i = 0; i < 12 && request == null; i++) {
        if (a.update(keyMsg('down')) case Handled(cmd: final LoadRequest r)) {
          request = r;
        }
      }
      expect(request, isNotNull, reason: 'expected a load request near the end');
      final id = request!.id;
      expect(id, equals('A'));
      expect(a.isLoading(), isTrue, reason: 'the widget self-marks loading on emit');

      // The app turns the request into a fetch whose result carries the id and
      // the key home — which fetchInto does structurally, from the request.
      final task = fetchInto(request, srcA);

      final msg = (await (task as AsyncCmd).execute())! as LoadResult<Object?>;
      expect(msg.id, equals('A'));

      // On receipt, resolve home by id and deliver to update — only A is touched.
      final dest = app.resolve(msg.id)!;
      expect(dest, same(a));
      expect(dest.update(msg), isA<Handled>());

      expect(a.cachedRowCount, greaterThan(10));
      expect(a.isLoading(), isFalse);
      expect(b.cachedRowCount, equals(10), reason: 'sibling must be untouched');
      expect(b.isLoading(), isFalse);
    });

    test('a result whose id resolves to no owner is dropped and logged', () {
      final app = _TwoTables(table(id: 'A', focused: false), table(id: 'B', focused: false));
      final beforeA = app.a.cachedRowCount;
      final beforeB = app.b.cachedRowCount;

      // A result addressed to an instance that no longer exists (row deleted,
      // tab closed, list rebuilt) — exactly the orphan case references hid.
      final orphan = LoadResult<List<Map<String, Object?>>>('ghost', key: const PageKey(1), data: rows(3));
      final dest = app.resolve(orphan.id);
      dest?.update(orphan);

      expect(dest, isNull);
      expect(app.log, contains('dropped: no owner for id "ghost"'));
      // Nothing mutated — the drop is clean, not a write to the wrong instance.
      expect(app.a.cachedRowCount, equals(beforeA));
      expect(app.b.cachedRowCount, equals(beforeB));
    });
  });
}
