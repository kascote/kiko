// Paginated TableView with simulated API loading.
//
// Shows:
// - A PageSource over a simulated offset API, fetched with the fetchInto helper
// - LoadRequest / LoadResult handling, keyed by page number
// - A demand pass that may ask for several pages at once (flattened by the app)
// - The frame-tick demand case that picks up what a resize reveals
// - Sliding window (keeps the pages around the viewport, plus keepPages more)
// - Loading state indicator
// - Total count as a deliberate one-shot
// - A policy gate that refuses requests and re-triggers demand when it lifts
// - Click-to-select, wheel-scroll, per-row hover; scrolling near the edge
//   pages the next/previous batch in, same as cursor nav

import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

import 'shared/theme_switcher.dart';

// ═══════════════════════════════════════════════════════════
// DATA SOURCE
// ═══════════════════════════════════════════════════════════

/// A simulated product API: an offset-and-limit endpoint with a slow round
/// trip, plus a separate count query.
///
/// This is app code — the shape a real REST or SQL backend has. Kiko only sees
/// it through the [PageSource] adapter below.
class ProductApi {
  static const _totalProducts = 500;

  /// The rows at `[offset, offset + limit)`, after a simulated network delay.
  Future<List<Map<String, Object?>>> read(int offset, int limit) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (offset >= _totalProducts) return [];
    final count = (offset + limit > _totalProducts) ? _totalProducts - offset : limit;

    return [
      for (var i = 0; i < count; i++)
        if (offset + i + 1 case final n)
          {
            'id': 'P${n.toString().padLeft(4, '0')}',
            'name': _productName(n),
            'category': _category(n),
            'price': _price(n),
            'stock': _stock(n),
          },
    ];
  }

  /// Simulates fetching total count.
  Future<int> fetchCount() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
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
  final api = ProductApi();

  /// The one page size in the app: the table windows over what the source ships.
  late final PageSource<Map<String, Object?>> source = PageSource.offset<Map<String, Object?>>(
    pageSize: 50,
    read: api.read,
  );
  final defaultHeaderStyle = Style(fg: Color.white, addModifier: Modifier.bold | Modifier.italic);

  late final table = TableViewModel(
    pageSize: source.pageSize,
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
          return Line.fromTexts([Text(cat, style: Style(fg: color))]);
        },
      ),
      TableColumn(
        field: 'price',
        label: Line('Price', style: defaultHeaderStyle),
        width: 10,
        alignment: TextAlign.end,
        render: (ctx) {
          final price = ctx.value as double? ?? 0.0;
          return Line('\$${price.toStringAsFixed(2)}');
        },
      ),
      TableColumn(
        field: 'stock',
        label: Line('Stock', style: defaultHeaderStyle),
        width: 8,
        alignment: TextAlign.end,
        render: (ctx) {
          final stock = ctx.value as int? ?? 0;
          final color = stock < 50
              ? Color.red
              : stock < 150
              ? Color.yellow
              : Color.green;
          return Line.fromTexts([Text(stock.toString(), style: Style(fg: color))]);
        },
      ),
    ],
    loadThreshold: 15,
    focused: true,
    loadingIndicator: Line.fromTexts(const [
      Text('Loading...', style: Style(fg: Color.yellow)),
    ]),
    emptyPlaceholder: Line('No products found', style: const Style(fg: Color.darkGray)),
  );

  String? error;
  bool initialized = false;

  /// A stand-in for an app-owned policy gate — "do not fetch while a sync is
  /// running". While it is closed every request is refused rather than fetched,
  /// and nothing paints an error: the pages keep their placeholders and are
  /// asked for again once it opens.
  bool paused = false;
}

// ═══════════════════════════════════════════════════════════
// LOAD PLUMBING (one shape for the first page and each near-edge page)
// ═══════════════════════════════════════════════════════════

/// One request, one fetch — explicit cases, read top to bottom.
///
/// [fetchInto] threads the request's id and key into the result, so a page can
/// only ever land on the widget that asked for it, and turns a read that throws
/// into a failed load rather than a page stuck loading forever.
Cmd fetchFor(AppModel model, LoadRequest req) {
  if (req.id == model.table.id) {
    // Policy, where a reader would look for it. A refusal resolves the page
    // without fetching and without failing it, so the table asks again later.
    if (model.paused) return declineLoad(req);
    return fetchInto(req, model.source);
  }
  // Nothing is wired to answer this one, which is a bug rather than a policy:
  // it resolves as a failure, so the widget shows it instead of a placeholder
  // nobody will ever fill.
  return declineLoad(req, error: 'no source wired for ${req.id}');
}

/// One demand pass can ask for several pages at once, so the app flattens
/// whatever the table returned and fetches each request.
Cmd? fetchAll(AppModel model, Cmd? cmd) {
  final requests = switch (cmd) {
    final LoadRequest r => [r],
    Batch(:final cmds) => cmds.whereType<LoadRequest>().toList(),
    _ => const <LoadRequest>[],
  };
  if (requests.isEmpty) return cmd;
  return Batch([for (final r in requests) fetchFor(model, r)]);
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg, UpdateContext _) {
  if (model.handleThemeSwitch(msg)) return (model, null);

  // Page results route home by id, then install generically — applyLoad clears
  // the slot on success or records the error on failure.
  if (msg case final LoadResult<Object?> r) {
    if (r.id == model.table.id) {
      model.table.applyLoad(r);
      // `ok` is false for a refusal as well as a failure, so check `cancelled`
      // first: a page this app declined on policy grounds did not fail, and
      // reporting it as an error would be a lie the user has to dismiss.
      if (!r.cancelled) model.error = r.ok ? null : 'Failed to load: ${r.error}';
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
        fetchFor(model, model.table.loadFirstPage()),
        // The count arrives as a benign one-shot; the table uses it to know how
        // far it can jump and which pages exist.
        Task(
          model.api.fetchCount,
          onSuccess: (count) => CountLoadedMsg(model.table.id, count),
          onError: (_) => const NoneMsg(),
        ),
      ]),
    );
  }

  // A pointer only reaches the table when it's actually the target — a click
  // on unrelated chrome (the status box, the help row) has a different
  // target (or none) and must not be treated as a click on the table.
  if (msg case Routed(:final targetId) when targetId != model.table.id) {
    return (model, null);
  }

  // A resize reveals rows through the paint path, where the table cannot return
  // a command, and a page landing can free a slot the in-flight cap truncated.
  // One case on the frame tick covers both.
  if (msg is FrameTickMsg) {
    return (model, fetchAll(model, model.table.demandIfDirty()));
  }

  // Navigation runs a demand pass, which may ask for one page or several.
  final result = model.table.update(msg);

  switch (result) {
    case Handled(:final cmd):
      return (model, fetchAll(model, cmd));
    case Declined():
      break;
  }

  if (msg case KeyMsg(:final key)) {
    // Open and close the policy gate. Closing it needs nothing: the next
    // request is simply refused. Opening it does — a refusal deliberately never
    // re-triggers demand, or a standing refusal would become a request storm —
    // so the app pokes the model, and the frame-tick demand case above picks
    // it up.
    if (key == 'p') {
      model.paused = !model.paused;
      if (!model.paused) model.table.markDemandDirty();
      return (model, null);
    }
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
  final resolver = StyleResolver(theme);
  final t = resolver.tones;
  frame.buffer.setStyle(frame.area, resolver.ground(resolver.tones.background));

  final table = model.table;

  // Table title with count
  final countStr = table.totalCount != null ? '${table.totalCount}' : '?';
  final titleText = 'Products ($countStr total, ${table.cachedRowCount} cached)';

  final loading = table.isLoading();

  // The pane rests on `focused`; a load in flight tints it with `loading`
  // layered on top, rather than replacing the focus look outright.
  final paneBorder = StyleResolver(theme).border({WidgetState.focused, if (loading) WidgetState.loading});

  final tableWidget = Container(
    border: BorderType.plain,
    borderStyle: paneBorder,
    topTitles: [Line(titleText, style: paneBorder)],
    child: TableView(
      model: table,
      theme: theme,
    ),
  );

  // Status
  final status = model.paused
      ? 'Paused — loads refused (p to resume)'
      : loading
      ? 'Loading...'
      : model.error ?? 'Ready';

  final statusTone = model.error != null
      ? t.error
      : loading
      ? t.warning
      : t.success;
  final statusBox = ConstrainedBox(
    additionalConstraints: const BoxConstraints(minH: 3, maxH: 3),
    child: Container(
      border: BorderType.plain,
      borderStyle: resolver.ink(statusTone),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      topTitles: [Line('Status')],
      child: Line(
        status,
        style: resolver.ink(statusTone),
      ),
    ),
  );

  // Scroll position
  final scroll = table.getScrollState();
  final scrollInfo = scroll.total != null
      ? 'Row ${table.cursorRow + 1}/${scroll.total} | Pages: ${table.cachedPages}'
      : 'Row ${table.cursorRow + 1}';

  final cursorInfo = 'Cell: ${table.cursorColField}';

  final help = Row(
    children: [
      Expanded(
        child: Line(
          '↑↓←→/hjkl/click nav | PgUp/PgDn/wheel page | p pause loads | $scrollInfo | $cursorInfo | Esc quit',
          style: resolver.ink(t.muted),
        ),
      ),
      ConstrainedBox(
        additionalConstraints: const BoxConstraints(minW: 25, maxW: 25),
        child: Line('Theme: ${model.themeName} (F1/F2)', style: resolver.ink(t.muted)),
      ),
    ],
  );

  final ui = Container(
    topTitles: [Line('Paginated TableView Demo', style: resolver.ink(t.muted))],
    child: Column(
      crossAxis: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: tableWidget),
        statusBox,
        help,
      ],
    ),
  );

  frame.render(ui);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

Future<void> main() async {
  exit(
    await Application(title: 'Paginated TableView Demo', mouseEvents: true).run(
      init: AppModel(),
      update: appUpdate,
      view: appView,
    ),
  );
}
