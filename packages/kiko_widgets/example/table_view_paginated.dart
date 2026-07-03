// Paginated TableView with simulated API loading.
//
// Shows:
// - Custom TableDataSource for async pagination
// - LoadRequest / LoadResult handling for infinite scroll (forward + backward)
// - Sliding window (keeps windowSize rows in memory)
// - Loading state indicator
// - Total count as a benign one-shot

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA SOURCE
// ═══════════════════════════════════════════════════════════

/// Simulated API data source that loads pages of products.
class ProductApiDataSource implements TableDataSource {
  static const _totalProducts = 500;

  bool _hasMore = true;
  int? _totalCount;

  @override
  Future<List<Map<String, Object?>>> getPage(int pageNum, int pageSize) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final start = pageNum * pageSize;
    if (start >= _totalProducts) return [];

    final count = (start + pageSize > _totalProducts) ? _totalProducts - start : pageSize;

    final rows = <Map<String, Object?>>[];
    for (var i = 0; i < count; i++) {
      final n = start + i + 1;
      rows.add({
        'id': 'P${n.toString().padLeft(4, '0')}',
        'name': _productName(n),
        'category': _category(n),
        'price': _price(n),
        'stock': _stock(n),
      });
    }

    _hasMore = start + count < _totalProducts;
    return rows;
  }

  @override
  bool get hasMore => _hasMore;

  @override
  int? get totalCount => _totalCount;

  /// Simulates fetching total count.
  Future<int> fetchCount() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _totalCount = _totalProducts;
    return _totalProducts;
  }

  String _productName(int n) {
    final adjectives = ['Premium', 'Classic', 'Deluxe', 'Basic', 'Pro'];
    final nouns = ['Widget', 'Gadget', 'Tool', 'Device', 'Item'];
    return '${adjectives[n % adjectives.length]} ${nouns[(n ~/ 5) % nouns.length]} $n';
  }

  String _category(int n) {
    final cats = ['Electronics', 'Home', 'Office', 'Sports', 'Garden'];
    return cats[n % cats.length];
  }

  double _price(int n) => 9.99 + (n % 100) * 5.0;

  int _stock(int n) => (n * 7) % 500;
}

// ═══════════════════════════════════════════════════════════
// MESSAGES
// ═══════════════════════════════════════════════════════════

// Pages route home through the generic LoadResult; the only table-specific
// message left is the total count, a benign one-shot that is not a tracked load.
class CountLoadedMsg extends Msg {
  final String id;
  final int count;
  CountLoadedMsg(this.id, this.count);
}

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel with ThemeSwitcher {
  final dataSource = ProductApiDataSource();
  final defaultHeaderStyle = Style(fg: Color.white, addModifier: Modifier.bold | Modifier.italic);

  late final table = TableViewModel(
    dataSource: dataSource,
    keyField: 'id',
    columns: [
      TableColumn(
        field: 'id',
        label: Line('ID', style: defaultHeaderStyle),
        width: 8,
      ),
      TableColumn(
        field: 'name',
        label: Line('Product Name', style: defaultHeaderStyle),
        width: 25,
      ),
      TableColumn(
        field: 'category',
        label: Line('Category', style: defaultHeaderStyle),
        width: 14,
        render: (ctx) {
          final cat = ctx.value?.toString() ?? '';
          final color = switch (cat) {
            'Electronics' => Color.cyan,
            'Home' => Color.yellow,
            'Office' => Color.blue,
            'Sports' => Color.green,
            'Garden' => Color.magenta,
            _ => Color.white,
          };
          return Line.fromSpans([Span(cat, style: Style(fg: color))]);
        },
      ),
      TableColumn(
        field: 'price',
        label: Line('Price', style: defaultHeaderStyle),
        width: 10,
        alignment: Alignment.right,
        render: (ctx) {
          final price = ctx.value as double? ?? 0.0;
          return Line('\$${price.toStringAsFixed(2)}');
        },
      ),
      TableColumn(
        field: 'stock',
        label: Line('Stock', style: defaultHeaderStyle),
        width: 8,
        alignment: Alignment.right,
        render: (ctx) {
          final stock = ctx.value as int? ?? 0;
          final color = stock < 50
              ? Color.red
              : stock < 150
              ? Color.yellow
              : Color.green;
          return Line.fromSpans([Span(stock.toString(), style: Style(fg: color))]);
        },
      ),
    ],
    loadThreshold: 15,
    focused: true,
    loadingIndicator: Line.fromSpans(const [
      Span('Loading...', style: Style(fg: Color.yellow)),
    ]),
    emptyPlaceholder: Line('No products found', style: const Style(fg: Color.darkGray)),
  );

  String? error;
  bool initialized = false;
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING (one shape for the first page and each near-edge page)
// ═══════════════════════════════════════════════════════════

/// Turns a table [LoadRequest] into the page fetch that resolves it, routing the
/// outcome home as a [LoadResult] (rows on success, error on failure).
Cmd fetchPage(AppModel model, LoadRequest req) {
  final page = model.table.pendingPage(req.key! as TableLoadKey)!;
  return Task<List<Map<String, Object?>>>(
    () => model.dataSource.getPage(page, model.table.pageSize),
    onSuccess: (rows) => LoadResult<List<Map<String, Object?>>>(req.id, key: req.key, data: rows),
    onError: (e) => LoadResult<List<Map<String, Object?>>>(req.id, key: req.key, error: e),
  );
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Page results route home by id, then install generically — applyLoad clears
  // the slot on success or records the error on failure.
  if (msg case final LoadResult<Object?> r) {
    if (r.id == model.table.id) {
      model.table.applyLoad(r);
      model.error = r.ok ? null : 'Failed to load: ${r.error}';
    }
    return (model, null);
  }

  // Total count is a benign one-shot, not a tracked load — a missing count just
  // leaves the scrollbar indeterminate.
  if (msg is CountLoadedMsg) {
    if (msg.id == model.table.id) model.table.totalCount = msg.count;
    return (model, null);
  }

  // Kick off the first page and the count once.
  if (msg is InitMsg && !model.initialized) {
    model.initialized = true;
    return (
      model,
      Batch([
        fetchPage(model, model.table.loadFirstPage()),
        Task(
          model.dataSource.fetchCount,
          onSuccess: (count) => CountLoadedMsg(model.table.id, count),
          onError: (_) => const NoneMsg(),
        ),
      ]),
    );
  }

  // A near-edge navigation may request the next or previous page.
  final cmd = model.table.update(msg);
  if (cmd case final LoadRequest r when r.id == model.table.id) {
    return (model, fetchPage(model, r));
  }

  if (cmd is! Unhandled) return (model, cmd);

  // Quit
  if (msg case KeyMsg(:final key)) {
    if (key == 'escape' || key == 'ctrl+q') {
      return (model, const Quit());
    }
  }

  return (model, null);
}

// ═══════════════════════════════════════════════════════════
// VIEW
// ═══════════════════════════════════════════════════════════

void appView(AppModel model, Frame frame) {
  final theme = model.theme;
  frame.buffer.setStyle(frame.area, Style(bg: theme.background.bg));

  final table = model.table;

  // Table title with count
  final countStr = table.totalCount != null ? '${table.totalCount}' : '?';
  final titleText = 'Products ($countStr total, ${table.cachedRowCount} cached)';

  final loading = table.isLoading();

  final tableWidget = Block(
    borders: Borders.all,
    borderStyle: loading ? theme.warning : theme.focus,
    child: TableView(model: table, theme: theme),
  ).titleTop(Line(titleText, style: loading ? theme.warning : theme.focus));

  // Status
  final status = loading ? 'Loading...' : model.error ?? 'Ready';

  final statusBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.error != null
          ? theme.error
          : loading
          ? theme.warning
          : theme.success,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        status,
        style: Style(
          fg: model.error != null
              ? theme.error.fg
              : loading
              ? theme.warning.fg
              : theme.success.fg,
        ),
      ),
    ).titleTop(Line('Status')),
  );

  // Scroll position
  final scroll = table.getScrollState();
  final scrollInfo = scroll.total != null
      ? 'Row ${table.cursorRow + 1}/${scroll.total} | Window: ${table.loadedRange}'
      : 'Row ${table.cursorRow + 1}';

  final cursorInfo = 'Cell: ${table.cursorColField}';

  final help = Fixed(
    1,
    child: Row(
      children: [
        Expanded(
          child: Text.raw(
            '↑↓←→/hjkl nav | PgUp/PgDn | $scrollInfo | $cursorInfo | Esc quit',
            style: theme.muted,
          ),
        ),
        Fixed(25, child: themeIndicator(model)),
      ],
    ),
  );

  final ui = Block(
    child: Column(
      children: [
        Expanded(child: tableWidget),
        statusBox,
        help,
      ],
    ),
  ).titleTop(Line('Paginated TableView Demo', style: theme.muted));

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'Paginated TableView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
