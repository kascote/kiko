import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// A routed wheel/button message over the widget, at local (0, 0).
PointerMsg pointer(PointerAction action) => PointerMsg(global: Position.origin, action: action, local: Position.origin);

/// A routed button/move message at a given local cell.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) =>
    PointerMsg(global: Position(x, y), action: action, local: Position(x, y));

/// [count] leaf roots, enough to fill more than one viewport.
List<TreeNode<String>> leaves(int count) =>
    List.generate(count, (i) => TreeNode(path: '/n$i', label: Line('n$i'), isLeaf: true));

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
  group('mouse wheel + scroll', () {
    test('a wheel notch scrolls an unfocused tree without moving the cursor', () {
      final model = modelWith(leaves(20), focused: false, visibleCount: 5);

      final result = model.update(pointer(PointerAction.wheelDown));

      expect(
        result,
        isA<Handled>().having((h) => h.cmd, 'cmd', isNull),
        reason: 'a tree pages on expand, not on scroll',
      );
      expect(model.scrollOffset, equals(3), reason: 'one notch is three rows');
      expect(model.cursor, equals(0), reason: 'the wheel never touches the keyboard cursor');
    });

    test('scrollBy clamps at both ends', () {
      final model = modelWith(leaves(10), visibleCount: 4);

      expect((model..scrollBy(-5)).scrollOffset, equals(0), reason: 'cannot scroll above the first node');
      expect(
        (model..scrollBy(100)).scrollOffset,
        equals(6),
        reason: 'stops at flattened length - visibleCount (10 - 4)',
      );
    });

    test('localToRow maps a local position to the flattened node row', () {
      final model = modelWith(leaves(10), visibleCount: 5)..scrollBy(2);

      expect(model.localToRow(Position.origin), equals(2));
      expect(model.localToRow(const Position(2, 3)), equals(5), reason: 'row = scrollOffset + local.y');
      expect(model.localToRow(const Position(0, -1)), isNull, reason: 'above the first node');
      expect(model.localToRow(const Position(0, 8)), isNull, reason: 'past the last node');
    });

    test('a horizontal wheel and a click past the last node are declined', () {
      final model = modelWith(leaves(10), visibleCount: 4);

      expect(model.update(pointer(PointerAction.wheelLeft)), isA<Declined>());
      expect(model.update(pointerAt(PointerAction.down, y: 20)), isA<Declined>(), reason: 'no node under the click');
      expect(model.scrollOffset, equals(0), reason: 'neither moved the viewport');
    });

    group('wheel decline at the scroll limit (mikos 0175 / G2)', () {
      test('at the top, wheel-up declines while wheel-down handles', () {
        final model = modelWith(leaves(10), visibleCount: 5);
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Declined>());
        expect(model.scrollOffset, equals(0), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Handled>());
      });

      test('at the bottom, wheel-down declines while wheel-up handles', () {
        final model = modelWith(leaves(10), visibleCount: 5)..scrollBy(100); // pin to the bottom edge
        final atBottom = model.scrollOffset;
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Declined>());
        expect(model.scrollOffset, equals(atBottom), reason: 'a declined notch moves nothing');
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Handled>());
      });

      test('content that fits entirely declines both directions', () {
        final model = modelWith(leaves(3), visibleCount: 5);
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Declined>());
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Declined>());
      });

      test('a partial scroll still consumes, even though it moves fewer rows than a full notch', () {
        // scrollOffset 4, max 5 (10 leaves - 5 visible): a 3-row notch down can
        // only move 1 row, but 1 row is not a no-op, so it must still handle.
        final model = modelWith(leaves(10), visibleCount: 5)..scrollBy(4);
        expect(model.scrollOffset, equals(4));

        final result = model.update(pointer(PointerAction.wheelDown));
        expect(result, isA<Handled>());
        expect(model.scrollOffset, equals(5), reason: 'moved the 1 remaining row');
      });

      test('mid-content, both directions handle', () {
        final model = modelWith(leaves(10), visibleCount: 5)..scrollBy(2);
        expect(model.update(pointer(PointerAction.wheelDown)), isA<Handled>());
        expect(model.update(pointer(PointerAction.wheelUp)), isA<Handled>());
      });
    });
  });

  group('mouse click + hover', () {
    // A branch root followed by two leaves; the branch's expand indicator sits
    // at local columns 0-1 (depth 0), its body from column 2 on.
    TreeViewModel<String> tree({bool focused = true}) => TreeViewModel<String>(id: 'nav', focused: focused)
      ..setVisibleCount(10)
      ..applyRoots(<TreeNode<String>>[
        TreeNode(path: '/A', label: Line('Alpha')),
        TreeNode(path: '/b', label: Line('Beta'), isLeaf: true),
        TreeNode(path: '/c', label: Line('Gamma'), isLeaf: true),
      ]);

    test('a click on a node body moves the cursor there and emits TreeActionCmd', () {
      final model = tree();

      // Column 4 on row 1 is well past the leaf's two-space indent — the body.
      final down = model.update(pointerAt(PointerAction.down, x: 4, y: 1));

      expect(
        down,
        isA<Handled>().having((h) => h.cmd, 'cmd', isA<TreeActionCmd<String>>().having((c) => c.path, 'path', '/b')),
      );
      expect(model.cursor, equals(1));
    });

    test('a click on the expand indicator toggles the node', () {
      final model = tree();

      // Column 0 on row 0 is the branch's expand arrow.
      final down = model.update(pointer(PointerAction.down));

      expect(model.isExpanded('/A'), isTrue, reason: 'the indicator click expanded the node');
      expect(
        down,
        isA<Handled>().having((h) => h.cmd, 'cmd', isA<Batch>()),
        reason: 'expanding an uncached node emits the expand event plus a load request',
      );

      // A second indicator click collapses it, emitting a collapse event.
      final again = model.update(pointer(PointerAction.down));
      expect(model.isExpanded('/A'), isFalse);
      expect(
        again,
        isA<Handled>().having((h) => h.cmd, 'cmd', isA<TreeCollapseCmd<String>>().having((c) => c.path, 'path', '/A')),
      );
    });

    test('a click past the last node is declined', () {
      expect(tree().update(pointerAt(PointerAction.down, y: 20)), isA<Declined>());
    });

    test('a click activates on an unfocused tree', () {
      final model = tree(focused: false)..update(pointerAt(PointerAction.down, x: 4, y: 2));

      expect(model.cursor, equals(2), reason: 'selection changes without a prior focus');
    });

    test('a pointer sets the hover row; a leave clears it', () {
      final model = tree()..update(pointerAt(PointerAction.move, y: 2));
      expect(model.hoverRow, equals(2));

      model.update(pointerAt(PointerAction.move, y: 20));
      expect(model.hoverRow, isNull, reason: 'a move past the last node clears the hover');

      model.update(const PointerLeaveMsg('nav'));
      expect(model.hoverRow, isNull);
    });
  });

  group('TreeViewModel', () {
    group('initialization', () {
      test('default state', () {
        final model = TreeViewModel<String>();
        expect(model.flatNodes, isEmpty);
        expect(model.cursor, equals(0));
        expect(model.cursorNode, isNull);
        expect(model.focused, isFalse);
        expect(model.isLoaded, isFalse);
        expect(model.isLoading(), isFalse);
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

      test('clears the roots-loading slot', () {
        final model = TreeViewModel<String>()..loadRoots();
        expect(model.isLoading(const RootsKey()), isTrue);

        model.applyRoots([TreeNode(path: '/a', label: Line('A'))]);

        expect(model.isLoading(const RootsKey()), isFalse);
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

      test('expand on uncached children batches an expand event + load request', () {
        final cmd = model.expand('/a');

        // Cache miss → the expansion event AND a load request, wrapped together.
        expect(cmd, isA<Batch>());
        final cmds = (cmd! as Batch).cmds;
        expect(cmds, hasLength(2));
        expect(cmds[0], isA<TreeExpandCmd<String>>());
        expect((cmds[0] as TreeExpandCmd).path, equals('/a'));
        expect(cmds[1], equals(LoadRequest(model.id, key: const PathKey('/a'))));

        expect(model.isExpanded('/a'), isTrue);
        expect(model.isPathLoading('/a'), isTrue);
      });

      test('expand performs no I/O — real children appear only via applyChildren', () {
        model.expand('/a');

        // The model fetched nothing: a loading placeholder shows, but the real
        // children are absent until the app delivers them. Proves the model
        // never performs I/O or mutates outside the update loop.
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

      test('re-expanding cached children emits an expand event but no load request', () {
        expandLoaded(model, '/a', children['/a']!);
        model.collapse('/a');

        final cmd = model.expand('/a');

        // Cache hit → a bare expansion event, never a Batch with a load request.
        expect(cmd, isA<TreeExpandCmd<String>>());
        expect(cmd, isNot(isA<Batch>()));
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

    group('load lifecycle', () {
      TreeViewModel<String> rootedAt(String path) => modelWith([TreeNode(path: path, label: Line(path))]);

      LoadResult<List<TreeNode<String>>> childError(TreeViewModel<String> m, String path, Object error) =>
          LoadResult<List<TreeNode<String>>>(m.id, key: PathKey(path), error: error);

      group('roots', () {
        test('loadRoots marks the roots slot loading and requests a fetch', () {
          final model = TreeViewModel<String>();
          final req = model.loadRoots();

          expect(req, equals(LoadRequest(model.id, key: const RootsKey())));
          expect(model.isLoading(const RootsKey()), isTrue);
          expect(model.isLoading(), isTrue); // any slot
          expect(model.isLoaded, isFalse);
        });

        test('a failed roots load records the error and stays unloaded', () {
          final model = TreeViewModel<String>()..loadRoots();
          model.applyLoad(LoadResult<List<TreeNode<String>>>(model.id, key: const RootsKey(), error: 'no net'));

          expect(model.isLoading(const RootsKey()), isFalse);
          expect(model.errorFor(const RootsKey()), equals('no net'));
          expect(model.isLoaded, isFalse);
        });
      });

      test('isLoading() reports any in-flight child; keyed isolates each', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
        ])..expand('/a');

        expect(model.isLoading(), isTrue);
        expect(model.isLoading(const PathKey('/a')), isTrue);
        expect(model.isLoading(const PathKey('/b')), isFalse);
        expect(model.isLoading(const RootsKey()), isFalse); // roots already done
      });

      test('failed child load shows an error placeholder, not an eternal spinner', () {
        final model = rootedAt('/a')..expand('/a');
        expect(model.isPathLoading('/a'), isTrue);

        model.applyLoad(childError(model, '/a', 'network down'));

        expect(model.isPathLoading('/a'), isFalse); // stopped spinning
        expect(model.errorFor(const PathKey('/a')), equals('network down'));
        expect(model.flatNodes.any((n) => n.path == '/a/_error'), isTrue);
        expect(model.flatNodes.any((n) => n.path == '/a/_loading'), isFalse);
      });

      test('a result for a non-loading path is dropped (staleness guard)', () {
        // No expand → slot idle. A stray result must not install.
        final model = rootedAt('/a')..applyChildren('/a', [TreeNode(path: '/a/x', label: Line('X'), isLeaf: true)]);

        expect(model.flatNodes.any((n) => n.path == '/a/x'), isFalse);
        // Nothing cached: expanding now starts a fresh load.
        expect(model.expand('/a'), isA<Batch>());
        expect(model.isPathLoading('/a'), isTrue);
      });

      test('a result addressed to another model is ignored', () {
        final model = rootedAt('/a')
          ..expand('/a')
          ..applyLoad(
            LoadResult<List<TreeNode<String>>>(
              'someone-else',
              key: const PathKey('/a'),
              data: [TreeNode(path: '/a/x', label: Line('X'), isLeaf: true)],
            ),
          );

        expect(model.isPathLoading('/a'), isTrue); // still waiting
        expect(model.flatNodes.any((n) => n.path == '/a/x'), isFalse);
      });

      test('collapse cancels a pending load; a late result is dropped', () {
        final model = rootedAt('/a')..expand('/a');
        expect(model.isPathLoading('/a'), isTrue);

        model.collapse('/a');
        expect(model.isPathLoading('/a'), isFalse); // cancelled

        // The original fetch resolves late — dropped, nothing cached.
        model.applyChildren('/a', [TreeNode(path: '/a/late', label: Line('Late'), isLeaf: true)]);
        expect(model.expand('/a'), isA<Batch>()); // re-expand refetches
      });

      test('collapse clears a failed load so re-expand retries', () {
        final model = rootedAt('/a')..expand('/a');
        model.applyLoad(childError(model, '/a', 'boom'));
        expect(model.errorFor(const PathKey('/a')), equals('boom'));

        model.collapse('/a');
        expect(model.errorFor(const PathKey('/a')), isNull); // cleared

        expect(model.expand('/a'), isA<Batch>()); // fresh retry
        expect(model.isPathLoading('/a'), isTrue);
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
        final result = model.update(keyMsg('right'));
        // Uncached → Batch(expand event + load request).
        expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isA<Batch>()));
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
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        // Load the subtree the way an app would — each load is started by expand.
        expandLoaded(model, '/a', [TreeNode(path: '/a/b', label: Line('B'))]);
        expandLoaded(model, '/a/b', [
          TreeNode(path: '/a/b/c', label: Line('C'), isLeaf: true),
        ]);

        // Collapse everything, then reveal the deep node from the cache.
        model
          ..collapseAll()
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

        final result = model.update(keyMsg('enter'));
        expect(
          result,
          isA<Handled>().having((h) => h.cmd, 'cmd', isA<TreeActionCmd<String>>()),
        );
        final cmd = (result as Handled).cmd;
        expect((cmd! as TreeActionCmd).path, equals('/a'));
      });

      test('unhandled key declines', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        expect(model.update(keyMsg('tab')), isA<Declined>());
      });

      test('unfocused declines', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
        ], focused: false);
        expect(model.update(keyMsg('down')), isA<Declined>());
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
