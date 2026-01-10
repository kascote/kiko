// Simple TableView example with static data.
//
// Shows:
// - Basic setup with TableDataSource.fromList()
// - Column definitions with width/alignment
// - Cell-level cursor navigation (arrows, h/j/k/l)
// - Row selection (space)
// - Confirm action (Enter)

import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';

// ═══════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════

final List<Map<String, Object?>> employees = [
  {'id': '1', 'name': 'Alice Johnson', 'dept': 'Engineering', 'salary': 95000},
  {'id': '2', 'name': 'Bob Smith', 'dept': 'Marketing', 'salary': 72000},
  {'id': '3', 'name': 'Carol White', 'dept': 'Engineering', 'salary': 88000},
  {'id': '4', 'name': 'David Brown', 'dept': 'Sales', 'salary': 65000},
  {'id': '5', 'name': 'Eva Martinez', 'dept': 'Engineering', 'salary': 102000},
  {'id': '6', 'name': 'Frank Lee', 'dept': 'Marketing', 'salary': 78000},
  {'id': '7', 'name': 'Grace Kim', 'dept': 'Sales', 'salary': 71000},
  {'id': '8', 'name': 'Henry Chen', 'dept': 'Engineering', 'salary': 92000},
  {'id': '9', 'name': 'Iris Davis', 'dept': 'HR', 'salary': 68000},
  {'id': '10', 'name': 'Jack Wilson', 'dept': 'Engineering', 'salary': 115000},
  {'id': '11', 'name': 'Karen Taylor', 'dept': 'Marketing', 'salary': 82000},
  {'id': '12', 'name': 'Leo Garcia', 'dept': 'Sales', 'salary': 69000},
  {'id': '13', 'name': 'Maya Patel', 'dept': 'Engineering', 'salary': 98000},
  {'id': '14', 'name': 'Nick Adams', 'dept': 'HR', 'salary': 62000},
  {'id': '15', 'name': 'Olivia Moore', 'dept': 'Engineering', 'salary': 105000},
];

// ═══════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════

class AppModel {
  final defaultHeaderStyle = const Style(fg: Color.white, bg: Color.darkGray, addModifier: Modifier.bold);

  late final table = TableViewModel(
    dataSource: TableDataSource.fromList(employees),
    keyField: 'id',
    columns: [
      TableColumn(
        field: 'id',
        label: Line('ID', style: defaultHeaderStyle),
        width: 6,
        alignment: Alignment.right,
      ),
      TableColumn(
        field: 'name',
        label: Line('Name', style: defaultHeaderStyle),
      ),
      TableColumn(
        field: 'dept',
        label: Line('Department', style: defaultHeaderStyle),
        width: 15,
        render: (ctx) {
          final dept = ctx.value?.toString() ?? '';
          final color = switch (dept) {
            'Engineering' => Color.cyan,
            'Marketing' => Color.magenta,
            'Sales' => Color.green,
            'HR' => Color.yellow,
            _ => Color.white,
          };
          return Line.fromSpans([Span(dept, style: Style(fg: color))]);
        },
      ),
      TableColumn(
        field: 'salary',
        label: Line('Salary', style: defaultHeaderStyle),
        width: 12,
        alignment: Alignment.right,
        render: (ctx) {
          final salary = ctx.value as int? ?? 0;
          final formatted = '\$${_formatNumber(salary)}';
          return Line(formatted);
        },
      ),
    ],
    selectionEnabled: true,
    focused: true,
    hoverStyle: const Style(bg: Color.blue),
    selectedStyle: const Style(bg: Color.green),
    columnHighlight: const Style(bg: Color.cyan, fg: Color.black),
  );

  String? confirmedCell;
}

String _formatNumber(int n) {
  final str = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

// ═══════════════════════════════════════════════════════════
// UPDATE
// ═══════════════════════════════════════════════════════════

(AppModel, Cmd?) appUpdate(AppModel model, Msg msg) {
  // Initial data load
  if (msg is InitMsg) {
    // Load first page synchronously (fromList returns immediately)
    model.table.insertRows(employees, 0);
    return (model, null);
  }

  final cmd = model.table.update(msg);

  // Handle confirm
  if (cmd case TableActionCmd(:final source, action: 'primary')) {
    if (source == model.table) {
      final row = model.table.cursorRowData;
      final field = model.table.cursorColField;
      final value = model.table.cursorCellValue;
      model.confirmedCell = '$field: $value (row ${row?['id']})';
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
  final tableWidget = Block(
    borders: Borders.all,
    borderStyle: const Style(fg: Color.green),
    child: TableView(model: model.table),
  ).titleTop(Line('Employees (${employees.length})'));

  // Selected rows info
  final selectedCount = model.table.selectedKeys.length;
  final selectedInfo = selectedCount > 0
      ? 'Selected: $selectedCount rows (${model.table.selectedKeys.join(", ")})'
      : 'No rows selected';

  final selectedBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: Style(fg: selectedCount > 0 ? Color.green : Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        selectedInfo,
        style: Style(fg: selectedCount > 0 ? Color.white : Color.darkGray),
      ),
    ).titleTop(Line('Selection')),
  );

  // Confirmed cell info
  final confirmedBox = Fixed(
    3,
    child: Block(
      borders: Borders.all,
      borderStyle: Style(fg: model.confirmedCell != null ? Color.cyan : Color.darkGray),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text.raw(
        model.confirmedCell ?? 'Press Enter to confirm cell',
        style: Style(fg: model.confirmedCell != null ? Color.cyan : Color.darkGray),
      ),
    ).titleTop(Line('Confirmed')),
  );

  final help = Fixed(
    1,
    child: Text.raw(
      '↑↓←→/hjkl nav | Space select | Enter confirm | Esc quit',
      alignment: Alignment.center,
      style: const Style(fg: Color.darkGray),
    ),
  );

  final ui = Block(
    child: Column(
      children: [
        Expanded(child: tableWidget),
        selectedBox,
        confirmedBox,
        help,
      ],
    ),
  ).titleTop(Line('TableView Demo', style: const Style(fg: Color.darkGray)));

  frame.renderWidget(ui, frame.area);
}

// ═══════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════

void main() async {
  await Application(title: 'TableView Demo').run(
    init: AppModel(),
    update: appUpdate,
    view: appView,
  );
}
