import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// End-to-end ANSI-16 wiring: prove that `StyleResolver.defaultPolicy` (the
/// process-wide flag the Application sets from the terminal profile) actually
/// reaches the resolvers each widget builds internally, so a state that would
/// paint a full-RGB surface instead paints the pair derived from Theme.dark
/// (`Ansi16Tones.derive`), lifted to its bright variant. The per-projection
/// matrix itself is proven in kiko_core's style_resolver_ansi16_test.
void main() {
  late StyleResolver resolver;
  setUp(() {
    StyleResolver.defaultPolicy = RenderPolicy.ansi16;
    resolver = StyleResolver(Theme.dark);
  });
  tearDown(() => StyleResolver.defaultPolicy = RenderPolicy.color);

  final tones = Ansi16Tones.derive(Theme.dark);

  // A cursor row with a bare base lifts the ground one step: the bright
  // variant of the background slot. The row keeps the terminal's own text
  // color, because the ansi16 ground projection sets no background.
  final cursorBg = tones.background.color!.lighten(Theme.step);

  Buffer canvas(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

  group('ANSI-16 degrades widget surfaces to the derived named pair, lifted to its bright variant', () {
    test('ListView cursor row', () {
      final model = ListViewModel<String, String>(
        items: const <String>['Apple', 'Banana'],
        focused: true,
      );
      final buffer = canvas(8, 2);
      Frame(buffer.area, buffer, 0).render(
        ListView<String, String>(model: model, resolver: resolver, itemBuilder: (i, n, s) => [Line(i)]),
      );
      final cell = buffer[(x: 7, y: 0)]; // cursor row, trailing fill-only cell
      expect(cell.fg, equals(Color.reset));
      expect(cell.bg, equals(cursorBg));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('TreeView cursor node', () {
      final model = TreeViewModel<String>(focused: true)
        ..loadRoots()
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Alpha'), isLeaf: true)]);
      final buffer = canvas(10, 2);
      Frame(buffer.area, buffer, 0).render(TreeView<String>(model: model, resolver: resolver));
      final cell = buffer[(x: 9, y: 0)];
      expect(cell.fg, equals(Color.reset));
      expect(cell.bg, equals(cursorBg));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('Button focused face', () {
      final buffer = canvas(4, 1);
      Frame(buffer.area, buffer, 0).render(
        Button(
          model: ButtonModel(id: 'ok', label: Line('OK'), focused: true),
          resolver: resolver,
        ),
      );
      final cell = buffer[(x: 0, y: 0)]; // left padding, part of the button face
      // The resting face is the named primary pair; focus lifts it to the
      // bright variant and adds bold.
      expect(cell.fg, equals(tones.primary.on));
      expect(cell.bg, equals(tones.primary.color!.lighten(Theme.step)));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('TableView cursor cell', () {
      final rows = List.generate(3, (i) => <String, Object?>{'id': 'r$i', 'a': 'v$i'});
      final model = TableViewModel(
        rows: rows,
        keyField: 'id',
        columns: [TableColumn(field: 'a', label: Line('A'), width: 5)],
        focused: true,
      );
      final buffer = canvas(5, 3);
      TableRenderer(model, resolver).paint(buffer.area, BufferSurface(buffer));
      final cell = buffer[(x: 0, y: 1)]; // cursor cell (row 0 under the sticky header)
      expect(cell.fg, equals(Color.reset));
      expect(cell.bg, equals(cursorBg));
      expect(cell.modifier.has(Modifier.bold), isTrue);
    });

    test('TableView crosshair: row and column cells take the lifted ground, only the cursor cell is bold', () {
      final rows = List.generate(3, (i) => <String, Object?>{'id': 'r$i', 'a': 'v$i', 'b': 'w$i'});
      final model = TableViewModel(
        rows: rows,
        keyField: 'id',
        columns: [
          TableColumn(field: 'a', label: Line('A'), width: 3),
          TableColumn(field: 'b', label: Line('B'), width: 3),
        ],
        focused: true,
      );
      // cursorRow == 0, cursorCol == 0 on a fresh model.
      final buffer = canvas(7, 4); // header + 3 rows; col a (0-2), sep (3), col b (4-6)
      TableRenderer(model, resolver, showCrosshair: true).paint(buffer.area, BufferSurface(buffer));

      final cursorCell = buffer[(x: 0, y: 1)]; // row 0, col a — the exact cursor cell
      expect(cursorCell.fg, equals(Color.reset));
      expect(cursorCell.bg, equals(cursorBg));
      expect(cursorCell.modifier.has(Modifier.bold), isTrue);

      final crosshairRowOnly = buffer[(x: 4, y: 1)]; // row 0, col b — cursor row, not cursor column
      expect(crosshairRowOnly.bg, equals(cursorBg), reason: 'the row wash lifts the ground to its bright variant');
      expect(crosshairRowOnly.modifier.has(Modifier.bold), isFalse);

      final crosshairColumnOnly = buffer[(x: 0, y: 2)]; // row 1, col a — cursor column, not cursor row
      expect(crosshairColumnOnly.bg, equals(cursorBg), reason: 'the column wash lifts the ground too');
      expect(crosshairColumnOnly.modifier.has(Modifier.bold), isFalse);
    });
  });
}
