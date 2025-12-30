import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  group('TreeNode', () {
    group('creation', () {
      test('basic node', () {
        final node = TreeNode<String>(
          path: '/root',
          label: Line('Root'),
        );
        expect(node.path, equals('/root'));
        expect(node.isLeaf, isFalse);
        expect(node.icon, isNull);
        expect(node.data, isNull);
      });

      test('leaf node', () {
        final node = TreeNode<String>(
          path: '/root/file.txt',
          label: Line('file.txt'),
          isLeaf: true,
        );
        expect(node.isLeaf, isTrue);
      });

      test('with icon and data', () {
        final node = TreeNode<int>(
          path: '/docs',
          label: Line('Documents'),
          icon: '📁',
          data: 42,
        );
        expect(node.icon, equals('📁'));
        expect(node.data, equals(42));
      });
    });

    group('depth', () {
      test('root has depth 0', () {
        final node = TreeNode<void>(path: '/root', label: Line('Root'));
        expect(node.depth, equals(0));
      });

      test('child has depth 1', () {
        final node = TreeNode<void>(path: '/root/child', label: Line('Child'));
        expect(node.depth, equals(1));
      });

      test('grandchild has depth 2', () {
        final node = TreeNode<void>(
          path: '/root/child/grandchild',
          label: Line('Grandchild'),
        );
        expect(node.depth, equals(2));
      });

      test('empty path has depth 0', () {
        final node = TreeNode<void>(path: '', label: Line('Empty'));
        expect(node.depth, equals(0));
      });

      test('slash only has depth 0', () {
        final node = TreeNode<void>(path: '/', label: Line('Slash'));
        expect(node.depth, equals(0));
      });
    });

    group('parentPath', () {
      test('root has null parent', () {
        final node = TreeNode<void>(path: '/root', label: Line('Root'));
        expect(node.parentPath, isNull);
      });

      test('child has parent path', () {
        final node = TreeNode<void>(path: '/root/child', label: Line('Child'));
        expect(node.parentPath, equals('/root'));
      });

      test('grandchild has parent path', () {
        final node = TreeNode<void>(
          path: '/root/child/grandchild',
          label: Line('Grandchild'),
        );
        expect(node.parentPath, equals('/root/child'));
      });

      test('empty path has null parent', () {
        final node = TreeNode<void>(path: '', label: Line('Empty'));
        expect(node.parentPath, isNull);
      });
    });

    test('toString', () {
      final node = TreeNode<void>(path: '/test/path', label: Line('Test'));
      expect(node.toString(), equals('TreeNode(/test/path)'));
    });
  });
}
