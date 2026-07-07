import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// End-to-end NO_COLOR wiring: prove that `StyleResolver.defaultPolicy`
/// (the process-wide flag the Application sets from the terminal profile)
/// actually reaches the resolvers each widget builds internally, so a state
/// that painted a colored surface degrades to `Modifier.reversed` — visible
/// once termkit strips the colors. The per-projection matrix itself is proven
/// in kiko_core's style_resolver_nocolor_test.
void main() {
  setUp(() => StyleResolver.defaultPolicy = RenderPolicy.noColor);
  tearDown(() => StyleResolver.defaultPolicy = RenderPolicy.color);

  Buffer canvas(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

  group('NO_COLOR degrades widget surfaces to reversed', () {
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
      expect(cell.modifier.has(Modifier.reversed), isTrue);
      expect(cell.bg, equals(Color.reset), reason: 'no color under NO_COLOR');
    });

    test('TreeView cursor node', () {
      final model = TreeViewModel<String>(focused: true)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Alpha'), isLeaf: true)]);
      final buffer = canvas(10, 2);
      Frame(buffer.area, buffer, 0).render(TreeView<String>(model: model, theme: Theme.dark));
      final cell = buffer[(x: 9, y: 0)];
      expect(cell.modifier.has(Modifier.reversed), isTrue);
      expect(cell.bg, equals(Color.reset));
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
      // The focus state degrades to reversed. The button's resting base is an
      // explicit theme.primary.fill the caller supplies, not a resolver
      // projection, so its color stays in the buffer here — termkit drops it at
      // output. Reversed is what keeps the focused face distinguishable.
      expect(cell.modifier.has(Modifier.reversed), isTrue);
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
      expect(cell.modifier.has(Modifier.reversed), isTrue);
      expect(cell.modifier.has(Modifier.bold), isTrue);
      expect(cell.bg, equals(Color.reset));
    });
  });
}
