import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

void main() {
  test('RegionMark (core view) and RegionMarker (table callback) resolve side by side', () {
    const marked = RegionMark(RowRegion(0), Text('x'));
    expect(marked.region, equals(const RowRegion(0)));

    Region? seen;
    RegionMarker marker;
    marker = (region, rect) => seen = region;
    marker(const RowRegion(1), Rect.create(x: 0, y: 0, width: 1, height: 1));
    expect(seen, equals(const RowRegion(1)));
  });
}
