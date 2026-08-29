import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Identity passthrough that returns a *runtime* (non-const) string, so the
/// commands below are built as distinct instances. Without this, `const`
/// canonicalization would make equal commands `identical`, and `operator ==`
/// would never actually run — defeating the point of these tests.
String v(String s) => s;

void main() {
  // Every widget→app command carries its address by value and defines
  // `==`/`hashCode`/`toString` over its id + payload (a2.1 §3.1). Two commands
  // are equal iff their address and payload match; `toString` surfaces the
  // address for debugging. References gave neither.
  group('command value equality', () {
    group('ButtonPressEvent (address: id)', () {
      test('equal iff id matches', () {
        expect(ButtonPressEvent(v('btn')), equals(ButtonPressEvent(v('btn'))));
        expect(ButtonPressEvent(v('btn')).hashCode, equals(ButtonPressEvent(v('btn')).hashCode));
        expect(ButtonPressEvent(v('btn')), isNot(equals(ButtonPressEvent(v('other')))));
      });

      test('toString shows the address', () {
        expect(ButtonPressEvent(v('submit')).toString(), equals('ButtonPressEvent(submit)'));
      });
    });

    group('ListActivateEvent (address: id)', () {
      test('equal iff id matches', () {
        expect(ListActivateEvent(v('l')), equals(ListActivateEvent(v('l'))));
        expect(ListActivateEvent(v('l')).hashCode, equals(ListActivateEvent(v('l')).hashCode));
        expect(ListActivateEvent(v('l')), isNot(equals(ListActivateEvent(v('m')))));
      });

      test('toString shows the address', () {
        expect(ListActivateEvent(v('l')).toString(), equals('ListActivateEvent(l)'));
      });
    });

    group('ComboboxSelectEvent (address: id)', () {
      test('equal iff id matches', () {
        expect(ComboboxSelectEvent(v('cb')), equals(ComboboxSelectEvent(v('cb'))));
        expect(ComboboxSelectEvent(v('cb')).hashCode, equals(ComboboxSelectEvent(v('cb')).hashCode));
        expect(ComboboxSelectEvent(v('cb')), isNot(equals(ComboboxSelectEvent(v('other')))));
      });

      test('toString shows the address', () {
        expect(ComboboxSelectEvent(v('cb')).toString(), equals('ComboboxSelectEvent(cb)'));
      });
    });

    group('TableActivateEvent (address: id + action)', () {
      test('equal iff id and action match', () {
        expect(TableActivateEvent(v('t'), v('primary')), equals(TableActivateEvent(v('t'), v('primary'))));
        expect(
          TableActivateEvent(v('t'), v('primary')).hashCode,
          equals(TableActivateEvent(v('t'), v('primary')).hashCode),
        );
        expect(TableActivateEvent(v('t'), v('primary')), isNot(equals(TableActivateEvent(v('u'), v('primary')))));
        expect(TableActivateEvent(v('t'), v('primary')), isNot(equals(TableActivateEvent(v('t'), v('secondary')))));
      });

      test('toString shows id and action', () {
        expect(TableActivateEvent(v('t'), v('primary')).toString(), equals('TableActivateEvent(t, primary)'));
      });
    });

    // Tree commands are equal by id + path. The carried `node` is *excluded*
    // from equality — it is identity-compared elsewhere, so folding it in would
    // defeat value equality (a2.1 §3.1, types doc comments).
    group('TreeExpandEvent (address: id + path, node excluded)', () {
      final node = TreeNode<String>(path: '/a', label: Line('A'));
      final sameAddrDifferentNode = TreeNode<String>(path: '/a', label: Line('A — other instance'));

      test('equal by id + path even when node differs', () {
        expect(TreeExpandEvent(v('t'), v('/a'), node), equals(TreeExpandEvent(v('t'), v('/a'), sameAddrDifferentNode)));
        expect(
          TreeExpandEvent(v('t'), v('/a'), node).hashCode,
          equals(TreeExpandEvent(v('t'), v('/a'), sameAddrDifferentNode).hashCode),
        );
      });

      test('differs when id or path differs', () {
        expect(TreeExpandEvent(v('t'), v('/a'), node), isNot(equals(TreeExpandEvent(v('t'), v('/b'), node))));
        expect(TreeExpandEvent(v('t'), v('/a'), node), isNot(equals(TreeExpandEvent(v('u'), v('/a'), node))));
      });

      test('toString shows id and path', () {
        expect(TreeExpandEvent(v('t'), v('/a'), node).toString(), equals('TreeExpandEvent(t, /a)'));
      });
    });

    group('TreeCollapseEvent (address: id + path, node excluded)', () {
      final node = TreeNode<String>(path: '/a', label: Line('A'));

      test('equal by id + path', () {
        expect(TreeCollapseEvent(v('t'), v('/a'), node), equals(TreeCollapseEvent(v('t'), v('/a'), node)));
        expect(TreeCollapseEvent(v('t'), v('/a'), node), isNot(equals(TreeCollapseEvent(v('t'), v('/b'), node))));
      });

      test('toString shows id and path', () {
        expect(TreeCollapseEvent(v('t'), v('/a'), node).toString(), equals('TreeCollapseEvent(t, /a)'));
      });
    });

    group('TreeActivateEvent (address: id + path, node excluded)', () {
      final node = TreeNode<String>(path: '/a', label: Line('A'));

      test('equal by id + path', () {
        expect(TreeActivateEvent(v('t'), v('/a'), node), equals(TreeActivateEvent(v('t'), v('/a'), node)));
        expect(TreeActivateEvent(v('t'), v('/a'), node), isNot(equals(TreeActivateEvent(v('u'), v('/a'), node))));
      });

      test('toString shows id and path', () {
        expect(TreeActivateEvent(v('t'), v('/a'), node).toString(), equals('TreeActivateEvent(t, /a)'));
      });
    });
  });
}
