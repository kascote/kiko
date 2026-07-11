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

      final frame = _frame(12, 3)..render(TreeView<String>(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '▼ Parent\n    Child1\n    Child2\n');
    });

    test('shows the empty placeholder before roots load', () {
      final model = TreeViewModel<String>();
      final frame = _frame(9, 1)
        ..render(TreeView<String>(model: model, theme: Theme.dark, emptyPlaceholder: Line('(empty)')));
      expect(_dump(frame.buffer), '(empty)\n');
    });

    test('draws three levels of nested expansion', () {
      final model = TreeViewModel<String>()
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Root'))])
        ..expand('/a')
        ..applyChildren('/a', <TreeNode<String>>[TreeNode(path: '/a/b', label: Line('Level1'))])
        ..expand('/a/b')
        ..applyChildren('/a/b', <TreeNode<String>>[
          TreeNode(path: '/a/b/c', label: Line('Level2'), isLeaf: true),
        ]);

      final frame = _frame(14, 3)..render(TreeView<String>(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '▼ Root\n  ▼ Level1\n      Level2\n');
    });

    test('shows icons before labels when showIcons is enabled', () {
      final model = TreeViewModel<String>(showIcons: true)
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Folder'), icon: '📁')])
        ..expand('/a')
        ..applyChildren('/a', <TreeNode<String>>[
          TreeNode(path: '/a/f', label: Line('File'), icon: '📄', isLeaf: true),
        ]);

      final frame = _frame(20, 2)..render(TreeView<String>(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '▼ 📁 Folder\n     📄 File\n');
    });

    test('aligns leaf and branch children at the same indent', () {
      final model = TreeViewModel<String>()
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Parent'))])
        ..expand('/a')
        ..applyChildren('/a', <TreeNode<String>>[
          TreeNode(path: '/a/branch', label: Line('Branch')),
          TreeNode(path: '/a/leaf', label: Line('Leaf'), isLeaf: true),
        ]);

      final frame = _frame(12, 3)..render(TreeView<String>(model: model, theme: Theme.dark));
      expect(_dump(frame.buffer), '▼ Parent\n  ▶ Branch\n    Leaf\n');
    });

    test('paints real row content through a RecordingSurface, not a hole', () {
      // The row body used to gate on `surface is BufferSurface`, so a golden
      // taken through plume's own RecordingSurface saw a border and nothing
      // else. Rows now paint through the plume Surface protocol directly, so
      // the focused row's fill and its text both land here too.
      final model = TreeViewModel<String>(focused: true)
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Root'), isLeaf: true)]);
      final node = TreeView<String>(model: model, theme: Theme.dark).build()
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

  group('tree view under a partial clip (viewport)', () {
    test('anchors content at the placement rect, not the clip sub-rect', () {
      // Simulates a Viewport ancestor showing only rows 2-4 of a tree placed at
      // (0, 0) with height 5: content must be computed against the full
      // placement (row 2 lands at screen row 2, matching where layout put it),
      // not re-anchored at the clip's origin — that would pin node0 to the top
      // of the visible window instead of scrolling it off.
      final model = TreeViewModel<String>()
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[
          for (var i = 0; i < 5; i++) TreeNode(path: '/n$i', label: Line('n$i'), isLeaf: true),
        ]);
      final node = TreeView<String>(model: model, theme: Theme.dark).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(4, 5)), _ctx)
        ..place(plume.Offset.zero);

      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 5));
      final surface = BufferSurface(buffer)..pushClip(const plume.Rect(0, 2, 4, 3));
      node.paint(surface);
      surface.popClip();

      // Rows scrolled above the clip are absent, not shown squeezed at the top.
      expect(_dump(buffer), '\n\n  n2\n  n3\n  n4\n');
    });
  });

  group('tree view click routing', () {
    test('a click in the tree resolves to its id', () {
      final model = TreeViewModel<String>(id: 'files')
        ..setVisibleCount(10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Root'))]);
      final frame = _frame(10, 2)..render(TreeView<String>(model: model, theme: Theme.dark));

      expect(frame.hits.hitId(0, 0), 'files');
      expect(frame.hits.hitId(3, 0), 'files');
    });
  });
}
