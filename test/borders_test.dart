import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  group('Borders', () {
    test('borders', () {
      const nothing = Borders.none;
      const justTop = Borders.top;
      final topBottom = Borders.top | Borders.bottom;
      final rightOpen = Borders.top | Borders.bottom | Borders.left;

      expect(nothing, Borders.none);
      expect(justTop, Borders.top);
      expect(topBottom, Borders.top | Borders.bottom);
      expect(rightOpen, Borders.top | Borders.bottom | Borders.left);
      expect(Borders.all, Borders.top | Borders.bottom | Borders.left | Borders.right);
      expect(Borders.top.hashCode, Borders.top.hashCode);
    });
  });
}
