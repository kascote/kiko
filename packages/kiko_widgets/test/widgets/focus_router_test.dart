import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:meta/meta.dart';
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

PointerMsg _pressAt(int x, int y, {String? targetId, bool captured = false}) => PointerMsg(
  global: Position(x, y),
  action: PointerAction.down,
  targetId: targetId,
  local: Position.origin,
  captured: captured,
);

PointerMsg _dragAt(int x, int y, {String? targetId, bool captured = false}) => PointerMsg(
  global: Position(x, y),
  action: PointerAction.drag,
  targetId: targetId,
  local: Position.origin,
  captured: captured,
);

PointerMsg _wheelAt(int x, int y, {String? targetId}) => PointerMsg(
  global: Position(x, y),
  action: PointerAction.wheelDown,
  targetId: targetId,
  local: Position.origin,
);

/// A message the router has never heard of, used to prove it forwards what
/// it does not recognize to the focused member and hands back the verdict —
/// the router routes by address, never by message class.
class _DomainMsg extends Msg {
  const _DomainMsg();
}

/// A region naming a row, for the alias region-resolution tests.
@immutable
class _Row implements Region {
  const _Row(this.index);

  final int index;

  @override
  bool operator ==(Object other) => other is _Row && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => '_Row($index)';
}

/// A leaf that self-tags with an id and marks one region over its whole rect —
/// a member whose view has parts, so a pointer resolves a region on it.
class _MarkingLeaf extends Node {
  _MarkingLeaf(String id, {required this.w, required this.h, required this.mark}) {
    tag = IdTag(id);
  }

  final int w;
  final int h;
  final Region mark;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface surface) => markRegion(mark, rect);
}

/// A view over a [_MarkingLeaf], usable as a focus-group member's chrome-decorated body.
class _MarkingMember implements View {
  const _MarkingMember(this.id, {required this.w, required this.h, required this.mark});

  final String id;
  final int w;
  final int h;
  final Region mark;

  @override
  Node build() => _MarkingLeaf(id, w: w, h: h, mark: mark);
}

/// A committed frame with nothing rendered into it, for tests that only
/// exercise the keyboard path and need no hit-tested geometry.
UpdateContext _ctx({int width = 3, int height = 3}) {
  final frame = _frame(width, height);
  return UpdateContext(hits: frame.hits, area: frame.area);
}

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

  group('FocusRouter keyboard', () {
    test('a traversal key never reaches a member that would swallow it', () {
      final trap = _FakeComponent('trap', (_) => const Handled());
      final other = _FakeComponent('other', (_) => const Declined());
      final focus = FocusGroup<Component>([trap, other]);
      final router = FocusRouter(focus);

      final result = router.route(const KeyMsg('tab'), _ctx());

      expect(result, isA<Handled>());
      expect(focus.index, equals(1));
      expect(trap.seen, isEmpty);
    });

    test('an unbound key reaches the focused member and its result comes back untouched', () {
      const cmd = Quit();
      final handles = _FakeComponent('handles', (_) => const Handled(cmd));
      final ctx = _ctx();

      final handledResult = FocusRouter(FocusGroup<Component>([handles])).route(const KeyMsg('enter'), ctx);

      expect(handledResult, isA<Handled>());
      expect((handledResult as Handled).cmd, same(cmd));
      expect(handles.seen, equals([const KeyMsg('enter')]));

      final declines = _FakeComponent('declines', (_) => const Declined());
      final declinedResult = FocusRouter(FocusGroup<Component>([declines])).route(const KeyMsg('enter'), ctx);

      expect(declinedResult, isA<Declined>());
    });

    test('FocusTo jumps to the named member and fires onFocusChange', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final b = _FakeComponent('b', (_) => const Declined());
      final focus = FocusGroup<Component>([a, b]);
      Component? changedTo;
      final bindings = defaultFocusBindings()..map(['alt+2'], const FocusTo('b'));
      final router = FocusRouter(focus, bindings: bindings, onFocusChange: (c) => changedTo = c);

      final result = router.route(const KeyMsg('alt+2'), _ctx());

      expect(result, isA<Handled>());
      expect(focus.index, equals(1));
      expect(changedTo, same(b));
    });

    test('FocusTo an unknown id is Handled with no focus change and no callback', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final focus = FocusGroup<Component>([a]);
      var called = false;
      final bindings = defaultFocusBindings()..map(['alt+2'], const FocusTo('ghost'));
      final router = FocusRouter(focus, bindings: bindings, onFocusChange: (_) => called = true);

      final result = router.route(const KeyMsg('alt+2'), _ctx());

      expect(result, isA<Handled>());
      expect(focus.index, equals(0));
      expect(called, isFalse);
    });

    test('cycling a one-member group is Handled but fires no callback', () {
      final only = _FakeComponent('only', (_) => const Declined());
      var called = false;
      final router = FocusRouter(FocusGroup<Component>([only]), onFocusChange: (_) => called = true);

      final result = router.route(const KeyMsg('tab'), _ctx());

      expect(result, isA<Handled>());
      expect(called, isFalse);
    });
  });

  group('FocusRouter pointer', () {
    test('a press on an unfocused member moves focus and the member still receives it', () {
      const cmd = Quit();
      final a = _FakeComponent('a', (_) => const Declined());
      final b = _FakeComponent('b', (_) => const Handled(cmd));
      final focus = FocusGroup<Component>([a, b]);
      Component? changed;
      final router = FocusRouter(focus, onFocusChange: (c) => changed = c);
      final frame = _frame(3, 3)..render(_region('b', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'b'), ctx);

      expect(focus.index, equals(1));
      expect(changed, same(b));
      expect(result, isA<Handled>());
      expect((result as Handled).cmd, same(cmd));
    });

    test('a press on an unfocused member that declines still moves focus, and Declined comes back', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final b = _FakeComponent('b', (_) => const Declined());
      final focus = FocusGroup<Component>([a, b]);
      final router = FocusRouter(focus);
      final frame = _frame(3, 3)..render(_region('b', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'b'), ctx);

      expect(focus.index, equals(1));
      expect(result, isA<Declined>());
    });

    test('clickToFocus: false leaves focus in place while still delivering the press', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final b = _FakeComponent('b', (_) => const Handled());
      final focus = FocusGroup<Component>([a, b]);
      final router = FocusRouter(focus, clickToFocus: false);
      final frame = _frame(3, 3)..render(_region('b', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'b'), ctx);

      expect(focus.index, equals(0));
      expect(result, isA<Handled>());
    });

    test('a press on an extra routes to it without moving focus', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final extra = _FakeComponent('extra', (_) => const Handled());
      final focus = FocusGroup<Component>([a]);
      var changeCalls = 0;
      final router = FocusRouter(focus, extras: [extra], onFocusChange: (_) => changeCalls++);
      final frame = _frame(3, 3)..render(_region('extra', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'extra'), ctx);

      expect(result, isA<Handled>());
      expect(focus.index, equals(0));
      expect(changeCalls, equals(0));
      expect(extra.seen, hasLength(1));
    });

    test('a background press declines at the router', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a]));

      final result = router.route(_pressAt(0, 0), _ctx());

      expect(result, isA<Declined>());
      expect(a.seen, isEmpty);
    });

    test('an unknown id with no alias declines at the router', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a]));

      final result = router.route(_pressAt(0, 0, targetId: 'ghost'), _ctx());

      expect(result, isA<Declined>());
      expect(a.seen, isEmpty);
    });
  });

  group('FocusRouter focus-addressed forwarding', () {
    test('a paste reaches the focused member only, and its verdict comes back', () {
      final editor = _FakeComponent('editor', (_) => const Handled());
      final other = _FakeComponent('other', (_) => const Declined());
      final router = FocusRouter(FocusGroup<Component>([editor, other]));
      const paste = PasteMsg('select 1;');

      final result = router.route(paste, _ctx());

      expect(result, isA<Handled>());
      expect(editor.seen, equals([paste]));
      expect(other.seen, isEmpty, reason: 'paste is focus-addressed — only the focused member sees it');
    });

    test('a message the router has never heard of goes to the focused member; its decline comes back', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final router = FocusRouter(FocusGroup<Component>([a]));

      final result = router.route(const _DomainMsg(), _ctx());

      expect(result, isA<Declined>());
      expect(a.seen, equals([const _DomainMsg()]));
    });

    test('a command the focused member returns for a forwarded message passes through untouched', () {
      const cmd = Quit();
      final a = _FakeComponent('a', (_) => const Handled(cmd));
      final router = FocusRouter(FocusGroup<Component>([a]));

      final result = router.route(const _DomainMsg(), _ctx());

      expect(result, isA<Handled>());
      expect((result as Handled).cmd, same(cmd));
    });

    test('a paste routed through the router lands in a real focused TextAreaModel', () {
      final editor = TextAreaModel(id: 'editor', focused: true);
      final router = FocusRouter(FocusGroup<Component>([editor]));

      final result = router.route(const PasteMsg('select 1;'), _ctx());

      expect(result, isA<Handled>());
      expect(editor.value, contains('select 1;'));
    });
  });

  group('FocusRouter chrome aliases', () {
    test('an alias naming an id absent from members and extras declines', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a]), aliases: {'chrome': 'ghost'});

      final result = router.route(_pressAt(0, 0, targetId: 'chrome'), _ctx());

      expect(result, isA<Declined>());
      expect(a.seen, isEmpty);
    });

    test('a press on chrome above the member re-addresses with a negative local and does not bubble past chrome', () {
      final decoy = _FakeComponent('decoy', (_) => const Declined());
      final member = _FakeComponent('member', (_) => const Declined());
      final focus = FocusGroup<Component>([decoy, member]);
      Component? changed;
      final router = FocusRouter(focus, aliases: {'chrome': 'member'}, onFocusChange: (c) => changed = c);
      final frame = _frame(3, 4)
        ..render(
          Tagged(
            'chrome',
            Column(
              children: [const SizedBox(width: 3, height: 1), _region('member', const SizedBox(width: 3, height: 3))],
            ),
          ),
        );
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);
      final memberRect = ctx.hits.rectOf('member')!;

      final result = router.route(_pressAt(1, 0, targetId: 'chrome'), ctx);

      expect(focus.index, equals(1));
      expect(changed, same(member));
      expect(member.seen, hasLength(1));
      final delivered = member.seen.single as PointerMsg;
      expect(delivered.targetId, equals('member'));
      expect(delivered.local, equals(const Position(1, -1)));
      expect(delivered.targetRect, equals(memberRect));
      expect(result, isA<Declined>(), reason: 'chrome is the outermost tag here — nothing left to bubble to');
    });

    test('a press via alias resolves the region against the member, dropping the chrome region', () {
      final member = _FakeComponent('member', (_) => const Handled());
      final focus = FocusGroup<Component>([member]);
      final router = FocusRouter(focus, aliases: {'chrome': 'member'});
      final frame = _frame(3, 4)
        ..render(
          const Tagged(
            'chrome',
            Column(
              children: [
                SizedBox(width: 3, height: 1),
                _MarkingMember('member', w: 3, h: 3, mark: _Row(0)),
              ],
            ),
          ),
        );
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      // The incoming press is addressed to chrome and even carries a
      // chrome-scoped region; the router must drop it and resolve the member's
      // own part at the pointer instead. Member rect is (0,1,3,3); (1,2) is in.
      const incoming = PointerMsg(
        global: Position(1, 2),
        action: PointerAction.down,
        targetId: 'chrome',
        local: Position.origin,
        region: _Row(99),
      );

      router.route(incoming, ctx);

      final delivered = member.seen.single as PointerMsg;
      expect(delivered.targetId, 'member');
      expect(delivered.region, const _Row(0), reason: "the member's part under the pointer, not the chrome's region");
    });

    test('a press via alias off the member carries a null region', () {
      final member = _FakeComponent('member', (_) => const Handled());
      final focus = FocusGroup<Component>([member]);
      final router = FocusRouter(focus, aliases: {'chrome': 'member'});
      final frame = _frame(3, 4)
        ..render(
          const Tagged(
            'chrome',
            Column(
              children: [
                SizedBox(width: 3, height: 1),
                _MarkingMember('member', w: 3, h: 3, mark: _Row(0)),
              ],
            ),
          ),
        );
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      // Chrome row 0 sits above the member (member starts at y=1), so the
      // rebuilt pointer lands on no marked part of it.
      router.route(_pressAt(1, 0, targetId: 'chrome'), ctx);

      final delivered = member.seen.single as PointerMsg;
      expect(delivered.targetId, 'member');
      expect(delivered.region, isNull, reason: 'the pointer is on chrome, off the member — nothing marked there');
    });

    test('a wheel notch on the chrome alias reaches the member and scrolls', () {
      final member = _FakeComponent('member', (_) => const Handled());
      final focus = FocusGroup<Component>([member]);
      final router = FocusRouter(focus, aliases: {'chrome': 'member'});
      final frame = _frame(3, 3)..render(_region('chrome', _region('member', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_wheelAt(1, 1, targetId: 'chrome'), ctx);

      expect(result, isA<Handled>());
      expect(member.seen, hasLength(1));
      expect((member.seen.single as PointerMsg).targetId, equals('member'));
    });

    test('a press on a presence-clipped alias declines but still moves focus', () {
      final decoy = _FakeComponent('decoy', (_) => const Declined());
      final member = _FakeComponent('member', (_) => const Handled());
      final focus = FocusGroup<Component>([decoy, member]);
      Component? changed;
      final router = FocusRouter(focus, aliases: {'chrome': 'member'}, onFocusChange: (c) => changed = c);
      // 'member' is never rendered this frame, so it has no rect to re-address against.
      final frame = _frame(3, 3);
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'chrome'), ctx);

      expect(result, isA<Declined>());
      expect(member.seen, isEmpty);
      expect(focus.index, equals(1));
      expect(changed, same(member));
    });

    test('a leave via alias reaches the member as the same instance, verbatim and unbubbled', () {
      final outer = _FakeComponent('outer', (_) => const Handled());
      final member = _FakeComponent('member', (_) => const Declined());
      final focus = FocusGroup<Component>([member]);
      final router = FocusRouter(
        focus,
        extras: [outer],
        aliases: {'chrome': 'member'},
      );
      final frame = _frame(3, 3)
        ..render(_region('outer', _region('chrome', _region('member', const SizedBox(width: 3, height: 3)))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);
      const leave = PointerLeaveMsg('chrome');

      final result = router.route(leave, ctx);

      expect(member.seen, hasLength(1));
      expect(member.seen.single, same(leave));
      expect(result, isA<Declined>());
      expect(outer.seen, isEmpty, reason: 'a leave carries no position to bubble from');
    });

    test('a cancel via alias reaches the member as the same instance, verbatim and unbubbled', () {
      final member = _FakeComponent('member', (_) => const Handled());
      final focus = FocusGroup<Component>([member]);
      final router = FocusRouter(focus, aliases: {'chrome': 'member'});
      final frame = _frame(3, 3)..render(_region('chrome', _region('member', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);
      const cancel = PointerCancelMsg('chrome');

      final result = router.route(cancel, ctx);

      expect(member.seen, hasLength(1));
      expect(member.seen.single, same(cancel));
      expect(result, isA<Handled>());
    });

    test('a captured drag sequence via alias stays coherent across events', () {
      final member = _FakeComponent('member', (_) => const Handled());
      final focus = FocusGroup<Component>([member]);
      final router = FocusRouter(focus, aliases: {'chrome': 'member'});
      final frame = _frame(5, 5)
        ..render(
          Tagged(
            'chrome',
            Column(
              children: [const SizedBox(width: 5, height: 1), _region('member', const SizedBox(width: 5, height: 4))],
            ),
          ),
        );
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);
      final memberRect = ctx.hits.rectOf('member')!;

      router
        ..route(_pressAt(2, 1, targetId: 'chrome', captured: true), ctx)
        ..route(_dragAt(4, 4, targetId: 'chrome', captured: true), ctx)
        ..route(_dragAt(0, 0, targetId: 'chrome', captured: true), ctx);

      expect(member.seen, hasLength(3));
      for (final msg in member.seen) {
        final p = msg as PointerMsg;
        expect(p.targetId, equals('member'));
        expect(p.captured, isTrue);
        expect(p.targetRect, equals(memberRect));
      }
      expect((member.seen[0] as PointerMsg).local, equals(const Position(2, 0)));
      expect((member.seen[1] as PointerMsg).local, equals(const Position(4, 3)));
      expect((member.seen[2] as PointerMsg).local, equals(const Position(0, -1)));
    });
  });

  group('FocusRouter live derivation', () {
    test('replacing a focus-group member routes to the replacement immediately', () {
      final original = _FakeComponent('a', (_) => const Declined());
      final focus = FocusGroup<Component>([original]);
      final router = FocusRouter(focus);

      final replacement = _FakeComponent('b', (_) => const Handled());
      focus.children[0] = replacement;

      final frame = _frame(3, 3)..render(_region('b', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'b'), ctx);

      expect(result, isA<Handled>());
      expect(replacement.seen, hasLength(1));
    });

    test('growing the extras list after construction routes to the new extra immediately', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final focus = FocusGroup<Component>([a]);
      final extras = <Component>[];
      final router = FocusRouter(focus, extras: extras);

      final extra = _FakeComponent('extra', (_) => const Handled());
      extras.add(extra);

      final frame = _frame(3, 3)..render(_region('extra', const SizedBox(width: 3, height: 3)));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'extra'), ctx);

      expect(result, isA<Handled>());
      expect(extra.seen, hasLength(1));
    });
  });
}
