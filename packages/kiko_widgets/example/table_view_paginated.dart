// Paginated TableView with simulated API loading.
//
// Shows:
// - Custom TableDataSource for async pagination
// - LoadPageCmd handling for infinite scroll
// - Sliding window (keeps windowSize rows in memory)
// - Loading state indicator
// - Total count fetching

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

class DataLoadedMsg extends Msg {
  final List<Map<String, Object?>> rows;
  final int pageNum;
  DataLoadedMsg(this.rows, this.pageNum);
}

class DataLoadErrorMsg extends Msg {
  final Object error;
  DataLoadErrorMsg(this.error);
}

class CountLoadedMsg extends Msg {
  final int count;
  CountLoadedMsg(this.count);
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
    emptyPlaceholder: Text.raw(
      'No products found',
      style: const Style(fg: Color.darkGray),
    ),
  );

  String? error;
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Initial load on startup
  if (msg is InitMsg) {
    model.table.isLoading = true;
    return (
      model,
      Batch([
        // Fetch total count
        Task(
          model.dataSource.fetchCount,
          onSuccess: CountLoadedMsg.new,
          onError: DataLoadErrorMsg.new,
        ),
        // Load first page
        Task(
          () => model.dataSource.getPage(0, model.table.pageSize),
          onSuccess: (rows) => DataLoadedMsg(rows, 0),
          onError: DataLoadErrorMsg.new,
        ),
      ]),
    );
  }

  // Handle count loaded
  if (msg is CountLoadedMsg) {
    model.table.totalCount = msg.count;
    return (model, null);
  }

  // Handle data loaded
  if (msg is DataLoadedMsg) {
    model.table
      ..insertRows(msg.rows, msg.pageNum)
      ..isLoading = false;
    model.error = null;
    return (model, null);
  }

  // Handle error
  if (msg is DataLoadErrorMsg) {
    model.table.isLoading = false;
    model.error = 'Failed to load: ${msg.error}';
    return (model, null);
  }

  // Route to table
  final cmd = model.table.update(msg);

  // Handle load page command
  if (cmd case TableLoadMoreCmd(:final source, :final direction)) {
    if (source == model.table && !model.table.isLoading) {
      model.table.isLoading = true;
      final pageNum = direction == LoadDirection.forward ? model.table.nextPageNum : model.table.prevPageNum;

      if (pageNum < 0) {
        model.table.isLoading = false;
        return (model, null);
      }

      return (
        model,
        Task(
          () => model.dataSource.getPage(pageNum, model.table.pageSize),
          onSuccess: (rows) => DataLoadedMsg(rows, pageNum),
          onError: DataLoadErrorMsg.new,
        ),
      );
    }
    return (model, null);
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

  final tableWidget = Block(
    borders: Borders.all,
    borderStyle: table.isLoading ? theme.warning : theme.focus,
    child: TableView(model: table, theme: theme),
  ).titleTop(Line(titleText, style: table.isLoading ? theme.warning : theme.focus));

  // Status
  final status = table.isLoading ? 'Loading...' : model.error ?? 'Ready';

  final statusBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: model.error != null
          ? theme.error
          : table.isLoading
          ? theme.warning
          : theme.success,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        status,
        style: Style(
          fg: model.error != null
              ? theme.error.fg
              : table.isLoading
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
