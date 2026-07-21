import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// Minimal [Component] used to give [FocusSlot] company inside a [FocusGroup].
class _FakeComponent implements Component {
  _FakeComponent(this.id);

  @override
  final String id;

  @override
  bool focused = false;

  @override
  UpdateResult update(Msg msg) => const Handled();
}

void main() {
  group('FocusSlot', () {
    test('declines a key message', () {
      final slot = FocusSlot();
      expect(slot.update(const KeyMsg('enter')), isA<Declined>());
    });

    test('declines a pointer message', () {
      final slot = FocusSlot();
      final msg = PointerMsg(
        global: Position.origin,
        action: PointerAction.down,
        targetId: slot.id,
        local: Position.origin,
      );
      expect(slot.update(msg), isA<Declined>());
    });

    test('declines any other message', () {
      final slot = FocusSlot();
      expect(slot.update(const NoneMsg()), isA<Declined>());
    });

    test('defaults to unfocused, and focused is settable', () {
      final slot = FocusSlot();
      expect(slot.focused, isFalse);
      slot.focused = true;
      expect(slot.focused, isTrue);
    });

    test('accepts an explicit id', () {
      final slot = FocusSlot(id: 'sink');
      expect(slot.id, equals('sink'));
    });

    test('gets an auto-generated id when none is given', () {
      final slot = FocusSlot();
      expect(slot.id, isNotEmpty);
    });

    test('cycling a FocusGroup onto a slot focuses it like any other member', () {
      final other = _FakeComponent('other');
      final slot = FocusSlot();
      final focus = FocusGroup<Component>([other, slot])..cycle(1);

      expect(focus.focused, same(slot));
      expect(slot.focused, isTrue);
      expect(other.focused, isFalse);
    });
  });
}
