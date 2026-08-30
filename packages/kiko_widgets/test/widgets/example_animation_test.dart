import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../../example/animation.dart' as anim;

// The animation example, booted through a real application over a
// TestBackend and driven with real key/mouse events. Every id-addressing
// case the example table lists gets one test here; a couple of cases that
// touch no panel are pinned directly on the models instead.

/// The step every case's own interval derives from, and the load delay the
/// loader case waits out — both short, so the whole suite runs in
/// milliseconds, but with enough separation between chains (1x, 2x, 3x, 6x,
/// 10x this step) that a wait long enough for the slow one is never mistaken
/// for a tick from the fast one.
const _step = Duration(milliseconds: 5);
const _loadDelay = Duration(milliseconds: 30);

/// Everything the recording wrapper captured from one scripted run.
///
/// Every list is in arrival order. [ticks] and [armed] carry a `landing`
/// index into the message that produced them, so a test can ask "what
/// happened before/after this keystroke landed" without guessing at timing.
class _Record {
  /// Every message that reached `update`, paired with the backend's draw
  /// count at that moment — before the frame this message itself causes.
  final List<(Msg, int)> landings = [];

  /// Every `TickMsg`'s id and key, in arrival order.
  final List<({String id, Object? key, int landing})> ticks = [];

  /// Every `Tick` a returned command armed, walking into a `Batch`, paired
  /// with the index into [landings] of the message that returned it.
  final List<({String id, Object? key, int landing})> armed = [];

  /// Every `WidgetEvent.id` the app's own event log gained, in order.
  final List<String> events = [];
}

/// Walks [cmd] into every `Tick` it carries, recursing into a `Batch` in
/// order. Every other command contributes nothing.
void _visitTicks(Cmd? cmd, void Function(String id, Object? key) visit) {
  switch (cmd) {
    case null:
      break;
    case Tick(:final id, :final key):
      visit(id, key);
    case Batch(:final cmds):
      for (final c in cmds) {
        _visitTicks(c, visit);
      }
    case Quit():
    case Emit():
    case Task<Object?>():
      break;
  }
}

/// Wraps [inner] to fill [record] with every fact the pins below read: see
/// [_Record].
Update<anim.AppModel> _recording(Update<anim.AppModel> inner, _Record record, TestBackend backend) =>
    (model, msg, ctx) {
      final landing = record.landings.length;
      record.landings.add((msg, backend.drawCount));
      if (msg case TickMsg(:final id, :final key)) record.ticks.add((id: id, key: key, landing: landing));

      final eventsBefore = model.events.length;
      final result = inner(model, msg, ctx);
      for (final event in model.events.skip(eventsBefore)) {
        record.events.add(event.id);
      }
      _visitTicks(result.$2, (id, key) => record.armed.add((id: id, key: key, landing: landing)));
      return result;
    };

/// A script step that waits [duration], then emits a harmless focus probe.
///
/// Every model in the example declines a `FocusMsg`, so nothing reacts to
/// it; landing is exactly what releases the next scripted step, and — since
/// it is a terminal-made message like any other — it also draws a frame,
/// which the drawCount pin below reads.
ScriptStep _wait(Duration duration) =>
    (b) => Future<void>.delayed(duration, () => b.emitFocus(hasFocus: true));

/// Drives [model] through a real application, recording everything the pins
/// below need. [readyId] is a hit path already live on the first frame,
/// since the whole grid paints before anything is started.
Future<_Record> _run({
  required TestBackend backend,
  required anim.AppModel model,
  required List<ScriptStep> Function(HitMap hits) steps,
  String readyId = 'panel/spinner',
}) async {
  final record = _Record();
  final script = FrameScript(backend, readyId: readyId, steps: steps);

  await Application(backend: backend, mouseEvents: true, fps: 1000, onFrame: script.onFrame).run<anim.AppModel>(
    init: model,
    update: script.wrap(_recording(anim.update, record, backend)),
    view: anim.view,
  );

  expect(script.completed, isTrue, reason: 'every scripted step ran');
  return record;
}

/// Starts the clock and every case at once, lets everything tick, stops
/// everything, and drains the pending ticks before the run ends — the shape
/// every invariant test in this file reads.
Future<(anim.AppModel, _Record)> _startAllRun() async {
  final backend = TestBackend(size: const TermSize(160, 40));
  final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

  final record = await _run(
    backend: backend,
    model: model,
    steps: (_) => [
      (b) => b.emitKey('c'),
      (b) => b.emitKey('a'),
      _wait(_loadDelay * 3),
      (b) => b.emitKey('c'),
      (b) => b.emitKey('s'),
      _wait(const Duration(milliseconds: 10) + _step * 12),
    ],
  );
  return (model, record);
}

/// A pointer press at the origin, addressed to [targetId] — enough to drive
/// [anim.PanelModel.update] directly, with no application underneath it.
PointerMsg _pressAt(String targetId) =>
    PointerMsg(global: Position.origin, action: PointerAction.down, local: Position.origin, targetId: targetId);

void main() {
  group('rows', () {
    test('clock: the app\'s own fall-through re-arms it, addressed "clock"', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [(b) => b.emitKey('c'), _wait(_step * 20)],
      );

      expect(model.clockTicks, greaterThan(0));
      expect(model.dropped, 0);
      expect(record.ticks.map((t) => t.id), contains('clock'));
      expect(record.armed.map((a) => a.id), everyElement('clock'));
    });

    test('member and extra: the frame index advances after a wait, ids stay bare', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [(b) => b.emitKey('m'), (b) => b.emitKey('x'), _wait(_step * 6)],
      );

      expect(model.member.frameIndex, greaterThan(0));
      expect(model.extra.frameIndex, greaterThan(0));
      expect(record.ticks.map((t) => t.id).toSet(), {'member', 'extra'});
    });

    test('panel: every recorded id for the embedded spinner is exactly panel/spinner', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);
      late Rect spinnerRect;

      final record = await _run(
        backend: backend,
        model: model,
        steps: (hits) {
          spinnerRect = hits.rectOf('panel/spinner')!;
          return [(b) => b.emitKey('p'), _wait(_step * 6)];
        },
      );

      expect(record.ticks, isNotEmpty);
      expect(record.ticks.map((t) => t.id).toSet(), {'panel/spinner'});
      expect(record.armed.map((a) => a.id).toSet(), {'panel/spinner'});
      final cell = backend.screen[(x: spinnerRect.x, y: spinnerRect.y)];
      expect(cell.symbol, isNot('·'), reason: 'a running spinner paints a moving glyph, not the idle dot');
    });

    test('nested: outer/inner/marquee advances the marquee, outer/inner blinks the panel', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        // Long enough for the 10x blink to land at least once.
        steps: (_) => [(b) => b.emitKey('n'), _wait(_step * 14)],
      );

      expect(record.ticks.map((t) => t.id).toSet(), {'outer/inner', 'outer/inner/marquee'});
      final inner = model.outer.parts.single as anim.PanelModel;
      expect((inner.parts.single as anim.MarqueeModel).frameIndex, greaterThan(0));
      expect(inner.ownTicks, greaterThan(0), reason: "the blink is the inner panel's own tick");
      expect(model.outer.ownTicks, 0, reason: 'the outer panel forwards every tick under it');
    });

    test('twins: a/bars outpaces b/bars, and stopping a leaves b running', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      // Tab three times to reach twinA (member, panel, outer, a, ...), then
      // Enter to stop it.
      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [
          (b) => b.emitKey('t'),
          _wait(_step * 8),
          (b) => b.emitKey('tab'),
          (b) => b.emitKey('tab'),
          (b) => b.emitKey('tab'),
          (b) => b.emitKey('enter'),
          _wait(_step * 8),
        ],
      );

      final stopAt = record.landings.indexWhere(
        (l) => switch (l.$1) {
          KeyMsg(key: 'enter') => true,
          _ => false,
        },
      );
      expect(stopAt, greaterThanOrEqualTo(0));

      final aBefore = record.ticks.where((t) => t.id == 'a/bars' && t.landing < stopAt).length;
      final bBefore = record.ticks.where((t) => t.id == 'b/bars' && t.landing < stopAt).length;
      expect(aBefore, greaterThan(bBefore), reason: 'a runs at 1x, b at 2x, so a ticks more before either stops');

      final aAfter = record.ticks.where((t) => t.id == 'a/bars' && t.landing > stopAt).length;
      final bAfter = record.ticks.where((t) => t.id == 'b/bars' && t.landing > stopAt).length;
      expect(aAfter, lessThanOrEqualTo(1), reason: 'at most one tick already in flight when Enter landed');
      expect(bAfter, greaterThan(0), reason: 'b keeps running after a alone is stopped');
    });

    test("echo: echo/echo advances the part, and the panel's own tick counter stays 0", () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [(b) => b.emitKey('e'), _wait(_step * 6)],
      );

      expect(record.ticks.map((t) => t.id).toSet(), {'echo/echo'});
      expect(model.echo.ownTicks, 0, reason: 'the panel forwards to its same-named part before its own guard');
    });

    test('duo: one key arms both duo/left and duo/right in one batch', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [(b) => b.emitKey('d'), _wait(_step * 8)],
      );

      expect(model.lastStarted, 'duo', reason: 'the non-tick command in the batch arrives at the app unrewritten');
      expect(record.ticks.map((t) => t.id).toSet(), {'duo/left', 'duo/right'});

      final startedAt = record.landings.indexWhere(
        (l) => switch (l.$1) {
          KeyMsg(key: 'd') => true,
          _ => false,
        },
      );
      final armedByD = record.armed.where((a) => a.landing == startedAt).map((a) => a.id).toSet();
      expect(armedByD, {'duo/left', 'duo/right'}, reason: 'both parts are armed by the single key that started them');
    });

    test('restart: at most one old-key tick lands after, every later tick carries the new key', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);
      const wait = 6;

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [
          (b) => b.emitKey('p'),
          _wait(_step * wait),
          (b) => b.emitKey('r'),
          _wait(_step * wait),
        ],
      );

      final restartAt = record.landings.indexWhere(
        (l) => switch (l.$1) {
          KeyMsg(key: 'r') => true,
          _ => false,
        },
      );
      expect(restartAt, greaterThanOrEqualTo(0));

      final before = record.ticks.where((t) => t.landing < restartAt).toList();
      final after = record.ticks.where((t) => t.landing > restartAt).toList();
      expect(before, isNotEmpty);
      expect(after, isNotEmpty);

      final oldKey = before.last.key;
      final newKey = record.armed.singleWhere((a) => a.landing == restartAt && a.id == 'panel/spinner').key;
      expect(newKey, isNot(oldKey));

      final firstFresh = after.indexWhere((t) => t.key == newKey);
      expect(firstFresh, greaterThanOrEqualTo(0));
      expect(firstFresh, lessThanOrEqualTo(1), reason: 'at most one old-key tick arrives after the restart');
      expect(after.take(firstFresh).every((t) => t.key == oldKey), isTrue);
      expect(after.skip(firstFresh).every((t) => t.key == newKey), isTrue);
      // One chain's rate, not two: a loose upper bound catches a double-arm
      // without being tripped by ordinary timer jitter.
      expect(after.where((t) => t.key == newKey).length, lessThanOrEqualTo(wait + 2));
    });

    test('loader: the bar fills in flight, the result arrives addressed loader, then it stops', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [(b) => b.emitKey('l'), _wait(_loadDelay * 2)],
      );

      final loadResultAt = record.landings.indexWhere(
        (l) => switch (l.$1) {
          LoadResult<Object?>(id: 'loader') => true,
          _ => false,
        },
      );
      expect(loadResultAt, greaterThanOrEqualTo(0), reason: 'the LoadResult must land, addressed to the panel');

      final barTicks = record.ticks.where((t) => t.id == 'loader/progress').toList();
      expect(barTicks, isNotEmpty);
      expect(barTicks.any((t) => t.landing < loadResultAt), isTrue, reason: 'ticked while the load was in flight');

      expect(model.loader.loading, isFalse);
      expect(model.loader.running, isFalse, reason: 'the bar stops once the result lands');
    });

    test('events: a click and Enter on an embedded spinner reach the app as PanelToggleEvent', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);
      late Rect spinnerRect;

      await _run(
        backend: backend,
        model: model,
        // Neither assertion below depends on real elapsed time, so the click
        // and the key can simply follow one another with no wait between —
        // the toggle only cares about current state, not the clock.
        steps: (hits) {
          spinnerRect = hits.rectOf('panel/spinner')!;
          return [(b) => b.emitClick(spinnerRect.x, spinnerRect.y), (b) => b.emitKey('enter')];
        },
      );

      expect(
        model.events.whereType<anim.SpinnerToggleEvent>(),
        isEmpty,
        reason: "a part's own toggle never reaches the app unwrapped",
      );
      final panelEvents = model.events.whereType<anim.PanelToggleEvent>().toList();
      expect(panelEvents, hasLength(2), reason: 'one for the click, one for Enter');
      expect(panelEvents.every((e) => e.id == 'panel' && e.part == 'spinner'), isTrue);
    });

    test('start all / stop all: after stop and a drain wait, a further wait draws nothing extra', () async {
      final backend = TestBackend(size: const TermSize(160, 40));
      final model = anim.AppModel(step: _step, loadDelay: _loadDelay);

      final record = await _run(
        backend: backend,
        model: model,
        steps: (_) => [
          (b) => b.emitKey('a'),
          _wait(_loadDelay * 3), // long enough for the load to resolve too
          (b) => b.emitKey('s'),
          _wait(const Duration(milliseconds: 10) + _step * 12), // drains every in-flight tick, blink included
          _wait(const Duration(milliseconds: 20)), // probe A
          _wait(const Duration(milliseconds: 20)), // probe B
        ],
      );

      final focusLandings = record.landings.where((l) => l.$1 is FocusMsg).toList();
      expect(focusLandings.length, greaterThanOrEqualTo(2));
      final drawAtA = focusLandings[focusLandings.length - 2].$2;
      final drawAtB = focusLandings.last.$2;
      expect(drawAtB, drawAtA + 1, reason: "only probe A's own frame drew between the two probes");
    });
  });

  group('direct', () {
    test("a stray tick under the panel's own id, naming no part, is declined", () {
      final panel = anim.PanelModel(
        id: 'panel',
        parts: [anim.SpinnerModel(id: 'spinner')],
      );

      final result = panel.update(const TickMsg('panel/ghost', elapsed: Duration(milliseconds: 1)));

      expect(result, isA<Declined>());
    });

    test('a tick at the bare part id, with no panel prefix, is declined', () {
      final panel = anim.PanelModel(
        id: 'panel',
        parts: [anim.SpinnerModel(id: 'spinner')],
      );

      final result = panel.update(const TickMsg('spinner', elapsed: Duration(milliseconds: 1)));

      expect(result, isA<Declined>());
    });

    test('a stale-key tick at panel/spinner is handled with no cmd', () {
      final panel = anim.PanelModel(
        id: 'panel',
        parts: [anim.SpinnerModel(id: 'spinner')],
      )..startAll();

      final result = panel.update(const TickMsg('panel/spinner', elapsed: Duration(milliseconds: 1), key: 999));

      expect(result, isA<Handled>().having((h) => h.cmd, 'cmd', isNull));
    });

    test('a panel inside a panel forwards start() and its tick through both hops', () {
      final spinner = anim.SpinnerModel(id: 'spinner');
      final inner = anim.PanelModel(id: 'a', parts: [spinner]);
      final outer = anim.PanelModel(id: 'a', parts: [inner]);

      final started = outer.startAll();
      final armed = <({String id, Object? key})>[];
      _visitTicks((started as Handled).cmd, (id, key) => armed.add((id: id, key: key)));
      expect(armed, hasLength(1));
      expect(armed.single.id, 'a/a/spinner');

      final result = outer.update(
        TickMsg('a/a/spinner', elapsed: const Duration(milliseconds: 1), key: armed.single.key),
      );

      expect(result, isA<Handled>());
      expect(spinner.frameIndex, 1);
    });

    test('a pointer path naming neither the panel nor a part is declined', () {
      final panel = anim.PanelModel(
        id: 'panel',
        parts: [anim.SpinnerModel(id: 'spinner')],
      );

      expect(panel.update(_pressAt('panel/ghost')), isA<Declined>());
    });

    test('a pointer at the bare part id, with no panel prefix, is declined', () {
      final panel = anim.PanelModel(
        id: 'panel',
        parts: [anim.SpinnerModel(id: 'spinner')],
      );

      expect(panel.update(_pressAt('spinner')), isA<Declined>());
    });
  });

  group('invariants', () {
    test("every case's tick id lands exactly as the table names it", () async {
      final (_, record) = await _startAllRun();

      expect(record.ticks.map((t) => t.id).toSet(), {
        'clock',
        'member',
        'extra',
        'panel/spinner',
        'outer/inner',
        'outer/inner/marquee',
        'a/bars',
        'b/bars',
        'echo/echo',
        'duo/left',
        'duo/right',
        'loader/progress',
      });
    });

    test('every tick the app arms is later delivered, and nothing drops', () async {
      final (model, record) = await _startAllRun();

      final armedIds = record.armed.map((a) => a.id).toSet();
      final tickIds = record.ticks.map((t) => t.id).toSet();
      expect(armedIds.difference(tickIds), isEmpty, reason: 'nothing armed goes undelivered');
      expect(model.dropped, 0);
    });

    test('every widget event the app reads names a registered id', () async {
      final (model, record) = await _startAllRun();

      final registered = {...model.focusGroup.children.map((c) => c.id), model.extra.id};
      expect(record.events, isNotEmpty, reason: 'the loader asks for its load through an event');
      expect(record.events.every(registered.contains), isTrue);
    });
  });
}
