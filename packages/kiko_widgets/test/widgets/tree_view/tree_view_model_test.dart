import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// Builds a focused-by-default model with [roots] already applied — what the
/// app does after its `getRoots` task resolves (the model performs no I/O).
TreeViewModel<String> modelWith(
  List<TreeNode<String>> roots, {
  bool focused = true,
  int visibleCount = 10,
}) => TreeViewModel<String>(focused: focused)
  ..setVisibleCount(visibleCount)
  ..applyRoots(roots);

/// Expands [path] and immediately resolves the child load with [children] —
/// what the app does in response to the [TreeExpandCmd] load request.
void expandLoaded(
  TreeViewModel<String> m,
  String path,
  List<TreeNode<String>> children,
) => m
  ..expand(path)
  ..applyChildren(path, children);

void main() {
  group('TreeViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = TreeViewModel<String>();
        expect(model.flatNodes, isEmpty);
        expect(model.cursor, equals(0));
        expect(model.cursorNode, isNull);
        expect(model.focused, isFalse);
        expect(model.isLoaded, isFalse);
        expect(model.isLoading, isFalse);
      });

      test('config fields', () {
        final model = TreeViewModel<String>(focused: true);
        expect(model.indentWidth, equals(2));
        expect(model.focused, isTrue);
      });

      test('auto-generates a unique id when omitted', () {
        final a = TreeViewModel<String>();
        final b = TreeViewModel<String>();
        expect(a.id, startsWith('treeview-'));
        expect(a.id, isNot(equals(b.id)));
      });

      test('keeps an explicit id', () {
        final model = TreeViewModel<String>(id: 'myTree');
        expect(model.id, equals('myTree'));
      });
    });

    group('applyRoots', () {
      test('installs and flattens roots', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
        ], focused: false);

        expect(model.isLoaded, isTrue);
        expect(model.flatNodes.length, equals(2));
        expect(model.flatNodes[0].path, equals('/a'));
        expect(model.flatNodes[1].path, equals('/b'));
      });

      test('clears the roots-loading flag', () {
        final model = TreeViewModel<String>()
          ..isLoading = true
          ..applyRoots([TreeNode(path: '/a', label: Line('A'))]);

        expect(model.isLoading, isFalse);
        expect(model.isLoaded, isTrue);
      });
    });

    group('expand/collapse', () {
      late TreeViewModel<String> model;
      final children = <String, List<TreeNode<String>>>{
        '/a': [
          TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true),
          TreeNode(path: '/a/2', label: Line('A2'), isLeaf: true),
        ],
      };

      setUp(() {
        model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
        ]);
      });

      test('expand requests a load for uncached children', () {
        final cmd = model.expand('/a');

        expect(cmd, isA<TreeExpandCmd<String>>());
        expect((cmd! as TreeExpandCmd).path, equals('/a'));
        expect(model.isExpanded('/a'), isTrue);
        expect(model.isPathLoading('/a'), isTrue);
      });

      test('expand performs no I/O — real children appear only via applyChildren', () {
        model.expand('/a');

        // The model fetched nothing: a loading placeholder shows, but the real
        // children are absent until the app delivers them. Proves the model
        // never mutates outside the loop (A3).
        expect(model.isPathLoading('/a'), isTrue);
        expect(model.flatNodes.any((n) => n.path == '/a/1'), isFalse);
        expect(model.flatNodes.any((n) => n.path == '/a/2'), isFalse);

        model.applyChildren('/a', children['/a']!);
        expect(model.flatNodes.any((n) => n.path == '/a/1'), isTrue);
        expect(model.flatNodes.length, equals(4));
      });

      test('applyChildren installs loaded children and clears loading', () {
        model
          ..expand('/a')
          ..applyChildren('/a', children['/a']!);

        expect(model.isPathLoading('/a'), isFalse);
        expect(model.flatNodes.length, equals(4));
        expect(model.flatNodes[1].path, equals('/a/1'));
        expect(model.flatNodes[2].path, equals('/a/2'));
      });

      test('re-expanding cached children does not request a load', () {
        expandLoaded(model, '/a', children['/a']!);
        model.collapse('/a');

        final cmd = model.expand('/a');

        expect(cmd, isNull);
        expect(model.isExpanded('/a'), isTrue);
        expect(model.flatNodes.length, equals(4));
      });

      test('collapse removes children from flat list', () {
        expandLoaded(model, '/a', children['/a']!);
        expect(model.flatNodes.length, equals(4));

        final cmd = model.collapse('/a');

        expect(model.isExpanded('/a'), isFalse);
        expect(model.flatNodes.length, equals(2));
        expect(cmd, isA<TreeCollapseCmd<String>>());
      });

      test('expand on leaf returns null', () {
        expandLoaded(model, '/a', children['/a']!);
        final cmd = model.expand('/a/1');
        expect(cmd, isNull);
      });

      test('toggle expands then collapses', () {
        model.toggle('/a');
        expect(model.isExpanded('/a'), isTrue);

        model.toggle('/a');
        expect(model.isExpanded('/a'), isFalse);
      });

      test('collapseAll clears all expansions', () {
        expandLoaded(model, '/a', children['/a']!);
        model.collapseAll();

        expect(model.isExpanded('/a'), isFalse);
        expect(model.flatNodes.length, equals(2));
      });
    });

    group('cursor movement', () {
      late TreeViewModel<String> model;

      setUp(() {
        model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
          TreeNode(path: '/c', label: Line('C')),
          TreeNode(path: '/d', label: Line('D')),
          TreeNode(path: '/e', label: Line('E')),
        ], visibleCount: 3);
      });

      test('down moves cursor', () {
        model.update(keyMsg('down'));
        expect(model.cursor, equals(1));
        expect(model.cursorNode?.path, equals('/b'));
      });

      test('j moves cursor down (vim)', () {
        model.update(keyMsg('j'));
        expect(model.cursor, equals(1));
      });

      test('up moves cursor', () {
        model
          ..update(keyMsg('down'))
          ..update(keyMsg('up'));
        expect(model.cursor, equals(0));
      });

      test('k moves cursor up (vim)', () {
        model
          ..update(keyMsg('j'))
          ..update(keyMsg('k'));
        expect(model.cursor, equals(0));
      });

      test('up at first stays at 0', () {
        model.update(keyMsg('up'));
        expect(model.cursor, equals(0));
      });

      test('down at last stays at end', () {
        for (var i = 0; i < 10; i++) {
          model.update(keyMsg('down'));
        }
        expect(model.cursor, equals(4));
      });

      test('home moves to first', () {
        model
          ..update(keyMsg('down'))
          ..update(keyMsg('down'))
          ..update(keyMsg('home'));
        expect(model.cursor, equals(0));
      });

      test('end moves to last', () {
        model.update(keyMsg('end'));
        expect(model.cursor, equals(4));
      });

      test('G moves to last (vim)', () {
        model.update(keyMsg('G'));
        expect(model.cursor, equals(4));
      });

      test('pageDown moves by visible count', () {
        model.update(keyMsg('pageDown'));
        expect(model.cursor, equals(3));
      });

      test('pageUp moves by visible count', () {
        model
          ..update(keyMsg('end'))
          ..update(keyMsg('pageUp'));
        expect(model.cursor, equals(1));
      });
    });

    group('expand/collapse via keys', () {
      late TreeViewModel<String> model;
      final children = <String, List<TreeNode<String>>>{
        '/a': [TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true)],
      };

      setUp(() {
        model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B'), isLeaf: true),
        ]);
      });

      test('right requests expand', () {
        final cmd = model.update(keyMsg('right'));
        expect(cmd, isA<TreeExpandCmd<String>>());
        expect(model.isExpanded('/a'), isTrue);
      });

      test('l requests expand (vim)', () {
        model.update(keyMsg('l'));
        expect(model.isExpanded('/a'), isTrue);
      });

      test('left collapses expanded node', () {
        expandLoaded(model, '/a', children['/a']!);
        model.update(keyMsg('left'));
        expect(model.isExpanded('/a'), isFalse);
      });

      test('h collapses expanded node (vim)', () {
        expandLoaded(model, '/a', children['/a']!);
        model.update(keyMsg('h'));
        expect(model.isExpanded('/a'), isFalse);
      });

      test('left on collapsed moves to parent', () {
        expandLoaded(model, '/a', children['/a']!);
        model
          ..update(keyMsg('down')) // Move to /a/1
          ..update(keyMsg('left')); // Should move to parent /a
        expect(model.cursorNode?.path, equals('/a'));
      });

      test('o toggles expand', () {
        model.update(keyMsg('o'));
        expect(model.isExpanded('/a'), isTrue);

        model.update(keyMsg('o'));
        expect(model.isExpanded('/a'), isFalse);
      });
    });

    group('expandPath', () {
      test('expands cached ancestors and scrolls to node', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))])
          // Pre-load the subtree the app would have fetched.
          ..applyChildren('/a', [TreeNode(path: '/a/b', label: Line('B'))])
          ..applyChildren('/a/b', [
            TreeNode(path: '/a/b/c', label: Line('C'), isLeaf: true),
          ])
          ..expandPath('/a/b/c');

        expect(model.isExpanded('/a'), isTrue);
        expect(model.isExpanded('/a/b'), isTrue);
        expect(model.cursorNode?.path, equals('/a/b/c'));
      });
    });

    group('search', () {
      test('finds matching nodes', () {
        final model = modelWith([
          TreeNode(path: '/apple', label: Line('Apple')),
          TreeNode(path: '/banana', label: Line('Banana')),
          TreeNode(path: '/apricot', label: Line('Apricot')),
        ], focused: false);

        final results = model.search('ap');
        expect(results.length, equals(2));
        expect(results.map((n) => n.path), containsAll(['/apple', '/apricot']));
      });

      test('findFirst returns first match path', () {
        final model = modelWith([
          TreeNode(path: '/apple', label: Line('Apple')),
          TreeNode(path: '/apricot', label: Line('Apricot')),
        ], focused: false);

        final path = model.findFirst('ap');
        expect(path, equals('/apple'));
      });

      test('returns empty for no match', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
        ], focused: false);

        expect(model.search('xyz'), isEmpty);
        expect(model.findFirst('xyz'), isNull);
      });
    });

    group('commands', () {
      test('enter returns TreeActionCmd', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);

        final cmd = model.update(keyMsg('enter'));
        expect(cmd, isA<TreeActionCmd<String>>());
        expect((cmd! as TreeActionCmd).path, equals('/a'));
      });

      test('unhandled key returns Unhandled', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        expect(model.update(keyMsg('tab')), isA<Unhandled>());
      });

      test('unfocused returns Unhandled', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
        ], focused: false);
        expect(model.update(keyMsg('down')), isA<Unhandled>());
      });
    });

    group('scroll offset', () {
      test('adjusts when cursor moves below visible', () {
        final model = modelWith(
          List.generate(
            20,
            (i) => TreeNode(path: '/item$i', label: Line('Item $i')),
          ),
          visibleCount: 5,
        );

        for (var i = 0; i < 6; i++) {
          model.update(keyMsg('down'));
        }

        expect(model.cursor, equals(6));
        expect(model.scrollOffset, equals(2));
      });

      test('scrollState returns correct values', () {
        final model = modelWith(
          List.generate(
            20,
            (i) => TreeNode(path: '/item$i', label: Line('Item $i')),
          ),
          focused: false,
          visibleCount: 5,
        );

        final state = model.getScrollState();
        expect(state.visible, equals(5));
        expect(state.total, equals(20));
        expect(state.offset, equals(0));
      });
    });

    group('empty tree', () {
      test('handles empty roots', () {
        final model = modelWith(<TreeNode<String>>[]);
        expect(model.flatNodes, isEmpty);
        expect(model.cursorNode, isNull);
      });

      test('navigation on empty tree is safe', () {
        // Navigation on an empty tree should not throw.
        final model = modelWith(<TreeNode<String>>[], visibleCount: 5)
          ..update(keyMsg('down'))
          ..update(keyMsg('up'))
          ..update(keyMsg('home'))
          ..update(keyMsg('end'));

        expect(model.cursor, equals(0));
      });
    });
  });

  group('StaticTreeDataSource', () {
    test('getRoots returns root nodes', () async {
      final source = StaticTreeDataSource<void>([
        TreeNode(path: '/a', label: Line('A')),
        TreeNode(path: '/b', label: Line('B')),
        TreeNode(path: '/a/child', label: Line('Child')),
      ]);

      final roots = await source.getRoots();
      expect(roots.length, equals(2));
      expect(roots.map((n) => n.path), containsAll(['/a', '/b']));
    });

    test('getChildren returns direct children', () async {
      final source = StaticTreeDataSource<void>([
        TreeNode(path: '/a', label: Line('A')),
        TreeNode(path: '/a/child1', label: Line('Child 1')),
        TreeNode(path: '/a/child2', label: Line('Child 2')),
        TreeNode(path: '/a/child1/grandchild', label: Line('Grandchild')),
      ]);

      final children = await source.getChildren('/a');
      expect(children.length, equals(2));
      expect(children.map((n) => n.path), containsAll(['/a/child1', '/a/child2']));
    });

    test('hasMore returns false', () {
      final source = StaticTreeDataSource<void>([]);
      expect(source.hasMore('/a'), isFalse);
    });
  });

  group('TreeScrollState', () {
    test('progress calculation', () {
      const state = TreeScrollState(offset: 5, visible: 10, total: 20);
      expect(state.progress, equals(0.5));
    });

    test('progress null when all visible', () {
      const state = TreeScrollState(offset: 0, visible: 10, total: 5);
      expect(state.progress, isNull);
    });

    test('thumbSize calculation', () {
      const state = TreeScrollState(offset: 0, visible: 10, total: 100);
      expect(state.thumbSize, equals(0.1));
    });

    test('thumbSize minimum 0.1', () {
      const state = TreeScrollState(offset: 0, visible: 1, total: 1000);
      expect(state.thumbSize, equals(0.1));
    });
  });
}
