import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

import '../../example/theme_viewer.dart' as viewer;

// The theme viewer example, rendered headlessly: it is the canonical example
// for the theming doctrine, so its first frame is where the lift-or-fallback
// rule (a cursor lifting a selected row's fill instead of replacing it)
// shows on a real app screen, not just in a resolver unit test.
void main() {
  test(
    "the gallery list's first row starts selected under the cursor, as the selection fill lifted once",
    () {
      final model = viewer.Model();
      final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 160, height: 50));
      final frame = Frame(buffer.area, buffer, 0);
      viewer.view(model, frame);

      // The list tags its own rect with the model id, so the row's cells
      // come straight from the hit map rather than hard-coded coordinates.
      final rect = frame.hits.rectOf(model.list.id);
      expect(rect, isNotNull, reason: 'the list paints under its own id');
      final cell = buffer[(x: rect!.x, y: rect.y)];

      expect(cell.fg, equals(Theme.dark.selection.on));
      expect(cell.bg, equals(Theme.dark.selection.color!.lighten(Theme.stateLift)));
      // The list starts unfocused — the name field holds focus first — so
      // the cursor paints in the wash class and adds no bold. Bold marks a
      // collection that owns focus.
      expect(cell.modifier.has(Modifier.bold), isFalse);
    },
  );
}
