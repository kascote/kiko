import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../../example/checkbox.dart' as cb;

// The checkbox example, booted through a real application over a
// TestBackend and driven with real key and mouse events.

/// Runs [model] through a real application over [backend], driving it with
/// the steps [FrameScript] builds from the ready frame's hit map.
Future<void> _run(
  cb.AppModel model,
  TestBackend backend,
  List<ScriptStep> Function(HitMap hits) steps, {
  required String readyId,
}) async {
  final script = FrameScript(backend, readyId: readyId, steps: steps);

  await Application(backend: backend, mouseEvents: true, fps: 1000, onFrame: script.onFrame).run<cb.AppModel>(
    init: model,
    update: script.wrap(cb.update),
    view: cb.view,
  );

  expect(script.completed, isTrue, reason: 'every scripted step ran');
}

void main() {
  test('a click on the label toggles the checkbox and the next frame paints the mark', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = cb.AppModel();
    late Rect rect;

    await _run(
      model,
      backend,
      (hits) {
        rect = hits.rectOf('preset-ascii')!;
        // The box is "[ ]" (3 cells) plus a gap; x+6 lands on the 'c' of
        // "ascii", well past the box.
        return [(b) => b.emitClick(rect.x + 6, rect.y)];
      },
      readyId: 'preset-ascii',
    );

    expect(model.presets.first.checked, isTrue);
    expect(backend.screen[(x: rect.x + 1, y: rect.y)].symbol, 'x');
  });

  test('space on the focused checkbox toggles it the same way a click does', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = cb.AppModel();

    // preset-ascii is the first focus-group member, so it already holds
    // focus on the first frame.
    await _run(model, backend, (_) => [(b) => b.emitKey('space')], readyId: 'preset-ascii');

    expect(model.presets.first.checked, isTrue);
  });

  test('tab walks focus into the form, and the focused box carries the focus look', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = cb.AppModel();
    late Rect rect;

    await _run(
      model,
      backend,
      (hits) {
        rect = hits.rectOf('form-terms')!;
        // preset-ascii holds focus first; six presets and two colors cases
        // sit ahead of the form in reading order.
        return [for (var i = 0; i < 8; i++) (b) => b.emitKey('tab')];
      },
      readyId: 'form-terms',
    );

    expect(model.focusGroup.focused.id, 'form-terms');
    final bracket = backend.screen[(x: rect.x, y: rect.y)];
    expect(bracket.fg, Theme.dark.focus.color);
    expect(bracket.modifier.has(Modifier.bold), isTrue);
  });

  test('a click on the disable button leaves the target checked and stops it toggling', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = cb.AppModel();
    late Rect disableRect;
    late Rect targetRect;

    await _run(
      model,
      backend,
      (hits) {
        disableRect = hits.rectOf('control-toggle-disable')!;
        targetRect = hits.rectOf('control-target')!;
        return [
          (b) => b.emitClick(disableRect.x + 1, disableRect.y),
          (b) => b.emitClick(targetRect.x + 1, targetRect.y),
        ];
      },
      readyId: 'control-toggle-disable',
    );

    expect(model.controlTarget.disabled, isTrue);
    expect(model.controlTarget.checked, isFalse, reason: 'the click on a disabled box changes nothing');
  });

  test('checking one select-all child puts the parent into mixed', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = cb.AppModel();
    late Rect childRect;

    await _run(
      model,
      backend,
      (hits) {
        childRect = hits.rectOf('select-all-1')!;
        return [(b) => b.emitClick(childRect.x + 1, childRect.y)];
      },
      readyId: 'select-all-1',
    );

    expect(model.selectAllChildren.first.checked, isTrue);
    expect(model.selectAllParent.state, CheckState.mixed);
  });

  test('toggling the parent from mixed checks every child', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = cb.AppModel()
      ..selectAllChildren.first.checked = true
      ..selectAllParent.state = CheckState.mixed;
    late Rect parentRect;

    await _run(
      model,
      backend,
      (hits) {
        parentRect = hits.rectOf('select-all-parent')!;
        return [(b) => b.emitClick(parentRect.x + 1, parentRect.y)];
      },
      readyId: 'select-all-parent',
    );

    expect(model.selectAllParent.state, CheckState.checked);
    expect(model.selectAllChildren.every((c) => c.checked), isTrue);
  });
}
