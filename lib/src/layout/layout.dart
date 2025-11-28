import 'dart:math' as math;

import 'package:cassowary/cassowary.dart' as cos;
import 'package:meta/meta.dart';

import '../extensions/integer.dart';
import '../extensions/iterator.dart';
import '../shared/lru_cache.dart';
import 'constraint.dart';
import 'flex.dart';
import 'margin.dart';
import 'rect.dart';
import 'spacing.dart';

const _floatPrecisionMultiplier = 100.0;

/// Represents the direction the layout is going.
enum Direction {
  /// The layout is horizontal.
  horizontal,

  /// The layout is vertical.
  vertical,
}

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// cassowary definitions
// https://github.com/dylanede/cassowary-rs/blob/master/src/lib.rs#L352-L355
const _required = 1001001000.0; // this value is different from google library
const _strong = 1000000.0;
const _medium = 1000.0;
const _weak = 1.0;

/// The strengths to apply to constraints.
enum Strengths {
  /// The strength to apply to Required constraints.
  required(_required),

  /// The strength to apply to Spacers to ensure that their sizes are equal.
  ///
  /// ┌     ┐┌───┐┌     ┐┌───┐┌     ┐
  ///   ==x  │   │  ==x  │   │  ==x
  /// └     ┘└───┘└     ┘└───┘└     ┘
  spacerSizeEq(_required / 10.0),

  /// The strength to apply to Min inequality constraints.
  ///
  /// ┌────────┐
  /// │Min(>=x)│
  /// └────────┘
  minSizeGe(_strong * 100.0),

  /// The strength to apply to Max inequality constraints.
  ///
  /// ┌────────┐
  /// │Max(<=x)│
  /// └────────┘
  maxSizeLe(_strong * 100.0),

  /// The strength to apply to Length constraints.
  ///
  /// ┌───────────┐
  /// │Length(==x)│
  /// └───────────┘
  lengthSizeEq(_strong * 10.0),

  /// The strength to apply to Percentage constraints.
  ///
  /// ┌───────────────┐
  /// │Percentage(==x)│
  /// └───────────────┘
  percentageSizeEq(_strong),

  /// The strength to apply to Ratio constraints.
  ///
  /// ┌────────────┐
  /// │Ratio(==x,y)│
  /// └────────────┘
  ratioSizeEq(_strong / 10.0),

  /// The strength to apply to Min equality constraints.
  ///
  /// ┌────────┐
  /// │Min(==x)│
  /// └────────┘
  minSizeEq(_medium * 10.0),

  /// The strength to apply to Max equality constraints.
  ///
  /// ┌────────┐
  /// │Max(==x)│
  /// └────────┘
  maxSizeEq(_medium * 10.0),

  /// The strength to apply to Fill growing constraints.
  ///
  /// ┌─────────────────────┐
  /// │<=     Fill(x)     =>│
  /// └─────────────────────┘
  fillGrow(_medium),

  /// The strength to apply to growing constraints.
  ///
  /// ┌────────────┐
  /// │<= Min(x) =>│
  /// └────────────┘
  grow(_medium / 10.0),

  /// The strength to apply to Spacer growing constraints.
  ///
  /// ┌       ┐
  ///  <= x =>
  /// └       ┘
  spaceGrow(_weak * 10.0),

  /// The strength to apply to growing the size of all segments equally.
  ///
  /// ┌───────┐
  /// │<= x =>│
  /// └───────┘
  allSegmentGrow(_weak);

  /// The value of the strength.
  final double value;

  /// Creates a new Strengths.
  const Strengths(this.value);
}

/// This is a somewhat arbitrary size for the layout cache based on adding the
/// columns and rows on my laptop's terminal (171+51 = 222) and doubling it for
/// good measure and then adding a bit more to make it a round number. This
/// gives enough entries to store a layout for every row and every column,
/// twice over, which should be enough for most apps.
const _defaultCacheSize = 500;
var _layoutCache = LruCache<String, (Segments, Spacers)>(_defaultCacheSize);

/// Returns the Layout's cache stats.
// coverage:ignore-start
CacheStats layoutCacheStats() => _layoutCache.stats;
// coverage:ignore-end

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
/// Type returned by [Layout] that contains the segments and spacers.
typedef Rects = List<Rect>;

/// Type that represent the segments of the layout.
typedef Segments = Rects;

/// Type that represent the spacers of the layout.
typedef Spacers = Rects;

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
/// Element is helper class to create constraints and feed them to the solver.
@immutable
class Element {
  /// The start parameter of the constraint.
  final cos.Param start;

  /// The end parameter of the constraint.
  final cos.Param end;

  /// Creates a new Element.
  const Element(this.start, this.end);

  /// Returns the size of the element.
  @pragma('vm:prefer-inline')
  cos.Expression get size => end - start;

  /// Creates a constraint that check if the size is less than or equal to the
  /// given [maxSize], assigning the given [strength] to the constraint.
  cos.Constraint hasMaxSize(int maxSize, double strength) {
    return (size <= cos.cm(maxSize * _floatPrecisionMultiplier))..priority = strength;
  }

  /// Creates a constraint that check if the size is greater than or equal to
  /// the given [minSize], assigning the given [strength] to the constraint.
  cos.Constraint hasMinSize(int minSize, double strength) {
    return (size >= cos.cm(minSize * _floatPrecisionMultiplier))..priority = strength;
  }

  /// Creates a constraint that check if the size is equal to the given
  /// [eqSize], assigning the given [strength] to the constraint.
  cos.Constraint hasIntSize(int eqSize, double strength) {
    return (size.equals(cos.cm(eqSize * _floatPrecisionMultiplier)))..priority = strength;
  }

  /// Creates a constraint that check if the size is equal to the given
  /// [expression], assigning the given [strength] to the constraint.
  cos.Constraint hasSize(cos.Expression expression, double strength) {
    return (size.equals(expression))..priority = strength;
  }

  /// Creates a constraint that check if the size is equal to 0
  cos.Constraint isEmpty() {
    return (size.equals(cos.cm(0)))..priority = Strengths.required.value - 1.0;
  }

  // coverage:ignore-start
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Element && other.start == start && other.end == end;
  }

  @override
  int get hashCode {
    return Object.hash(Element, start, end);
  }

  // coverage:ignore-end
}

/// A layout is a set of constraints that can be applied to a given area to
/// split it into smaller ones.
///
/// A layout is composed of:
/// - a direction (horizontal or vertical)
/// - a set of constraints (length, ratio, percentage, fill, min, max)
/// - a margin (horizontal and vertical), the space between the edge of the
/// main area and the split  areas
/// - a flex option
/// - a spacing option
///
/// The algorithm used to compute the layout is based on the [`cassowary`]
/// solver. It is a simple linear solver that can be used to solve linear
/// equations and inequalities. In our case, we define a set of constraints
/// that are applied to split the provided area into Rects aligned in a single
/// direction, and the solver computes the values of the position and sizes
/// that satisfy as many of the constraints in order of their priorities.
///
/// When the layout is computed, the result is cached in a thread-local cache,
/// so that subsequent calls with the same parameters are faster. The cache is
/// a [LruCache], and the size of the cache can be configured
/// using [Layout.init_cache()].
///
/// # Constructors
///
/// There are three ways to create a new layout:
///
/// - [Layout]: create a new layout with default values
/// - [Layout.vertical]: create a new vertical layout with the given constraints
/// - [Layout.horizontal]: create a new horizontal layout with the given constraints
@immutable
class Layout {
  /// The direction in which the layout is applied.
  final Direction direction;

  /// The constraints that are applied to the layout.
  final List<Constraint> _constraints;

  /// Defines the margin of the layout.
  final Margin margin;

  /// Defines the way the layout should distribute the space between the items.
  final Flex flex;

  /// Sets the spacing between items in the layout.
  ///
  /// The [spacing] sets the spacing between items in the layout. The spacing
  /// is applied evenly between all segments. The spacing value represents the
  /// number of cells between each item.
  ///
  /// Spacing can be positive integers, representing gaps between segments; or
  /// negative integers representing overlaps. Additionally, one of the
  /// variants of the [Spacing] enum can be passed to this function. See the
  /// documentation of the [Spacing] enum for more information.
  ///
  /// Note that if the layout has only one segment, the spacing will not be
  /// applied. Also, spacing will not be applied for [Flex.spaceAround] and
  /// [Flex.spaceBetween]
  ///
  final Spacing spacing;

  /// Creates a new layout with the default parameters.
  /// [margin] by default is zero, [flex] is set to [Flex.start] and [spacing]
  /// is set to zero.
  Layout({
    required this.direction,
    required List<Constraint> constraints,
    Margin? margin,
    Flex? flex,
    Spacing? spacing,
  }) : _constraints = List.from(constraints),
       margin = margin ?? Margin.zero,
       flex = flex ?? Flex.start,
       spacing = spacing ?? Space(0);

  /// Creates a new vertical layout with the given constraints.
  factory Layout.vertical(
    List<Constraint> constraints, {
    Flex? flex,
    Spacing? spacing,
  }) {
    return Layout(
      direction: Direction.vertical,
      constraints: constraints,
      flex: flex,
      spacing: spacing,
    );
  }

  /// Creates a new horizontal layout with the given constraints.
  factory Layout.horizontal(
    List<Constraint> constraints, {
    Flex? flex,
    Spacing? spacing,
  }) {
    return Layout(
      direction: Direction.horizontal,
      constraints: constraints,
      flex: flex,
      spacing: spacing,
    );
  }

  /// Initialize the cache with the given [cacheSize], clearing the previous
  /// content.
  // coverage:ignore-start
  void initCache(int cacheSize) {
    _layoutCache.clear();
    _layoutCache = LruCache<String, (Segments, Spacers)>(cacheSize);
  }
  // coverage:ignore-end

  /// Returns the constraints of the layout.
  List<Constraint> get constraints => List.unmodifiable(_constraints);

  /// Sets the horizontal margin of the layout. Returns a new Layout with the
  /// updated margin.
  Layout horizontalMargin(int horizontal) {
    return copyWith(margin: Margin(horizontal, margin.vertical));
  }

  /// Sets the vertical margin of the layout. Returns a new Layout with the
  /// updated margin.
  Layout verticalMargin(int vertical) {
    return copyWith(margin: Margin(margin.horizontal, vertical));
  }

  /// Split the rect into a number of sub-rects according to the given [Layout].
  ///
  /// An ergonomic wrapper around [Layout.split] that returns an array of
  /// [Rect]'s.
  ///
  /// This method requires the number of constraints to be known at compile
  /// time. If you don't know the number of constraints at compile time,
  /// use [Layout.split] instead.
  Rects areas(Rect area) {
    final (areas, _) = splitWithSpacers(area);
    if (areas.length != _constraints.length) {
      throw ArgumentError('areas and constraints must have the same length');
    }
    return areas;
  }

  /// Split the rect into a number of sub-rects according to the given [Layout]
  /// and return just the spacers between the areas.
  Rects spacers(Rect area) {
    final (_, spacers) = splitWithSpacers(area);
    if (spacers.length != _constraints.length + 1) {
      throw ArgumentError('spacers and constraints must have the same length');
    }
    return spacers;
  }

  /// Wrapper function around the cassowary solver to be able to split a given
  /// area into smaller ones based on the preferred widths or heights and the
  /// direction.
  ///
  /// Note that the constraints are applied to the whole area that is to be
  /// split, so using percentages and ratios with the other constraints may not
  /// have the desired effect of splitting the area up. (e.g. splitting 100
  /// into [min 20, 50%, 50%], may not result in [20, 40, 40] but rather an
  /// indeterminate result between [20, 50, 30] and [20, 30, 50]).
  ///
  /// This method stores the result of the computation in a thread-local cache
  /// keyed on the layout and area, so that subsequent calls with the same
  /// parameters are faster. The cache is a [LruCache], and grows until
  /// [_defaultCacheSize] is reached by default, if the cache is initialized
  /// with the [Layout.initCache()] grows until the initialized cache size.
  ///
  /// There is a helper method that can be used to split the whole area into
  /// smaller ones based on the layout: [Layout::areas()]. That method is a
  /// shortcut for calling this method. It allows you to destructure the result
  /// directly into variables, which is useful when you know at compile time
  /// the number of areas that will be created.
  Rects split(Rect area) => splitWithSpacers(area).$1;

  /// Wrapper function around the cassowary solver that splits the given area
  /// into smaller ones based on the preferred widths or heights and the
  /// direction, with the ability to include spacers between the areas.
  ///
  /// This method is similar to [split], but it returns two sets of rectangles:
  /// one for the areas and one for the spacers.
  (Segments, Spacers) splitWithSpacers(Rect area) {
    final key = '${area.hashCode}:$hashCode';

    final cachedValue = _layoutCache.get(key);
    if (cachedValue != null) return cachedValue;

    final value = _trySplit(area);
    _layoutCache.set(key, value);
    return value;
  }

  (Segments, Spacers) _trySplit(Rect area) {
    final solver = cos.Solver();

    final innerArea = area.inner(margin);
    final (areaStart, areaEnd) = switch (direction) {
      Direction.horizontal => (
        innerArea.x * _floatPrecisionMultiplier,
        innerArea.right * _floatPrecisionMultiplier,
      ),
      Direction.vertical => (
        innerArea.y * _floatPrecisionMultiplier,
        innerArea.bottom * _floatPrecisionMultiplier,
      ),
    };
    // ```plain
    // <───────────────────────────────────area_size──────────────────────────────────>
    // ┌─area_start                                                          area_end─┐
    // V                                                                              V
    // ┌────┬───────────────────┬────┬─────variables─────┬────┬───────────────────┬────┐
    // │    │                   │    │                   │    │                   │    │
    // V    V                   V    V                   V    V                   V    V
    // ┌   ┐┌──────────────────┐┌   ┐┌──────────────────┐┌   ┐┌──────────────────┐┌   ┐
    //      │     Max(20)      │     │      Max(20)     │     │      Max(20)     │
    // └   ┘└──────────────────┘└   ┘└──────────────────┘└   ┘└──────────────────┘└   ┘
    // ^    ^                   ^    ^                   ^    ^                   ^    ^
    // │    │                   │    │                   │    │                   │    │
    // └─┬──┶━━━━━━━━━┳━━━━━━━━━┵─┬──┶━━━━━━━━━┳━━━━━━━━━┵─┬──┶━━━━━━━━━┳━━━━━━━━━┵─┬──┘
    //   │            ┃           │            ┃           │            ┃           │
    //   └────────────╂───────────┴────────────╂───────────┴────────────╂──Spacers──┘
    //                ┃                        ┃                        ┃
    //                ┗━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━Segments━━━━━━━━┛
    // ```
    final variableCount = _constraints.length * 2 + 2;
    final variables = List.generate(variableCount, (_) => cos.Param());
    final spacers = variables.tuples().map((x) => Element(x.$1, x.$2));
    final segments = variables.skip(1).tuples().map((x) => Element(x.$1, x.$2));

    final spacing = switch (this.spacing) {
      Space(:final value) => value,
      Overlap(:final value) => -value,
    };

    final areaSize = Element(variables.first, variables.last);
    _configureArea(solver, areaSize, areaStart, areaEnd);
    _configureVariableConstraints(solver, variables, areaSize);
    _configureFlexConstraints(solver, areaSize, spacers, flex, spacing);
    _configureConstraints(solver, areaSize, segments, _constraints, flex);
    _configureFillConstraints(solver, segments, _constraints, flex);

    if (flex != Flex.legacy) {
      for (final (left, right) in segments.tupleWindow()) {
        solver.addConstraint(
          left.hasSize(right.size, Strengths.allSegmentGrow.value),
        );
      }
    }
    solver.flushUpdates();
    final segmentRects = _changesToRects(
      solver,
      segments,
      innerArea,
      direction,
    );
    final spacerRects = _changesToRects(solver, spacers, innerArea, direction);

    return (segmentRects, spacerRects);
  }

  void _configureArea(
    cos.Solver solver,
    Element area,
    double areaStart,
    double areaEnd,
  ) {
    solver
      ..addConstraint(
        area.start.equals(cos.cm(areaStart))..priority = Strengths.required.value,
      )
      ..addConstraint(
        area.end.equals(cos.cm(areaEnd))..priority = Strengths.required.value,
      );
  }

  void _configureVariableConstraints(
    cos.Solver solver,
    List<cos.Param> variables,
    Element area,
  ) {
    for (final variable in variables) {
      solver
        ..addConstraint(
          (variable >= area.start)..priority = Strengths.required.value,
        )
        ..addConstraint(
          (variable <= area.end)..priority = Strengths.required.value,
        );
    }

    // ┌────┬───────────────────┬────┬─────variables─────┬────┬───────────────────┬────┐
    // │    │                   │    │                   │    │                   │    │
    // v    v                   v    v                   v    v                   v    v
    // ┌   ┐┌──────────────────┐┌   ┐┌──────────────────┐┌   ┐┌──────────────────┐┌   ┐
    //      │     Max(20)      │     │      Max(20)     │     │      Max(20)     │
    // └   ┘└──────────────────┘└   ┘└──────────────────┘└   ┘└──────────────────┘└   ┘
    // ^    ^                   ^    ^                   ^    ^                   ^    ^
    // └v0  └v1                 └v2  └v3                 └v4  └v5                 └v6  └v7
    for (final (left, right) in variables.skip(1).tuples()) {
      solver.addConstraint(
        (left <= right)..priority = Strengths.required.value,
      );
    }
  }

  void _configureConstraints(
    cos.Solver solver,
    Element area,
    Iterable<Element> segments,
    List<Constraint> constraints,
    Flex flex,
  ) {
    for (final (constraint, segment) in constraints.zip(segments)) {
      switch (constraint) {
        case ConstraintMax(:final value):
          solver.addConstraint(
            segment.hasMaxSize(value, Strengths.maxSizeLe.value),
          );
          solver.addConstraint(
            segment.hasIntSize(value, Strengths.maxSizeEq.value),
          );
        case ConstraintMin(:final value):
          solver.addConstraint(
            segment.hasMinSize(value, Strengths.minSizeGe.value),
          );
          if (flex == Flex.legacy) {
            solver.addConstraint(
              segment.hasIntSize(value, Strengths.minSizeEq.value),
            );
          } else {
            solver.addConstraint(
              segment.hasSize(area.size, Strengths.fillGrow.value),
            );
          }
        case ConstraintLength(:final value):
          solver.addConstraint(
            segment.hasIntSize(value, Strengths.lengthSizeEq.value),
          );
        case ConstraintPercentage(:final value):
          final size = area.size * cos.cm(value.toDouble()) / cos.cm(100);
          solver.addConstraint(
            segment.hasSize(size, Strengths.percentageSizeEq.value),
          );
        case ConstraintRatio(:final numerator, :final denominator):
          final size = area.size * cos.cm(numerator.toDouble()) / cos.cm(math.max(denominator, 1).toDouble());
          solver.addConstraint(
            segment.hasSize(size, Strengths.ratioSizeEq.value),
          );
        case ConstraintFill():
          solver.addConstraint(
            segment.hasSize(area.size, Strengths.fillGrow.value),
          );
      }
    }
  }

  void _configureFlexConstraints(
    cos.Solver solver,
    Element area,
    Iterable<Element> spacers,
    Flex flex,
    int spacing,
  ) {
    final spacersExceptFirstLast = spacers.skip(1).take(spacers.length - 2);
    final spacingF = spacing * _floatPrecisionMultiplier;
    switch (flex) {
      case Flex.legacy:
        for (final spacer in spacersExceptFirstLast) {
          solver.addConstraint(
            spacer.hasSize(
              cos.cm(spacingF).asExpression(),
              Strengths.spacerSizeEq.value,
            ),
          );
        }
        solver
          ..addConstraint(spacers.first.isEmpty())
          ..addConstraint(spacers.last.isEmpty());
      case Flex.spaceAround:
        for (final (left, right) in spacers.tupleCombinations()) {
          solver.addConstraint(
            left.hasSize(right.size, Strengths.spacerSizeEq.value),
          );
        }
        for (final spacer in spacers) {
          solver
            ..addConstraint(
              spacer.hasMinSize(spacing, Strengths.spacerSizeEq.value),
            )
            ..addConstraint(
              spacer.hasSize(area.size, Strengths.spaceGrow.value),
            );
        }
      case Flex.spaceBetween:
        for (final (left, right) in spacersExceptFirstLast.tupleCombinations()) {
          solver.addConstraint(
            left.hasSize(right.size, Strengths.spacerSizeEq.value),
          );
        }
        for (final spacer in spacersExceptFirstLast) {
          solver
            ..addConstraint(
              spacer.hasMinSize(spacing, Strengths.spacerSizeEq.value),
            )
            ..addConstraint(
              spacer.hasSize(area.size, Strengths.spaceGrow.value),
            );
        }
        solver
          ..addConstraint(spacers.first.isEmpty())
          ..addConstraint(spacers.last.isEmpty());
      case Flex.start:
        for (final spacer in spacersExceptFirstLast) {
          solver.addConstraint(
            spacer.hasSize(
              cos.cm(spacingF).asExpression(),
              Strengths.spacerSizeEq.value,
            ),
          );
        }
        solver
          ..addConstraint(spacers.first.isEmpty())
          ..addConstraint(
            spacers.last.hasSize(area.size, Strengths.grow.value),
          );
      case Flex.center:
        for (final spacer in spacersExceptFirstLast) {
          solver.addConstraint(
            spacer.hasSize(
              cos.cm(spacingF).asExpression(),
              Strengths.spacerSizeEq.value,
            ),
          );
        }
        solver
          ..addConstraint(
            spacers.first.hasSize(area.size, Strengths.grow.value),
          )
          ..addConstraint(spacers.last.hasSize(area.size, Strengths.grow.value))
          ..addConstraint(
            spacers.first.hasSize(
              spacers.last.size,
              Strengths.spacerSizeEq.value,
            ),
          );
      case Flex.end:
        for (final spacer in spacersExceptFirstLast) {
          solver.addConstraint(
            spacer.hasSize(
              cos.cm(spacingF).asExpression(),
              Strengths.spacerSizeEq.value,
            ),
          );
        }
        solver
          ..addConstraint(spacers.last.isEmpty())
          ..addConstraint(
            spacers.first.hasSize(area.size, Strengths.grow.value),
          );
    }
  }

  void _configureFillConstraints(
    cos.Solver solver,
    Iterable<Element> segments,
    List<Constraint> constraints,
    Flex flex,
  ) {
    bool constraintFilter((Constraint, Element) p) =>
        p.$1 is ConstraintFill || (flex != Flex.legacy && p.$1 is ConstraintMin);
    final constraintSegment = constraints.zip(segments).where(constraintFilter).tupleCombinations();

    for (final ((leftConstraint, leftSegment), (rightConstraint, rightSegment)) in constraintSegment) {
      final leftScalingFactor = switch (leftConstraint) {
        ConstraintFill(:final value) => math.max(value.toDouble(), 1e-6),
        ConstraintMin() => 1.0,
        _ => throw UnimplementedError(
          'constraint not implemented: $leftConstraint',
        ),
      };
      final rightScalingFactor = switch (rightConstraint) {
        ConstraintFill(:final value) => math.max(value.toDouble(), 1e-6),
        ConstraintMin() => 1.0,
        _ => throw UnimplementedError(
          'constraint not implemented: $rightConstraint',
        ),
      };
      final rhs = cos.cm(rightScalingFactor) * leftSegment.size;
      final lhs = cos.cm(leftScalingFactor) * rightSegment.size;

      solver.addConstraint(rhs.equals(lhs)..priority = Strengths.grow.value);
    }
  }

  Rects _changesToRects(
    cos.Solver solver,
    Iterable<Element> elements,
    Rect area,
    Direction direction,
  ) {
    return elements.map((element) {
      final start = (element.start.value.round() / _floatPrecisionMultiplier).round();
      final end = (element.end.value.round() / _floatPrecisionMultiplier).round();
      final size = end.saturatingSubU16(start);
      return switch (direction) {
        Direction.horizontal => Rect.create(
          x: start,
          y: area.y,
          width: size,
          height: area.height,
        ),
        Direction.vertical => Rect.create(
          x: area.x,
          y: start,
          width: area.width,
          height: size,
        ),
      };
    }).toList();
  }

  /// Returns a new [Layout] overriding the specified properties.
  Layout copyWith({
    Direction? direction,
    List<Constraint>? constraints,
    Margin? margin,
    Flex? flex,
    Spacing? spacing,
  }) {
    return Layout(
      direction: direction ?? this.direction,
      constraints: constraints != null ? List.from(constraints) : List.from(_constraints),
      margin: margin ?? this.margin,
      flex: flex ?? this.flex,
      spacing: spacing ?? this.spacing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Layout) return false;

    if (other.flex != flex || other.spacing != spacing || other.direction != direction || other.margin != margin) {
      return false;
    }

    if (_constraints.length != other._constraints.length) return false;

    for (var i = 0; i < _constraints.length; i++) {
      if (_constraints[i] != other._constraints[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Layout,
    direction,
    Object.hashAll(_constraints),
    margin,
    flex,
    spacing,
  );
}
