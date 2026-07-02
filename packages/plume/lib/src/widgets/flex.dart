import '../geometry/box_constraints.dart';
import '../geometry/offset.dart';
import '../geometry/size.dart';
import '../render/layout_context.dart';
import '../render/render_node.dart';
import '../render/single_child_node.dart';

/// The axis a [Flex] lays its children along.
enum Axis {
  /// Left to right ([Row]).
  horizontal,

  /// Top to bottom ([Column]).
  vertical,
}

/// How free space along the main axis is distributed.
enum MainAxisAlignment {
  /// Pack children at the start.
  start,

  /// Pack children at the end.
  end,

  /// Pack children in the middle.
  center,

  /// Free space split evenly between children, none at the ends.
  spaceBetween,

  /// Free space split around children, half-gaps at the ends.
  spaceAround,

  /// Free space split evenly between and around children.
  spaceEvenly,
}

/// How each child is positioned (or sized) along the cross axis.
enum CrossAxisAlignment {
  /// Align children to the cross-axis start.
  start,

  /// Align children to the cross-axis end.
  end,

  /// Center children on the cross axis.
  center,

  /// Stretch children to fill the cross axis.
  stretch,
}

/// Whether a [Flex] shrink-wraps its children or fills the main axis.
enum MainAxisSize {
  /// Take only as much main-axis space as the children need.
  min,

  /// Fill the available main-axis space.
  max,
}

/// Whether a flexible child must fill its share or may be smaller.
enum FlexFit {
  /// The child is forced to exactly its allocated main-axis extent.
  tight,

  /// The child may be up to its allocated main-axis extent.
  loose,
}

/// Marks its child as flexible within a [Flex], taking a share of the free
/// main-axis space proportional to [flex].
class Flexible<T> extends SingleChildNode<T> {
  /// Gives [child] a [flex] share, filled according to [fit].
  ///
  /// [flex] must be positive: a zero or negative factor has no meaning in the
  /// two-pass share-out and would put the child in an inconsistent state
  /// between the passes.
  Flexible({required this.flex, required RenderNode<T> child, this.fit = FlexFit.loose})
    : assert(flex > 0, 'Flexible.flex must be positive; got $flex.'),
      super(child);

  /// This child's share of the free space, relative to its siblings.
  final int flex;

  /// Whether the child must fill its share ([FlexFit.tight]) or may be smaller.
  final FlexFit fit;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final size = child.layout(constraints, context);
    child.offset = Offset.zero;
    return size;
  }
}

/// A [Flexible] child that fills its whole share of the main axis.
class Expanded<T> extends Flexible<T> {
  /// Expands [child] with the given [flex] share.
  Expanded({required super.child, super.flex = 1}) : super(fit: FlexFit.tight);
}

/// Lays children out in a line (the two-pass flex algorithm).
///
/// Inflexible children are measured first with a loose main axis; the leftover
/// main-axis space is then shared among [Flexible] children by flex factor.
/// [mainAxisAlignment] distributes any remaining space, [crossAxisAlignment]
/// positions or stretches children on the cross axis, and [mainAxisSize]
/// decides whether the line fills the main axis or shrink-wraps its children.
class Flex<T> extends RenderNode<T> {
  /// Creates a flex line along [direction].
  Flex({
    required this.direction,
    required List<RenderNode<T>> children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  }) : _children = children;

  /// The axis children are laid along.
  final Axis direction;

  /// How free main-axis space is distributed.
  final MainAxisAlignment mainAxisAlignment;

  /// How children are aligned or stretched on the cross axis.
  final CrossAxisAlignment crossAxisAlignment;

  /// Whether the line fills the main axis or shrink-wraps.
  final MainAxisSize mainAxisSize;

  final List<RenderNode<T>> _children;

  @override
  List<RenderNode<T>> get children => _children;

  int? _mainMax(BoxConstraints c) => direction == Axis.horizontal ? c.maxW : c.maxH;

  int? _crossMax(BoxConstraints c) => direction == Axis.horizontal ? c.maxH : c.maxW;

  int _main(Size size) => direction == Axis.horizontal ? size.w : size.h;

  int _cross(Size size) => direction == Axis.horizontal ? size.h : size.w;

  Size _sizeOf(int main, int cross) => direction == Axis.horizontal ? Size(main, cross) : Size(cross, main);

  Offset _offsetOf(int main, int cross) => direction == Axis.horizontal ? Offset(main, cross) : Offset(cross, main);

  int _flexOf(RenderNode<T> child) => child is Flexible<T> ? child.flex : 0;

  FlexFit _fitOf(RenderNode<T> child) => child is Flexible<T> ? child.fit : FlexFit.loose;

  BoxConstraints _childConstraints({required int mainMin, required int? mainMax, required int? maxCross}) {
    final crossMin = (crossAxisAlignment == CrossAxisAlignment.stretch && maxCross != null) ? maxCross : 0;
    return direction == Axis.horizontal
        ? BoxConstraints(minW: mainMin, maxW: mainMax, minH: crossMin, maxH: maxCross)
        : BoxConstraints(minW: crossMin, maxW: maxCross, minH: mainMin, maxH: mainMax);
  }

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) {
    final maxMain = _mainMax(constraints);
    final maxCross = _crossMax(constraints);
    final n = _children.length;
    final childMain = List<int>.filled(n, 0);
    final childCross = List<int>.filled(n, 0);

    var totalFlex = 0;
    var allocatedMain = 0;
    var maxChildCross = 0;
    var lastFlex = -1;

    // Pass 1: measure inflexible children with a loose main axis.
    for (var i = 0; i < n; i++) {
      final flex = _flexOf(_children[i]);
      if (flex > 0) {
        totalFlex += flex;
        lastFlex = i;
        continue;
      }
      final size = _children[i].layout(_childConstraints(mainMin: 0, mainMax: null, maxCross: maxCross), context);
      childMain[i] = _main(size);
      childCross[i] = _cross(size);
      allocatedMain += _main(size);
      if (_cross(size) > maxChildCross) {
        maxChildCross = _cross(size);
      }
    }

    // A flexible child divides the leftover main-axis space, but an unbounded
    // main axis has no leftover to divide — the child would silently collapse
    // to zero. That is almost always an author mistake, so fail loudly.
    assert(
      maxMain != null || totalFlex == 0,
      'A flexible child cannot be laid out along an unbounded $direction main '
      'axis: it has no bounded space to take a share of and would collapse to '
      'zero. Give the flex a bounded main-axis constraint, or make the child '
      'inflexible.',
    );

    // Pass 2: share the leftover main-axis space among flexible children.
    final free = (maxMain == null || maxMain - allocatedMain < 0) ? 0 : maxMain - allocatedMain;
    var distributed = 0;
    for (var i = 0; i < n; i++) {
      final flex = _flexOf(_children[i]);
      if (flex == 0) {
        continue;
      }
      final share = (i == lastFlex) ? free - distributed : (totalFlex == 0 ? 0 : (free * flex) ~/ totalFlex);
      distributed += share;
      final mainMin = _fitOf(_children[i]) == FlexFit.tight ? share : 0;
      final size = _children[i].layout(
        _childConstraints(mainMin: mainMin, mainMax: share, maxCross: maxCross),
        context,
      );
      childMain[i] = _main(size);
      childCross[i] = _cross(size);
      if (_cross(size) > maxChildCross) {
        maxChildCross = _cross(size);
      }
    }

    final totalChildrenMain = childMain.fold<int>(0, (sum, m) => sum + m);
    final mainRaw = (mainAxisSize == MainAxisSize.max && maxMain != null) ? maxMain : totalChildrenMain;
    final crossRaw = (crossAxisAlignment == CrossAxisAlignment.stretch && maxCross != null) ? maxCross : maxChildCross;
    final size = constraints.constrain(_sizeOf(mainRaw, crossRaw));
    final mainExtent = _main(size);
    final crossExtent = _cross(size);

    final freeMain = mainExtent - totalChildrenMain < 0 ? 0 : mainExtent - totalChildrenMain;
    final (leading, betweens) = _distribute(freeMain, n);

    var mainPos = leading;
    for (var i = 0; i < n; i++) {
      final crossFree = crossExtent - childCross[i];
      final crossPos = switch (crossAxisAlignment) {
        CrossAxisAlignment.start || CrossAxisAlignment.stretch => 0,
        CrossAxisAlignment.center => crossFree ~/ 2,
        CrossAxisAlignment.end => crossFree,
      };
      _children[i].offset = _offsetOf(mainPos, crossPos);
      mainPos += childMain[i];
      if (i < betweens.length) {
        mainPos += betweens[i];
      }
    }

    return size;
  }

  /// Splits [freeMain] into a leading offset and the gap after each child (a
  /// list of length `count - 1`), consuming every cell of the free space.
  ///
  /// Cells cannot be split, so an uneven division leaves an integer remainder.
  /// The policy is explicit: hand the remainder out one cell at a time to the
  /// leading gaps. So the fill modes ([MainAxisAlignment.spaceBetween],
  /// [MainAxisAlignment.spaceAround], [MainAxisAlignment.spaceEvenly]) reach the
  /// trailing edge exactly — the earliest gaps are one cell wider rather than
  /// the slack piling up unused at the end.
  (int, List<int>) _distribute(int freeMain, int count) {
    if (count <= 0) {
      return (0, const <int>[]);
    }
    switch (mainAxisAlignment) {
      case MainAxisAlignment.start:
        return (0, _zeros(count - 1));
      case MainAxisAlignment.end:
        return (freeMain, _zeros(count - 1));
      case MainAxisAlignment.center:
        return (freeMain ~/ 2, _zeros(count - 1));
      case MainAxisAlignment.spaceBetween:
        // Gaps sit only between children; the ends touch the edges.
        return (0, _spread(freeMain, count - 1));
      case MainAxisAlignment.spaceEvenly:
        // Equal gaps between children and at both ends.
        final gaps = _spread(freeMain, count + 1);
        return (gaps.first, gaps.sublist(1, count));
      case MainAxisAlignment.spaceAround:
        // Each child gets a half-gap on each side, so the ends are half the
        // between-child gap. Spread over half-slots, then fold pairs back into
        // the between-child gaps.
        final halves = _spread(freeMain, count * 2);
        final betweens = <int>[for (var i = 0; i < count - 1; i++) halves[2 * i + 1] + halves[2 * i + 2]];
        return (halves.first, betweens);
    }
  }

  /// Splits [total] into [slots] non-negative gaps summing to exactly [total],
  /// giving the first `total % slots` gaps one extra cell.
  static List<int> _spread(int total, int slots) {
    if (slots <= 0) {
      return const <int>[];
    }
    final base = total ~/ slots;
    final remainder = total % slots;
    return <int>[for (var i = 0; i < slots; i++) base + (i < remainder ? 1 : 0)];
  }

  static List<int> _zeros(int count) => count <= 0 ? const <int>[] : List<int>.filled(count, 0);
}

/// A horizontal [Flex].
class Row<T> extends Flex<T> {
  /// Lays [children] out left to right.
  Row({
    required super.children,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
  }) : super(direction: Axis.horizontal);
}

/// A vertical [Flex].
class Column<T> extends Flex<T> {
  /// Lays [children] out top to bottom.
  Column({
    required super.children,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
  }) : super(direction: Axis.vertical);
}
