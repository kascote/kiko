import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

const _ctx = plume.LayoutContext(measurer: plume.MonospaceMeasurer());

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

String _dump(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

void main() {
  group('tree view render', () {
    test('draws an expanded tree with depth indentation', () {
      final model = TreeViewModel<String>()
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Parent'))])
        ..expand('/a')
        ..applyChildren('/a', <TreeNode<String>>[
          TreeNode(path: '/a/c1', label: Line('Child1'), isLeaf: true),
          TreeNode(path: '/a/c2', label: Line('Child2'), isLeaf: true),
        ]);

      final frame = _frame(12, 3)..renderNode(treeView<String>(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '▼ Parent\n    Child1\n    Child2\n');
    });

    test('shows the empty placeholder before roots load', () {
      final model = TreeViewModel<String>();
      final frame = _frame(9, 1)
        ..renderNode(treeView<String>(model: model, theme: Theme.dark, emptyPlaceholder: Line('(empty)')));
      expect(_dump(frame.buffer), '(empty)\n');
    });

    test('paints real row content through a RecordingSurface, not a hole', () {
      // The row body used to gate on `surface is BufferSurface`, so a golden
      // taken through plume's own RecordingSurface saw a border and nothing
      // else. Rows now paint through the plume Surface protocol directly, so
      // the focused row's fill and its text both land here too.
      final model = TreeViewModel<String>(focused: true)
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Root'), isLeaf: true)]);
      final node = treeView<String>(model: model, theme: Theme.dark)
        ..layout(plume.BoxConstraints.tight(const plume.Size(6, 1)), _ctx)
        ..place(plume.Offset.zero);
      final surface = plume.RecordingSurface<PaintToken>();
      node.paint(surface);

      final intents = surface.intents.map((i) => '$i').toList();
      expect(intents, hasLength(2));
      expect(intents[0], startsWith('fillRect('));
      expect(intents[1], startsWith('drawText(0, 0, "  Root'));
    });
  });

  group('tree view click routing', () {
    test('a click in the tree resolves to its id', () {
      final model = TreeViewModel<String>(id: 'files')
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Root'))]);
      final frame = _frame(10, 2)..renderNode(treeView<String>(model: model, theme: Theme.dark));

      expect(frame.hitId(0, 0), 'files');
      expect(frame.hitId(3, 0), 'files');
    });
  });
}
