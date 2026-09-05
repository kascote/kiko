import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';
import '../../support/viewport.dart';

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
        ..viewport(rows: 10)
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
        ..viewport(rows: 10)
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
        ..viewport(rows: 10)
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
        ..viewport(rows: 10)
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
        ..viewport(rows: 10)
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

  group('placeholder rows', () {
    // A branch root with nothing cached: expanding it appends one placeholder
    // row beneath it, at the depth a real child would sit at.
    TreeViewModel<String> branchNoChildren() => TreeViewModel<String>(focused: true)
      ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Branch'))])
      ..viewport(rows: 3)
      ..expand('/a');

    test("the loading row shows the view's label over the muted base", () {
      final model = branchNoChildren();
      final frame = _frame(20, 2)
        ..render(TreeView<String>(model: model, theme: Theme.dark, loadingLabel: Line('Fetching')));

      // The branch's own row still carries the loading state, on its glyph.
      expect(_dump(frame.buffer), '◌ Branch\n    Fetching\n');
      expect(frame.buffer[(x: 4, y: 1)].fg, equals(Theme.dark.muted.color));
    });

    test("the failed row shows the view's label with the error tone", () {
      final model = branchNoChildren();
      model.update(LoadResult<List<TreeNode<String>>>(model.id, key: const PathKey('/a'), error: 'boom'));

      final frame = _frame(20, 2)..render(TreeView<String>(model: model, theme: Theme.dark, errorLabel: Line('Broke')));

      expect(_dump(frame.buffer), '▼ Branch\n    Broke\n');
      expect(frame.buffer[(x: 4, y: 1)].fg, equals(Theme.dark.error.color));
    });

    test("the stalled row shows the view's label over the muted base", () {
      final model = branchNoChildren();
      model.update(LoadResult<List<TreeNode<String>>>.cancelled(model.id, key: const PathKey('/a')));

      final frame = _frame(20, 2)
        ..render(TreeView<String>(model: model, theme: Theme.dark, stalledLabel: Line('Skip')));

      expect(_dump(frame.buffer), '▼ Branch\n    Skip\n');
      expect(frame.buffer[(x: 4, y: 1)].fg, equals(Theme.dark.muted.color));
    });

    test('a custom nodeBuilder is not called for a placeholder row', () {
      final model = branchNoChildren();
      var calls = 0;
      final frame = _frame(20, 2)
        ..render(
          TreeView<String>(
            model: model,
            theme: Theme.dark,
            nodeBuilder: (node, depth, state) {
              calls++;
              return node.label;
            },
          ),
        );

      expect(calls, 1, reason: 'called once for the real branch row, never for its placeholder row');
      expect(_dump(frame.buffer), 'Branch\n    Loading…\n');
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
        ..viewport(rows: 10)
        ..applyRoots(<TreeNode<String>>[
          for (var i = 0; i < 5; i++) TreeNode(path: '/n$i', label: Line('n$i'), isLeaf: true),
        ]);
      final node = TreeView<String>(model: model, theme: Theme.dark).build()
        ..layout(plume.BoxConstraints.tight(const plume.Size(4, 5)), _ctx)
        ..place(plume.Offset.zero);

      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 5));
      final surface = BufferSurface(buffer)..pushNode(const plume.Rect(0, 2, 4, 3));
      node.paint(surface);
      surface.popNode();

      // Rows scrolled above the clip are absent, not shown squeezed at the top.
      expect(_dump(buffer), '\n\n  n2\n  n3\n  n4\n');
    });
  });

  group('tree view viewport report', () {
    test('reports the rows it painted, addressed to the model id', () {
      final model = TreeViewModel<String>(id: 'nav')
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('A'), isLeaf: true)]);
      final frame = _frame(8, 4)..render(TreeView<String>(model: model, theme: Theme.dark));

      final report = frame.reports.single as ViewportChanged;
      expect(report.id, 'nav');
      expect(report.rows, 4);
      expect(model.visibleCount, 0, reason: 'paint reports; it never writes into the model');
    });

    test('a paint whose count the model already holds reports nothing', () {
      final model = TreeViewModel<String>(id: 'nav')
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('A'), isLeaf: true)]);
      final view = TreeView<String>(model: model, theme: Theme.dark);
      (_frame(8, 4)..render(view)).reports.forEach(model.update);
      expect(model.visibleCount, 4);

      final second = _frame(8, 4)..render(view);
      expect(second.reports, isEmpty, reason: 'the model holds the count, so the frame a report causes settles');
    });

    test('under a scope, the report carries the scoped path', () {
      final model = TreeViewModel<String>(id: 'nav')
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('A'), isLeaf: true)]);
      final frame = _frame(8, 4)
        ..render(
          Tagged.scope(
            'sidebar',
            Container(
              child: TreeView<String>(model: model, theme: Theme.dark),
            ),
          ),
        );

      expect((frame.reports.single as ViewportChanged).id, 'sidebar/nav');
      expect(frame.hits.hitId(0, 0), 'sidebar/nav', reason: 'the same path the hit map records');
    });
  });

  group('tree view click routing', () {
    test('a click in the tree resolves to its id', () {
      final model = TreeViewModel<String>(id: 'files')
        ..viewport(rows: 10)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Root'))]);
      final frame = _frame(10, 2)..render(TreeView<String>(model: model, theme: Theme.dark));

      expect(frame.hits.hitId(0, 0), 'files');
      expect(frame.hits.hitId(3, 0), 'files');
    });
  });

  group('hit regions (task 0262)', () {
    // A branch root at depth 0 (its expand indicator sits at columns 0-1),
    // followed by a leaf (which paints no indicator).
    TreeViewModel<String> branchTree() => TreeViewModel<String>(id: 'nav')
      ..viewport(rows: 10)
      ..applyRoots(<TreeNode<String>>[
        TreeNode(path: '/A', label: Line('Alpha')),
        TreeNode(path: '/b', label: Line('Beta'), isLeaf: true),
      ]);

    test('the default builder marks the expand indicator over the row', () {
      final hits = (_frame(10, 2)..render(TreeView<String>(model: branchTree(), theme: Theme.dark))).hits;

      // Branch row 0: the indicator wins columns 0-1, the row body owns the rest.
      expect(hits.regionAt('nav', 0, 0), const TreeIndicatorRegion(0), reason: 'the expand arrow');
      expect(hits.regionAt('nav', 1, 0), const TreeIndicatorRegion(0));
      expect(hits.regionAt('nav', 4, 0), const RowRegion(0), reason: 'past the indicator is the row body');
      // Leaf row 1 paints no indicator — the whole row is the plain region.
      expect(hits.regionAt('nav', 0, 1), const RowRegion(1), reason: 'a leaf has no indicator');
      expect(hits.regionAt('nav', 4, 1), const RowRegion(1));
    });

    test('a custom nodeBuilder marks no indicator, so the indent is the row', () {
      // The latent bug: the old model toggled on any press in [indent, indent+2)
      // even when a custom builder drew no arrow there. With no indicator region
      // marked, that press now resolves to the plain row and activates instead.
      final node = TreeView<String>(
        model: branchTree(),
        theme: Theme.dark,
        nodeBuilder: (n, depth, state) => n.label,
      );
      final hits = (_frame(10, 2)..render(node)).hits;

      expect(hits.regionAt('nav', 0, 0), const RowRegion(0), reason: 'no indicator with a custom builder');
      expect(hits.regionAt('nav', 1, 0), const RowRegion(0));
    });
  });
}
