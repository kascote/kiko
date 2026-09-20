import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';
import '../../support/load.dart';
import '../../support/viewport.dart';

/// Helper to create a KeyMsg.
KeyMsg keyMsg(String key) => KeyMsg(key);

/// A routed wheel/button message over the widget, at local (0, 0), on no marked
/// part.
PointerMsg pointer(PointerAction action) => PointerMsg(global: Position.origin, action: action, local: Position.origin);

/// A routed button/move message at a given local cell, on no marked part.
PointerMsg pointerAt(PointerAction action, {int x = 0, int y = 0}) =>
    PointerMsg(global: Position(x, y), action: action, local: Position(x, y));

/// A routed button/move message over the node at [row]'s body, the way the
/// framework delivers it once the view marked the row and the router resolved it.
PointerMsg pointerOnRow(PointerAction action, int row) =>
    PointerMsg(global: Position.origin, action: action, local: Position.origin, region: RowRegion(row));

/// A routed button/move message over the expand indicator of the node at [row].
PointerMsg pointerOnIndicator(PointerAction action, int row) =>
    PointerMsg(global: Position.origin, action: action, local: Position.origin, region: TreeIndicatorRegion(row));

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
  ..viewport(rows: visibleCount)
  ..loadRoots()
  ..applyRoots(roots);

/// Expands [path] and returns the request the expansion made.
LoadRequest expandAsking(TreeViewModel<String> m, String path) => requestIn(m.expand(path));

/// Expands [path] and immediately resolves the child load with [children] —
/// what the app does in response to the [TreeExpandEvent] load request.
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
        isA<Handled>().having((h) => h.events, 'events', isEmpty),
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
      ..viewport(rows: 10)
      ..loadRoots()
      ..applyRoots(<TreeNode<String>>[
        TreeNode(path: '/A', label: Line('Alpha')),
        TreeNode(path: '/b', label: Line('Beta'), isLeaf: true),
        TreeNode(path: '/c', label: Line('Gamma'), isLeaf: true),
      ]);

    test('a click on a node body moves the cursor there and emits TreeActivateEvent', () {
      final model = tree();

      final down = model.update(pointerOnRow(PointerAction.down, 1));

      expect(
        down,
        isA<Handled>().having(
          (h) => h.events,
          'events',
          [isA<TreeActivateEvent<String>>().having((c) => c.path, 'path', '/b')],
        ),
      );
      expect(model.cursor, equals(1));
    });

    test('a press on the expand indicator toggles the node', () {
      final model = tree();

      final down = model.update(pointerOnIndicator(PointerAction.down, 0));

      expect(model.isExpanded('/A'), isTrue, reason: 'the indicator press expanded the node');
      expect(
        down,
        isA<Handled>().having((h) => h.events, 'events', [isA<TreeExpandEvent<String>>(), isA<LoadRequest>()]),
        reason: 'expanding an uncached node emits the expand event plus a load request',
      );

      // A second indicator press collapses it, emitting a collapse event.
      final again = model.update(pointerOnIndicator(PointerAction.down, 0));
      expect(model.isExpanded('/A'), isFalse);
      expect(
        again,
        isA<Handled>().having(
          (h) => h.events,
          'events',
          [isA<TreeCollapseEvent<String>>().having((c) => c.path, 'path', '/A')],
        ),
      );
    });

    test('a hover over the indicator still highlights its row and does not toggle', () {
      final model = tree();

      final move = model.update(pointerOnIndicator(PointerAction.move, 0));

      expect(model.hoverRow, equals(0), reason: 'the indicator is row-scoped, so a hover highlights the row');
      expect(model.isExpanded('/A'), isFalse, reason: 'a hover never toggles');
      expect(move, isA<Handled>().having((h) => h.events, 'events', isEmpty));
    });

    test('a press on no marked part (the tail) is declined', () {
      expect(tree().update(pointer(PointerAction.down)), isA<Declined>());
    });

    test('a click activates on an unfocused tree', () {
      final model = tree(focused: false)..update(pointerOnRow(PointerAction.down, 2));

      expect(model.cursor, equals(2), reason: 'selection changes without a prior focus');
    });

    test('a pointer sets the hover row; a leave clears it', () {
      final model = tree()..update(pointerOnRow(PointerAction.move, 2));
      expect(model.hoverRow, equals(2));

      model.update(pointer(PointerAction.move));
      expect(model.hoverRow, isNull, reason: 'a move over no marked part clears the hover');

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

      test('expand on uncached children returns the expand event + load request', () {
        final events = model.expand('/a');

        // Cache miss → the expansion event AND a load request.
        expect(events, hasLength(2));
        expect(events[0], isA<TreeExpandEvent<String>>());
        expect((events[0] as TreeExpandEvent).path, equals('/a'));
        expect(events[1], isRequestFor(model.id, const PathKey('/a')));

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

        final events = model.expand('/a');

        // Cache hit → a bare expansion event, no load request.
        expect(events, [isA<TreeExpandEvent<String>>()]);
        expect(model.isExpanded('/a'), isTrue);
        expect(model.flatNodes.length, equals(4));
      });

      test('collapse removes children from flat list', () {
        expandLoaded(model, '/a', children['/a']!);
        expect(model.flatNodes.length, equals(4));

        final events = model.collapse('/a');

        expect(model.isExpanded('/a'), isFalse);
        expect(model.flatNodes.length, equals(2));
        expect(events, [isA<TreeCollapseEvent<String>>()]);
      });

      test('expand on leaf returns nothing', () {
        expandLoaded(model, '/a', children['/a']!);
        final events = model.expand('/a/1');
        expect(events, isEmpty);
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

    group('viewport reports', () {
      test('stores the count and returns no events', () {
        final model = TreeViewModel<String>(id: 'nav')
          ..loadRoots()
          ..applyRoots(leaves(30));

        final verdict = model.update(const ViewportChanged('nav', rows: 7));

        expect(
          verdict,
          isA<Handled>().having((h) => h.events, 'events', isEmpty),
          reason: 'a tree pages on expand, never on its viewport',
        );
        expect(model.visibleCount, equals(7));
      });

      test('a report addressed to another id is declined; the scoped path of its own id is accepted', () {
        final model = TreeViewModel<String>(id: 'nav');

        expect(model.update(const ViewportChanged('other', rows: 7)), isA<Declined>());
        expect(model.visibleCount, equals(0));
        expect(model.update(const ViewportChanged('side/nav', rows: 7)), isA<Handled>());
        expect(model.visibleCount, equals(7));
      });
    });

    group('load lifecycle', () {
      TreeViewModel<String> rootedAt(String path) => modelWith([TreeNode(path: path, label: Line(path))]);

      LoadResult<List<TreeNode<String>>> childError(LoadRequest request, Object error) =>
          LoadResult<List<TreeNode<String>>>.failed(request, error);

      group('roots', () {
        test('loadRoots marks the roots slot loading and requests a fetch', () {
          final model = TreeViewModel<String>();
          final req = model.loadRoots();

          expect(req, isRequestFor(model.id, const RootsKey()));
          expect(model.isLoading(const RootsKey()), isTrue);
          expect(model.isLoading(), isTrue); // any slot
          expect(model.isLoaded, isFalse);
        });

        test('a failed roots load records the error and stays unloaded', () {
          final model = TreeViewModel<String>();
          model.update(LoadResult<List<TreeNode<String>>>.failed(model.loadRoots(), 'no net'));

          expect(model.isLoading(const RootsKey()), isFalse);
          expect(model.errorFor(const RootsKey()), equals('no net'));
          expect(model.isLoaded, isFalse);
        });

        test('a roots result for an idle slot installs nothing', () {
          final model = TreeViewModel<String>()..applyRoots([TreeNode(path: '/a', label: Line('A'))]);

          expect(model.isLoaded, isFalse, reason: 'nothing asked for these roots');
          expect(model.flatNodes, isEmpty);
        });

        test('loadRoots while the roots are in flight returns the request and keeps the one slot', () {
          final model = TreeViewModel<String>();
          final first = model.loadRoots();
          final again = model.loadRoots();

          expect(again, equals(first));
          expect(model.isLoading(const RootsKey()), isTrue);

          model.applyRoots([TreeNode(path: '/a', label: Line('A'))]);
          expect(model.isLoaded, isTrue);
          expect(model.isLoading(const RootsKey()), isFalse);
        });

        test('loadRoots on a loaded, idle tree asserts', () {
          final model = TreeViewModel<String>()
            ..loadRoots()
            ..applyRoots([TreeNode(path: '/a', label: Line('A'))]);

          expect(model.loadRoots, throwsA(isA<AssertionError>()), reason: 'call reset() first');
        });

        test('a cancelled roots result resolves the slot and installs nothing', () {
          final model = TreeViewModel<String>();
          model.update(LoadResult<List<TreeNode<String>>>.cancelled(model.loadRoots()));

          expect(model.isLoading(const RootsKey()), isFalse);
          expect(model.errorFor(const RootsKey()), isNull);
          expect(model.isLoaded, isFalse);
          expect(model.loadRoots(), isRequestFor(model.id, const RootsKey()), reason: 'asks again');
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
        final model = rootedAt('/a');
        final req = expandAsking(model, '/a');
        expect(model.isPathLoading('/a'), isTrue);

        model.update(childError(req, 'network down'));

        expect(model.isPathLoading('/a'), isFalse); // stopped spinning
        expect(model.errorFor(const PathKey('/a')), equals('network down'));
        expect(model.flatNodes.any((n) => n.path == '/a/_error'), isTrue);
        expect(model.flatNodes.any((n) => n.path == '/a/_loading'), isFalse);
      });

      test('a refused child load clears the slot and caches nothing', () {
        final model = rootedAt('/a');
        final req = expandAsking(model, '/a');
        expect(model.isPathLoading('/a'), isTrue);

        model.update(LoadResult<List<TreeNode<String>>>.cancelled(req));

        expect(model.isPathLoading('/a'), isFalse, reason: 'the slot returns to idle');
        expect(model.errorFor(const PathKey('/a')), isNull, reason: 'nothing failed');
        expect(model.flatNodes.any((n) => n.path == '/a/_error'), isFalse);
        // The branch is expanded with nothing cached and nothing coming: it
        // paints the stalled placeholder, never the loading line and never
        // nothing (nothing would read as an empty branch).
        expect(model.flatNodes.any((n) => n.path == '/a/_loading'), isFalse);
        expect(model.flatNodes.any((n) => n.path == '/a/_stalled'), isTrue);
        // Nothing was cached, so collapsing and expanding asks again.
        model.collapse('/a');
        expect(model.expand('/a'), contains(isA<LoadRequest>()));
        expect(model.isPathLoading('/a'), isTrue);
      });

      test('branchStatus names each load state: filling, ready, failed, stalled', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
        ]);

        expect(model.branchStatus('/a'), SliceStatus.stalled, reason: 'nothing cached, nothing coming');

        model.expand('/a');
        expect(model.branchStatus('/a'), SliceStatus.filling);

        model.applyChildren('/a', [TreeNode(path: '/a/x', label: Line('X'), isLeaf: true)]);
        expect(model.branchStatus('/a'), SliceStatus.ready);

        model.update(childError(expandAsking(model, '/b'), 'boom'));
        expect(model.branchStatus('/b'), SliceStatus.failed);

        model.collapse('/b');
        expect(model.branchStatus('/b'), SliceStatus.stalled, reason: 'collapse clears the failure');
      });

      test('a result for a non-loading path is dropped (staleness guard)', () {
        // No expand → slot idle. A stray result must not install.
        final model = rootedAt('/a')..applyChildren('/a', [TreeNode(path: '/a/x', label: Line('X'), isLeaf: true)]);

        expect(model.flatNodes.any((n) => n.path == '/a/x'), isFalse);
        // Nothing cached: expanding now starts a fresh load.
        expect(model.expand('/a'), contains(isA<LoadRequest>()));
        expect(model.isPathLoading('/a'), isTrue);
      });

      test('a result addressed to another model is declined and ignored', () {
        final model = rootedAt('/a')..expand('/a');
        final verdict = model.update(
          LoadResult<List<TreeNode<String>>>.ok(requestFor('someone-else', key: const PathKey('/a')), [
            TreeNode(path: '/a/x', label: Line('X'), isLeaf: true),
          ]),
        );

        expect(verdict, isA<Declined>(), reason: 'a message addressed elsewhere is not one this tree understands');
        expect(model.isPathLoading('/a'), isTrue); // still waiting
        expect(model.flatNodes.any((n) => n.path == '/a/x'), isFalse);
      });

      test('every result addressed to the tree is consumed, installed or not', () {
        final model = rootedAt('/a');
        final req = expandAsking(model, '/a');

        expect(model.update(childError(req, 'boom')), isA<Handled>());
        expect(
          model.update(
            LoadResult<List<TreeNode<String>>>.ok(requestFor(model.id, key: const PathKey('/never')), const []),
          ),
          isA<Handled>(),
          reason: "a path not in flight is dropped, but the message was the tree's own",
        );
        expect(model.update(LoadResult<Object?>.ok(requestFor(model.id, key: 'not a tree key'), null)), isA<Handled>());
      });

      test('collapse cancels a pending load; a late result is dropped', () {
        final model = rootedAt('/a')..expand('/a');
        expect(model.isPathLoading('/a'), isTrue);

        model.collapse('/a');
        expect(model.isPathLoading('/a'), isFalse); // cancelled

        // The original fetch resolves late — dropped, nothing cached.
        model.applyChildren('/a', [TreeNode(path: '/a/late', label: Line('Late'), isLeaf: true)]);
        expect(model.expand('/a'), contains(isA<LoadRequest>())); // re-expand refetches
      });

      test('collapse clears a failed load so re-expand retries', () {
        final model = rootedAt('/a');
        model.update(childError(expandAsking(model, '/a'), 'boom'));
        expect(model.errorFor(const PathKey('/a')), equals('boom'));

        model.collapse('/a');
        expect(model.errorFor(const PathKey('/a')), isNull); // cleared

        expect(model.expand('/a'), contains(isA<LoadRequest>())); // fresh retry
        expect(model.isPathLoading('/a'), isTrue);
      });

      group('payload mismatch', () {
        test('a wrong-shaped roots payload fails the roots slot and installs nothing', () {
          final model = TreeViewModel<String>();
          model.update(LoadResult<Object?>.ok(model.loadRoots(), const <int>[1, 2]));

          expect(model.isLoading(const RootsKey()), isFalse, reason: 'the slot resolved');
          expect(model.errorFor(const RootsKey()), isA<PayloadMismatch>());
          expect(model.isLoaded, isFalse, reason: 'a mismatch is not an empty tree');
          expect(model.flatNodes, isEmpty);
        });

        test('a null children payload on a successful result fails the branch', () {
          final model = rootedAt('/a');
          model.update(LoadResult<Object?>.ok(expandAsking(model, '/a'), null));

          expect(model.isPathLoading('/a'), isFalse);
          expect(model.errorFor(const PathKey('/a')), isA<PayloadMismatch>());
          expect(model.branchStatus('/a'), SliceStatus.failed);
          final under = model.flatNodes.where((n) => n.path.startsWith('/a/')).map((n) => n.path);
          expect(under, equals(['/a/_error']), reason: 'only the error placeholder, no children installed');
        });

        test('a wrong-shaped children payload fails the branch, not the app', () {
          final model = rootedAt('/a');
          model.update(LoadResult<Object?>.ok(expandAsking(model, '/a'), 'not a list'));

          expect(model.errorFor(const PathKey('/a')), isA<PayloadMismatch>());
          expect('${model.errorFor(const PathKey('/a'))}', contains('expected List<TreeNode<String>>'));
          expect(model.collapse('/a'), [isA<TreeCollapseEvent<String>>()]);
          expect(model.expand('/a'), contains(isA<LoadRequest>()), reason: 'collapse and expand retries the load');
        });
      });
    });

    group('reset', () {
      test('clears every observable and keeps the viewport count', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
        ], visibleCount: 3);
        expandLoaded(model, '/a', [
          TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true),
          TreeNode(path: '/a/2', label: Line('A2'), isLeaf: true),
        ]);
        model
          ..expand('/b') // a child fetch in flight
          ..update(keyMsg('end'))
          ..hoverRow = 1;
        expect(model.scrollOffset, greaterThan(0));

        model.reset();

        expect(model.isLoaded, isFalse);
        expect(model.flatNodes, isEmpty);
        expect(model.isExpanded('/a'), isFalse);
        expect(model.isExpanded('/b'), isFalse);
        expect(model.isLoading(), isFalse, reason: 'every slot is retired');
        expect(model.cursor, equals(0));
        expect(model.cursorNode, isNull);
        expect(model.scrollOffset, equals(0));
        expect(model.hoverRow, isNull);
        expect(model.visibleCount, equals(3), reason: 'the viewport is a layout fact, not data');
        expect(model.focused, isTrue);
      });

      test('roots load again after a reset, exactly as at init', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))])..reset();

        expect(model.loadRoots(), isRequestFor(model.id, const RootsKey()));
        expect(model.isLoading(const RootsKey()), isTrue);

        model.applyRoots([TreeNode(path: '/z', label: Line('Z'))]);
        expect(model.flatNodes.map((n) => n.path), equals(['/z']));
      });

      test('a late child result after a reset is dropped', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))])..expand('/a');
        expect(model.isPathLoading('/a'), isTrue);

        model
          ..reset()
          ..loadRoots()
          ..applyRoots([TreeNode(path: '/a', label: Line('A'))])
          ..applyChildren('/a', [TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true)]);

        expect(model.isExpanded('/a'), isFalse);
        expect(model.flatNodes.map((n) => n.path), equals(['/a']));
        expect(model.expand('/a'), contains(isA<LoadRequest>()), reason: 'nothing was cached by the late result');
      });

      test('a late roots result after a reset is dropped', () {
        final model = TreeViewModel<String>()
          ..loadRoots()
          ..reset()
          ..applyRoots([TreeNode(path: '/a', label: Line('A'))]);

        expect(model.isLoaded, isFalse);
        expect(model.flatNodes, isEmpty);
      });

      test('roots asked again after a reset: the old fetch is dropped, the new one installs', () {
        final model = TreeViewModel<String>();
        final old = model.loadRoots();
        model.reset();
        final fresh = model.loadRoots();

        model.update(LoadResult<List<TreeNode<String>>>.ok(old, [TreeNode(path: '/old', label: Line('Old'))]));
        expect(model.isLoaded, isFalse, reason: 'the old asking no longer exists');
        expect(model.isLoading(const RootsKey()), isTrue, reason: 'the live asking still waits');

        model.update(LoadResult<List<TreeNode<String>>>.ok(fresh, [TreeNode(path: '/new', label: Line('New'))]));
        expect(model.flatNodes.map((n) => n.path), equals(['/new']));
        expect(model.isLoading(const RootsKey()), isFalse);
      });
    });

    group('reload', () {
      final kids = <TreeNode<String>>[
        TreeNode(path: '/a/1', label: Line('A1'), isLeaf: true),
        TreeNode(path: '/a/2', label: Line('A2'), isLeaf: true),
      ];

      /// `/a` expanded with [kids] cached, then `/b`, on a five-row viewport.
      TreeViewModel<String> openTree() {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B')),
        ], visibleCount: 5);
        expandLoaded(model, '/a', kids);
        return model;
      }

      List<String> paths(TreeViewModel<String> m) => m.flatNodes.map((n) => n.path).toList();

      test('an expanded branch paints its loading placeholder, asks once, and installs in place', () {
        final model = openTree()
          ..update(keyMsg('down'))
          ..update(keyMsg('down')) // on /a/2
          ..hoverRow = 3;

        final events = model.reload('/a');

        expect(events, [isRequestFor(model.id, const PathKey('/a'))]);
        expect(model.isExpanded('/a'), isTrue, reason: 'the branch stays open');
        expect(model.branchStatus('/a'), SliceStatus.filling);
        expect(paths(model), equals(['/a', '/a/_loading', '/b']));
        expect(model.cursorNode?.path, equals('/a'), reason: 'a cursor inside the subtree lands on the branch');
        expect(model.hoverRow, isNull);

        model.applyChildren('/a', [TreeNode(path: '/a/3', label: Line('A3'), isLeaf: true)]);

        expect(paths(model), equals(['/a', '/a/3', '/b']));
        expect(model.branchStatus('/a'), SliceStatus.ready);
        expect(model.cursorNode?.path, equals('/a'));
      });

      test('a cursor outside the branch stays on its node, not its row', () {
        final model = openTree()
          ..update(keyMsg('end')) // on /b, row 3
          ..reload('/a');

        expect(model.cursorNode?.path, equals('/b'));
        expect(model.cursor, equals(2), reason: 'two child rows became one placeholder row');
      });

      test('the scroll offset follows the cursor onto the shorter row list', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/b', label: Line('B'), isLeaf: true),
        ], visibleCount: 2);
        expandLoaded(model, '/a', [
          for (final n in leaves(6)) TreeNode<String>(path: '/a${n.path}', label: n.label, isLeaf: true),
        ]);
        model.update(keyMsg('end')); // /b at row 7, offset 6
        expect(model.scrollOffset, equals(6));

        model.reload('/a');

        expect(paths(model), equals(['/a', '/a/_loading', '/b']));
        expect(model.cursorNode?.path, equals('/b'));
        expect(model.scrollOffset, equals(1), reason: 'the cursor row is in view and the offset is in range');
      });

      test('a failed branch reloads: one request, then the children install', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        model.update(LoadResult<List<TreeNode<String>>>.failed(expandAsking(model, '/a'), 'boom'));
        expect(model.branchStatus('/a'), SliceStatus.failed);

        expect(model.reload('/a'), [isRequestFor(model.id, const PathKey('/a'))]);
        expect(model.branchStatus('/a'), SliceStatus.filling);
        expect(model.errorFor(const PathKey('/a')), isNull);

        model.applyChildren('/a', kids);
        expect(paths(model), equals(['/a', '/a/1', '/a/2']));
      });

      test('a refused branch reloads the same way', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        model.update(LoadResult<List<TreeNode<String>>>.cancelled(expandAsking(model, '/a')));
        expect(model.branchStatus('/a'), SliceStatus.stalled);

        expect(model.reload('/a'), hasLength(1));
        expect(model.branchStatus('/a'), SliceStatus.filling);
      });

      test('a collapsed branch only forgets; the next expand re-fetches', () {
        final model = openTree()..collapse('/a');

        expect(model.reload('/a'), isEmpty);
        expect(model.isExpanded('/a'), isFalse);
        expect(paths(model), equals(['/a', '/b']));

        expect(model.expand('/a'), contains(isRequestFor(model.id, const PathKey('/a'))));
        expect(model.branchStatus('/a'), SliceStatus.filling);
      });

      test('a branch already loading returns nothing and keeps its one request', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))])..expand('/a');

        expect(model.reload('/a'), isEmpty);
        expect(model.isPathLoading('/a'), isTrue);

        model.applyChildren('/a', kids);
        expect(paths(model), equals(['/a', '/a/1', '/a/2']), reason: 'the in-flight result still installs');
      });

      test('a leaf, a placeholder row and a missing path return nothing', () {
        final model = modelWith([
          TreeNode(path: '/a', label: Line('A')),
          TreeNode(path: '/leaf', label: Line('Leaf'), isLeaf: true),
        ])..expand('/a');
        expect(paths(model), equals(['/a', '/a/_loading', '/leaf']));

        expect(model.reload('/leaf'), isEmpty);
        expect(model.reload('/a/_loading'), isEmpty);
        expect(model.reload('/nope'), isEmpty);
        expect(model.isPathLoading('/a'), isTrue, reason: 'nothing was disturbed');
      });

      test('descendants are collapsed and uncached, and a late result for one is dropped', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        expandLoaded(model, '/a', [TreeNode(path: '/a/x', label: Line('X'))]);
        expandLoaded(model, '/a/x', [TreeNode(path: '/a/x/y', label: Line('Y'))]);
        model.expand('/a/x/y'); // in flight
        expect(paths(model), equals(['/a', '/a/x', '/a/x/y', '/a/x/y/_loading']));

        model.reload('/a');

        expect(model.isExpanded('/a/x'), isFalse);
        expect(model.isExpanded('/a/x/y'), isFalse);
        expect(model.isPathLoading('/a/x/y'), isFalse, reason: 'the descendant slot is retired');
        expect(model.isLoading(), isTrue, reason: 'only the branch itself loads');

        model
          ..applyChildren('/a/x/y', [TreeNode(path: '/a/x/y/z', label: Line('Z'), isLeaf: true)]) // late, dropped
          ..applyChildren('/a', [TreeNode(path: '/a/x', label: Line('X'))]);
        expect(paths(model), equals(['/a', '/a/x']));

        expect(model.expand('/a/x'), contains(isA<LoadRequest>()), reason: 'the old children are gone');
        model.applyChildren('/a/x', [TreeNode(path: '/a/x/y', label: Line('Y'))]);
        expect(model.expand('/a/x/y'), contains(isA<LoadRequest>()), reason: 'the late result cached nothing');
      });

      test('a descendant re-expanded after a reload: the old fetch is dropped, the new one installs', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        expandLoaded(model, '/a', [TreeNode(path: '/a/x', label: Line('X'))]);
        final old = expandAsking(model, '/a/x'); // in flight when the parent reloads

        model
          ..reload('/a')
          ..applyChildren('/a', [TreeNode(path: '/a/x', label: Line('X'))]);
        final fresh = expandAsking(model, '/a/x'); // the same path, a new asking

        model.update(
          LoadResult<List<TreeNode<String>>>.ok(old, [TreeNode(path: '/a/x/old', label: Line('Old'), isLeaf: true)]),
        );
        expect(model.isPathLoading('/a/x'), isTrue, reason: 'the old asking is dropped; the live one still waits');
        expect(paths(model), equals(['/a', '/a/x', '/a/x/_loading']));

        model.update(
          LoadResult<List<TreeNode<String>>>.ok(fresh, [TreeNode(path: '/a/x/new', label: Line('New'), isLeaf: true)]),
        );
        expect(paths(model), equals(['/a', '/a/x', '/a/x/new']));
      });

      test('a branch expanded under a collapsed ancestor reloads and paints once the ancestor reopens', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);
        expandLoaded(model, '/a', [TreeNode(path: '/a/x', label: Line('X'))]);
        expandLoaded(model, '/a/x', [TreeNode(path: '/a/x/1', label: Line('1'), isLeaf: true)]);
        model.collapse('/a');

        expect(model.reload('/a/x'), [isRequestFor(model.id, const PathKey('/a/x'))]);
        expect(paths(model), equals(['/a']), reason: 'nothing shows under a collapsed ancestor');

        model.expand('/a');
        expect(paths(model), equals(['/a', '/a/x', '/a/x/_loading']));
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
        // Uncached → the expand event plus a load request.
        expect(
          result,
          isA<Handled>().having((h) => h.events, 'events', [isA<TreeExpandEvent<String>>(), isA<LoadRequest>()]),
        );
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

      test('an uncached ancestor is left untouched, never wedged loading', () {
        // '/a' is a root whose children were never loaded. expandPath cannot
        // reveal it (no I/O here), and it must not half-expand it either:
        // beginning its slot would drop the request no app ever sees.
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))])..expandPath('/a/b/c');

        expect(model.isExpanded('/a'), isFalse);
        expect(model.isPathLoading('/a'), isFalse, reason: 'no slot begun, so nothing waits on a dropped request');
        expect(model.branchStatus('/a'), SliceStatus.stalled, reason: 'nothing cached, nothing coming');
        expect(model.flatNodes.any((n) => n.path == '/a/_loading'), isFalse);
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

    group('events', () {
      test('enter returns TreeActivateEvent', () {
        final model = modelWith([TreeNode(path: '/a', label: Line('A'))]);

        final result = model.update(keyMsg('enter'));
        expect(
          result,
          isA<Handled>().having((h) => h.events, 'events', [isA<TreeActivateEvent<String>>()]),
        );
        final event = (result as Handled).events.single;
        expect((event as TreeActivateEvent).path, equals('/a'));
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
