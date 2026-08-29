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

/// A member scoped 'cb', one cell of padding around a 4×2 'field' leaf — so a
/// press on the field resolves as the path 'cb/field'.
View _scopedMember() => Tagged.scope(
  'cb',
  Padding(insets: const EdgeInsets.all(1), child: _region('field', const SizedBox(width: 4, height: 2))),
);

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

/// A message that is nothing but an address, to prove the router keys on
/// [Addressed] itself and not on any one message class that implements it.
class _AddressedMsg extends Msg implements Addressed {
  const _AddressedMsg(this.id);

  @override
  final String id;
}

/// A successful, empty load result addressed to [id].
LoadResult<Object?> _loadFor(String id) => LoadResult<Object?>(id, key: 'page', data: const <Object>[]);

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

    test('a press on a path under a member focuses that member', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final cb = _FakeComponent('cb', (_) => const Declined());
      final focus = FocusGroup<Component>([a, cb]);

      final moved = focusOnPress(_pressAt(0, 0, targetId: 'cb/field'), focus);

      expect(moved, isTrue);
      expect(focus.index, equals(1));
      expect(cb.focused, isTrue);
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

    test('a path under a registered id delivers to it, full path riding along untouched', () {
      final cb = _FakeComponent('cb', (_) => const Handled());
      final targets = <String, Component>{'cb': cb};

      final result = routeToTarget(_pressAt(0, 0, targetId: 'cb/field'), _ctx(), targets);

      expect(result, isA<Handled>());
      expect(cb.seen, hasLength(1));
      expect((cb.seen.single as PointerMsg).targetId, 'cb/field', reason: 'nothing retargets for a prefix match');
    });

    test('a registration at the fuller path wins over the shorter one', () {
      final cb = _FakeComponent('cb', (_) => const Handled());
      final field = _FakeComponent('cb/field', (_) => const Handled());
      final targets = <String, Component>{'cb': cb, 'cb/field': field};

      final result = routeToTarget(_pressAt(0, 0, targetId: 'cb/field'), _ctx(), targets);

      expect(result, isA<Handled>());
      expect(field.seen, hasLength(1));
      expect(cb.seen, isEmpty, reason: 'the more specific registration wins');
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

  group('routeToTarget addressed', () {
    test('an addressed message delivers to the component under its id, verbatim, verdict as-is', () {
      const cmd = Quit();
      final a = _FakeComponent('a', (_) => const Handled(cmd));
      final b = _FakeComponent('b', (_) => const Handled());
      final targets = <String, Component>{'a': a, 'b': b};
      final result = _loadFor('a');

      final verdict = routeToTarget(result, _ctx(), targets);

      expect(verdict, isA<Handled>());
      expect((verdict as Handled).cmd, same(cmd));
      expect(a.seen, equals([result]));
      expect(b.seen, isEmpty);
    });

    test('an id nothing registers declines and calls no component', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final targets = <String, Component>{'a': a};

      final verdict = routeToTarget(_loadFor('ghost'), _ctx(), targets);

      expect(verdict, isA<Declined>());
      expect(a.seen, isEmpty);
    });

    test('an id under a registered prefix climbs to the registration, id riding along untouched', () {
      final combo = _FakeComponent('combo', (_) => const Handled());
      final targets = <String, Component>{'combo': combo};

      final verdict = routeToTarget(_loadFor('combo/list'), _ctx(), targets);

      expect(verdict, isA<Handled>());
      expect(combo.seen, hasLength(1));
      expect(
        (combo.seen.single as LoadResult<Object?>).id,
        'combo/list',
        reason: 'nothing retargets on a prefix match',
      );
    });

    test('a declined addressed message does not bubble outward', () {
      final frame = _frame(3, 3)..render(_region('outer', _region('inner', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final inner = _FakeComponent('inner', (_) => const Declined());
      final outer = _FakeComponent('outer', (_) => const Handled());
      final targets = <String, Component>{'inner': inner, 'outer': outer};

      final verdict = routeToTarget(_loadFor('inner'), ctx, targets);

      expect(verdict, isA<Declined>());
      expect(inner.seen, hasLength(1));
      expect(outer.seen, isEmpty, reason: 'an addressed message carries no position to bubble from');
    });

    test('any message implementing Addressed is routed by its id, whatever its class', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final targets = <String, Component>{'a': a};
      const msg = _AddressedMsg('a');

      final verdict = routeToTarget(msg, _ctx(), targets);

      expect(verdict, isA<Handled>());
      expect(a.seen, equals([msg]));
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

    test('an unknown id declines at the router', () {
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

  group('FocusRouter addressed', () {
    test('a LoadResult addressed to an unfocused member reaches it, not the focused one, and focus stays', () {
      const cmd = Quit();
      final a = _FakeComponent('a', (_) => const Declined());
      final b = _FakeComponent('b', (_) => const Handled(cmd));
      final focus = FocusGroup<Component>([a, b]);
      var changeCalls = 0;
      final router = FocusRouter(focus, onFocusChange: (_) => changeCalls++);
      final result = _loadFor('b');

      final verdict = router.route(result, _ctx());

      expect(verdict, isA<Handled>());
      expect((verdict as Handled).cmd, same(cmd));
      expect(b.seen, equals([result]));
      expect(a.seen, isEmpty, reason: 'the focused member never sees a message addressed elsewhere');
      expect(focus.index, equals(0), reason: 'an addressed message never moves focus');
      expect(changeCalls, equals(0));
    });

    test('a LoadResult addressed to an extra reaches it', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final extra = _FakeComponent('extra', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a]), extras: [extra]);
      final result = _loadFor('extra');

      final verdict = router.route(result, _ctx());

      expect(verdict, isA<Handled>());
      expect(extra.seen, equals([result]));
      expect(a.seen, isEmpty);
    });

    test("a LoadResult addressed to a composite's part reaches the composite by the prefix climb", () {
      final other = _FakeComponent('other', (_) => const Declined());
      final combo = _FakeComponent('combo', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([other, combo]));
      final result = _loadFor('combo/list');

      final verdict = router.route(result, _ctx());

      expect(verdict, isA<Handled>());
      expect(combo.seen, equals([result]));
      expect(
        (combo.seen.single as LoadResult<Object?>).id,
        'combo/list',
        reason: 'the composite reads the leaf itself',
      );
      expect(other.seen, isEmpty);
    });

    test('a LoadResult addressed to an id nothing registers declines and reaches no member', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a]));

      final verdict = router.route(_loadFor('ghost'), _ctx());

      expect(verdict, isA<Declined>());
      expect(a.seen, isEmpty, reason: 'an unresolved address is never re-aimed at the focused member');
    });

    test('any message implementing Addressed is routed by its id, whatever its class', () {
      final a = _FakeComponent('a', (_) => const Declined());
      final b = _FakeComponent('b', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a, b]));
      const msg = _AddressedMsg('b');

      final verdict = router.route(msg, _ctx());

      expect(verdict, isA<Handled>());
      expect(b.seen, equals([msg]));
      expect(a.seen, isEmpty);
    });
  });

  group('FocusRouter prefix resolution', () {
    test('a press on a path under a member focuses and delivers to it, full path riding along', () {
      final other = _FakeComponent('other', (_) => const Declined());
      final cb = _FakeComponent('cb', (_) => const Handled());
      final focus = FocusGroup<Component>([other, cb]);
      Component? changed;
      final router = FocusRouter(focus, onFocusChange: (c) => changed = c);
      final frame = _frame(6, 4)..render(_scopedMember());
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(2, 2, targetId: 'cb/field'), ctx);

      expect(focus.index, equals(1));
      expect(changed, same(cb));
      expect(result, isA<Handled>());
      expect(cb.seen, hasLength(1));
      final delivered = cb.seen.single as PointerMsg;
      expect(delivered.targetId, 'cb/field', reason: 'a prefix match delivers as-is, nothing retargets');
    });

    test('a fuller registration wins over the shorter one that also prefixes the path', () {
      final cb = _FakeComponent('cb', (_) => const Declined());
      final field = _FakeComponent('cb/field', (_) => const Handled());
      final focus = FocusGroup<Component>([cb]);
      final router = FocusRouter(focus, extras: [field]);
      final frame = _frame(6, 4)..render(_scopedMember());
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(2, 2, targetId: 'cb/field'), ctx);

      expect(result, isA<Handled>());
      expect(field.seen, hasLength(1));
      expect(cb.seen, isEmpty, reason: 'the more specific registration wins');
    });

    test('a direct prefix match on the field delivers to its member alone', () {
      final decoy = _FakeComponent('decoy', (_) => const Declined());
      final cb = _FakeComponent('cb', (_) => const Handled());
      final focus = FocusGroup<Component>([decoy, cb]);
      final router = FocusRouter(focus);
      final frame = _frame(6, 4)..render(_scopedMember());
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(2, 2, targetId: 'cb/field'), ctx);

      expect(result, isA<Handled>());
      expect(cb.seen, hasLength(1));
      expect(decoy.seen, isEmpty);
    });

    test('an unscoped id is unaffected by prefix logic and still needs an exact match', () {
      final a = _FakeComponent('a', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([a]));
      final frame = _frame(3, 3)..render(_region('chrome', _region('a', const SizedBox(width: 3, height: 3))));
      final ctx = UpdateContext(hits: frame.hits, area: frame.area);

      final result = router.route(_pressAt(0, 0, targetId: 'chrome'), ctx);

      expect(
        result,
        isA<Declined>(),
        reason: '"chrome" has no "/" to split, so no prefix of it is registered and no exact match exists',
      );
      expect(a.seen, isEmpty);
    });

    test('a wheel notch on a bare scope path resolves to the member by prefix and reaches it as-is', () {
      final member = _FakeComponent('cb', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([member]));

      final result = router.route(_wheelAt(0, 0, targetId: 'cb'), _ctx());

      expect(result, isA<Handled>());
      expect(member.seen, hasLength(1));
      final delivered = member.seen.single as PointerMsg;
      expect(delivered.targetId, 'cb');
      expect(delivered.targetRect, isNull, reason: 'a bare scope path carries no rect of its own');
    });

    test('a leave on a path under a scope resolves to the member by prefix, verbatim and unbubbled', () {
      final outer = _FakeComponent('outer', (_) => const Handled());
      final member = _FakeComponent('cb', (_) => const Declined());
      final router = FocusRouter(FocusGroup<Component>([member]), extras: [outer]);
      const leave = PointerLeaveMsg('cb/field');

      final result = router.route(leave, _ctx());

      expect(member.seen, hasLength(1));
      expect(member.seen.single, same(leave));
      expect(result, isA<Declined>());
      expect(outer.seen, isEmpty, reason: 'a leave carries no position to bubble from');
    });

    test('a cancel on a path under a scope resolves to the member by prefix, verbatim and unbubbled', () {
      final member = _FakeComponent('cb', (_) => const Handled());
      final router = FocusRouter(FocusGroup<Component>([member]));
      const cancel = PointerCancelMsg('cb/field');

      final result = router.route(cancel, _ctx());

      expect(member.seen, hasLength(1));
      expect(member.seen.single, same(cancel));
      expect(result, isA<Handled>());
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
