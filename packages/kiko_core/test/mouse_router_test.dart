import 'package:kiko/kiko.dart';
// The router and the un-routed form it consumes never leave the runtime.
import 'package:kiko/src/mvu/mouse_router.dart';
import 'package:kiko/src/mvu/msg.dart' show RawPointerMsg;
import 'package:meta/meta.dart';
import 'package:plume/plume.dart' as plume;
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Something that fills whatever slot it is given.
View _pane() => Container(border: BorderType.plain, child: Line(''));

/// A region naming a row.
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

/// A leaf tagged with an id that marks a row region per painted item.
class _MarkingLeaf extends plume.RenderNode<PaintToken> {
  _MarkingLeaf(String id, {required this.w, required this.h, required this.marks}) {
    tag = IdTag(id);
  }

  final int w;
  final int h;
  final List<(Region, plume.Rect)> marks;

  @override
  plume.Size performLayout(plume.BoxConstraints constraints, plume.LayoutContext context) =>
      constraints.constrain(plume.Size(w, h));

  @override
  void paintSelf(plume.Surface<PaintToken> surface) {
    for (final (region, r) in marks) {
      markRegion(region, plume.Rect(rect.x + r.x, rect.y + r.y, r.width, r.height));
    }
  }
}

/// A frame with one marking widget 'list' covering the whole 6×5 surface: item
/// 0 two rows tall (y 0-1), a separator (y 2), item 1 two rows tall (y 3-4).
HitMap _listHits() {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 6, height: 5));
  return (Frame(buffer.area, buffer, 0)..renderNode(
        _MarkingLeaf(
          'list',
          w: 6,
          h: 5,
          marks: const [
            (_Row(0), plume.Rect(0, 0, 6, 2)),
            (_Row(1), plume.Rect(0, 3, 6, 2)),
          ],
        ),
      ))
      .hits;
}

/// A frame's geometry: two 4×2 panes side by side on a 9×3 surface, so the
/// bottom row and the last column belong to nobody.
///
/// Pass [swap] to paint the same two ids the other way round, as a later frame
/// would if the layout changed under the pointer.
HitMap _twoPanes({bool swap = false, bool dropLeft = false}) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 9, height: 3));
  final panes = <View>[
    if (!dropLeft) Positioned(left: swap ? 4 : 0, top: 0, width: 4, height: 2, child: Tagged('left', _pane())),
    Positioned(left: swap ? 0 : 4, top: 0, width: 4, height: 2, child: Tagged('right', _pane())),
  ];
  return (Frame(buffer.area, buffer, 0)..render(Stack(fit: plume.StackFit.expand, children: panes))).hits;
}

/// A leaf tagged with a bare id, for building a scoped composite.
plume.RenderNode<PaintToken> _idLeaf(String id, int w, int h) =>
    plume.SizedBox<PaintToken>(width: w, height: h)..tag = IdTag(id);

/// A composite: a 4×2 'field' leaf inside 1 cell of padding, the padding node
/// scoped 'cb' — so the scope covers 6×4 and the field sits at (1,1).
plume.RenderNode<PaintToken> _composite() =>
    plume.Padding<PaintToken>(insets: const plume.EdgeInsets.all(1), child: _idLeaf('field', 4, 2))
      ..tag = ScopeTag('cb');

/// Pins [child] at ([left], [top]) sized [w]×[h] — roots are laid out tight to
/// the frame, so fixed geometry needs a Stack.
plume.RenderNode<PaintToken> _pinned(plume.RenderNode<PaintToken> child, int left, int top, int w, int h) =>
    plume.Stack<PaintToken>(
      children: [plume.Positioned<PaintToken>(left: left, top: top, width: w, height: h, child: child)],
    );

/// A blank frame with nothing painted into it, [width]×[height].
Frame _blank(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// The composite pinned at (0,0) as 6×4 on a 9×5 surface: the columns right
/// of x=5 and the bottom row belong to the background.
HitMap _compositeHits() => (_blank(9, 5)..renderNode(_pinned(_composite(), 0, 0, 6, 4))).hits;

/// A mouse event as it waits in the queue, aimed at [hits] and stamped with
/// the arrival time [at].
RawPointerMsg _at(int x, int y, MouseButton button, HitMap hits, {Duration at = Duration.zero}) =>
    RawPointerMsg(MouseEvent(x, y, button), hits, at: at);

MouseButton _down() => MouseButton.down(MouseButtonKind.left);
MouseButton _up() => MouseButton.up(MouseButtonKind.left);
MouseButton _drag() => MouseButton.drag(MouseButtonKind.left);
MouseButton _move() => MouseButton.moved();

/// The single routed event in [msgs], which must hold exactly one.
PointerMsg _only(List<Msg> msgs) => msgs.whereType<PointerMsg>().single;

void main() {
  late MouseRouter router;
  late HitMap hits;

  setUp(() {
    router = MouseRouter(doubleClickInterval: const Duration(milliseconds: 400));
    hits = _twoPanes();
  });

  group('resolution', () {
    test('addresses the widget under the pointer, in that widget’s own cells', () {
      final p = _only(router.route(_at(5, 1, _move(), hits)));

      expect(p.targetId, 'right');
      expect(p.global, const Position(5, 1));
      expect(p.local, const Position(1, 1));
      expect(p.targetRect, Rect.create(x: 4, y: 0, width: 4, height: 2));
      expect(p.inside, isTrue);
      expect(p.captured, isFalse);
    });

    test('over no widget, the local position is the absolute one', () {
      final p = _only(router.route(_at(8, 2, _move(), hits)));

      expect(p.targetId, isNull);
      expect(p.targetRect, isNull);
      expect(p.local, const Position(8, 2));
      expect(p.inside, isFalse, reason: 'there is nothing to be inside of');
    });

    test('carries the event’s button, action and modifiers in kiko’s own vocabulary', () {
      final event = MouseEvent(5, 1, _down(), modifiers: KeyModifiers.shift);

      final p = _only(router.route(RawPointerMsg(event, hits)));

      expect(p.button, PointerButton.left);
      expect(p.action, PointerAction.down);
      expect(p.shift, isTrue);
      expect(p.ctrl, isFalse);
      expect(p.alt, isFalse);
    });

    test('a message that was already routed passes straight through', () {
      const routed = PointerMsg(
        global: Position.origin,
        action: PointerAction.down,
        button: PointerButton.left,
        local: Position.origin,
        targetId: 'left',
      );

      expect(router.route(routed), [same(routed)]);
      expect(router.hoverId, isNull, reason: 'a re-emitted event does not re-run the router');
    });

    test('a key press passes straight through', () {
      expect(router.route(const KeyMsg('a')), [const KeyMsg('a')]);
    });
  });

  group('capture', () {
    test('the release lands on the widget that took the press, wherever the cursor went', () {
      router.route(_at(1, 1, _down(), hits));

      final drag = _only(router.route(_at(6, 1, _drag(), hits)));
      final up = _only(router.route(_at(6, 1, _up(), hits)));

      expect(drag.targetId, 'left');
      expect(drag.captured, isTrue);
      expect(drag.local, const Position(6, 1), reason: 'still counted from the captor’s top-left cell');
      expect(drag.inside, isFalse, reason: 'the cursor has run off the captor');
      expect(up.targetId, 'left');
      expect(up.captured, isTrue);
      expect(up.inside, isFalse, reason: 'so a button knows not to fire');
      expect(router.capturing, isFalse, reason: 'the release ended the gesture');
    });

    test('the press itself is not captured — it is a fresh hit', () {
      final down = _only(router.route(_at(1, 1, _down(), hits)));

      expect(down.targetId, 'left');
      expect(down.captured, isFalse);
      expect(router.capturing, isTrue);
      expect(router.captureId, 'left');
    });

    test('a press on the background captures the background', () {
      router.route(_at(1, 2, _down(), hits));
      expect(router.capturing, isTrue);
      expect(router.captureId, isNull);

      final drag = _only(router.route(_at(1, 1, _drag(), hits)));

      expect(drag.targetId, isNull, reason: 'a rubber band does not grab the first widget it crosses');
      expect(drag.captured, isTrue);
      expect(drag.local, const Position(1, 1));
    });

    test('a second press while a gesture is held goes to the widget holding it', () {
      router.route(_at(1, 1, _down(), hits));

      final second = _only(router.route(_at(6, 1, MouseButton.down(MouseButtonKind.right), hits)));

      expect(second.targetId, 'left');
      expect(second.captured, isTrue);
      expect(router.captureId, 'left', reason: 'the slot is not re-taken');
    });

    test('any button releases, because legacy mode reports none on release', () {
      router.route(_at(1, 1, _down(), hits));

      final up = _only(router.route(_at(1, 1, MouseButton.up(), hits)));

      expect(up.targetId, 'left');
      expect(router.capturing, isFalse);
    });

    test('the captor’s rect is read from the frame the event was aimed at, not frozen at the press', () {
      router.route(_at(1, 1, _down(), hits));

      // The layout changed under the gesture: `left` is now the right-hand pane.
      final moved = _twoPanes(swap: true);
      final drag = _only(router.route(_at(5, 1, _drag(), moved)));

      expect(drag.targetId, 'left');
      expect(drag.targetRect, Rect.create(x: 4, y: 0, width: 4, height: 2));
      expect(drag.local, const Position(1, 1));
      expect(drag.inside, isTrue, reason: 'the user aims at the cells that are on screen now');
    });

    test('a captor painted out of the event’s own frame falls back to absolute coordinates', () {
      router.route(_at(1, 1, _down(), hits));

      // The event's own map carries no rect for the captor, so there is
      // nothing to measure the drag against.
      final drag = _only(router.route(_at(6, 1, _drag(), _twoPanes(dropLeft: true))));

      expect(drag.targetId, 'left');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, isNull);
      expect(drag.local, const Position(6, 1));
    });
  });

  group('capture under a scope', () {
    late HitMap scoped;

    setUp(() {
      scoped = _compositeHits();
    });

    test('an inner leaf captures by its path; the gesture stays on it off the composite', () {
      final down = _only(router.route(_at(2, 2, _down(), scoped)));
      expect(down.targetId, 'cb/field');

      final drag = _only(router.route(_at(8, 4, _drag(), scoped)));
      expect(drag.targetId, 'cb/field');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, Rect.create(x: 1, y: 1, width: 4, height: 2), reason: 'the field, not the scope');

      final up = _only(router.route(_at(8, 4, _up(), scoped)));
      expect(up.targetId, 'cb/field');
    });

    test('a captured bare scope survives rect-less, falling back to absolute coordinates', () {
      final down = _only(router.route(_at(0, 0, _down(), scoped)));
      expect(down.targetId, 'cb', reason: 'a press on the scope’s own cells, not on the field');
      expect(scoped.rectOf('cb'), isNull, reason: 'a scope has no rect of its own');

      final msgs = router.route(_at(3, 3, _drag(), scoped));
      expect(msgs.whereType<PointerCancelMsg>(), isEmpty, reason: 'the scope is still on screen');
      final drag = _only(msgs);
      expect(drag.targetId, 'cb');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, isNull);
      expect(drag.local, drag.global, reason: 'a rect-less captor falls back to absolute coordinates');

      final up = _only(router.route(_at(3, 3, _up(), scoped)));
      expect(up.targetId, 'cb');
    });

    test('a scope painted out from under the gesture still addresses it, captured and rect-less', () {
      router.route(_at(0, 0, _down(), scoped));

      final gone = _blank(9, 5).hits;
      final msgs = router.route(_at(3, 3, _drag(), gone));

      expect(msgs.whereType<PointerCancelMsg>(), isEmpty, reason: 'the scope’s gesture is bound to its path');
      final drag = _only(msgs);
      expect(drag.targetId, 'cb');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, isNull);
      expect(drag.local, drag.global, reason: 'a rect-less captor falls back to absolute coordinates');

      final up = _only(router.route(_at(3, 3, _up(), gone)));
      expect(up.targetId, 'cb');
      expect(router.capturing, isFalse, reason: 'the release ends the gesture');
    });
  });

  group('capture termination', () {
    test('a bare move while a button is held means the release happened off-window', () {
      router.route(_at(1, 1, _down(), hits));

      final msgs = router.route(_at(6, 1, _move(), hits));

      expect(msgs.first, const PointerCancelMsg('left'));
      expect(router.capturing, isFalse);
      expect(_only(msgs).targetId, 'right', reason: 'and the move itself routes as an ordinary one');
    });

    test('a captor that has left the screen still receives its drag, captured and rect-less', () {
      router.route(_at(1, 1, _down(), hits));

      final newest = _twoPanes(dropLeft: true);
      final msgs = router.route(_at(1, 1, _drag(), newest));

      expect(msgs.whereType<PointerCancelMsg>(), isEmpty, reason: 'the gesture is bound to an id, not to a rect');
      final drag = _only(msgs);
      expect(drag.targetId, 'left');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, isNull);
      expect(drag.local, drag.global, reason: 'a rect-less captor falls back to absolute coordinates');
    });

    test('capture holds the resolution to the end: a captor painted out still receives its drags and its release', () {
      router.route(_at(1, 1, _down(), hits));

      // The captor is painted out and another widget now sits under the
      // cursor, as when a press closes a popup over a button.
      final newest = _twoPanes(swap: true, dropLeft: true);
      expect(newest.hitId(1, 1), 'right');

      final onDrag = router.route(_at(1, 1, _drag(), newest));
      expect(onDrag.whereType<PointerCancelMsg>(), isEmpty, reason: 'the gesture is bound to an id, not to a rect');
      final drag = _only(onDrag);
      expect(drag.targetId, 'left');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, isNull);
      expect(drag.local, drag.global, reason: 'a rect-less captor falls back to absolute coordinates');

      final onUp = router.route(_at(1, 1, _up(), newest));
      final up = _only(onUp);
      expect(up.targetId, 'left', reason: 'the release never re-targets at the widget now under the cursor');
      expect(up.captured, isTrue);
      expect(up.inside, isFalse, reason: 'so a press-activated widget cannot fire on it');
      expect(router.capturing, isFalse, reason: 'the release ends the gesture');

      // The button is up: the next event is a fresh interaction and routes
      // normally.
      final onMove = router.route(_at(1, 1, _move(), newest));
      expect(_only(onMove).targetId, 'right');
    });

    test('losing terminal focus ends the gesture, the hover, and then reports itself', () {
      router.route(_at(1, 1, _down(), hits));

      final msgs = router.route(const FocusMsg(hasFocus: false));

      expect(msgs, [
        const PointerCancelMsg('left'),
        const PointerLeaveMsg('left'),
        const FocusMsg(hasFocus: false),
      ]);
      expect(router.capturing, isFalse);
      expect(router.hoverId, isNull);
    });

    test('regaining focus reports itself and nothing else', () {
      expect(router.route(const FocusMsg(hasFocus: true)), [const FocusMsg(hasFocus: true)]);
    });

    test('a gesture on the background is cancelled too, with a null target', () {
      router.route(_at(1, 2, _down(), hits));

      final msgs = router.route(const FocusMsg(hasFocus: false));

      expect(msgs.first, const PointerCancelMsg(null));
    });
  });

  group('hover', () {
    test('arriving over a widget says nothing — the pointer event is the news', () {
      final msgs = router.route(_at(1, 1, _move(), hits));

      expect(msgs, hasLength(1), reason: 'there is no enter message');
      expect(router.hoverId, 'left');
    });

    test('the widget being left hears so before the event that left it', () {
      router.route(_at(1, 1, _move(), hits));

      final msgs = router.route(_at(5, 1, _move(), hits));

      expect(msgs.first, const PointerLeaveMsg('left'));
      expect(_only(msgs).targetId, 'right');
      expect(router.hoverId, 'right');
    });

    test('leaving for the background still says goodbye', () {
      router.route(_at(1, 1, _move(), hits));

      final msgs = router.route(_at(8, 2, _move(), hits));

      expect(msgs.first, const PointerLeaveMsg('left'));
      expect(router.hoverId, isNull);
    });

    test('a press at a fresh position moves hover too, not only a move', () {
      router.route(_at(1, 1, _move(), hits));

      final msgs = router.route(_at(5, 1, _down(), hits));

      expect(msgs.first, const PointerLeaveMsg('left'));
      expect(router.hoverId, 'right');
    });

    test('hover holds still for the length of a gesture', () {
      router.route(_at(1, 1, _down(), hits));

      final msgs = router.route(_at(5, 1, _drag(), hits));

      expect(msgs.whereType<PointerLeaveMsg>(), isEmpty, reason: 'the pointer is in use, not browsing');
      expect(router.hoverId, 'left');
    });

    test('and picks up wherever the cursor is once the button comes up', () {
      router.route(_at(1, 1, _down(), hits));

      final msgs = router.route(_at(5, 1, _up(), hits));

      expect(msgs, [
        PointerMsg(
          global: const Position(5, 1),
          action: PointerAction.up,
          button: PointerButton.left,
          targetId: 'left',
          local: const Position(5, 1),
          targetRect: Rect.create(x: 0, y: 0, width: 4, height: 2),
          captured: true,
          clickCount: 1,
        ),
        const PointerLeaveMsg('left'),
      ], reason: 'the release reaches the captor first, and only then does hover catch up');
      expect(router.hoverId, 'right');
    });

    test('a release inside the captor leaves hover where it is', () {
      router.route(_at(1, 1, _down(), hits));

      final msgs = router.route(_at(2, 1, _up(), hits));

      expect(msgs.whereType<PointerLeaveMsg>(), isEmpty);
      expect(router.hoverId, 'left');
    });
  });

  group('wheel', () {
    test('turns for whatever is under the pointer, even while another widget holds a gesture', () {
      router.route(_at(1, 1, _down(), hits));

      final p = _only(router.route(_at(5, 1, MouseButton.wheelDown(), hits)));

      expect(p.targetId, 'right', reason: 'the wheel is not part of a button gesture');
      expect(p.captured, isFalse);
      expect(p.isWheel, isTrue);
      expect(router.captureId, 'left', reason: 'and it leaves the gesture alone');
    });

    test('and leaves a held gesture alone even once its captor is gone', () {
      router.route(_at(1, 1, _down(), hits));

      final newest = _twoPanes(dropLeft: true);
      final msgs = router.route(_at(5, 1, MouseButton.wheelDown(), newest));

      expect(msgs.whereType<PointerCancelMsg>(), isEmpty, reason: 'the wheel does not end a gesture');
      expect(router.capturing, isTrue);
      expect(router.captureId, 'left');
      expect(_only(msgs).targetId, 'right', reason: 'the notch still addresses what is under the pointer');
    });

    test('all four directions arrive, unscaled and unread', () {
      final actions = [
        MouseButton.wheelUp(),
        MouseButton.wheelDown(),
        MouseButton.wheelLeft(),
        MouseButton.wheelRight(),
      ];

      final routed = actions.map((b) => _only(router.route(_at(1, 1, b, hits)))).toList();

      expect(routed.map((p) => p.action), [
        PointerAction.wheelUp,
        PointerAction.wheelDown,
        PointerAction.wheelLeft,
        PointerAction.wheelRight,
      ]);
      expect(routed.every((p) => p.isWheel && p.targetId == 'left'), isTrue);
      expect(routed.every((p) => p.button == PointerButton.none), isTrue, reason: 'wheel carries no button');
    });
  });

  group('click count', () {
    test('a second press on the same cell within the interval counts 2, and its release carries the same count', () {
      final down1 = _only(router.route(_at(1, 1, _down(), hits)));
      router.route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)));

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 100))));
      final up2 = _only(router.route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 150))));

      expect(down1.clickCount, 1);
      expect(down2.clickCount, 2);
      expect(up2.clickCount, 2);
    });

    test('a third press in time counts 3', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)))
        ..route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 100)))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 150)));

      final down3 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 200))));

      expect(down3.clickCount, 3);
    });

    test('past the interval, the count is 1', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)));

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 500))));

      expect(down2.clickCount, 1);
    });

    test('a press on a different cell resets the count to 1', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)));

      final down2 = _only(router.route(_at(2, 1, _down(), hits, at: const Duration(milliseconds: 100))));

      expect(down2.targetId, 'left', reason: 'still the same widget');
      expect(down2.clickCount, 1);
    });

    test('a press on a different target resets the count to 1, even at the same cell', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)));

      // The layout changed under the cursor: the same cell now belongs to
      // the other pane.
      final swapped = _twoPanes(swap: true);
      final down2 = _only(router.route(_at(1, 1, _down(), swapped, at: const Duration(milliseconds: 100))));

      expect(down2.targetId, 'right');
      expect(down2.clickCount, 1);
    });

    test('a press with a different button resets the count to 1', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)));

      final down2 = _only(
        router.route(
          _at(1, 1, MouseButton.down(MouseButtonKind.right), hits, at: const Duration(milliseconds: 100)),
        ),
      );

      expect(down2.clickCount, 1);
    });

    test('the interval is press to press, so a slow release does not break a chain', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 350)));

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 380))));

      expect(down2.clickCount, 2);
    });

    test('a move, a drag and a wheel notch carry no count and leave a chain intact', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)));

      final move = _only(router.route(_at(1, 1, _move(), hits, at: const Duration(milliseconds: 60))));
      final drag = _only(router.route(_at(1, 1, _drag(), hits, at: const Duration(milliseconds: 70))));
      final wheel = _only(router.route(_at(1, 1, MouseButton.wheelDown(), hits, at: const Duration(milliseconds: 80))));

      expect(move.clickCount, 0);
      expect(drag.clickCount, 0);
      expect(wheel.clickCount, 0);

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 100))));
      expect(down2.clickCount, 2);
    });

    test('a bare move while held cancels the gesture and resets the chain', () {
      router
        ..route(_at(1, 1, _down(), hits))
        // A held gesture that sees a bare `moved` treats it as the release
        // happening off-window: the router cancels it.
        ..route(_at(1, 1, _move(), hits, at: const Duration(milliseconds: 50)));

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 100))));

      expect(down2.clickCount, 1);
    });

    test('losing terminal focus resets the chain', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 50)))
        ..route(const FocusMsg(hasFocus: false));

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 100))));

      expect(down2.clickCount, 1);
    });

    test('the background chains with itself', () {
      final down1 = _only(router.route(_at(1, 2, _down(), hits)));
      router.route(_at(1, 2, _up(), hits, at: const Duration(milliseconds: 50)));

      final down2 = _only(router.route(_at(1, 2, _down(), hits, at: const Duration(milliseconds: 100))));

      expect(down1.targetId, isNull);
      expect(down1.clickCount, 1);
      expect(down2.targetId, isNull);
      expect(down2.clickCount, 2);
    });

    test('a press with an earlier time than the last press counts 1', () {
      router
        ..route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 200)))
        ..route(_at(1, 1, _up(), hits, at: const Duration(milliseconds: 250)));

      final down2 = _only(router.route(_at(1, 1, _down(), hits, at: const Duration(milliseconds: 100))));

      expect(down2.clickCount, 1);
    });
  });

  group('dispatch', () {
    test('one Routed case forwards every kind, and a background event falls through it', () {
      final forwarded = <Msg>[];
      var background = 0;

      final traffic = <Msg>[
        const PointerMsg(
          global: Position(1, 1),
          action: PointerAction.down,
          button: PointerButton.left,
          local: Position(1, 1),
          targetId: 'left',
        ),
        const PointerLeaveMsg('left'),
        const PointerCancelMsg('left'),
        const PointerMsg(global: Position(8, 2), action: PointerAction.move, local: Position(8, 2)),
      ];

      for (final msg in traffic) {
        switch (msg) {
          case Routed(:final targetId?) when targetId == 'left':
            forwarded.add(msg);
          case PointerMsg():
            background++;
          default:
            fail('nothing else should reach here');
        }
      }

      expect(forwarded, hasLength(3), reason: 'pointer, leave and cancel share one line');
      expect(background, 1, reason: 'a null target declines the Routed case');
    });
  });

  group('a fresh run', () {
    test('forgets the pointer', () {
      router
        ..route(_at(1, 1, _down(), hits))
        ..reset();

      expect(router.capturing, isFalse);
      expect(router.captureId, isNull);
      expect(router.hoverId, isNull);
    });
  });

  group('region', () {
    late HitMap list;

    setUp(() {
      list = _listHits();
    });

    test('a pointer over a marked part carries its region', () {
      final p0 = _only(router.route(_at(1, 0, _move(), list)));
      final p1 = _only(router.route(_at(1, 4, _move(), list)));

      expect(p0.targetId, 'list');
      expect(p0.region, const _Row(0));
      expect(p1.region, const _Row(1), reason: 'the second line of item 1 is still item 1');
    });

    test('a pointer over an unmarked cell carries a null region', () {
      final p = _only(router.route(_at(1, 2, _move(), list)));

      expect(p.targetId, 'list', reason: 'still over the widget');
      expect(p.region, isNull, reason: 'but the separator is marked by nobody');
    });

    test('a tag-only widget and the background both carry a null region', () {
      // `_twoPanes` widgets mark nothing — the permanent tag-only tier — and the
      // bottom row belongs to no widget at all.
      final onPane = _only(router.route(_at(1, 1, _move(), hits)));
      final onBackground = _only(router.route(_at(8, 2, _move(), hits)));

      expect(onPane.targetId, 'left');
      expect(onPane.region, isNull, reason: 'a widget that marks no regions delivers a null region');
      expect(onBackground.targetId, isNull);
      expect(onBackground.region, isNull);
    });

    test('a captured gesture recomputes the region per event', () {
      router.route(_at(1, 0, _down(), list));

      final onRow1 = _only(router.route(_at(1, 3, _drag(), list)));
      final onSeparator = _only(router.route(_at(1, 2, _drag(), list)));
      final offWidget = _only(router.route(_at(20, 1, _drag(), list)));

      expect(onRow1.captured, isTrue);
      expect(onRow1.region, const _Row(1), reason: 'the captor resolves the part now under the pointer');
      expect(onSeparator.region, isNull, reason: 'an unmarked cell inside the captor');
      expect(offWidget.region, isNull, reason: 'the pointer has left the widget holding the gesture');
    });

    test('a wheel over a marked part carries its region, harmless above region logic', () {
      final p = _only(router.route(_at(1, 4, MouseButton.wheelDown(), list)));

      expect(p.isWheel, isTrue);
      expect(p.targetId, 'list');
      expect(p.region, const _Row(1), reason: 'the wheel addresses what is under the pointer');
    });
  });
}
