import 'dart:async';

import 'package:kiko/kiko.dart';
// The un-routed form of a mouse event never leaves the runtime, so it is not
// part of the public library. The queue is what these tests are about.
import 'package:kiko/src/mvu/msg.dart' show RawPointerMsg;
import 'package:kiko_log/kiko_log.dart';
import 'package:meta/meta.dart';
import 'package:termparser/termparser_events.dart';
import 'package:test/test.dart';

/// A mouse event as it waits in the queue, aimed at nothing in particular.
RawPointerMsg _pointer(int x, int y, MouseButton button) =>
    RawPointerMsg(MouseEvent(x, y, button), const HitMap.empty());

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

/// A report carrying one number, with value equality: the shape a widget's
/// own kind takes.
@immutable
class _Rows extends FrameReport {
  const _Rows(super.id, this.rows);

  final int rows;

  @override
  bool operator ==(Object other) => other is _Rows && other.id == id && other.rows == rows;

  @override
  int get hashCode => Object.hash(id, rows);
}

/// A second report kind under the same ids as [_Rows].
@immutable
class _Cols extends FrameReport {
  const _Cols(super.id, this.cols);

  final int cols;

  @override
  bool operator ==(Object other) => other is _Cols && other.id == id && other.cols == cols;

  @override
  int get hashCode => Object.hash(id, cols);
}

/// A widget→app event command — the kind that must be consumed in update()
/// and, if forgotten, falls through to the runtime's default guard.
class _WidgetEventCmd extends Cmd {
  const _WidgetEventCmd();
}

/// In-memory log output for asserting on captured records.
class _CapturingOutput implements LogOutput {
  final List<LogRecord> records = [];

  @override
  void write(LogRecord record) => records.add(record);

  @override
  Future<void> close() async {}
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

      test('Quit returns true (exit) with default code 0', () {
        expect(runtime.processCmd(const Quit()), isTrue);
        expect(runtime.exitCode, equals(0));
      });

      test('Quit returns true with custom exit code', () {
        expect(runtime.processCmd(const Quit(42)), isTrue);
        expect(runtime.exitCode, equals(42));
      });

      test('Quit cancels a pending tick', () async {
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20), id: 'clock'))
          ..processCmd(const Quit());

        // Long enough for the tick to have fired had it survived.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runtime.hasPending, isFalse, reason: 'the tick timer was cancelled by Quit');
      });

      test('Tick delivers exactly one TickMsg, addressed and keyed as armed, after its interval', () async {
        runtime.processCmd(const Tick(Duration(milliseconds: 20), id: 'clock', key: 3));

        await Future<void>.delayed(const Duration(milliseconds: 70));

        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<TickMsg>());
        final tick = msg as TickMsg;
        expect(tick.id, 'clock');
        expect(tick.key, 3);
        expect(tick.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 20)), reason: 'measured from arming');
        expect(runtime.hasPending, isFalse, reason: 'one-shot: three intervals passed, one tick arrived');
      });

      test('a TickMsg is Addressed by the id the Tick named', () {
        const msg = TickMsg('clock', elapsed: Duration.zero);
        expect(msg, isA<Addressed>());
        expect((msg as Addressed).id, 'clock');
      });

      test('several ticks may be pending at once, each on its own timer', () async {
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 10), id: 'fast'))
          ..processCmd(const Tick(Duration(milliseconds: 30), id: 'slow'));

        await Future<void>.delayed(const Duration(milliseconds: 60));

        final first = (await runtime.nextMsg())!;
        final second = (await runtime.nextMsg())!;
        expect((first as TickMsg).id, 'fast');
        expect((second as TickMsg).id, 'slow');
        expect(runtime.hasPending, isFalse);
      });

      test('Task queues result message on success', () async {
        final task = Task<int>(
          () async => 42,
          onSuccess: (v) => TestMsg('got $v'),
        );

        runtime.processCmd(task);

        // Wait for task to complete
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final msg = (await runtime.nextMsg())!;
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

        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<TestMsg>());
        expect((msg as TestMsg).value, contains('error:'));
      });

      test('a Task with no handler for its outcome queues nothing', () async {
        runtime
          ..processCmd(Task<int>(() async => 42))
          ..processCmd(Task<int>(() async => throw Exception('oops')));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runtime.hasPending, isFalse);
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
        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;
        final msg3 = (await runtime.nextMsg())!;

        expect((msg1 as TestMsg).value, equals('1'));
        expect((msg2 as TestMsg).value, equals('2'));
        expect((msg3 as TestMsg).value, equals('3'));
      });

      test('Batch stops on first Quit', () {
        final result = runtime.processCmd(
          Batch([
            const Tick(Duration(milliseconds: 100), id: 'a'),
            const Quit(5),
            const Tick(Duration(milliseconds: 200), id: 'b'),
          ]),
        );

        expect(result, isTrue);
        expect(runtime.exitCode, equals(5));
      });

      test('Batch returns Quit exit code', () {
        runtime.processCmd(
          Batch([const Emit(TestMsg('a')), const Quit(99), const Emit(TestMsg('b'))]),
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

        // After Quit the task's result is discarded: nothing was queued.
        expect(runtime.hasPending, isFalse);
      });

      test('nested Batch works correctly', () {
        final result = runtime.processCmd(
          Batch([
            const Emit(TestMsg('a')),
            Batch([const Emit(TestMsg('b')), const Quit(7)]),
            const Emit(TestMsg('c')),
          ]),
        );

        expect(result, isTrue);
        expect(runtime.exitCode, equals(7));
      });

      test('Emit queues message immediately', () async {
        runtime.processCmd(const Emit(TestMsg('emitted')));

        final msg = (await runtime.nextMsg())!;
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

        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;

        expect((msg1 as TestMsg).value, equals('first'));
        expect((msg2 as TestMsg).value, equals('second'));
      });
    });

    group('unhandled command guard', () {
      test('logs a warning when a custom Cmd reaches the runtime', () {
        // The guard is debug-only (assert idiom); tests run with asserts on.
        final output = _CapturingOutput();
        bool? exit;
        Log(output: output, level: LogLevel.debug).runZoned(() {
          exit = runtime.processCmd(const _WidgetEventCmd());
        });

        // Still dropped (returns false), but now observable.
        expect(exit, isFalse);
        expect(output.records, hasLength(1));
        expect(output.records.single.level, equals(LogLevel.warn));
        expect(output.records.single.message, contains('_WidgetEventCmd'));
        expect(output.records.single.message, contains('update()'));
      });

      test('legitimate commands never trip the guard', () {
        final output = _CapturingOutput();
        Log(output: output, level: LogLevel.debug).runZoned(() {
          runtime
            ..processCmd(null)
            ..processCmd(const Emit(TestMsg('x')))
            ..processCmd(const Tick(Duration(seconds: 1), id: 'clock'));
        });

        expect(output.records, isEmpty);
      });
    });

    group('queueMsg and nextMsg', () {
      test('queueMsg messages are returned by nextMsg', () async {
        runtime
          ..queueMsg(const TestMsg('a'))
          ..queueMsg(const TestMsg('b'));

        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;

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
        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;

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

        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;
        final msg3 = (await runtime.nextMsg())!;

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
        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<KeyMsg>());
      });

      test('reset clears exitCode', () {
        runtime
          ..exitCode = 42
          ..reset();

        expect(runtime.exitCode, equals(0));
      });

      test('reset cancels a pending tick', () async {
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20), id: 'clock'))
          ..reset()
          ..subscribeToEvents(events.stream);

        // Wait for tick to have fired if still active
        await Future<void>.delayed(const Duration(milliseconds: 50));

        events.emit(const KeyEvent(KeyCode.char('x')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        // Should get the key event, not a TickMsg
        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<KeyMsg>());
      });
    });

    group('nextMsg event conversion', () {
      test('converts KeyEvent to KeyMsg', () async {
        events.emit(const KeyEvent(KeyCode.char('z')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = (await runtime.nextMsg())!;

        expect(msg, isA<KeyMsg>());
        expect((msg as KeyMsg).key, equals('z'));
      });

      test('converts MouseEvent to a stamped pointer message', () async {
        events.emit(MouseEvent(10, 20, MouseButton.down(MouseButtonKind.left)));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = (await runtime.nextMsg())!;

        expect(msg, isA<RawPointerMsg>());
        expect((msg as RawPointerMsg).mouse.x, equals(10));
        expect(msg.mouse.y, equals(20));
        expect(msg.hits, same(runtime.lastHitMap), reason: 'stamped with the frame it was aimed at');
      });

      test('converts FocusEvent to FocusMsg', () async {
        events.emit(const FocusEvent());

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = (await runtime.nextMsg())!;

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

        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;
        final msg3 = (await runtime.nextMsg())!;

        expect((msg1 as TestMsg).value, equals('first'));
        expect((msg2 as TestMsg).value, equals('second'));
        expect((msg3 as KeyMsg).key, equals('x'));
      });

      test('waits, without polling, until a message is queued', () async {
        var answered = false;
        final waiting = runtime.nextMsg().then((msg) {
          answered = true;
          return msg;
        });

        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(answered, isFalse, reason: 'nothing queued, nothing returned');

        runtime.queueMsg(const TestMsg('late'));
        expect(((await waiting)! as TestMsg).value, 'late');
      });
    });

    group('close', () {
      test('wakes a waiting nextMsg with null', () async {
        final waiting = runtime.nextMsg();
        await Future<void>.delayed(Duration.zero);

        runtime.close();

        expect(await waiting, isNull);
      });

      test('nextMsg answers null after close even while messages remain queued', () async {
        runtime
          ..queueMsg(const TestMsg('left behind'))
          ..close();

        expect(await runtime.nextMsg(), isNull);
        expect(await runtime.nextMsg(), isNull, reason: 'and on every later call');
      });

      test('reset reopens the queue', () async {
        runtime
          ..close()
          ..reset()
          ..queueMsg(const TestMsg('after reset'));

        expect(((await runtime.nextMsg())! as TestMsg).value, 'after reset');
      });
    });

    group('queueReports', () {
      test('a report absent from the previous frame is queued', () async {
        runtime.queueReports([const _Rows('list', 5)]);

        expect(await runtime.nextMsg(), const _Rows('list', 5));
      });

      test("a report equal to the previous frame's is not queued", () async {
        runtime
          ..queueReports([const _Rows('list', 5)])
          ..queueReports([const _Rows('list', 5)]);

        expect(await runtime.nextMsg(), const _Rows('list', 5));
        expect(runtime.hasPending, isFalse, reason: 'the fact did not change');
      });

      test('a report that changed is queued again', () async {
        runtime
          ..queueReports([const _Rows('list', 5)])
          ..queueReports([const _Rows('list', 6)]);

        expect(await runtime.nextMsg(), const _Rows('list', 5));
        expect(await runtime.nextMsg(), const _Rows('list', 6));
      });

      test('a report that skipped a frame is queued when it returns, even unchanged', () async {
        runtime
          ..queueReports([const _Rows('popup', 3)])
          ..queueReports(const [])
          ..queueReports([const _Rows('popup', 3)]);

        expect(await runtime.nextMsg(), const _Rows('popup', 3));
        expect(await runtime.nextMsg(), const _Rows('popup', 3), reason: 'its owner may have forgotten it');
      });

      test('reports are compared per id and type', () async {
        runtime
          ..queueReports([const _Rows('a', 1), const _Rows('b', 1), const _Cols('a', 1)])
          ..queueReports([const _Rows('a', 1), const _Rows('b', 2), const _Cols('a', 1)]);

        final first = [await runtime.nextMsg(), await runtime.nextMsg(), await runtime.nextMsg()];
        expect(first, [const _Rows('a', 1), const _Rows('b', 1), const _Cols('a', 1)]);
        expect(await runtime.nextMsg(), const _Rows('b', 2));
        expect(runtime.hasPending, isFalse);
      });
    });

    group('dispose', () {
      test('safe to call multiple times', () {
        runtime.dispose();
        expect(() => runtime.dispose(), returnsNormally);
      });

      test('cancels a pending tick and closes the queue', () async {
        runtime
          ..processCmd(const Tick(Duration(milliseconds: 20), id: 'clock'))
          ..dispose();

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runtime.hasPending, isFalse, reason: 'the tick timer was cancelled');
        expect(await runtime.nextMsg(), isNull, reason: 'the queue is closed');
      });
    });

    group('unified FIFO ordering', () {
      test('interleaves ticks and stream events fairly', () async {
        // Start tick
        runtime.processCmd(const Tick(Duration(milliseconds: 20), id: 'clock'));

        // Wait for first tick
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Emit a key event
        events.emit(const KeyEvent(KeyCode.char('a')));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        // Get messages - should be in arrival order
        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;

        // First should be TickMsg (arrived first)
        expect(msg1, isA<TickMsg>());
        // Second should be KeyMsg (arrived after)
        expect(msg2, isA<KeyMsg>());
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

        final msg = (await runtime.nextMsg())!;
        expect((msg as KeyMsg).key, equals('a'));
      });

      test('non-coalesceable messages are preserved', () async {
        runtime
          ..queueMsg(const KeyMsg('a'))
          ..queueMsg(const KeyMsg('b'))
          ..queueMsg(const KeyMsg('c'))
          ..coalesceQueue();

        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;
        final msg3 = (await runtime.nextMsg())!;

        expect((msg1 as KeyMsg).key, equals('a'));
        expect((msg2 as KeyMsg).key, equals('b'));
        expect((msg3 as KeyMsg).key, equals('c'));
      });

      test('mouse moves are coalesced to latest', () async {
        // Queue multiple mouse move events
        runtime
          ..queueMsg(_pointer(0, 0, MouseButton.moved()))
          ..queueMsg(_pointer(5, 5, MouseButton.moved()))
          ..queueMsg(_pointer(10, 10, MouseButton.moved()))
          ..coalesceQueue();

        // Only the latest should remain
        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<RawPointerMsg>());
        expect((msg as RawPointerMsg).mouse.x, equals(10));
        expect(msg.mouse.y, equals(10));

        expect(runtime.hasPending, isFalse, reason: 'only the latest remained');
      });

      test('mouse drags are coalesced to latest', () async {
        runtime
          ..queueMsg(_pointer(0, 0, MouseButton.drag(MouseButtonKind.left)))
          ..queueMsg(_pointer(5, 5, MouseButton.drag(MouseButtonKind.left)))
          ..queueMsg(_pointer(10, 10, MouseButton.drag(MouseButtonKind.left)))
          ..coalesceQueue();

        final msg = (await runtime.nextMsg())!;
        expect((msg as RawPointerMsg).mouse.x, equals(10));
      });

      test('mouse clicks are NOT coalesced', () async {
        runtime
          ..queueMsg(_pointer(0, 0, MouseButton.down(MouseButtonKind.left)))
          ..queueMsg(_pointer(5, 5, MouseButton.down(MouseButtonKind.left)))
          ..coalesceQueue();

        // Both clicks should remain
        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;

        expect((msg1 as RawPointerMsg).mouse.x, equals(0));
        expect((msg2 as RawPointerMsg).mouse.x, equals(5));
      });

      test('a wheel notch is a delta, so it is never coalesced', () async {
        runtime
          ..queueMsg(_pointer(0, 0, MouseButton.wheelDown()))
          ..queueMsg(_pointer(0, 0, MouseButton.wheelDown()))
          ..coalesceQueue();

        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;

        expect(msg1, isA<RawPointerMsg>(), reason: 'merging two notches would eat one');
        expect(msg2, isA<RawPointerMsg>());
      });

      test('mixed messages preserve order with coalescing', () async {
        runtime
          ..queueMsg(const KeyMsg('a'))
          ..queueMsg(_pointer(0, 0, MouseButton.moved()))
          ..queueMsg(const KeyMsg('b'))
          ..queueMsg(_pointer(5, 5, MouseButton.moved()))
          ..queueMsg(const KeyMsg('c'))
          ..coalesceQueue();

        // Key messages preserved, mouse moves coalesced
        final msg1 = (await runtime.nextMsg())!;
        final msg2 = (await runtime.nextMsg())!;
        final msg3 = (await runtime.nextMsg())!;
        final msg4 = (await runtime.nextMsg())!;

        expect((msg1 as KeyMsg).key, equals('a'));
        expect((msg2 as KeyMsg).key, equals('b'));
        expect((msg3 as RawPointerMsg).mouse.x, equals(5)); // latest mouse move
        expect((msg4 as KeyMsg).key, equals('c'));
      });

      test('only a position-valued mouse event is coalesceable', () {
        final moveMsg = _pointer(0, 0, MouseButton.moved());
        final dragMsg = _pointer(0, 0, MouseButton.drag(MouseButtonKind.left));
        final clickMsg = _pointer(0, 0, MouseButton.down(MouseButtonKind.left));
        final releaseMsg = _pointer(0, 0, MouseButton.up(MouseButtonKind.left));
        final wheelMsg = _pointer(0, 0, MouseButton.wheelUp());

        expect(moveMsg.coalesceable, isTrue);
        expect(dragMsg.coalesceable, isTrue);
        expect(clickMsg.coalesceable, isFalse);
        expect(releaseMsg.coalesceable, isFalse);
        expect(wheelMsg.coalesceable, isFalse);
      });

      test('default Msg is not coalesceable', () {
        const msg = TestMsg('test');
        expect(msg.coalesceable, isFalse);
        expect(msg.coalesceKey, equals(''));
      });

      test('resizes are coalesced to latest', () async {
        runtime
          ..queueMsg(const ResizeMsg(width: 80, height: 24))
          ..queueMsg(const ResizeMsg(width: 100, height: 30))
          ..queueMsg(const ResizeMsg(width: 120, height: 40))
          ..coalesceQueue();

        // Only the latest should remain
        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<ResizeMsg>());
        expect((msg as ResizeMsg).width, equals(120));
        expect(msg.height, equals(40));

        expect(runtime.hasPending, isFalse, reason: 'only the latest remained');
      });

      test('ResizeMsg is coalesceable under the resize key', () {
        const msg = ResizeMsg(width: 80, height: 24);
        expect(msg.coalesceable, isTrue);
        expect(msg.coalesceKey, equals('resize'));
      });
    });

    group('startup event hold', () {
      test('a resize held for the first frame is swallowed on flush, other events are not', () async {
        runtime.holdEventsForFirstFrame();

        events
          ..emit(const WindowResizeEvent(24, 80))
          ..emit(const KeyEvent(KeyCode.char('x')));

        // Allow stream to deliver into the startup hold
        await Future<void>.delayed(Duration.zero);

        runtime.flushStartupEvents();

        // The key event flushed; the resize did not.
        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<KeyMsg>());

        expect(runtime.hasPending, isFalse, reason: 'the held resize should have been dropped, not queued');
      });

      test('a resize arriving after the flush is delivered normally', () async {
        runtime
          ..holdEventsForFirstFrame()
          ..flushStartupEvents();

        events.emit(const WindowResizeEvent(24, 80));

        // Allow stream to deliver
        await Future<void>.delayed(Duration.zero);

        final msg = (await runtime.nextMsg())!;
        expect(msg, isA<ResizeMsg>());
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
      expect(msg, isA<RawPointerMsg>());
    });

    test('stamps a mouse event with the map it was aimed at', () {
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 4, height: 2));
      final frame = Frame(buffer.area, buffer, 0)
        ..render(Tagged('a', Container(border: BorderType.plain, child: Line(''))));

      final msg = eventToMsg(MouseEvent(0, 0, MouseButton.moved()), hits: frame.hits);

      expect((msg! as RawPointerMsg).hits.hitId(0, 0), 'a');
    });

    test('converts FocusEvent', () {
      final msg = eventToMsg(const FocusEvent());
      expect(msg, isA<FocusMsg>());
    });

    test('converts PasteEvent', () {
      final msg = eventToMsg(const PasteEvent('hello'));
      expect(msg, isA<PasteMsg>());
      expect((msg! as PasteMsg).text, equals('hello'));
    });

    test('drops NoneEvent: there is no event to deliver', () {
      expect(eventToMsg(const NoneEvent()), isNull);
    });

    test('converts unknown event to UnknownMsg', () {
      final msg = eventToMsg(const CursorPositionEvent(0, 0));
      expect(msg, isA<UnknownMsg>());
    });

    test('converts WindowResizeEvent to ResizeMsg', () {
      // The event constructor is height-first; the message fields are not.
      final msg = eventToMsg(const WindowResizeEvent(24, 80));
      expect(msg, isA<ResizeMsg>());
      final resizeMsg = msg! as ResizeMsg;
      expect(resizeMsg.height, equals(24));
      expect(resizeMsg.width, equals(80));
      expect(resizeMsg.widthPixels, equals(0));
      expect(resizeMsg.heightPixels, equals(0));
    });

    test('converts WindowResizeEvent pixel dimensions through unchanged', () {
      final msg = eventToMsg(const WindowResizeEvent(24, 80, 480, 800));
      expect(msg, isA<ResizeMsg>());
      final resizeMsg = msg! as ResizeMsg;
      expect(resizeMsg.heightPixels, equals(480));
      expect(resizeMsg.widthPixels, equals(800));
    });

    test('QueryWindowResizeEvent (a DECRPM status reply) stays UnknownMsg', () {
      final msg = eventToMsg(QueryWindowResizeEvent(1));
      expect(msg, isA<UnknownMsg>());
    });
  });
}
