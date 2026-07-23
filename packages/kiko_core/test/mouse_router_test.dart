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
    tag = id;
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

/// A mouse event as it waits in the queue, aimed at [hits].
RawPointerMsg _at(int x, int y, MouseButton button, HitMap hits) => RawPointerMsg(MouseEvent(x, y, button), hits);

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
    router = MouseRouter();
    hits = _twoPanes();
  });

  group('resolution', () {
    test('addresses the widget under the pointer, in that widget’s own cells', () {
      final p = _only(router.route(_at(5, 1, _move(), hits), hits));

      expect(p.targetId, 'right');
      expect(p.global, const Position(5, 1));
      expect(p.local, const Position(1, 1));
      expect(p.targetRect, Rect.create(x: 4, y: 0, width: 4, height: 2));
      expect(p.inside, isTrue);
      expect(p.captured, isFalse);
    });

    test('over no widget, the local position is the absolute one', () {
      final p = _only(router.route(_at(8, 2, _move(), hits), hits));

      expect(p.targetId, isNull);
      expect(p.targetRect, isNull);
      expect(p.local, const Position(8, 2));
      expect(p.inside, isFalse, reason: 'there is nothing to be inside of');
    });

    test('carries the event’s button, action and modifiers in kiko’s own vocabulary', () {
      final event = MouseEvent(5, 1, _down(), modifiers: KeyModifiers.shift);

      final p = _only(router.route(RawPointerMsg(event, hits), hits));

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

      expect(router.route(routed, hits), [same(routed)]);
      expect(router.hoverId, isNull, reason: 'a re-emitted event does not re-run the router');
    });

    test('a key press passes straight through', () {
      expect(router.route(const KeyMsg('a'), hits), [const KeyMsg('a')]);
    });
  });

  group('capture', () {
    test('the release lands on the widget that took the press, wherever the cursor went', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final drag = _only(router.route(_at(6, 1, _drag(), hits), hits));
      final up = _only(router.route(_at(6, 1, _up(), hits), hits));

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
      final down = _only(router.route(_at(1, 1, _down(), hits), hits));

      expect(down.targetId, 'left');
      expect(down.captured, isFalse);
      expect(router.capturing, isTrue);
      expect(router.captureId, 'left');
    });

    test('a press on the background captures the background', () {
      router.route(_at(1, 2, _down(), hits), hits);
      expect(router.capturing, isTrue);
      expect(router.captureId, isNull);

      final drag = _only(router.route(_at(1, 1, _drag(), hits), hits));

      expect(drag.targetId, isNull, reason: 'a rubber band does not grab the first widget it crosses');
      expect(drag.captured, isTrue);
      expect(drag.local, const Position(1, 1));
    });

    test('a second press while a gesture is held goes to the widget holding it', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final second = _only(router.route(_at(6, 1, MouseButton.down(MouseButtonKind.right), hits), hits));

      expect(second.targetId, 'left');
      expect(second.captured, isTrue);
      expect(router.captureId, 'left', reason: 'the slot is not re-taken');
    });

    test('any button releases, because legacy mode reports none on release', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final up = _only(router.route(_at(1, 1, MouseButton.up(), hits), hits));

      expect(up.targetId, 'left');
      expect(router.capturing, isFalse);
    });

    test('the captor’s rect is read from the frame the event was aimed at, not frozen at the press', () {
      router.route(_at(1, 1, _down(), hits), hits);

      // The layout changed under the gesture: `left` is now the right-hand pane.
      final moved = _twoPanes(swap: true);
      final drag = _only(router.route(_at(5, 1, _drag(), moved), moved));

      expect(drag.targetId, 'left');
      expect(drag.targetRect, Rect.create(x: 4, y: 0, width: 4, height: 2));
      expect(drag.local, const Position(1, 1));
      expect(drag.inside, isTrue, reason: 'the user aims at the cells that are on screen now');
    });

    test('a captor painted out of the event’s own frame falls back to absolute coordinates', () {
      router.route(_at(1, 1, _down(), hits), hits);

      // Absent from the event's map, still present in the newest one, so the
      // gesture is not cancelled — it simply has no rect to measure against.
      final drag = _only(router.route(_at(6, 1, _drag(), _twoPanes(dropLeft: true)), hits));

      expect(drag.targetId, 'left');
      expect(drag.captured, isTrue);
      expect(drag.targetRect, isNull);
      expect(drag.local, const Position(6, 1));
    });
  });

  group('capture termination', () {
    test('a bare move while a button is held means the release happened off-window', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final msgs = router.route(_at(6, 1, _move(), hits), hits);

      expect(msgs.first, const PointerCancelMsg('left'));
      expect(router.capturing, isFalse);
      expect(_only(msgs).targetId, 'right', reason: 'and the move itself routes as an ordinary one');
    });

    test('a captor that has left the screen is told its gesture is over', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final newest = _twoPanes(dropLeft: true);
      final msgs = router.route(_at(1, 1, _drag(), newest), newest);

      expect(msgs.first, const PointerCancelMsg('left'));
      expect(router.capturing, isFalse);
    });

    test('losing terminal focus ends the gesture, the hover, and then reports itself', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final msgs = router.route(const FocusMsg(hasFocus: false), hits);

      expect(msgs, [
        const PointerCancelMsg('left'),
        const PointerLeaveMsg('left'),
        const FocusMsg(hasFocus: false),
      ]);
      expect(router.capturing, isFalse);
      expect(router.hoverId, isNull);
    });

    test('regaining focus reports itself and nothing else', () {
      expect(router.route(const FocusMsg(hasFocus: true), hits), [const FocusMsg(hasFocus: true)]);
    });

    test('a gesture on the background is cancelled too, with a null target', () {
      router.route(_at(1, 2, _down(), hits), hits);

      final msgs = router.route(const FocusMsg(hasFocus: false), hits);

      expect(msgs.first, const PointerCancelMsg(null));
    });
  });

  group('hover', () {
    test('arriving over a widget says nothing — the pointer event is the news', () {
      final msgs = router.route(_at(1, 1, _move(), hits), hits);

      expect(msgs, hasLength(1), reason: 'there is no enter message');
      expect(router.hoverId, 'left');
    });

    test('the widget being left hears so before the event that left it', () {
      router.route(_at(1, 1, _move(), hits), hits);

      final msgs = router.route(_at(5, 1, _move(), hits), hits);

      expect(msgs.first, const PointerLeaveMsg('left'));
      expect(_only(msgs).targetId, 'right');
      expect(router.hoverId, 'right');
    });

    test('leaving for the background still says goodbye', () {
      router.route(_at(1, 1, _move(), hits), hits);

      final msgs = router.route(_at(8, 2, _move(), hits), hits);

      expect(msgs.first, const PointerLeaveMsg('left'));
      expect(router.hoverId, isNull);
    });

    test('a press at a fresh position moves hover too, not only a move', () {
      router.route(_at(1, 1, _move(), hits), hits);

      final msgs = router.route(_at(5, 1, _down(), hits), hits);

      expect(msgs.first, const PointerLeaveMsg('left'));
      expect(router.hoverId, 'right');
    });

    test('hover holds still for the length of a gesture', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final msgs = router.route(_at(5, 1, _drag(), hits), hits);

      expect(msgs.whereType<PointerLeaveMsg>(), isEmpty, reason: 'the pointer is in use, not browsing');
      expect(router.hoverId, 'left');
    });

    test('and picks up wherever the cursor is once the button comes up', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final msgs = router.route(_at(5, 1, _up(), hits), hits);

      expect(msgs, [
        PointerMsg(
          global: const Position(5, 1),
          action: PointerAction.up,
          button: PointerButton.left,
          targetId: 'left',
          local: const Position(5, 1),
          targetRect: Rect.create(x: 0, y: 0, width: 4, height: 2),
          captured: true,
        ),
        const PointerLeaveMsg('left'),
      ], reason: 'the release reaches the captor first, and only then does hover catch up');
      expect(router.hoverId, 'right');
    });

    test('a release inside the captor leaves hover where it is', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final msgs = router.route(_at(2, 1, _up(), hits), hits);

      expect(msgs.whereType<PointerLeaveMsg>(), isEmpty);
      expect(router.hoverId, 'left');
    });
  });

  group('wheel', () {
    test('turns for whatever is under the pointer, even while another widget holds a gesture', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final p = _only(router.route(_at(5, 1, MouseButton.wheelDown(), hits), hits));

      expect(p.targetId, 'right', reason: 'the wheel is not part of a button gesture');
      expect(p.captured, isFalse);
      expect(p.isWheel, isTrue);
      expect(router.captureId, 'left', reason: 'and it leaves the gesture alone');
    });

    test('but it still notices that the widget holding a gesture has gone', () {
      router.route(_at(1, 1, _down(), hits), hits);

      final newest = _twoPanes(dropLeft: true);
      final msgs = router.route(_at(5, 1, MouseButton.wheelDown(), newest), newest);

      // The wheel takes no part in the gesture, but it is when the router first
      // sees that the captor is gone — and telling it late is worse than never
      // scaling a notch. The wheel itself still goes to what is under the
      // pointer.
      expect(msgs.first, const PointerCancelMsg('left'));
      expect(router.capturing, isFalse);
      expect(_only(msgs).targetId, 'right');
    });

    test('all four directions arrive, unscaled and unread', () {
      final actions = [
        MouseButton.wheelUp(),
        MouseButton.wheelDown(),
        MouseButton.wheelLeft(),
        MouseButton.wheelRight(),
      ];

      final routed = actions.map((b) => _only(router.route(_at(1, 1, b, hits), hits))).toList();

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
        ..route(_at(1, 1, _down(), hits), hits)
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
      final p0 = _only(router.route(_at(1, 0, _move(), list), list));
      final p1 = _only(router.route(_at(1, 4, _move(), list), list));

      expect(p0.targetId, 'list');
      expect(p0.region, const _Row(0));
      expect(p1.region, const _Row(1), reason: 'the second line of item 1 is still item 1');
    });

    test('a pointer over an unmarked cell carries a null region', () {
      final p = _only(router.route(_at(1, 2, _move(), list), list));

      expect(p.targetId, 'list', reason: 'still over the widget');
      expect(p.region, isNull, reason: 'but the separator is marked by nobody');
    });

    test('a tag-only widget and the background both carry a null region', () {
      // `_twoPanes` widgets mark nothing — the permanent tag-only tier — and the
      // bottom row belongs to no widget at all.
      final onPane = _only(router.route(_at(1, 1, _move(), hits), hits));
      final onBackground = _only(router.route(_at(8, 2, _move(), hits), hits));

      expect(onPane.targetId, 'left');
      expect(onPane.region, isNull, reason: 'a widget that marks no regions delivers a null region');
      expect(onBackground.targetId, isNull);
      expect(onBackground.region, isNull);
    });

    test('a captured gesture recomputes the region per event', () {
      router.route(_at(1, 0, _down(), list), list);

      final onRow1 = _only(router.route(_at(1, 3, _drag(), list), list));
      final onSeparator = _only(router.route(_at(1, 2, _drag(), list), list));
      final offWidget = _only(router.route(_at(20, 1, _drag(), list), list));

      expect(onRow1.captured, isTrue);
      expect(onRow1.region, const _Row(1), reason: 'the captor resolves the part now under the pointer');
      expect(onSeparator.region, isNull, reason: 'an unmarked cell inside the captor');
      expect(offWidget.region, isNull, reason: 'the pointer has left the widget holding the gesture');
    });

    test('a wheel over a marked part carries its region, harmless above region logic', () {
      final p = _only(router.route(_at(1, 4, MouseButton.wheelDown(), list), list));

      expect(p.isWheel, isTrue);
      expect(p.targetId, 'list');
      expect(p.region, const _Row(1), reason: 'the wheel addresses what is under the pointer');
    });
  });
}
