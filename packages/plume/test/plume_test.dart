import 'package:plume/plume.dart';
import 'package:test/test.dart';

void main() {
  test('public geometry types are exported', () {
    expect(Size.zero.w, 0);
    expect(Offset.zero.dy, 0);
    expect(Rect.zero.width, 0);
    expect(const BoxConstraints().hasBoundedWidth, isFalse);
  });
}
