import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// Tags [child] with [id], wrapped in a zero-inset [Padding] so a chain of
/// these nests as distinct rects at the same geometry — [Tagged] tags its
/// child's own root node, so two [Tagged]s back to back would collide on one
/// node and trip the one-tag-per-frame assert.
View _region(String id, View child) => Tagged(id, Padding(insets: EdgeInsets.zero, child: child));

/// A scriptable [Component] whose [update] returns whatever [onUpdate] says,
/// and records every message it was asked to handle.
class _FakeComponent implements Component {
  _FakeComponent(this.id, this.onUpdate);

  @override
  final String id;

  final UpdateResult Function(Msg msg) onUpdate;

  final List<Msg> seen = [];

  @override
  bool focused = false;

  @override
  UpdateResult update(Msg msg) {
    seen.add(msg);
    return onUpdate(msg);
  }
}

PointerMsg _wheelAt(int x, int y, {String? targetId}) => PointerMsg(
  global: Position(x, y),
  action: PointerAction.wheelDown,
  targetId: targetId,
  local: Position.origin,
);

void main() {
  group('offerOutward', () {
    test('excludes the decliner and offers the next id out', () {
      final frame = _frame(3, 3)
        ..render(_region('outer', _region('middle', _region('inner', const SizedBox(width: 3, height: 3)))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final calls = <String>[];
      final middle = _FakeComponent('middle', (msg) {
        calls.add('middle');
        return const Handled();
      });
      final targets = <String, Component>{'middle': middle};

      final result = offerOutward(_wheelAt(0, 0, targetId: 'inner'), ctx, targets);

      expect(result, isA<Handled>());
      expect(calls, equals(['middle']), reason: 'inner (the decliner) and outer (absent from targets) are skipped');
      expect(middle.seen, hasLength(1));
    });

    test('walks inside-out and stops at the first Handled', () {
      final frame = _frame(3, 3)
        ..render(_region('outer', _region('middle', _region('inner', const SizedBox(width: 3, height: 3)))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final calls = <String>[];
      final middle = _FakeComponent('middle', (msg) {
        calls.add('middle');
        return const Declined();
      });
      final outer = _FakeComponent('outer', (msg) {
        calls.add('outer');
        return const Handled();
      });
      final targets = <String, Component>{'middle': middle, 'outer': outer};

      final result = offerOutward(_wheelAt(0, 0, targetId: 'inner'), ctx, targets);

      expect(result, isA<Handled>());
      expect(calls, equals(['middle', 'outer']), reason: 'middle declines first, so outer is tried next');
    });

    test('declines when every enclosing target declines', () {
      final frame = _frame(3, 3)..render(_region('outer', _region('inner', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final outer = _FakeComponent('outer', (msg) => const Declined());
      final targets = <String, Component>{'outer': outer};

      final result = offerOutward(_wheelAt(0, 0, targetId: 'inner'), ctx, targets);

      expect(result, isA<Declined>());
      expect(outer.seen, hasLength(1));
    });

    test('an enclosing region with no matching Component is skipped, not an error', () {
      // 'chrome' is tagged but has no entry in targets — a bare app-composed
      // region with no model behind it.
      final frame = _frame(3, 3)
        ..render(_region('chrome', _region('middle', _region('inner', const SizedBox(width: 3, height: 3)))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final middle = _FakeComponent('middle', (msg) => const Handled());
      final targets = <String, Component>{'middle': middle};

      final result = offerOutward(_wheelAt(0, 0, targetId: 'inner'), ctx, targets);

      expect(result, isA<Handled>());
    });

    test('a background event (no target) has an empty path and declines', () {
      final frame = _frame(3, 3)..render(_region('outer', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      // (5, 5) is outside the 3x3 tagged region entirely.
      final result = offerOutward(_wheelAt(5, 5), ctx, const <String, Component>{});

      expect(result, isA<Declined>());
    });
  });
}
