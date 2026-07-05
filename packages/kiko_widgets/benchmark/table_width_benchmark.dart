// Is `widthString` hot on the table render path?
//
// Ground truth is the *real* production frame: `Frame.render(TableView(...))` —
// view.build() → paint into a Buffer, including the table renderer's own
// `_truncateLine`/`_alignLine` width work and the plume paint path.
//
// There are two distinct width-measuring call patterns in one frame, and
// neither is swappable by injecting a measurer (the table body's `paintLine`
// hardcodes its own `TermUnicodeMeasurer`, ignoring the frame's), so we isolate
// each at its true per-frame volume and compare to the ground-truth frame:
//
//   A. whole-string (kiko truncate/align): widthString(cell) — every label +
//      cell, measured twice (truncate, then align).
//   B. per-grapheme (plume paintRuns→clusterRuns): widthString(grapheme) for
//      every grapheme of every painted cell, once.
//
// Each isolated pattern is timed raw and with a content-keyed memo (the cache
// we debated), so total width cost and the achievable saving both fall out.
//
// Run:  dart run benchmark/table_width_benchmark.dart

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:characters/characters.dart';
import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termunicode/termunicode.dart';

// ── Scenario: a wide terminal showing a full viewport of a data table ────────
const int kCols = 6;
const int kAreaWidth = 132;
const int kAreaHeight = 41; // 1 sticky header + 40 data rows
const int kVisibleRows = kAreaHeight - 1;
const int kFrameBudgetUs = 16667; // 60fps

/// Deterministic realistic cell data — names, emails, statuses, money, plus a
/// fair sprinkling of wide (CJK/emoji) glyphs so the wide-width path is exercised.
List<Map<String, Object?>> buildRows(int n) {
  const first = ['Ada', 'Grace', 'Alan', 'Linus', '田中', 'Katherine', 'Dennis', '李'];
  const last = ['Lovelace', 'Hopper', 'Turing', 'Torvalds', '太郎', 'Johnson', 'Ritchie', '明'];
  const statuses = ['✅ Active', 'Pending', '⏸ Paused', 'Archived', 'Active'];
  return List.generate(n, (i) {
    final f = first[i % first.length];
    final l = last[(i * 3) % last.length];
    return <String, Object?>{
      'id': 1000 + i,
      'name': '$f $l',
      'email': '${f.toLowerCase()}.${l.toLowerCase()}@example.com',
      'status': statuses[i % statuses.length],
      'updated': '2026-07-${(i % 28) + 1} ${i % 24}:${i % 60}',
      'amount': '\$${(i * 137 % 100000) / 100}',
    };
  });
}

List<TableColumn> buildColumns() => <TableColumn>[
      TableColumn(field: 'id', label: Line('ID'), width: 6, alignment: TextAlign.end),
      TableColumn(field: 'name', label: Line('Name'), width: 22),
      TableColumn(field: 'email', label: Line('Email'), width: 28),
      // A styled render callback — realistic (colored status pill).
      TableColumn(
        field: 'status',
        label: Line('Status'),
        width: 12,
        render: (ctx) => Line.fromTexts([Text('${ctx.value}', style: const Style(fg: Color.green))]),
      ),
      TableColumn(field: 'updated', label: Line('Updated'), width: 16),
      TableColumn(field: 'amount', label: Line('Amount'), width: 14, alignment: TextAlign.end),
    ];

TableViewModel buildModel() => TableViewModel(
      dataSource: TableDataSource.fromList(const []),
      keyField: 'id',
      columns: buildColumns(),
    )..insertRows(buildRows(kVisibleRows + 10), 0);

/// Every whole-string `widthString` argument one frame of the table produces on
/// the kiko side (labels + each visible cell's rendered text). Drives pattern A.
List<String> frameWholeStrings() {
  final rows = buildRows(kVisibleRows);
  final out = <String>['ID', 'Name', 'Email', 'Status', 'Updated', 'Amount'];
  for (final r in rows) {
    out
      ..add('${r['id']}')
      ..add('${r['name']}')
      ..add('${r['email']}')
      ..add('${r['status']}')
      ..add('${r['updated']}')
      ..add('${r['amount']}');
  }
  return out;
}

/// Every grapheme plume measures once while painting those same strings
/// (`clusterRuns` calls `widthOf` per cluster). Drives pattern B.
List<String> frameGraphemes() =>
    [for (final s in frameWholeStrings()) ...s.characters];

// ── Ground-truth frame benchmark (one real frame per run) ────────────────────

class FrameBenchmark extends BenchmarkBase {
  final TableViewModel model;
  final Rect area;
  late Buffer buffer;
  FrameBenchmark(super.name)
      : model = buildModel(),
        area = Rect.create(x: 0, y: 0, width: kAreaWidth, height: kAreaHeight);

  @override
  void setup() => buffer = Buffer.empty(area);

  @override
  void exercise() => run(); // one frame per measured op

  @override
  void run() => Frame(area, buffer, 0).render(TableView(model: model, theme: Theme.dark));
}

// ── Isolated width-measuring benchmarks ──────────────────────────────────────

/// Pattern A: whole-string widthString, each string measured twice (truncate +
/// align), raw or content-keyed-memoized.
class WholeStringBenchmark extends BenchmarkBase {
  final bool cached;
  final List<String> strings = frameWholeStrings();
  final Map<String, int> memo = {};
  WholeStringBenchmark({required this.cached})
      : super('wholeString ${cached ? "memo" : "raw "} (kiko truncate/align)');
  @override
  void exercise() => run();
  @override
  void run() {
    var sink = 0;
    for (var pass = 0; pass < 2; pass++) {
      for (final s in strings) {
        sink += cached ? (memo[s] ??= widthString(s)) : widthString(s);
      }
    }
    if (sink < 0) throw StateError('unreachable');
  }
}

/// Pattern B: per-grapheme widthString, each grapheme measured once, raw or
/// grapheme-keyed-memoized (the "cache in the measurer" option).
class GraphemeBenchmark extends BenchmarkBase {
  final bool cached;
  final List<String> graphemes = frameGraphemes();
  final Map<String, int> memo = {};
  GraphemeBenchmark({required this.cached})
      : super('grapheme    ${cached ? "memo" : "raw "} (plume clusterRuns)');
  @override
  void exercise() => run();
  @override
  void run() {
    var sink = 0;
    for (final g in graphemes) {
      sink += cached ? (memo[g] ??= widthString(g)) : widthString(g);
    }
    if (sink < 0) throw StateError('unreachable');
  }
}

void main() {
  final wholeCount = frameWholeStrings().length;
  final graphemeCount = frameGraphemes().length;

  final us = <String, double>{};
  double bench(BenchmarkBase b) => us[b.name] = b.measure();

  final frame = bench(FrameBenchmark('fullFrameReal'));
  final wholeRaw = bench(WholeStringBenchmark(cached: false));
  final wholeMemo = bench(WholeStringBenchmark(cached: true));
  final graphRaw = bench(GraphemeBenchmark(cached: false));
  final graphMemo = bench(GraphemeBenchmark(cached: true));

  final widthRaw = wholeRaw + graphRaw;
  final widthMemo = wholeMemo + graphMemo;

  String u(double v) => '${v.toStringAsFixed(1)}µs';
  String budget(double v) => '${(v / kFrameBudgetUs * 100).toStringAsFixed(3)}% of budget';
  String frameShare(double v) => '${(v / frame * 100).toStringAsFixed(1)}% of frame';

  // Benchmark output; a plain print is the whole point of this script.
  // ignore: avoid_print
  print('''

════════════════════════════════════════════════════════════════════════
 Table render — is widthString hot?
 Scenario: $kAreaWidth×$kAreaHeight, $kCols cols, $kVisibleRows visible rows, real cell data
 60fps frame budget: $kFrameBudgetUsµs
 Per-frame width calls: $wholeCount whole-strings ×2  +  $graphemeCount graphemes ×1
────────────────────────────────────────────────────────────────────────
 GROUND TRUTH — one real frame (view→layout→paint):
   fullFrameReal ............ ${u(frame)}   (${budget(frame)})

 ISOLATED width work, at true per-frame volume:
   A whole-string  raw ...... ${u(wholeRaw)}   (${budget(wholeRaw)})
   A whole-string  memo ..... ${u(wholeMemo)}
   B grapheme      raw ...... ${u(graphRaw)}   (${budget(graphRaw)})
   B grapheme      memo ..... ${u(graphMemo)}

 TOTAL width work per frame:
   raw ...................... ${u(widthRaw)}   (${frameShare(widthRaw)}, ${budget(widthRaw)})
   content-keyed cache ...... ${u(widthMemo)}   (${frameShare(widthMemo)})
   cache saves .............. ${u(widthRaw - widthMemo)}  (${frameShare(widthRaw - widthMemo)}, ${budget(widthRaw - widthMemo)})
════════════════════════════════════════════════════════════════════════
''');
}
