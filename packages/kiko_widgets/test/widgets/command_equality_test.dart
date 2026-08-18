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
    group('ButtonPressCmd (address: id)', () {
      test('equal iff id matches', () {
        expect(ButtonPressCmd(v('btn')), equals(ButtonPressCmd(v('btn'))));
        expect(ButtonPressCmd(v('btn')).hashCode, equals(ButtonPressCmd(v('btn')).hashCode));
        expect(ButtonPressCmd(v('btn')), isNot(equals(ButtonPressCmd(v('other')))));
      });

      test('toString shows the address', () {
        expect(ButtonPressCmd(v('submit')).toString(), equals('ButtonPressCmd(submit)'));
      });
    });

    group('ListActionCmd (address: id)', () {
      test('equal iff id matches', () {
        expect(ListActionCmd(v('l')), equals(ListActionCmd(v('l'))));
        expect(ListActionCmd(v('l')).hashCode, equals(ListActionCmd(v('l')).hashCode));
        expect(ListActionCmd(v('l')), isNot(equals(ListActionCmd(v('m')))));
      });

      test('toString shows the address', () {
        expect(ListActionCmd(v('l')).toString(), equals('ListActionCmd(l)'));
      });
    });

    group('ComboboxSelectCmd (address: id)', () {
      test('equal iff id matches', () {
        expect(ComboboxSelectCmd(v('cb')), equals(ComboboxSelectCmd(v('cb'))));
        expect(ComboboxSelectCmd(v('cb')).hashCode, equals(ComboboxSelectCmd(v('cb')).hashCode));
        expect(ComboboxSelectCmd(v('cb')), isNot(equals(ComboboxSelectCmd(v('other')))));
      });

      test('toString shows the address', () {
        expect(ComboboxSelectCmd(v('cb')).toString(), equals('ComboboxSelectCmd(cb)'));
      });
    });

    group('TableActionCmd (address: id + action)', () {
      test('equal iff id and action match', () {
        expect(TableActionCmd(v('t'), v('primary')), equals(TableActionCmd(v('t'), v('primary'))));
        expect(
          TableActionCmd(v('t'), v('primary')).hashCode,
          equals(TableActionCmd(v('t'), v('primary')).hashCode),
        );
        expect(TableActionCmd(v('t'), v('primary')), isNot(equals(TableActionCmd(v('u'), v('primary')))));
        expect(TableActionCmd(v('t'), v('primary')), isNot(equals(TableActionCmd(v('t'), v('secondary')))));
      });

      test('toString shows id and action', () {
        expect(TableActionCmd(v('t'), v('primary')).toString(), equals('TableActionCmd(t, primary)'));
      });
    });

    // Tree commands are equal by id + path. The carried `node` is *excluded*
    // from equality — it is identity-compared elsewhere, so folding it in would
    // defeat value equality (a2.1 §3.1, types doc comments).
    group('TreeExpandCmd (address: id + path, node excluded)', () {
      final node = TreeNode<String>(path: '/a', label: Line('A'));
      final sameAddrDifferentNode = TreeNode<String>(path: '/a', label: Line('A — other instance'));

      test('equal by id + path even when node differs', () {
        expect(TreeExpandCmd(v('t'), v('/a'), node), equals(TreeExpandCmd(v('t'), v('/a'), sameAddrDifferentNode)));
        expect(
          TreeExpandCmd(v('t'), v('/a'), node).hashCode,
          equals(TreeExpandCmd(v('t'), v('/a'), sameAddrDifferentNode).hashCode),
        );
      });

      test('differs when id or path differs', () {
        expect(TreeExpandCmd(v('t'), v('/a'), node), isNot(equals(TreeExpandCmd(v('t'), v('/b'), node))));
        expect(TreeExpandCmd(v('t'), v('/a'), node), isNot(equals(TreeExpandCmd(v('u'), v('/a'), node))));
      });

      test('toString shows id and path', () {
        expect(TreeExpandCmd(v('t'), v('/a'), node).toString(), equals('TreeExpandCmd(t, /a)'));
      });
    });

    group('TreeCollapseCmd (address: id + path, node excluded)', () {
      final node = TreeNode<String>(path: '/a', label: Line('A'));

      test('equal by id + path', () {
        expect(TreeCollapseCmd(v('t'), v('/a'), node), equals(TreeCollapseCmd(v('t'), v('/a'), node)));
        expect(TreeCollapseCmd(v('t'), v('/a'), node), isNot(equals(TreeCollapseCmd(v('t'), v('/b'), node))));
      });

      test('toString shows id and path', () {
        expect(TreeCollapseCmd(v('t'), v('/a'), node).toString(), equals('TreeCollapseCmd(t, /a)'));
      });
    });

    group('TreeActionCmd (address: id + path, node excluded)', () {
      final node = TreeNode<String>(path: '/a', label: Line('A'));

      test('equal by id + path', () {
        expect(TreeActionCmd(v('t'), v('/a'), node), equals(TreeActionCmd(v('t'), v('/a'), node)));
        expect(TreeActionCmd(v('t'), v('/a'), node), isNot(equals(TreeActionCmd(v('u'), v('/a'), node))));
      });

      test('toString shows id and path', () {
        expect(TreeActionCmd(v('t'), v('/a'), node).toString(), equals('TreeActionCmd(t, /a)'));
      });
    });
  });
}
