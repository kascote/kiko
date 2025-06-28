import 'package:meta/meta.dart';

import 'colors.dart';

const _empty = 0; // 0b0000_0000_0000
const _bold = 1; // 0b0000_0000_0001
const _dim = 2; // 0b0000_0000_0010
const _italic = 4; // 0b0000_0000_0100,
const _underlined = 8; // 0b0000_0000_1000,
const _slowBlink = 16; // 0b0000_0001_0000,
const _rapidBlink = 32; // 0b0000_0010_0000,
const _reversed = 64; // 0b0000_0100_0000,
const _hidden = 128; // 0b0000_1000_0000,
const _crossedOut = 256; // 0b0001_0000_0000,
const _all = 0x1ff; // 0b0001_1111_1111

const _listModifiers = {
  'empty': Modifier.empty,
  'bold': Modifier.bold,
  'dim': Modifier.dim,
  'italic': Modifier.italic,
  'underlined': Modifier.underlined,
  'slowBlink': Modifier.slowBlink,
  'rapidBlink': Modifier.rapidBlink,
  'reversed': Modifier.reversed,
  'hidden': Modifier.hidden,
  'crossedOut': Modifier.crossedOut,
};

/// Modifier changes the way a piece of text is display
@immutable
class Modifier {
  /// The value of the modifier.
  final int value;
  const Modifier._(this.value);

  /// Bold modifier
  static const Modifier bold = Modifier._(_bold);

  /// Dim modifier
  static const Modifier dim = Modifier._(_dim);

  /// Italic modifier
  static const Modifier italic = Modifier._(_italic);

  /// Underlined modifier
  static const Modifier underlined = Modifier._(_underlined);

  /// Slow blink modifier
  static const Modifier slowBlink = Modifier._(_slowBlink);

  /// Rapid blink modifier
  static const Modifier rapidBlink = Modifier._(_rapidBlink);

  /// Reversed modifier
  static const Modifier reversed = Modifier._(_reversed);

  /// Hidden modifier
  static const Modifier hidden = Modifier._(_hidden);

  /// Crossed out modifier
  static const Modifier crossedOut = Modifier._(_crossedOut);

  /// Creates a [Modifier] with no effect.
  static const Modifier empty = Modifier._(_empty);

  /// Creates a [Modifier] with all effects enabled.
  static const Modifier all = Modifier._(_all);

  /// Returns a list of all the modifiers
  static const Map<String, Modifier> list = _listModifiers;

  /// Checks if the given modifier is included in this modifier.
  @pragma('vm:prefer-inline')
  bool has(Modifier mod) => (value & mod.value) == mod.value;

  /// Concatenate two modifiers
  @pragma('vm:prefer-inline')
  Modifier operator |(Modifier other) => Modifier._(value | other.value);

  /// Removes the given modifier from this modifier.
  @pragma('vm:prefer-inline')
  Modifier operator &(Modifier other) => Modifier._(value & other.value);

  /// Removes the given modifier from this modifier.
  @pragma('vm:prefer-inline')
  Modifier operator -(Modifier other) => Modifier._(value & ~other.value);

  @override
  String toString() {
    final sb = StringBuffer()..write('Modifier(');
    if (value == 0) {
      sb.write('NONE');
    } else if (value == 0x1ff) {
      sb.write('ALL');
    } else {
      final sb2 = StringBuffer();
      if (has(Modifier.bold)) sb2.write('bold ');
      if (has(Modifier.dim)) sb2.write('dim ');
      if (has(Modifier.italic)) sb2.write('italic ');
      if (has(Modifier.underlined)) sb2.write('underline ');
      if (has(Modifier.slowBlink)) sb2.write('slowBlink ');
      if (has(Modifier.rapidBlink)) sb2.write('rapidBlink ');
      if (has(Modifier.reversed)) sb2.write('reversed ');
      if (has(Modifier.hidden)) sb2.write('hidden ');
      if (has(Modifier.crossedOut)) sb2.write('crossedOut ');
      sb.write(sb2.toString().trim());
    }
    sb.write(')');
    return sb.toString();
  }

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Modifier && other.value == value;
  }

  @override
  int get hashCode => Object.hash(Modifier, value);
  // coverage:ignore-end
}

/// [Style] contains the primitives used to control how your user interface
/// will look.
@immutable
class Style {
  /// The foreground color.
  final Color? fg;

  /// The background color.
  final Color? bg;

  /// The underline color.
  final Color? underline;
  final Modifier _addModifier;
  final Modifier _subModifier;

  /// Creates a new [Style] object.
  const Style({
    this.fg,
    this.bg,
    this.underline,
    Modifier addModifier = Modifier.empty,
    Modifier subModifier = Modifier.empty,
  })  : _addModifier = addModifier,
        _subModifier = subModifier;

  /// Creates a new [Style] with the colors set to Reset
  const Style.reset()
      : fg = Color.reset,
        bg = Color.reset,
        underline = Color.reset,
        _addModifier = Modifier.empty,
        _subModifier = Modifier.all;

  static const Object _useNull = Object();

  /// Returns the modifiers to be applied when applied
  Modifier get addModifier => _addModifier;

  /// Returns the modifiers to be removed when applied
  Modifier get subModifier => _subModifier;

  /// Returns a new [Style] object with the given [Modifier] set.
  Style incModifier(Modifier modifier) {
    return copyWith(
      addModifier: _addModifier | modifier,
      subModifier: _subModifier - modifier,
    );
  }

  /// Returns a new [Style] object with the given [Modifier] removed.
  Style removeModifier(Modifier modifier) {
    return copyWith(
      addModifier: _addModifier - modifier,
      subModifier: _subModifier | modifier,
    );
  }

  /// Returns a new [Style] object with the given [Style] patched.
  Style patch(Style other) {
    return copyWith(
      fg: other.fg ?? fg,
      bg: other.bg ?? bg,
      underline: other.underline ?? underline,
      addModifier: (_addModifier - other._subModifier) | other._addModifier,
      subModifier: (_subModifier - other._addModifier) | other._subModifier,
    );
  }

  /// Returns a new [Style] object with the given fields updated.
  Style copyWith({
    Object? fg = _useNull,
    Object? bg = _useNull,
    Object? underline = _useNull,
    Object? addModifier = _useNull,
    Object? subModifier = _useNull,
  }) {
    return Style(
      fg: _getValueOrNull<Color>(fg, 'fg', this.fg),
      bg: _getValueOrNull<Color>(bg, 'bg', this.bg),
      underline: _getValueOrNull<Color>(underline, 'underline', this.underline),
      addModifier: _getValue<Modifier>(addModifier, 'addModifier', _addModifier),
      subModifier: _getValue<Modifier>(subModifier, 'subModifier', _subModifier),
    );
  }

  /// Helper method to get the value or null for nullable fields.
  T? _getValueOrNull<T>(Object? value, String fieldName, T? current) {
    if (value == _useNull) return current;
    if (value == null) return null;
    if (value is T) return value as T;
    throw ArgumentError('Invalid value for $fieldName. Expected $T, got ${value.runtimeType}');
  }

  /// Helper method to get the value for non-nullable fields.
  T _getValue<T>(Object? value, String fieldName, T current) {
    if (value == _useNull) return current;
    if (value is T) return value;
    throw ArgumentError('Invalid value for $fieldName. Expected $T, got ${value.runtimeType}');
  }

  @override
  String toString() {
    return 'Style(fg: $fg, bg: $bg, underline: $underline, addModifier: $_addModifier, subModifier: $_subModifier)';
  }

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Style &&
        other.fg == fg &&
        other.bg == bg &&
        other.underline == underline &&
        other._addModifier == _addModifier &&
        other._subModifier == _subModifier;
  }

  @override
  int get hashCode {
    return Object.hash(Style, fg, bg, underline, _addModifier, _subModifier);
  }
  // coverage:ignore-end
}
