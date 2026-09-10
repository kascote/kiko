import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:test/test.dart';

import '../../example/theme_viewer/main.dart' as viewer;

// The theme viewer driven through a real application: a press whose effect
// removes the widget under the cursor, then a release at the same cell one
// frame later. The widget that the release lands on must not react to a
// gesture it never started.

/// Runs the theme viewer over a [TestBackend], one scripted step per
/// committed frame, and records every routed pointer message the app's
/// `update` sees.
///
/// [steps] receives the script, so a step can read the hit map of the frame
/// it goes out on through `script.lastFrame`.
Future<(viewer.Model, List<Msg>)> _drive(
  List<ScriptStep> Function(FrameScript script, viewer.Model model) steps,
) async {
  final backend = TestBackend(size: const TermSize(160, 50));
  final model = viewer.Model();
  late final FrameScript script;
  script = FrameScript(backend, readyId: model.combo.togglePath, steps: (_) => steps(script, model));
  final seen = <Msg>[];

  await Application(backend: backend, fps: 120, onFrame: script.onFrame, mouseEvents: true).run<viewer.Model>(
    init: model,
    update: script.wrap((m, msg, ctx) {
      if (msg is Routed) seen.add(msg);
      return viewer.update(m, msg, ctx);
    }),
    view: viewer.view,
  );
  expect(script.completed, isTrue, reason: 'every step went out');
  return (model, seen);
}

void main() {
  test(
    'a popup row pressed over a button selects the row and leaves the button alone',
    () async {
      late Rect dialogButton;
      late Position pressAt;
      final (model, seen) = await _drive(
        (script, model) => [
          // Open the popup with a click on the toggle.
          (b) {
            final hits = script.lastFrame!.hits;
            dialogButton = hits.rectOf(model.dialogButton.id)!;
            final toggle = hits.rectOf(model.combo.togglePath)!;
            b.emitClick(toggle.x, toggle.y);
          },
          // Press the first popup row where it covers the Dialog… button. The
          // combobox commits and closes the popup on this press.
          (b) {
            final hits = script.lastFrame!.hits;
            final listPath = HitTag.join(model.combo.id, model.combo.internalList.id);
            final list = hits.rectOf(listPath)!;
            pressAt = Position(dialogButton.right - 1, list.y);
            expect(hits.hitId(pressAt.x, pressAt.y), listPath, reason: 'the press lands on the popup list');
            expect(dialogButton.contains(pressAt), isTrue, reason: 'the row covers the button');
            b.emitPress(pressAt.x, pressAt.y);
          },
          // Release at the same cell, one frame later: the popup is gone and
          // the button is under the cursor.
          (b) => b.emitRelease(pressAt.x, pressAt.y),
        ],
      );

      expect(model.combo.value, 'Admin', reason: 'the press selected the first row');
      expect(model.status, 'Combobox: Admin');
      expect(model.modal, isNull, reason: 'the release belongs to the popup gesture, not to the button behind it');
      expect(
        seen.whereType<PointerMsg>().where((p) => p.isUp && p.targetId == model.dialogButton.id),
        isEmpty,
        reason: 'no release reaches the button',
      );
    },
    skip: 'pending: the router re-targets the release of a cancelled gesture at the widget now under the cursor',
  );

  test(
    'a press outside the dialog dismisses it and leaves the button behind the backdrop alone',
    () async {
      late Position pressAt;
      final (model, seen) = await _drive(
        (script, model) => [
          // Open the dialog with a click on the Dialog… button.
          (b) {
            final r = script.lastFrame!.hits.rectOf(model.dialogButton.id)!;
            b.emitClick(r.x, r.y);
          },
          // Press outside the dialog, over the OK button in the base tree. The
          // app dismisses the dialog on this press.
          (b) {
            final hits = script.lastFrame!.hits;
            expect(hits.isLive(model.modal!.id), isTrue, reason: 'the dialog is open');
            final ok = hits.rectOf(model.okButton.id)!;
            pressAt = Position(ok.x, ok.y);
            b.emitPress(pressAt.x, pressAt.y);
          },
          (b) => b.emitRelease(pressAt.x, pressAt.y),
        ],
      );

      expect(model.modal, isNull, reason: 'the press dismissed the dialog');
      expect(model.status, 'Dialog: cancelled', reason: 'the OK button never fired');
      // The app's update does see the press, addressed to the button, and
      // dismisses the dialog instead of routing it. The release is what must
      // not fire the button.
      expect(seen.whereType<PointerMsg>().where((p) => p.isDown && p.targetId == model.okButton.id), hasLength(1));
    },
    skip: 'pending: a button fires on a release without having seen its own press',
  );
}
