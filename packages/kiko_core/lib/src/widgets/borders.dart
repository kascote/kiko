import 'package:meta/meta.dart';

const _none = 0;
const _top = 1;
const _right = 2;
const _bottom = 4;
const _left = 8;
const int _all = _top | _right | _bottom | _left;

/// Defines the type of borders for the Block.
@immutable
class Borders {
  final int _value;

  const Borders._(int value) : _value = value;

  /// Defines all borders.
  static const all = Borders._(_all);

  /// Defines no borders.
  static const none = Borders._(_none);

  /// Defines the top border.
  static const top = Borders._(_top);

  /// Defines the right border.
  static const right = Borders._(_right);

  /// Defines the bottom border.
  static const bottom = Borders._(_bottom);

  /// Defines the left border.
  static const left = Borders._(_left);

  @pragma('vm:prefer-inline')
  /// Returns true if the border is present.
  bool has(Borders border) => _value & border._value == border._value;

  @pragma('vm:prefer-inline')
  /// Add a border to the current one.
  Borders operator |(Borders other) => Borders._(_value | other._value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Borders && other._value == _value;
  }

  @override
  int get hashCode => Object.hash(Borders, _value);
}
