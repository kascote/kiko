import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

// The combobox driven end to end through a real application: a backend
// delivers mouse events, the runtime routes them by the live hit map, and
// `FocusRouter` wires focus and dispatch the way a real app would. Nothing
// here hand-computes a layout — every coordinate is read back from the
// committed [HitMap].

/// A minimal app around one [ComboboxModel], wired the way a real app would:
/// a single-member [FocusGroup] behind a [FocusRouter], and the widget's own
/// [ComboboxSelectCmd] caught and logged.
class _App {
  _App() {
    focus.setIndex(0);
  }

  final ComboboxModel<String> combo = ComboboxModel<String>(
    id: 'combo',
    fieldId: 'combo-field',
    toggleId: 'combo-toggle',
    label: (s) => s,
    options: const ['Apple', 'Banana', 'Cherry', 'Date'],
    value: 'Apple', // non-empty, so a field click has a character to land on
    // maxVisibleRows defaults to 5 — taller than the 4 options below, so row
    // 4 is a blank popup row past the last match.
  );

  late final FocusGroup<Component> focus = FocusGroup([combo]);

  /// The one routing line a real app writes: pointers by the id the combobox
  /// tags itself with, keys to the focused (only) member, focus to whatever a
  /// press lands on.
  late final FocusRouter router = FocusRouter(focus);

  final List<String> log = [];
}

(_App, Cmd?) _update(_App model, Msg msg, UpdateContext ctx) {
  switch (model.router.route(msg, ctx)) {
    case Handled(cmd: ComboboxSelectCmd(:final id)):
      model.log.add('$id -> ${model.combo.value}');
      return (model, null);
    case Handled(:final cmd):
      return (model, cmd);
    case Declined():
      break; // not interaction traffic the router owns
  }
  return (model, null);
}

const Theme _theme = Theme.dark;

void _view(_App model, Frame frame) {
  final comboView = Combobox(model: model.combo, theme: _theme);
  frame.render(
    Column(
      children: [
        ConstrainedBox(additionalConstraints: const BoxConstraints(minH: 1, maxH: 1), child: comboView),
      ],
    ),
  );
  comboView.renderPopup(frame);
}

/// Runs [model] through a real application over [backend] until [readyId] has
/// painted (its rect, or its live scope, is in the committed hit map), then
/// feeds the events [act] builds from that map, one per frame tick, and lets
/// a couple of idle ticks settle before quitting.
///
/// A message emitted on tick N is only dequeued and applied on a later
/// iteration, so the idle ticks give the last event's effect room to land and
/// paint before `Quit` skips a frame. Returns the last committed [HitMap]; the
/// model is mutated in place so later calls can pick straight up from it.
Future<HitMap> _drive(
  TestBackend backend,
  _App model,
  String readyId,
  List<void Function(TestBackend)> Function(HitMap hits) act,
) async {
  List<void Function(TestBackend)>? queue;
  var i = 0;
  var idleTicks = 0;
  HitMap? lastHits;

  await Application(backend: backend, fps: 120).run<_App>(
    init: model,
    update: (m, msg, ctx) {
      if (msg is FrameTickMsg) {
        if (queue == null) {
          if (ctx.hits.rectOf(readyId) != null || ctx.hits.isLive(readyId)) queue = act(ctx.hits);
          return (m, null);
        }
        if (i < queue!.length) {
          queue![i++](backend);
          return (m, null);
        }
        if (idleTicks < 2) {
          idleTicks++;
          return (m, null);
        }
        return (m, const Quit());
      }
      return _update(m, msg, ctx);
    },
    view: (m, frame) {
      _view(m, frame);
      lastHits = frame.hits;
    },
  );

  return lastHits!;
}

void main() {
  test('field press places the caret, toggle press opens the popup, a row click commits, '
      'and a blank-row press does nothing', () async {
    final model = _App();

    // Phase 1: press the field (places the caret) and the toggle (opens).
    final afterOpen = await _drive(
      TestBackend(size: const TermSize(20, 8)),
      model,
      'combo/combo-field',
      (hits) {
        final field = hits.rectOf('combo/combo-field')!;
        final toggle = hits.rectOf('combo/combo-toggle')!;
        return [
          (b) => b.emitClick(field.x + 2, field.y),
          (b) => b.emitClick(toggle.x, toggle.y),
        ];
      },
    );

    expect(model.combo.field.cursor, equals(2), reason: 'the field press placed the caret');
    expect(model.combo.isOpen, isTrue, reason: 'the toggle press opened the popup');
    final listPath = 'combo/${model.combo.internalList.id}';
    expect(afterOpen.isLive(listPath), isTrue);

    // Phase 2: click the popup's row 1 (Banana) — commits it, exactly like Enter.
    final afterCommit = await _drive(
      TestBackend(size: const TermSize(20, 8)),
      model,
      listPath,
      (hits) {
        final list = hits.rectOf(listPath)!;
        return [(b) => b.emitClick(list.x, list.y + 1)];
      },
    );

    expect(model.combo.value, equals('Banana'));
    expect(model.combo.field.value, equals('Banana'));
    expect(model.combo.isOpen, isFalse, reason: 'a row commit closes the popup');
    expect(
      model.log,
      equals(['combo -> Banana']),
      reason: 'the click emitted the same id-addressed command Enter would',
    );
    expect(afterCommit.isLive(listPath), isFalse, reason: 'the popup is gone once closed');

    // Phase 3: reopen, then press a blank popup row (row 4, past the 4 options
    // in a 5-row popup) — the bare scope path. Nothing changes.
    final afterReopen = await _drive(
      TestBackend(size: const TermSize(20, 8)),
      model,
      'combo/combo-field',
      (hits) => [(b) => b.emitClick(hits.rectOf('combo/combo-toggle')!.x, hits.rectOf('combo/combo-toggle')!.y)],
    );
    expect(model.combo.isOpen, isTrue);

    final blankListRect = afterReopen.rectOf(listPath)!;
    await _drive(
      TestBackend(size: const TermSize(20, 8)),
      model,
      listPath,
      (_) => [(b) => b.emitClick(blankListRect.x, blankListRect.y + 4)],
    );

    expect(model.combo.value, equals('Banana'), reason: 'a blank-row press never commits');
    expect(model.combo.isOpen, isTrue, reason: 'a blank-row press never closes the popup');
    expect(model.log, equals(['combo -> Banana']), reason: 'no second command was emitted');
  });

  test('hover on a popup row rides along with the list, wheel included', () async {
    final model = _App();

    final afterOpen = await _drive(
      TestBackend(size: const TermSize(20, 8)),
      model,
      'combo/combo-field',
      (hits) => [(b) => b.emitClick(hits.rectOf('combo/combo-toggle')!.x, hits.rectOf('combo/combo-toggle')!.y)],
    );
    final listPath = 'combo/${model.combo.internalList.id}';
    final listRect = afterOpen.rectOf(listPath)!;

    await _drive(TestBackend(size: const TermSize(20, 8)), model, listPath, (_) {
      return [(b) => b.emitMove(listRect.x, listRect.y + 2)];
    });

    expect(model.combo.internalList.hoverRow, equals(2), reason: 'a move over a popup row hovers it');
  });
}
