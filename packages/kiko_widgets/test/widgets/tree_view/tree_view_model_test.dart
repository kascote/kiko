import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// Test data source with immediate children.
class TestTreeDataSource extends TreeDataSource<String> {
  final List<TreeNode<String>> roots;
  final Map<String, List<TreeNode<String>>> children;

  TestTreeDataSource({
    required this.roots,
    this.children = const {},
  });

  @override
  Future<List<TreeNode<String>>> getRoots() async => roots;

  @override
  Future<List<TreeNode<String>>> getChildren(String path) async {
    return children[path] ?? [];
  }
}

void main() {
  group('TreeViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(roots: []),
        );
        expect(model.flatNodes, isEmpty);
        expect(model.cursor, equals(0));
        expect(model.cursorNode, isNull);
        expect(model.focused, isFalse);
        expect(model.isLoaded, isFalse);
      });

      test('config fields', () {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(roots: []),
          focused: true,
        );
        expect(model.indentWidth, equals(2));
        expect(model.focused, isTrue);
      });
    });

    group('loadRoots', () {
      test('loads and flattens roots', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/a', label: Line('A')),
              TreeNode(path: '/b', label: Line('B')),
            ],
          ),
        );

        await model.loadRoots();

        expect(model.isLoaded, isTrue);
        expect(model.flatNodes.length, equals(2));
        expect(model.flatNodes[0].path, equals('/a'));
        expect(model.flatNodes[1].path, equals('/b'));
      });

      test('does not reload if already loaded', () async {
        var callCount = 0;
        final source = _CountingSource(() => callCount++);
        final model = TreeViewModel<String>(dataSource: source);

        await model.loadRoots();
        await model.loadRoots();

        expect(callCount, equals(1));
      });
    });

    group('expand/collapse', () {
      late TreeViewModel<String> model;

      setUp(() async {
        model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/a', label: Line('A')),
              TreeNode(path: '/b', label: Line('B')),
            ],
            children: {
              '/a': [
                TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true),
                TreeNode(path: '/a/2', label: Line('A2'), isLeaf: true),
              ],
            },
          ),
          focused: true,
        )..setVisibleCount(10);
        await model.loadRoots();
      });

      test('expand loads children', () async {
        expect(model.flatNodes.length, equals(2));

        await model.expand('/a');

        expect(model.isExpanded('/a'), isTrue);
        expect(model.flatNodes.length, equals(4));
        expect(model.flatNodes[1].path, equals('/a/1'));
        expect(model.flatNodes[2].path, equals('/a/2'));
      });

      test('expand returns TreeExpandCmd', () async {
        final cmd = await model.expand('/a');

        expect(cmd, isA<TreeExpandCmd<String>>());
        expect((cmd! as TreeExpandCmd).path, equals('/a'));
      });

      test('collapse removes children from flat list', () async {
        await model.expand('/a');
        expect(model.flatNodes.length, equals(4));

        final cmd = model.collapse('/a');

        expect(model.isExpanded('/a'), isFalse);
        expect(model.flatNodes.length, equals(2));
        expect(cmd, isA<TreeCollapseCmd<String>>());
      });

      test('expand on leaf returns null', () async {
        await model.expand('/a');
        final cmd = await model.expand('/a/1');
        expect(cmd, isNull);
      });

      test('toggle expands then collapses', () async {
        await model.toggle('/a');
        expect(model.isExpanded('/a'), isTrue);

        await model.toggle('/a');
        expect(model.isExpanded('/a'), isFalse);
      });

      test('collapseAll clears all expansions', () async {
        await model.expand('/a');
        model.collapseAll();

        expect(model.isExpanded('/a'), isFalse);
        expect(model.flatNodes.length, equals(2));
      });
    });

    group('cursor movement', () {
      late TreeViewModel<String> model;

      setUp(() async {
        model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/a', label: Line('A')),
              TreeNode(path: '/b', label: Line('B')),
              TreeNode(path: '/c', label: Line('C')),
              TreeNode(path: '/d', label: Line('D')),
              TreeNode(path: '/e', label: Line('E')),
            ],
          ),
          focused: true,
        )..setVisibleCount(3);
        await model.loadRoots();
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

      setUp(() async {
        model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/a', label: Line('A')),
              TreeNode(path: '/b', label: Line('B'), isLeaf: true),
            ],
            children: {
              '/a': [
                TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true),
              ],
            },
          ),
          focused: true,
        )..setVisibleCount(10);
        await model.loadRoots();
      });

      test('right expands node', () async {
        model.update(keyMsg('right'));
        // Give async expand time to complete
        await Future<void>.delayed(Duration.zero);
        expect(model.isExpanded('/a'), isTrue);
      });

      test('l expands node (vim)', () async {
        model.update(keyMsg('l'));
        await Future<void>.delayed(Duration.zero);
        expect(model.isExpanded('/a'), isTrue);
      });

      test('left collapses expanded node', () async {
        await model.expand('/a');
        model.update(keyMsg('left'));
        expect(model.isExpanded('/a'), isFalse);
      });

      test('h collapses expanded node (vim)', () async {
        await model.expand('/a');
        model.update(keyMsg('h'));
        expect(model.isExpanded('/a'), isFalse);
      });

      test('left on collapsed moves to parent', () async {
        await model.expand('/a');
        model
          ..update(keyMsg('down')) // Move to /a/1
          ..update(keyMsg('left')); // Should move to parent /a
        expect(model.cursorNode?.path, equals('/a'));
      });

      test('o toggles expand', () async {
        model.update(keyMsg('o'));
        await Future<void>.delayed(Duration.zero);
        expect(model.isExpanded('/a'), isTrue);

        model.update(keyMsg('o'));
        expect(model.isExpanded('/a'), isFalse);
      });
    });

    group('expandPath', () {
      test('expands ancestors and scrolls to node', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/a', label: Line('A')),
            ],
            children: {
              '/a': [TreeNode(path: '/a/b', label: Line('B'))],
              '/a/b': [
                TreeNode(path: '/a/b/c', label: Line('C'), isLeaf: true),
              ],
            },
          ),
          focused: true,
        )..setVisibleCount(10);
        await model.loadRoots();

        await model.expandPath('/a/b/c');

        expect(model.isExpanded('/a'), isTrue);
        expect(model.isExpanded('/a/b'), isTrue);
        expect(model.cursorNode?.path, equals('/a/b/c'));
      });
    });

    group('search', () {
      test('finds matching nodes', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/apple', label: Line('Apple')),
              TreeNode(path: '/banana', label: Line('Banana')),
              TreeNode(path: '/apricot', label: Line('Apricot')),
            ],
          ),
        );
        await model.loadRoots();

        final results = model.search('ap');
        expect(results.length, equals(2));
        expect(results.map((n) => n.path), containsAll(['/apple', '/apricot']));
      });

      test('findFirst returns first match path', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [
              TreeNode(path: '/apple', label: Line('Apple')),
              TreeNode(path: '/apricot', label: Line('Apricot')),
            ],
          ),
        );
        await model.loadRoots();

        final path = model.findFirst('ap');
        expect(path, equals('/apple'));
      });

      test('returns empty for no match', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('A'))],
          ),
        );
        await model.loadRoots();

        expect(model.search('xyz'), isEmpty);
        expect(model.findFirst('xyz'), isNull);
      });
    });

    group('commands', () {
      test('enter returns TreeConfirmCmd', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('A'))],
          ),
          focused: true,
        )..setVisibleCount(10);
        await model.loadRoots();

        final cmd = model.update(keyMsg('enter'));
        expect(cmd, isA<TreeActionCmd<String>>());
        expect((cmd! as TreeActionCmd).path, equals('/a'));
      });

      test('unhandled key returns Unhandled', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('A'))],
          ),
          focused: true,
        );
        await model.loadRoots();

        final cmd = model.update(keyMsg('tab'));
        expect(cmd, isA<Unhandled>());
      });

      test('unfocused returns Unhandled', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: [TreeNode(path: '/a', label: Line('A'))],
          ),
        );
        await model.loadRoots();

        final cmd = model.update(keyMsg('down'));
        expect(cmd, isA<Unhandled>());
      });
    });

    group('scroll offset', () {
      test('adjusts when cursor moves below visible', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: List.generate(
              20,
              (i) => TreeNode(path: '/item$i', label: Line('Item $i')),
            ),
          ),
          focused: true,
        )..setVisibleCount(5);
        await model.loadRoots();

        for (var i = 0; i < 6; i++) {
          model.update(keyMsg('down'));
        }

        expect(model.cursor, equals(6));
        expect(model.scrollOffset, equals(2));
      });

      test('scrollState returns correct values', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(
            roots: List.generate(
              20,
              (i) => TreeNode(path: '/item$i', label: Line('Item $i')),
            ),
          ),
        )..setVisibleCount(5);
        await model.loadRoots();

        final state = model.getScrollState();
        expect(state.visible, equals(5));
        expect(state.total, equals(20));
        expect(state.offset, equals(0));
      });
    });

    group('empty tree', () {
      test('handles empty data source', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(roots: []),
          focused: true,
        );
        await model.loadRoots();

        expect(model.flatNodes, isEmpty);
        expect(model.cursorNode, isNull);
      });

      test('navigation on empty tree is safe', () async {
        final model = TreeViewModel<String>(
          dataSource: TestTreeDataSource(roots: []),
          focused: true,
        )..setVisibleCount(5);
        await model.loadRoots();

        // Should not throw
        model
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

/// Test data source that counts calls.
class _CountingSource extends TreeDataSource<String> {
  final void Function() onGetRoots;

  _CountingSource(this.onGetRoots);

  @override
  Future<List<TreeNode<String>>> getRoots() async {
    onGetRoots();
    return [TreeNode(path: '/a', label: Line('A'))];
  }

  @override
  Future<List<TreeNode<String>>> getChildren(String path) async => [];
}
