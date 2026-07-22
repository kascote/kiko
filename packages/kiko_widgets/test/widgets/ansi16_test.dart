import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// End-to-end ANSI-16 wiring: prove that `StyleResolver.defaultPolicy` (the
/// process-wide flag the Application sets from the terminal profile) actually
/// reaches the resolvers each widget builds internally, so a state that would
/// paint a full-RGB surface instead paints Theme.dark's hand-authored
/// `tones16` pair. The per-projection matrix itself is proven in kiko_core's
/// style_resolver_ansi16_test.
void main() {
  setUp(() => StyleResolver.defaultPolicy = RenderPolicy.ansi16);
  tearDown(() => StyleResolver.defaultPolicy = RenderPolicy.color);

  final tones = Theme.dark.tones16!;

  Buffer canvas(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

  group('ANSI-16 degrades widget surfaces to the named tones16 pair', () {
    test('ListView cursor row', () {
      final model = ListViewModel<String, String>(
        dataView: DataView.fromList<String>(<String>['Apple', 'Banana']),
        focused: true,
      );
      final buffer = canvas(8, 2);
      Frame(buffer.area, buffer, 0).render(
        ListView<String, String>(model: model, theme: Theme.dark, itemBuilder: (i, n, s) => [Line(i)]),
      );
      final cell = buffer[(x: 7, y: 0)]; // cursor row, trailing fill-only cell
      expect(cell.fg, equals(tones.cursor.on));
      expect(cell.bg, equals(tones.cursor.color));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('TreeView cursor node', () {
      final model = TreeViewModel<String>(focused: true)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Alpha'), isLeaf: true)]);
      final buffer = canvas(10, 2);
      Frame(buffer.area, buffer, 0).render(TreeView<String>(model: model, theme: Theme.dark));
      final cell = buffer[(x: 9, y: 0)];
      expect(cell.fg, equals(tones.cursor.on));
      expect(cell.bg, equals(tones.cursor.color));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('Button focused face', () {
      final buffer = canvas(4, 1);
      Frame(buffer.area, buffer, 0).render(
        Button(
          model: ButtonModel(id: 'ok', label: Line('OK'), focused: true),
          theme: Theme.dark,
        ),
      );
      final cell = buffer[(x: 0, y: 0)]; // left padding, part of the button face
      // The resting face is an explicit theme.primary.fill the caller
      // supplies directly (not a resolver projection), so it keeps its raw
      // RGB regardless of policy — same as the NO_COLOR suite's note. The
      // focused STATE contribution, though, comes from the resolver's state
      // matrix, so it paints through the named tones16.focus pair.
      expect(cell.fg, equals(tones.focus.on));
      expect(cell.bg, equals(tones.focus.color));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('TableView cursor cell', () {
      final rows = List.generate(3, (i) => <String, Object?>{'id': 'r$i', 'a': 'v$i'});
      final model = TableViewModel(
        dataSource: TableDataSource.fromList(rows),
        keyField: 'id',
        columns: [TableColumn(field: 'a', label: Line('A'), width: 5)],
        focused: true,
      )..insertRows(rows, 0);
      final buffer = canvas(5, 3);
      TableRenderer(model, Theme.dark, null).paint(buffer.area, BufferSurface(buffer));
      final cell = buffer[(x: 0, y: 1)]; // cursor cell (row 0 under the sticky header)
      expect(cell.fg, equals(tones.cursor.on));
      expect(cell.bg, equals(tones.cursor.color));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('TableView crosshair: row and column cells keep their own colors, only the cursor cell '
        'paints the named pair', () {
      final rows = List.generate(3, (i) => <String, Object?>{'id': 'r$i', 'a': 'v$i', 'b': 'w$i'});
      final model = TableViewModel(
        dataSource: TableDataSource.fromList(rows),
        keyField: 'id',
        columns: [
          TableColumn(field: 'a', label: Line('A'), width: 3),
          TableColumn(field: 'b', label: Line('B'), width: 3),
        ],
        focused: true,
        showCrosshair: true,
      )..insertRows(rows, 0);
      // cursorRow == 0, cursorCol == 0 (fresh model, per insertRows).
      final buffer = canvas(7, 4); // header + 3 rows; col a (0-2), sep (3), col b (4-6)
      TableRenderer(model, Theme.dark, null).paint(buffer.area, BufferSurface(buffer));

      final cursorCell = buffer[(x: 0, y: 1)]; // row 0, col a — the exact cursor cell
      expect(cursorCell.fg, equals(tones.cursor.on));
      expect(cursorCell.bg, equals(tones.cursor.color));
      expect(cursorCell.modifier.has(Modifier.bold), isTrue);

      final crosshairRowOnly = buffer[(x: 4, y: 1)]; // row 0, col b — cursor row, not cursor column
      expect(crosshairRowOnly.bg, equals(Color.reset), reason: 'the row wash drops under ansi16 — no bleed');
      expect(crosshairRowOnly.modifier.has(Modifier.bold), isFalse);

      final crosshairColumnOnly = buffer[(x: 0, y: 2)]; // row 1, col a — cursor column, not cursor row
      expect(crosshairColumnOnly.bg, equals(Color.reset), reason: 'the column wash drops under ansi16 too');
      expect(crosshairColumnOnly.modifier.has(Modifier.bold), isFalse);
    });
  });
}
