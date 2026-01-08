import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Test data source.
class TestTreeDataSource extends TreeDataSource<String> {
  final List<TreeNode<String>> roots;
  final Map<String, List<TreeNode<String>>> children;

  TestTreeDataSource({required this.roots, this.children = const {}});

  @override
  Future<List<TreeNode<String>>> getRoots() async => roots;

  @override
  Future<List<TreeNode<String>>> getChildren(String path) async => children[path] ?? [];
}

void main() {
  group('TreeView visual tests', () {
    test('collapsed root renders with indicator', () async {
      final result = await CaptureBuilder(width: 20, height: 3).setup((t) async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('Root'))],
          ),
        )..setVisibleCount(10);
        await model.loadRoots();

        t.render(TreeView(model: model));
      }).capture();

      expect(
        result,
        equals('▶ Root'),
      );
    });

    test('expanded tree shows children', () async {
      final result = await CaptureBuilder(width: 20, height: 5).setup((t) async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('Parent'))],
            children: {
              '/a': [
                TreeNode(path: '/a/c1', label: Line('Child1'), isLeaf: true),
                TreeNode(path: '/a/c2', label: Line('Child2'), isLeaf: true),
              ],
            },
          ),
        )..setVisibleCount(10);
        await model.loadRoots();
        await model.expand('/a');

        t.render(TreeView(model: model));
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
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('Root'))],
            children: {
              '/a': [TreeNode(path: '/a/b', label: Line('Level1'))],
              '/a/b': [
                TreeNode(path: '/a/b/c', label: Line('Level2'), isLeaf: true),
              ],
            },
          ),
        )..setVisibleCount(10);
        await model.loadRoots();
        await model.expand('/a');
        await model.expand('/a/b');

        t.render(TreeView(model: model));
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
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('Folder'), icon: '📁')],
            children: {
              '/a': [
                TreeNode(
                  path: '/a/f',
                  label: Line('File'),
                  icon: '📄',
                  isLeaf: true,
                ),
              ],
            },
          ),
          showIcons: true,
        )..setVisibleCount(10);
        await model.loadRoots();
        await model.expand('/a');

        t.render(TreeView(model: model));
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
            final model = TreeViewModel<String>(
              dataSource: TestTreeDataSource(
                roots: [
                  TreeNode(path: '/a', label: Line('A')),
                  TreeNode(path: '/b', label: Line('B')),
                ],
              ),
            )..setVisibleCount(10);
            await model.loadRoots();

            t.render(TreeView(model: model));
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
      final model = TreeViewModel<String>(
        dataSource: TestTreeDataSource(
          roots: [TreeNode(path: '/x', label: Line('Item'))],
        ),
      )..setVisibleCount(10);
      await model.loadRoots();

      final tree = TreeView(model: model);

      expect(tree, rendersAs('▶ Item', width: 20, height: 1));
    });

    test('empty tree with placeholder', () async {
      final result = await CaptureBuilder(width: 20, height: 3).setup((t) async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(roots: []),
        )..setVisibleCount(10);
        await model.loadRoots();

        t.render(
          TreeView(
            model: model,
            emptyPlaceholder: Paragraph(content: '(empty)'),
          ),
        );
      }).capture();

      expect(result, equals('(empty)'));
    });

    test('leaf and branch alignment', () async {
      final result = await CaptureBuilder(width: 20, height: 4).setup((t) async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('Parent'))],
            children: {
              '/a': [
                TreeNode(path: '/a/branch', label: Line('Branch')),
                TreeNode(
                  path: '/a/leaf',
                  label: Line('Leaf'),
                  isLeaf: true,
                ),
              ],
            },
          ),
        )..setVisibleCount(10);
        await model.loadRoots();
        await model.expand('/a');

        t.render(TreeView(model: model));
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
