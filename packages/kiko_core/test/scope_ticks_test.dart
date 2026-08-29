import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// A stand-in widget event, the shape a real one takes ([id] plus payload).
class _TestEvent extends WidgetEvent {
  _TestEvent(this.id);

  @override
  final String id;
}

void main() {
  group('UpdateResult.scopeTicks', () {
    test('joins a bare Tick under the scope', () {
      const result = Handled(cmd: Tick(Duration(seconds: 1), id: 'field'));

      final scoped = result.scopeTicks('combo');

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

      final scoped = result.scopeTicks('combo') as Handled;
      final cmds = (scoped.cmd! as Batch).cmds;

      expect((cmds[0] as Tick).id, 'combo/field');
      expect(cmds[1], isA<Quit>());
      final nested = (cmds[2] as Batch).cmds;
      expect((nested[0] as Tick).id, 'combo/popup');
      expect(nested[1], same(task));
    });

    test('passes events through untouched', () {
      final events = [_TestEvent('field')];
      final result = Handled(
        events: events,
        cmd: const Tick(Duration(seconds: 1), id: 'field'),
      );

      final scoped = result.scopeTicks('combo') as Handled;

      expect(scoped.events, same(events));
    });

    test('passes Declined through unchanged', () {
      const result = Declined();

      expect(result.scopeTicks('combo'), same(result));
    });

    test('a null cmd stays null', () {
      final result = Handled.event(_TestEvent('field'));

      final scoped = result.scopeTicks('combo') as Handled;

      expect(scoped.cmd, isNull);
    });

    test('an empty scope leaves the id unchanged', () {
      const result = Handled(cmd: Tick(Duration(seconds: 1), id: 'field'));

      final scoped = result.scopeTicks('') as Handled;

      expect((scoped.cmd! as Tick).id, 'field');
    });
  });
}
