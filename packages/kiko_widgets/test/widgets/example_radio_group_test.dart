import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:test/test.dart';

import '../../example/radio_group.dart' as rg;

// The radio group example, booted through a real application over a
// TestBackend and driven with real key and mouse events.

/// Runs [model] through a real application over [backend], driving it with
/// the steps [FrameScript] builds from the ready frame's hit map.
Future<void> _run(
  rg.AppModel model,
  TestBackend backend,
  List<ScriptStep> Function(HitMap hits) steps, {
  required String readyId,
}) async {
  final script = FrameScript(backend, readyId: readyId, steps: steps);

  await Application(backend: backend, mouseEvents: true, fps: 1000, onFrame: script.onFrame).run<rg.AppModel>(
    init: model,
    update: script.wrap(rg.update),
    view: rg.view,
  );

  expect(script.completed, isTrue, reason: 'every scripted step ran');
}

void main() {
  test('a click on an option label chooses it and the next frame paints the mark', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = rg.AppModel();
    late Rect rect;

    await _run(
      model,
      backend,
      (hits) {
        rect = hits.rectOf('preset-paren')!;
        // The box is "( )" (3 cells) plus a gap; x+6 lands inside "Medium",
        // the second row's label.
        return [(b) => b.emitClick(rect.x + 6, rect.y + 1)];
      },
      readyId: 'preset-paren',
    );

    expect(model.presetParen.value, 'Medium');
    expect(backend.screen[(x: rect.x + 1, y: rect.y + 1)].symbol, '*');
  });

  test('down from the last option wraps to the first and the frame follows', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = rg.AppModel()..presetParen.value = 'Large';
    late Rect rect;

    await _run(
      model,
      backend,
      (hits) {
        rect = hits.rectOf('preset-paren')!;
        return [(b) => b.emitKey('down')];
      },
      readyId: 'preset-paren',
    );

    expect(model.presetParen.value, 'Small');
    expect(backend.screen[(x: rect.x + 1, y: rect.y)].symbol, '*');
  });

  test('tab from the form radio group reaches the button', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = rg.AppModel();
    model.focusGroup.setIndex(model.focusGroup.children.indexWhere((c) => c.id == 'form-delivery'));

    await _run(model, backend, (_) => [(b) => b.emitKey('tab')], readyId: 'form-delivery');

    expect(model.focusGroup.focused.id, 'form-submit');
  });

  test('a click on the disabled option changes nothing', () async {
    final backend = TestBackend(size: const TermSize(160, 45));
    final model = rg.AppModel();

    await _run(
      model,
      backend,
      (hits) {
        final rect = hits.rectOf('skip-group')!;
        // Row 1 is "Express", the middle option, disabled.
        return [(b) => b.emitClick(rect.x + 1, rect.y + 1)];
      },
      readyId: 'skip-group',
    );

    expect(model.skipGroup.value, isNull);
  });
}
