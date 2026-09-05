import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';
import '../../support/viewport.dart';

/// Renders [model] into a fresh buffer so tests can inspect cell fg/bg/modifier
/// directly. The tree is [width] wide so trailing cells past the short labels
/// are fill-only — a reliable place to read a row's resolved background.
Buffer _render(
  TreeViewModel<String> model, {
  int width = 10,
  int height = 3,
  Theme theme = Theme.dark,
  TreeViewStyle style = const TreeViewStyle(),
}) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  Frame(buffer.area, buffer, 0).render(TreeView<String>(model: model, theme: theme, style: style));
  return buffer;
}

TreeViewModel<String> _tree() => TreeViewModel<String>(focused: true)
  ..applyRoots(<TreeNode<String>>[
    TreeNode(path: '/a', label: Line('Alpha'), isLeaf: true),
    TreeNode(path: '/b', label: Line('Beta'), isLeaf: true),
  ]);

void main() {
  group('TreeView anatomy styling', () {
    test('the cursor node paints the cursor tone, not the focus tone (F2)', () {
      // The regression guard: the current node is WidgetState.cursor, so it
      // must derive from the cursor tone — never the focus tone the old code
      // borrowed for "the current row".
      final model = _tree();
      final buffer = _render(model);

      final cursorCell = buffer[(x: 9, y: 0)]; // trailing fill-only cell, cursor row
      expect(cursorCell.bg, equals(Theme.dark.cursor.color));
      expect(cursorCell.bg, isNot(equals(Theme.dark.focus.color)));
      expect(cursorCell.modifier.has(Modifier.bold), isTrue);
    });

    test('a non-cursor node is left unfilled', () {
      final model = _tree();
      final buffer = _render(model);

      final plainCell = buffer[(x: 9, y: 1)];
      expect(plainCell.bg, equals(Color.reset));
    });

    test('an explicit cursorItem style wins outright over the derivation', () {
      const override = Style(fg: Color.green, bg: Color.blue);
      final model = _tree();
      final buffer = _render(model, style: const TreeViewStyle(cursorItem: override));

      final cell = buffer[(x: 9, y: 0)];
      expect(cell.bg, equals(Color.blue));
      expect(cell.fg, equals(Color.green));
      expect(cell.modifier.has(Modifier.bold), isFalse);
    });

    test('a hovered node derives the hover wash', () {
      // Hover node 1, away from the cursor at node 0, so only the hover wash paints.
      final model = _tree()..hoverRow = 1;
      final buffer = _render(model);

      final hoverCell = buffer[(x: 9, y: 1)];
      expect(hoverCell.bg, equals(Theme.dark.hover.color));
    });

    test('hover is the weakest state: a hovered cursor node still reads cursor', () {
      final model = _tree()..hoverRow = 0;
      final buffer = _render(model);

      final cell = buffer[(x: 9, y: 0)];
      expect(cell.bg, equals(Theme.dark.cursor.color), reason: 'the cursor fill wins over the hover wash');
    });

    test('a node whose children are loading blinks warning over the row', () {
      // Expanding an uncached branch marks it loading; its own row then carries
      // the loading state (warning ink + slow blink) from the state matrix.
      final model = TreeViewModel<String>(focused: true)
        ..applyRoots(<TreeNode<String>>[TreeNode(path: '/a', label: Line('Branch'))])
        ..viewport(rows: 3)
        ..expand('/a'); // no children cached → slot begins loading
      final buffer = _render(model);

      final cell = buffer[(x: 9, y: 0)];
      expect(cell.modifier.has(Modifier.slowBlink), isTrue);
      expect(cell.fg, equals(Theme.dark.warning.color));
    });

    test('the empty placeholder derives the muted ink', () {
      final model = TreeViewModel<String>(focused: true); // roots not loaded yet
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 10, height: 3));
      Frame(buffer.area, buffer, 0).render(
        TreeView<String>(model: model, theme: Theme.dark, emptyPlaceholder: Line('none')),
      );

      expect(buffer[(x: 0, y: 0)].fg, equals(Theme.dark.muted.color));
    });
  });
}
