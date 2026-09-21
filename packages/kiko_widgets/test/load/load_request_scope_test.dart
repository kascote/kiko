import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Columns for a small paginated table.
List<TableColumn> _sampleColumns() => [
  TableColumn(field: 'id', label: Line('ID')),
  TableColumn(field: 'name', label: Line('Name')),
];

/// [count] rows for one page.
List<Map<String, Object?>> _sampleRows(int count) => List.generate(count, (i) => {'id': 'row$i', 'name': 'Name $i'});

/// A composite embedding one lazy [TableViewModel] part, the way a real pane
/// would: it forwards addressed traffic to the table named by
/// [HitTag.partOn] and scopes what comes back under its own id.
class _Pane implements Component {
  _Pane() : _table = TableViewModel(totalCount: 20, keyField: 'id', columns: _sampleColumns(), pageSize: 10);

  @override
  final String id = 'pane';

  final TableViewModel _table;

  /// The embedded table's own id, for assertions.
  String get tableId => _table.id;

  /// The pages the table currently holds.
  List<int> get cachedPages => _table.cachedPages;

  /// Whether the table's page 0 slot is loading.
  bool get tableLoadingPage0 => _table.isLoading(const PageKey(0));

  @override
  bool focused = false;

  /// Asks the table for its first page, scoped under this pane's id — the
  /// same path the pane's own [update] would carry a part's request out on.
  LoadRequest askFirstPage() {
    final scoped = Handled(events: [_table.loadFirstPage()]).scopeUnder(id) as Handled;
    return scoped.events.single as LoadRequest;
  }

  @override
  UpdateResult update(Msg msg) {
    if (msg case Addressed(id: final path) when HitTag.partOn(path, under: id, parts: {_table.id}) == _table.id) {
      return _table.update(msg).scopeUnder(id);
    }
    return const Declined();
  }
}

void main() {
  group('LoadRequest.scopeUnder', () {
    test('joins the id, keeps key and ticket, and is unequal to the original', () {
      final ticket = LoadTracker<PageKey>().begin(const PageKey(0));
      final request = LoadRequest('table', key: const PageKey(0), ticket: ticket);

      final scoped = request.scopeUnder('pane');

      expect(scoped.id, 'pane/table');
      expect(scoped.key, request.key);
      expect(scoped.ticket, same(request.ticket));
      expect(scoped, isNot(equals(request)));
    });
  });

  group('a Handled carrying a Tick and a LoadRequest', () {
    test('scopeUnder prefixes both', () {
      final ticket = LoadTracker<PageKey>().begin(const PageKey(0));
      final request = LoadRequest('table', key: const PageKey(0), ticket: ticket);
      final handled = Handled(
        events: [request],
        cmd: const Tick(Duration.zero, id: 'table'),
      );

      final scoped = handled.scopeUnder('pane') as Handled;

      expect((scoped.events.single as LoadRequest).id, 'pane/table');
      expect((scoped.cmd! as Tick).id, 'pane/table');
    });
  });

  group('a part scoped under a composite', () {
    test('the request leaves scoped, and its result installs the page in the part', () {
      final pane = _Pane();
      const ctx = UpdateContext(hits: HitMap.empty(), area: Rect.zero);
      final targets = <String, Component>{pane.id: pane};

      final request = pane.askFirstPage();
      expect(request.id, 'pane/${pane.tableId}');

      final result = LoadResult<List<Map<String, Object?>>>.ok(request, _sampleRows(10));
      final verdict = routeToTarget(result, ctx, targets);

      expect(verdict, isA<Handled>());
      expect(pane.cachedPages, contains(0));
      expect(pane.tableLoadingPage0, isFalse);
    });
  });
}
