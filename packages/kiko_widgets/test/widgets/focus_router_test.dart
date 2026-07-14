import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:termparser/termparser_events.dart';
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

PointerMsg _pressAt(int x, int y, {String? targetId}) =>
    PointerMsg(MouseEvent(x, y, MouseButton.down()), targetId: targetId, local: Position.origin);

PointerMsg _wheelAt(int x, int y, {String? targetId}) =>
    PointerMsg(MouseEvent(x, y, MouseButton.wheelDown()), targetId: targetId, local: Position.origin);

/// Builds a two-member focus group, plus typed handles to its members —
/// `focus.children` is typed as [Component], which (like [Focusable]) has no
/// `focused` getter, only a setter, so assertions need the concrete type.
({FocusGroup<Component> focus, _FakeComponent a, _FakeComponent b}) _group() {
  final a = _FakeComponent('a', (_) => const Declined());
  final b = _FakeComponent('b', (_) => const Declined());
  return (focus: FocusGroup<Component>([a, b]), a: a, b: b);
}

void main() {
  group('focusOnPress', () {
    test('press on a member id moves focus and returns true', () {
      final g = _group();

      final moved = focusOnPress(_pressAt(0, 0, targetId: 'b'), g.focus);

      expect(moved, isTrue);
      expect(g.focus.index, equals(1));
      expect(g.a.focused, isFalse);
      expect(g.b.focused, isTrue);
    });

    test('press via an alias moves focus to the member the alias names', () {
      final g = _group();

      final moved = focusOnPress(_pressAt(0, 0, targetId: 'b-chrome'), g.focus, aliases: {'b-chrome': 'b'});

      expect(moved, isTrue);
      expect(g.focus.index, equals(1));
      expect(g.b.focused, isTrue);
    });

    test('press on the already-focused member returns false and leaves focus unchanged', () {
      final g = _group();

      final moved = focusOnPress(_pressAt(0, 0, targetId: 'a'), g.focus);

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
      expect(g.a.focused, isTrue);
    });

    test('a background press (no targetId) leaves focus untouched', () {
      final g = _group();

      final moved = focusOnPress(_pressAt(0, 0), g.focus);

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
    });

    test('a press on an unknown id leaves focus untouched', () {
      final g = _group();

      final moved = focusOnPress(_pressAt(0, 0, targetId: 'ghost'), g.focus);

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
    });

    test('an alias naming a non-member leaves focus untouched', () {
      final g = _group();

      final moved = focusOnPress(_pressAt(0, 0, targetId: 'chrome'), g.focus, aliases: {'chrome': 'not-a-member'});

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
    });

    test('a wheel notch (not a press) leaves focus untouched', () {
      final g = _group();

      final moved = focusOnPress(_wheelAt(0, 0, targetId: 'b'), g.focus);

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
    });

    test('a key message leaves focus untouched', () {
      final g = _group();

      final moved = focusOnPress(const KeyMsg('tab'), g.focus);

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
    });

    test('a leave message leaves focus untouched', () {
      final g = _group();

      final moved = focusOnPress(const PointerLeaveMsg('b'), g.focus);

      expect(moved, isFalse);
      expect(g.focus.index, equals(0));
    });
  });

  group('routeToTarget', () {
    test('a background press (null targetId) declines and calls no component', () {
      final frame = _frame(3, 3)..render(_region('a', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final a = _FakeComponent('a', (_) => const Handled());
      final targets = <String, Component>{'a': a};

      final result = routeToTarget(_pressAt(5, 5), ctx, targets);

      expect(result, isA<Declined>());
      expect(a.seen, isEmpty);
    });

    test('an unknown targetId declines and calls no component', () {
      final frame = _frame(3, 3)..render(_region('a', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final a = _FakeComponent('a', (_) => const Handled());
      final targets = <String, Component>{'a': a};

      final result = routeToTarget(_pressAt(0, 0, targetId: 'ghost'), ctx, targets);

      expect(result, isA<Declined>());
      expect(a.seen, isEmpty);
    });

    test('a known target that handles comes back verbatim', () {
      final frame = _frame(3, 3)..render(_region('a', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      const cmd = Quit();
      final a = _FakeComponent('a', (_) => const Handled(cmd));
      final targets = <String, Component>{'a': a};

      final result = routeToTarget(_pressAt(0, 0, targetId: 'a'), ctx, targets);

      expect(result, isA<Handled>());
      expect((result as Handled).cmd, same(cmd));
    });

    test('a declined positional PointerMsg bubbles outward to the enclosing target', () {
      final frame = _frame(3, 3)
        ..render(_region('outer', _region('middle', _region('inner', const SizedBox(width: 3, height: 3)))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final inner = _FakeComponent('inner', (_) => const Declined());
      final middle = _FakeComponent('middle', (_) => const Handled());
      final targets = <String, Component>{'inner': inner, 'middle': middle};

      final result = routeToTarget(_wheelAt(0, 0, targetId: 'inner'), ctx, targets);

      expect(result, isA<Handled>());
      expect(inner.seen, hasLength(1), reason: 'the addressed target is asked first');
      expect(middle.seen, hasLength(1), reason: 'the decline bubbles to the enclosing target');
    });

    test('a declined PointerLeaveMsg does not bubble', () {
      final frame = _frame(3, 3)..render(_region('outer', _region('inner', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final inner = _FakeComponent('inner', (_) => const Declined());
      final outer = _FakeComponent('outer', (_) => const Handled());
      final targets = <String, Component>{'inner': inner, 'outer': outer};

      final result = routeToTarget(const PointerLeaveMsg('inner'), ctx, targets);

      expect(result, isA<Declined>());
      expect(outer.seen, isEmpty, reason: 'a leave carries no position to bubble from');
    });

    test('a declined PointerCancelMsg does not bubble', () {
      final frame = _frame(3, 3)..render(_region('outer', _region('inner', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final inner = _FakeComponent('inner', (_) => const Declined());
      final outer = _FakeComponent('outer', (_) => const Handled());
      final targets = <String, Component>{'inner': inner, 'outer': outer};

      final result = routeToTarget(const PointerCancelMsg('inner'), ctx, targets);

      expect(result, isA<Declined>());
      expect(outer.seen, isEmpty, reason: 'a cancel carries no position to bubble from');
    });

    test('a non-routed message declines and calls no component', () {
      final frame = _frame(3, 3)..render(_region('a', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final a = _FakeComponent('a', (_) => const Handled());
      final targets = <String, Component>{'a': a};

      final result = routeToTarget(const KeyMsg('enter'), ctx, targets);

      expect(result, isA<Declined>());
      expect(a.seen, isEmpty);
    });
  });
}
