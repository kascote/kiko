import 'dart:io';

import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

import '../../example/layout.dart' as pilot;

/// The pilot screen rendered onto a fixed grid, dumped to plain text — one line
/// per row, empty cells as spaces, trailing blanks trimmed.
String _dump(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      // A wide glyph's trailing cell contributes no character of its own.
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

void main() {
  // The pilot moved from a cassowary layout to a plume tree. This golden was
  // frozen from the original cassowary output; the plume version must reproduce
  // it cell for cell, since the grid is all fixed sizes. Regenerate with
  // `UPDATE_GOLDENS=1 dart test` after an intended layout change.
  test('layout pilot matches the frozen cassowary baseline', () {
    final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: 90, height: 60));
    pilot.draw(Frame(buffer.area, buffer, 0));
    final actual = _dump(buffer);

    final golden = File('test/plume/goldens/layout_pilot.txt');
    if (Platform.environment['UPDATE_GOLDENS'] == '1' || !golden.existsSync()) {
      golden.parent.createSync(recursive: true);
      golden.writeAsStringSync(actual);
    }

    expect(actual, golden.readAsStringSync());
  });
}
