import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

void main() {
  List<ConstraintLength> constraintFromLengths(List<int> values) {
    assert(
      values.every((v) => v > 0),
      'All length elements must be greater than 0',
    );
    return List.generate(
      values.length,
      (i) => ConstraintLength(values[i]),
      growable: false,
    );
  }

  List<ConstraintRatio> constraintFromRatios(List<(int, int)> values) {
    return List.generate(
      values.length,
      (i) => ConstraintRatio(values[i].$1, values[i].$2),
      growable: false,
    );
  }

  List<ConstraintPercentage> constraintFromPercentages(List<int> values) {
    return List.generate(
      values.length,
      (i) => ConstraintPercentage(values[i]),
      growable: false,
    );
  }

  List<ConstraintMax> constraintFromMaxes(List<int> values) {
    return List.generate(
      values.length,
      (i) => ConstraintMax(values[i]),
      growable: false,
    );
  }

  List<ConstraintMin> constraintFromMins(List<int> values) {
    return List.generate(
      values.length,
      (i) => ConstraintMin(values[i]),
      growable: false,
    );
  }

  List<ConstraintFill> constraintFromFills(List<int> values) {
    return List.generate(
      values.length,
      (i) => ConstraintFill(values[i]),
      growable: false,
    );
  }

  group('Constraint >', () {
    test('fromLengths', () {
      expect(constraintFromLengths([1, 2, 3]), [
        const ConstraintLength(1),
        const ConstraintLength(2),
        const ConstraintLength(3),
      ]);
    });
    test('fromRatios', () {
      expect(constraintFromRatios([(1, 4), (1, 2), (1, 4)]), [
        const ConstraintRatio(1, 4),
        const ConstraintRatio(1, 2),
        const ConstraintRatio(1, 4),
      ]);
    });
    test('fromPercentages', () {
      expect(constraintFromPercentages([25, 50, 25]), [
        const ConstraintPercentage(25),
        const ConstraintPercentage(50),
        const ConstraintPercentage(25),
      ]);
    });
    test('fromMaxes', () {
      expect(constraintFromMaxes([1, 2, 3]), [
        const ConstraintMax(1),
        const ConstraintMax(2),
        const ConstraintMax(3),
      ]);
    });
    test('fromMins', () {
      expect(constraintFromMins([1, 2, 3]), [
        const ConstraintMin(1),
        const ConstraintMin(2),
        const ConstraintMin(3),
      ]);
    });
    test('fromFills', () {
      expect(constraintFromFills([1, 2, 3]), [
        const ConstraintFill(1),
        const ConstraintFill(2),
        const ConstraintFill(3),
      ]);
    });
  });
}
