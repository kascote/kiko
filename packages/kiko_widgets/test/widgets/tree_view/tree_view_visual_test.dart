import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  group('TreeView visual tests', () {
    test('collapsed root renders with indicator', () async {
      final result = await CaptureBuilder(width: 20, height: 3).setup((t) async {
        final model = TreeViewModel<String>()
          ..setVisibleCount(10)
          ..applyRoots([TreeNode(path: '/a', label: Line('Root'))]);

        t.render(TreeView(model: model, theme: Theme.dark));
      }).capture();

      expect(
        result,
        equals('▶ Root'),
      );
    });

    test('expanded tree shows children', () async {
      final result = await CaptureBuilder(width: 20, height: 5).setup((t) async {
        final model = TreeViewModel<String>()
          ..setVisibleCount(10)
          ..applyRoots([TreeNode(path: '/a', label: Line('Parent'))])
          ..expand('/a')
          ..applyChildren('/a', [
            TreeNode(path: '/a/c1', label: Line('Child1'), isLeaf: true),
            TreeNode(path: '/a/c2', label: Line('Child2'), isLeaf: true),
          ]);

        t.render(TreeView(model: model, theme: Theme.dark));
      }).capture();

      expect(
        result,
        equals('''
▼ Parent
    Child1
    Child2'''),
      );
    });

    test('nested tree structure', () async {
      final result = await CaptureBuilder(width: 25, height: 5).setup((t) async {
        final model = TreeViewModel<String>()
          ..setVisibleCount(10)
          ..applyRoots([TreeNode(path: '/a', label: Line('Root'))])
          ..expand('/a')
          ..applyChildren('/a', [TreeNode(path: '/a/b', label: Line('Level1'))])
          ..expand('/a/b')
          ..applyChildren('/a/b', [
            TreeNode(path: '/a/b/c', label: Line('Level2'), isLeaf: true),
          ]);

        t.render(TreeView(model: model, theme: Theme.dark));
      }).capture();

      expect(
        result,
        equals('''
▼ Root
  ▼ Level1
      Level2'''),
      );
    });

    test('tree with icons', () async {
      final result = await CaptureBuilder(width: 30, height: 4).setup((t) async {
        final model = TreeViewModel<String>(showIcons: true)
          ..setVisibleCount(10)
          ..applyRoots([TreeNode(path: '/a', label: Line('Folder'), icon: '📁')])
          ..expand('/a')
          ..applyChildren('/a', [
            TreeNode(
              path: '/a/f',
              label: Line('File'),
              icon: '📄',
              isLeaf: true,
            ),
          ]);

        t.render(TreeView(model: model, theme: Theme.dark));
      }).capture();

      expect(
        result,
        equals('''
▼ 📁 Folder
     📄 File'''),
      );
    });

    test('debug border shows widget bounds', () async {
      final result =
          await CaptureBuilder(
            width: 15,
            height: 2,
            showBorder: true,
          ).setup((t) async {
            final model = TreeViewModel<String>()
              ..setVisibleCount(10)
              ..applyRoots([
                TreeNode(path: '/a', label: Line('A')),
                TreeNode(path: '/b', label: Line('B')),
              ]);

            t.render(TreeView(model: model, theme: Theme.dark));
          }).capture();

      expect(
        result,
        equals('''
+---------------+
|▶ A            |
|▶ B            |
+---------------+'''),
      );
    });

    test('using rendersAs matcher', () async {
      final model = TreeViewModel<String>()
        ..setVisibleCount(10)
        ..applyRoots([TreeNode(path: '/x', label: Line('Item'))]);

      final tree = TreeView(model: model, theme: Theme.dark);

      expect(tree, rendersAs('▶ Item', width: 20, height: 1));
    });

    test('empty tree with placeholder', () async {
      final result = await CaptureBuilder(width: 20, height: 3).setup((t) async {
        final model = TreeViewModel<String>()
          ..setVisibleCount(10)
          ..applyRoots([]);

        t.render(
          TreeView(
            model: model,
            theme: Theme.dark,
            emptyPlaceholder: Paragraph(content: '(empty)'),
          ),
        );
      }).capture();

      expect(result, equals('(empty)'));
    });

    test('leaf and branch alignment', () async {
      final result = await CaptureBuilder(width: 20, height: 4).setup((t) async {
        final model = TreeViewModel<String>()
          ..setVisibleCount(10)
          ..applyRoots([TreeNode(path: '/a', label: Line('Parent'))])
          ..expand('/a')
          ..applyChildren('/a', [
            TreeNode(path: '/a/branch', label: Line('Branch')),
            TreeNode(path: '/a/leaf', label: Line('Leaf'), isLeaf: true),
          ]);

        t.render(TreeView(model: model, theme: Theme.dark));
      }).capture();

      // Both children should have labels aligned
      expect(
        result,
        equals('''
▼ Parent
  ▶ Branch
    Leaf'''),
      );
    });
  });
}
