import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// A stand-in widget event, the shape a real one takes ([id] plus payload).
///
/// Keeps the default [WidgetEvent.scopeUnder], the way most events do.
class _TestEvent extends WidgetEvent {
  _TestEvent(this.id);

  @override
  final String id;
}

/// A stand-in widget event whose reply comes back addressed, the shape
/// `LoadRequest` takes.
///
/// Overrides [WidgetEvent.scopeUnder] to join its id under the scope.
class _AddressedTestEvent extends WidgetEvent {
  _AddressedTestEvent(this.id);

  @override
  final String id;

  @override
  WidgetEvent scopeUnder(String scope) => _AddressedTestEvent(HitTag.join(scope, id));
}

void main() {
  group('UpdateResult.scopeUnder', () {
    test('joins a bare Tick under the scope', () {
      const result = Handled(cmd: Tick(Duration(seconds: 1), id: 'field'));

      final scoped = result.scopeUnder('combo');

      expect(scoped, isA<Handled>());
      final cmd = (scoped as Handled).cmd;
      expect(cmd, isA<Tick>());
      expect((cmd! as Tick).id, 'combo/field');
    });

    test('rewrites every Tick in a nested Batch, keeping order, leaving '
        'Quit and Task untouched', () {
      final task = Task<void>(() async {});
      final result = Handled(
        cmd: Batch([
          const Tick(Duration(seconds: 1), id: 'field'),
          const Quit(),
          Batch([const Tick(Duration(seconds: 2), id: 'popup'), task]),
        ]),
      );

      final scoped = result.scopeUnder('combo') as Handled;
      final cmds = (scoped.cmd! as Batch).cmds;

      expect((cmds[0] as Tick).id, 'combo/field');
      expect(cmds[1], isA<Quit>());
      final nested = (cmds[2] as Batch).cmds;
      expect((nested[0] as Tick).id, 'combo/popup');
      expect(nested[1], same(task));
    });

    test('an event with the default scopeUnder comes out identical', () {
      final event = _TestEvent('field');
      final result = Handled(
        events: [event],
        cmd: const Tick(Duration(seconds: 1), id: 'field'),
      );

      final scoped = result.scopeUnder('combo') as Handled;

      expect(scoped.events, [same(event)]);
    });

    test('an event that overrides scopeUnder comes out with the joined id', () {
      final result = Handled(events: [_AddressedTestEvent('field')]);

      final scoped = result.scopeUnder('combo') as Handled;

      expect(scoped.events, hasLength(1));
      expect(scoped.events.single.id, 'combo/field');
    });

    test('passes Declined through unchanged', () {
      const result = Declined();

      expect(result.scopeUnder('combo'), same(result));
    });

    test('a null cmd stays null', () {
      final result = Handled.event(_TestEvent('field'));

      final scoped = result.scopeUnder('combo') as Handled;

      expect(scoped.cmd, isNull);
    });

    test('an empty scope leaves the id unchanged', () {
      const result = Handled(cmd: Tick(Duration(seconds: 1), id: 'field'));

      final scoped = result.scopeUnder('') as Handled;

      expect((scoped.cmd! as Tick).id, 'field');
    });
  });
}
