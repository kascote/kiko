import 'dart:async';

import 'package:kiko/kiko.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// Test event stream controller for injecting events.
class TestEventStream {
  final _controller = StreamController<Event>.broadcast();

  /// The stream to subscribe to.
  Stream<Event> get stream => _controller.stream;

  /// Emits an event to subscribers.
  void emit(Event event) => _controller.add(event);

  /// Closes the stream.
  Future<void> close() => _controller.close();
}

/// Custom message for testing.
class TestMsg extends Msg {
  final String value;
  const TestMsg(this.value);
}

void main() {
  group('MvuRuntime', () {
    late MvuRuntime runtime;
    late TestEventStream events;

    setUp(() {
      runtime = MvuRuntime();
      events = TestEventStream();
      runtime.subscribeToEvents(events.stream);
    });

    tearDown(() async {
      runtime.dispose();
      await events.close();
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
        // Start tick, then quit
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..processCmd(const Quit());

        // Wait enough time for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // After Quit, subscription is cancelled, so nextMsg returns NoneMsg on timeout.
        // The key thing is that tick timer was stopped by Quit, so no TickMsg was queued.
        final msg = await runtime.nextMsg(timeout: 10);
        expect(msg, isA<NoneMsg>());
      });

      test('Tick produces TickMsg periodically', () async {
        runtime.processCmd(const Tick(Duration(milliseconds: 30)));

        // Wait for tick to fire
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should get TickMsg from queue
        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<TickMsg>());
      });

      test('StopTick prevents further TickMsg', () async {
        // Start then stop tick
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..processCmd(const StopTick());

        // Wait enough time for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Emit an event so nextMsg can return
        events.emit(const KeyEvent(KeyCode.char('x')));

        // Allow stream to deliver event
        await Future<void>.delayed(Duration.zero);

        // Should get the key event, not a TickMsg
        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('StopTick is safe when no timer active', () {
        expect(() => runtime.processCmd(const StopTick()), returnsNormally);
      });

      test('Task queues result message on success', () async {
        final task = Task<int>(
          () async => 42,
          onSuccess: (v) => TestMsg('got $v'),
        );

        runtime.processCmd(task);

        // Wait for task to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, equals('got 42'));
      });

      test('Task queues error message on failure', () async {
        final task = Task<int>(
          () async => throw Exception('oops'),
          onError: (e) => TestMsg('error: $e'),
        );

        runtime.processCmd(task);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, contains('error:'));
      });

      test('Task queues NoneMsg when no handlers provided', () async {
        final task = Task<int>(() async => 42);

        runtime.processCmd(task);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<NoneMsg>());
      });

      test('Batch processes all commands', () async {
        runtime.processCmd(
          Batch([
            Task(() async => 1, onSuccess: (_) => const TestMsg('1')),
            Task(() async => 2, onSuccess: (_) => const TestMsg('2')),
            Task(() async => 3, onSuccess: (_) => const TestMsg('3')),
          ]),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // All 3 tasks should have queued messages
        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);
        final msg3 = await runtime.nextMsg(timeout: 100);

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

      test('Task result discarded after Quit (orphaned task)', () async {
        final completer = Completer<int>();

        // Start a task that won't complete immediately
        final task = Task<int>(
          () => completer.future,
          onSuccess: (v) => TestMsg('got $v'),
        );
        runtime
          ..processCmd(task)
          // Quit before task completes
          ..processCmd(const Quit());

        // Now complete the task
        completer.complete(42);

        // Give time for the task callback to run
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // After Quit, subscription is cancelled and task result was discarded.
        // nextMsg returns NoneMsg on timeout - the key thing is no TestMsg was queued.
        final msg = await runtime.nextMsg(timeout: 10);
        expect(msg, isA<NoneMsg>());
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
        runtime.processCmd(const Emit(TestMsg('emitted')));

        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, equals('emitted'));
      });

      test('Emit in Batch queues all messages', () async {
        runtime.processCmd(
          Batch([
            const Emit(TestMsg('first')),
            const Emit(TestMsg('second')),
          ]),
        );

        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as TestMsg).value, equals('first'));
        expect((msg2 as TestMsg).value, equals('second'));
      });
    });

    group('queueMsg and nextMsg', () {
      test('queueMsg messages are returned by nextMsg', () async {
        runtime
          ..queueMsg(const TestMsg('a'))
          ..queueMsg(const TestMsg('b'));

        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as TestMsg).value, equals('a'));
        expect((msg2 as TestMsg).value, equals('b'));
      });

      test('FIFO ordering: queued before stream events', () async {
        // Queue a message first
        runtime.queueMsg(const TestMsg('queued'));

        // Then emit a terminal event
        events.emit(const KeyEvent(KeyCode.char('x')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        // Queued message should come first (FIFO)
        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as TestMsg).value, equals('queued'));
        expect(msg2, isA<KeyMsg>());
      });

      test('FIFO ordering: stream events arrive in order', () async {
        // Emit multiple events
        events
          ..emit(const KeyEvent(KeyCode.char('a')))
          ..emit(const KeyEvent(KeyCode.char('b')))
          ..emit(const KeyEvent(KeyCode.char('c')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);
        final msg3 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as KeyMsg).key, equals('a'));
        expect((msg2 as KeyMsg).key, equals('b'));
        expect((msg3 as KeyMsg).key, equals('c'));
      });

      test('reset clears queued messages', () async {
        runtime
          ..queueMsg(const TestMsg('will be cleared'))
          ..reset()
          ..subscribeToEvents(events.stream);

        // Emit an event so nextMsg can return
        events.emit(const KeyEvent(KeyCode.char('x')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        // Should get the event, not the cleared message
        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('reset clears exitCode', () {
        runtime
          ..exitCode = 42
          ..reset();

        expect(runtime.exitCode, equals(0));
      });

      test('reset stops tick from producing messages', () async {
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..reset()
          ..subscribeToEvents(events.stream);

        // Wait for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        events.emit(const KeyEvent(KeyCode.char('x')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        // Should get the key event, not a TickMsg
        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<KeyMsg>());
      });
    });

    group('nextMsg event conversion', () {
      test('converts KeyEvent to KeyMsg', () async {
        events.emit(const KeyEvent(KeyCode.char('z')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = await runtime.nextMsg(timeout: 100);

        expect(msg, isA<KeyMsg>());
        expect((msg as KeyMsg).key, equals('z'));
      });

      test('converts MouseEvent to MouseMsg', () async {
        events.emit(MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left)));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = await runtime.nextMsg(timeout: 100);

        expect(msg, isA<MouseMsg>());
        expect((msg as MouseMsg).x, equals(10));
        expect(msg.y, equals(20));
      });

      test('converts FocusEvent to FocusMsg', () async {
        events.emit(const FocusEvent());

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = await runtime.nextMsg(timeout: 100);

        expect(msg, isA<FocusMsg>());
        expect((msg as FocusMsg).hasFocus, isTrue);
      });

      test('drains queue before stream events', () async {
        runtime
          ..queueMsg(const TestMsg('first'))
          ..queueMsg(const TestMsg('second'));

        events
          ..emit(const KeyEvent(KeyCode.char('x')))
          ..emit(const KeyEvent(KeyCode.char('y')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);
        final msg3 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as TestMsg).value, equals('first'));
        expect((msg2 as TestMsg).value, equals('second'));
        expect((msg3 as KeyMsg).key, equals('x'));
      });

      test('returns NoneMsg on timeout (enables render cycle)', () async {
        // No events - will timeout
        final msg = await runtime.nextMsg(timeout: 10);

        // Must return NoneMsg, not block forever
        // This is critical for continuous rendering (animations, FPS counters)
        expect(msg, isA<NoneMsg>());
      });

      test('returns NoneMsg on each timeout (render cycle continues)', () async {
        // No events - multiple timeouts
        // Simulate multiple render cycles with no input
        final msg1 = await runtime.nextMsg(timeout: 10);
        final msg2 = await runtime.nextMsg(timeout: 10);
        final msg3 = await runtime.nextMsg(timeout: 10);

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
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20)))
          ..dispose();

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // After dispose, tick timer is stopped and subscription is cancelled.
        // nextMsg returns NoneMsg on timeout - the key thing is no TickMsg was queued.
        final msg = await runtime.nextMsg(timeout: 10);
        expect(msg, isA<NoneMsg>());
      });
    });

    group('unified FIFO ordering', () {
      test('interleaves ticks and stream events fairly', () async {
        // Start tick
        runtime.processCmd(const Tick(Duration(milliseconds: 20)));

        // Wait for first tick
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Emit a key event
        events.emit(const KeyEvent(KeyCode.char('a')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        // Get messages - should be in arrival order
        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);

        // First should be TickMsg (arrived first)
        expect(msg1, isA<TickMsg>());
        // Second should be KeyMsg (arrived after)
        expect(msg2, isA<KeyMsg>());

        runtime.processCmd(const StopTick());
      });
    });

    group('FrameTick', () {
      test('startFrameTick produces FrameTickMsg', () async {
        runtime.startFrameTick(60);

        // Wait for at least one frame tick (~17ms for 60fps)
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<FrameTickMsg>());

        final frameTick = msg as FrameTickMsg;
        expect(frameTick.frameNumber, equals(1));
        expect(frameTick.delta.inMilliseconds, greaterThan(0));

        runtime.stopFrameTick();
      });

      test('stopFrameTick stops the timer', () async {
        runtime
          ..startFrameTick(60)
          ..stopFrameTick();

        // Wait enough time for frame tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Emit an event so nextMsg can return
        events.emit(const KeyEvent(KeyCode.char('x')));
        await Future<void>.delayed(Duration.zero);

        // Should get the key event, not a FrameTickMsg
        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('reset stops frame tick timer', () async {
        runtime
          ..startFrameTick(60)
          ..reset()
          ..subscribeToEvents(events.stream);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        events.emit(const KeyEvent(KeyCode.char('x')));
        await Future<void>.delayed(Duration.zero);

        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<KeyMsg>());
      });

      test('Quit stops frame tick timer', () async {
        runtime
          ..startFrameTick(60)
          ..processCmd(const Quit());

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = await runtime.nextMsg(timeout: 10);
        expect(msg, isA<NoneMsg>());
      });

      test('FrameTickMsg has incrementing frame numbers', () async {
        runtime.startFrameTick(100); // 10ms intervals

        await Future<void>.delayed(const Duration(milliseconds: 35));

        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);
        final msg3 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as FrameTickMsg).frameNumber, equals(1));
        expect((msg2 as FrameTickMsg).frameNumber, equals(2));
        expect((msg3 as FrameTickMsg).frameNumber, equals(3));

        runtime.stopFrameTick();
      });

      test('FrameTick separate from user Tick', () async {
        // Start both timers
        runtime
          ..startFrameTick(50) // 20ms intervals
          ..processCmd(const Tick(Duration(milliseconds: 30)));

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should get both types of messages
        final messages = <Msg>[];
        for (var i = 0; i < 3; i++) {
          messages.add(await runtime.nextMsg(timeout: 100));
        }

        expect(messages.whereType<FrameTickMsg>().length, greaterThan(0));
        expect(messages.whereType<TickMsg>().length, greaterThan(0));

        runtime
          ..stopFrameTick()
          ..processCmd(const StopTick());
      });
    });

    group('isStale (frame dropping)', () {
      test('non-droppable messages are never stale', () {
        const keyMsg = KeyMsg('a');
        expect(keyMsg.droppable, isFalse);
        expect(runtime.isStale(keyMsg, 60), isFalse);
      });

      test('fresh FrameTickMsg is not stale', () {
        final msg = FrameTickMsg(
          delta: const Duration(milliseconds: 16),
          frameNumber: 1,
          timestamp: DateTime.now(),
        );
        expect(msg.droppable, isTrue);
        expect(runtime.isStale(msg, 60), isFalse);
      });

      test('old FrameTickMsg is stale', () {
        // At 60fps, stale threshold is ~33ms (2 * 16.67ms)
        final msg = FrameTickMsg(
          delta: const Duration(milliseconds: 16),
          frameNumber: 1,
          timestamp: DateTime.now().subtract(const Duration(milliseconds: 50)),
        );
        expect(runtime.isStale(msg, 60), isTrue);
      });

      test('FrameTickMsg at boundary is not stale', () {
        // At 60fps, stale threshold is ~33ms
        // A message 30ms old should NOT be stale
        final msg = FrameTickMsg(
          delta: const Duration(milliseconds: 16),
          frameNumber: 1,
          timestamp: DateTime.now().subtract(const Duration(milliseconds: 30)),
        );
        expect(runtime.isStale(msg, 60), isFalse);
      });

      test('stale threshold adjusts with fps', () {
        // At 30fps, stale threshold is ~67ms (2 * 33.33ms)
        final msg = FrameTickMsg(
          delta: const Duration(milliseconds: 33),
          frameNumber: 1,
          timestamp: DateTime.now().subtract(const Duration(milliseconds: 50)),
        );
        // 50ms is stale at 60fps but not at 30fps
        expect(runtime.isStale(msg, 60), isTrue);
        expect(runtime.isStale(msg, 30), isFalse);
      });

      test('TickMsg is not droppable', () {
        const msg = TickMsg(Duration(seconds: 1));
        expect(msg.droppable, isFalse);
        expect(runtime.isStale(msg, 60), isFalse);
      });

      test('custom Msg defaults to not droppable', () {
        const msg = TestMsg('test');
        expect(msg.droppable, isFalse);
        expect(runtime.isStale(msg, 60), isFalse);
      });
    });

    group('coalesceQueue', () {
      test('empty queue is unchanged', () {
        runtime.coalesceQueue();
        // No error, queue remains empty
      });

      test('single message is unchanged', () async {
        runtime
          ..queueMsg(const KeyMsg('a'))
          ..coalesceQueue();

        final msg = await runtime.nextMsg(timeout: 100);
        expect((msg as KeyMsg).key, equals('a'));
      });

      test('non-coalesceable messages are preserved', () async {
        runtime
          ..queueMsg(const KeyMsg('a'))
          ..queueMsg(const KeyMsg('b'))
          ..queueMsg(const KeyMsg('c'))
          ..coalesceQueue();

        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);
        final msg3 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as KeyMsg).key, equals('a'));
        expect((msg2 as KeyMsg).key, equals('b'));
        expect((msg3 as KeyMsg).key, equals('c'));
      });

      test('mouse moves are coalesced to latest', () async {
        // Queue multiple mouse move events
        runtime
          ..queueMsg(MouseMsg(MouseEvent(0, 0, MouseButton.moved())))
          ..queueMsg(MouseMsg(MouseEvent(5, 5, MouseButton.moved())))
          ..queueMsg(MouseMsg(MouseEvent(10, 10, MouseButton.moved())))
          ..coalesceQueue();

        // Only the latest should remain
        final msg = await runtime.nextMsg(timeout: 100);
        expect(msg, isA<MouseMsg>());
        expect((msg as MouseMsg).x, equals(10));
        expect(msg.y, equals(10));

        // Queue should be empty now (only timeout)
        final next = await runtime.nextMsg(timeout: 10);
        expect(next, isA<NoneMsg>());
      });

      test('mouse drags are coalesced to latest', () async {
        runtime
          ..queueMsg(
            MouseMsg(MouseEvent(0, 0, MouseButton.drag(MouseButtonKind.left))),
          )
          ..queueMsg(
            MouseMsg(MouseEvent(5, 5, MouseButton.drag(MouseButtonKind.left))),
          )
          ..queueMsg(
            MouseMsg(
              MouseEvent(10, 10, MouseButton.drag(MouseButtonKind.left)),
            ),
          )
          ..coalesceQueue();

        final msg = await runtime.nextMsg(timeout: 100);
        expect((msg as MouseMsg).x, equals(10));
      });

      test('mouse clicks are NOT coalesced', () async {
        runtime
          ..queueMsg(
            MouseMsg(MouseEvent(0, 0, MouseButton.down(MouseButtonKind.left))),
          )
          ..queueMsg(
            MouseMsg(MouseEvent(5, 5, MouseButton.down(MouseButtonKind.left))),
          )
          ..coalesceQueue();

        // Both clicks should remain
        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as MouseMsg).x, equals(0));
        expect((msg2 as MouseMsg).x, equals(5));
      });

      test('mixed messages preserve order with coalescing', () async {
        runtime
          ..queueMsg(const KeyMsg('a'))
          ..queueMsg(MouseMsg(MouseEvent(0, 0, MouseButton.moved())))
          ..queueMsg(const KeyMsg('b'))
          ..queueMsg(MouseMsg(MouseEvent(5, 5, MouseButton.moved())))
          ..queueMsg(const KeyMsg('c'))
          ..coalesceQueue();

        // Key messages preserved, mouse moves coalesced
        final msg1 = await runtime.nextMsg(timeout: 100);
        final msg2 = await runtime.nextMsg(timeout: 100);
        final msg3 = await runtime.nextMsg(timeout: 100);
        final msg4 = await runtime.nextMsg(timeout: 100);

        expect((msg1 as KeyMsg).key, equals('a'));
        expect((msg2 as KeyMsg).key, equals('b'));
        expect((msg3 as MouseMsg).x, equals(5)); // latest mouse move
        expect((msg4 as KeyMsg).key, equals('c'));
      });

      test('MouseMsg.coalesceable returns correct values', () {
        final moveMsg = MouseMsg(MouseEvent(0, 0, MouseButton.moved()));
        final dragMsg = MouseMsg(
          MouseEvent(0, 0, MouseButton.drag(MouseButtonKind.left)),
        );
        final clickMsg = MouseMsg(
          MouseEvent(0, 0, MouseButton.down(MouseButtonKind.left)),
        );
        final releaseMsg = MouseMsg(
          MouseEvent(0, 0, MouseButton.up(MouseButtonKind.left)),
        );

        expect(moveMsg.coalesceable, isTrue);
        expect(dragMsg.coalesceable, isTrue);
        expect(clickMsg.coalesceable, isFalse);
        expect(releaseMsg.coalesceable, isFalse);
      });

      test('default Msg is not coalesceable', () {
        const msg = TestMsg('test');
        expect(msg.coalesceable, isFalse);
        expect(msg.coalesceKey, equals(''));
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
