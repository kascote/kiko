import 'dart:async';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Test event source that returns scripted events.
class TestEventSource implements EventSource {
  final List<Event> _events;
  int _index = 0;

  TestEventSource([List<Event> events = const []]) : _events = List.of(events);

  /// Adds an event to be returned.
  void addEvent(Event event) => _events.add(event);

  @override
  Event poll() {
    if (_index < _events.length) {
      return _events[_index++];
    }
    return const NoneEvent();
  }

  @override
  Future<Event> readEvent({required int timeout}) async {
    if (_index < _events.length) {
      return _events[_index++];
    }
    return Future.delayed(
      Duration(milliseconds: timeout),
      () => const NoneEvent(),
    );
  }
}

/// Custom message for testing.
class TestMsg extends Msg {
  final String value;
  const TestMsg(this.value);
}

void main() {
  group('MvuRuntime', () {
    late MvuRuntime runtime;

    setUp(() {
      runtime = MvuRuntime();
    });

    tearDown(() {
      runtime.dispose();
    });

    group('processCmd', () {
      test('null returns false (continue)', () {
        expect(runtime.processCmd(null), isFalse);
      });

      test('None returns false (continue)', () {
        expect(runtime.processCmd(const None()), isFalse);
      });

      test('Quit returns true (exit) with default code 0', () {
        expect(runtime.processCmd(const Quit()), isTrue);
        expect(runtime.exitCode, equals(0));
      });

      test('Quit returns true with custom exit code', () {
        expect(runtime.processCmd(const Quit(42)), isTrue);
        expect(runtime.exitCode, equals(42));
      });

      test('Quit stops tick from producing messages', () async {
        final source = TestEventSource();

        // Start tick, then quit
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..processCmd(const Quit());

        // Wait enough time for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Add an event so nextMsg can return
        source.addEvent(const KeyEvent(KeyCode.char('x')));

        // Should get the key event, not a TickMsg
        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('Tick produces TickMsg periodically', () async {
        final source = TestEventSource();

        runtime.processCmd(const Tick(Duration(milliseconds: 30)));

        // Wait for tick to fire
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should get TickMsg from queue
        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<TickMsg>());
      });

      test('StopTick prevents further TickMsg', () async {
        final source = TestEventSource();

        // Start then stop tick
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..processCmd(const StopTick());

        // Wait enough time for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Add an event so nextMsg can return
        source.addEvent(const KeyEvent(KeyCode.char('x')));

        // Should get the key event, not a TickMsg
        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('StopTick is safe when no timer active', () {
        expect(() => runtime.processCmd(const StopTick()), returnsNormally);
      });

      test('Task queues result message on success', () async {
        final source = TestEventSource();
        final task = Task<int>(
          () async => 42,
          onSuccess: (v) => TestMsg('got $v'),
        );

        runtime.processCmd(task);

        // Wait for task to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, equals('got 42'));
      });

      test('Task queues error message on failure', () async {
        final source = TestEventSource();
        final task = Task<int>(
          () async => throw Exception('oops'),
          onError: (e) => TestMsg('error: $e'),
        );

        runtime.processCmd(task);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, contains('error:'));
      });

      test('Task queues NoneMsg when no handlers provided', () async {
        final source = TestEventSource();
        final task = Task<int>(() async => 42);

        runtime.processCmd(task);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<NoneMsg>());
      });

      test('Batch processes all commands', () async {
        final source = TestEventSource();

        runtime.processCmd(
          Batch([
            Task(() async => 1, onSuccess: (_) => const TestMsg('1')),
            Task(() async => 2, onSuccess: (_) => const TestMsg('2')),
            Task(() async => 3, onSuccess: (_) => const TestMsg('3')),
          ]),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // All 3 tasks should have queued messages
        final msg1 = await runtime.nextMsg(source, timeout: 100);
        final msg2 = await runtime.nextMsg(source, timeout: 100);
        final msg3 = await runtime.nextMsg(source, timeout: 100);

        expect((msg1 as TestMsg).value, equals('1'));
        expect((msg2 as TestMsg).value, equals('2'));
        expect((msg3 as TestMsg).value, equals('3'));
      });

      test('Batch stops on first Quit', () {
        final result = runtime.processCmd(
          Batch([
            const Tick(Duration(milliseconds: 100)),
            const Quit(5),
            const Tick(Duration(milliseconds: 200)),
          ]),
        );

        expect(result, isTrue);
        expect(runtime.exitCode, equals(5));
      });

      test('Batch returns Quit exit code', () {
        runtime.processCmd(
          Batch([const None(), const Quit(99), const None()]),
        );
        expect(runtime.exitCode, equals(99));
      });

      test('nested Batch works correctly', () {
        final result = runtime.processCmd(
          Batch([
            const None(),
            Batch([const None(), const Quit(7)]),
            const None(),
          ]),
        );

        expect(result, isTrue);
        expect(runtime.exitCode, equals(7));
      });

      test('Emit queues message immediately', () async {
        final source = TestEventSource();

        runtime.processCmd(const Emit(TestMsg('emitted')));

        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, equals('emitted'));
      });

      test('Emit in Batch queues all messages', () async {
        final source = TestEventSource();

        runtime.processCmd(
          Batch([
            const Emit(TestMsg('first')),
            const Emit(TestMsg('second')),
          ]),
        );

        final msg1 = await runtime.nextMsg(source, timeout: 100);
        final msg2 = await runtime.nextMsg(source, timeout: 100);

        expect((msg1 as TestMsg).value, equals('first'));
        expect((msg2 as TestMsg).value, equals('second'));
      });
    });

    group('queueMsg and nextMsg', () {
      test('queueMsg messages are returned by nextMsg', () async {
        final source = TestEventSource();

        runtime
          ..queueMsg(const TestMsg('a'))
          ..queueMsg(const TestMsg('b'));

        final msg1 = await runtime.nextMsg(source, timeout: 100);
        final msg2 = await runtime.nextMsg(source, timeout: 100);

        expect((msg1 as TestMsg).value, equals('a'));
        expect((msg2 as TestMsg).value, equals('b'));
      });

      test('queued messages have priority over polled events', () async {
        final source = TestEventSource([
          const KeyEvent(KeyCode.char('x')),
        ]);

        runtime.queueMsg(const TestMsg('queued'));

        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, equals('queued'));
      });

      test('reset clears queued messages', () async {
        final source = TestEventSource([
          const KeyEvent(KeyCode.char('x')),
        ]);

        runtime
          ..queueMsg(const TestMsg('will be cleared'))
          ..reset();

        // Should get the event, not the cleared message
        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('reset clears exitCode', () {
        runtime
          ..exitCode = 42
          ..reset();

        expect(runtime.exitCode, equals(0));
      });

      test('reset stops tick from producing messages', () async {
        final source = TestEventSource();

        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..reset();

        // Wait for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        source.addEvent(const KeyEvent(KeyCode.char('x')));

        // Should get the key event, not a TickMsg
        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<KeyMsg>());
      });
    });

    group('nextMsg event conversion', () {
      test('converts KeyEvent to KeyMsg', () async {
        final source = TestEventSource([
          const KeyEvent(KeyCode.char('z')),
        ]);

        final msg = await runtime.nextMsg(source, timeout: 100);

        expect(msg, isA<KeyMsg>());
        expect((msg as KeyMsg).key.code.char, equals('z'));
      });

      test('converts MouseEvent to MouseMsg', () async {
        final source = TestEventSource([
          MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left)),
        ]);

        final msg = await runtime.nextMsg(source, timeout: 100);

        expect(msg, isA<MouseMsg>());
        expect((msg as MouseMsg).x, equals(10));
        expect(msg.y, equals(20));
      });

      test('converts FocusEvent to FocusMsg', () async {
        final source = TestEventSource([
          const FocusEvent(),
        ]);

        final msg = await runtime.nextMsg(source, timeout: 100);

        expect(msg, isA<FocusMsg>());
        expect((msg as FocusMsg).hasFocus, isTrue);
      });

      test('drains queue before polling', () async {
        final source = TestEventSource([
          const KeyEvent(KeyCode.char('x')),
          const KeyEvent(KeyCode.char('y')),
        ]);

        runtime
          ..queueMsg(const TestMsg('first'))
          ..queueMsg(const TestMsg('second'));

        final msg1 = await runtime.nextMsg(source, timeout: 100);
        final msg2 = await runtime.nextMsg(source, timeout: 100);
        final msg3 = await runtime.nextMsg(source, timeout: 100);

        expect((msg1 as TestMsg).value, equals('first'));
        expect((msg2 as TestMsg).value, equals('second'));
        expect((msg3 as KeyMsg).key.code.char, equals('x'));
      });

      test('returns NoneMsg on timeout (enables render cycle)', () async {
        // Empty source - will timeout
        final source = TestEventSource();

        final msg = await runtime.nextMsg(source, timeout: 10);

        // Must return NoneMsg, not block forever
        // This is critical for continuous rendering (animations, FPS counters)
        expect(msg, isA<NoneMsg>());
      });

      test('returns NoneMsg on each timeout (render cycle continues)', () async {
        // Empty source - multiple timeouts
        final source = TestEventSource();

        // Simulate multiple render cycles with no input
        final msg1 = await runtime.nextMsg(source, timeout: 10);
        final msg2 = await runtime.nextMsg(source, timeout: 10);
        final msg3 = await runtime.nextMsg(source, timeout: 10);

        // Each call must return NoneMsg, not block
        expect(msg1, isA<NoneMsg>());
        expect(msg2, isA<NoneMsg>());
        expect(msg3, isA<NoneMsg>());
      });
    });

    group('dispose', () {
      test('safe to call multiple times', () {
        runtime.dispose();
        expect(() => runtime.dispose(), returnsNormally);
      });

      test('stops tick from producing messages', () async {
        final source = TestEventSource();

        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..dispose();

        await Future<void>.delayed(const Duration(milliseconds: 50));

        source.addEvent(const KeyEvent(KeyCode.char('x')));

        // Should get the key event, not a TickMsg
        final msg = await runtime.nextMsg(source, timeout: 100);
        expect(msg, isA<KeyMsg>());
      });
    });
  });

  group('eventToMsg', () {
    test('converts KeyEvent', () {
      final msg = eventToMsg(const KeyEvent(KeyCode.char('a')));
      expect(msg, isA<KeyMsg>());
    });

    test('converts MouseEvent', () {
      final msg = eventToMsg(
        MouseEvent(0, 0, MouseButton.down(MouseButtonKind.left)),
      );
      expect(msg, isA<MouseMsg>());
    });

    test('converts FocusEvent', () {
      final msg = eventToMsg(const FocusEvent());
      expect(msg, isA<FocusMsg>());
    });

    test('converts PasteEvent', () {
      final msg = eventToMsg(const PasteEvent('hello'));
      expect(msg, isA<PasteMsg>());
      expect((msg as PasteMsg).text, equals('hello'));
    });

    test('converts NoneEvent', () {
      final msg = eventToMsg(const NoneEvent());
      expect(msg, isA<NoneMsg>());
    });

    test('converts unknown event to UnknownMsg', () {
      final msg = eventToMsg(const CursorPositionEvent(0, 0));
      expect(msg, isA<UnknownMsg>());
    });
  });
}
