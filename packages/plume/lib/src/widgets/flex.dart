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
class Flexible<S> extends SingleChildNode<S> {
  /// Gives [child] a [flex] share, filled according to [fit].
  Flexible({required this.flex, required RenderNode<S> child, this.fit = FlexFit.loose}) : super(child);

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
class Expanded<S> extends Flexible<S> {
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
class Flex<S> extends RenderNode<S> {
  /// Creates a flex line along [direction].
  Flex({
    required this.direction,
    required List<RenderNode<S>> children,
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

  final List<RenderNode<S>> _children;

  @override
  List<RenderNode<S>> get children => _children;

  int? _mainMax(BoxConstraints c) => direction == Axis.horizontal ? c.maxW : c.maxH;

  int? _crossMax(BoxConstraints c) => direction == Axis.horizontal ? c.maxH : c.maxW;

  int _main(Size size) => direction == Axis.horizontal ? size.w : size.h;

  int _cross(Size size) => direction == Axis.horizontal ? size.h : size.w;

  Size _sizeOf(int main, int cross) => direction == Axis.horizontal ? Size(main, cross) : Size(cross, main);

  Offset _offsetOf(int main, int cross) => direction == Axis.horizontal ? Offset(main, cross) : Offset(cross, main);

  int _flexOf(RenderNode<S> child) => child is Flexible<S> ? child.flex : 0;

  FlexFit _fitOf(RenderNode<S> child) => child is Flexible<S> ? child.fit : FlexFit.loose;

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
    final (leading, between) = _distribute(freeMain, n);

    var mainPos = leading;
    for (var i = 0; i < n; i++) {
      final crossFree = crossExtent - childCross[i];
      final crossPos = switch (crossAxisAlignment) {
        CrossAxisAlignment.start || CrossAxisAlignment.stretch => 0,
        CrossAxisAlignment.center => crossFree ~/ 2,
        CrossAxisAlignment.end => crossFree,
      };
      _children[i].offset = _offsetOf(mainPos, crossPos);
      mainPos += childMain[i] + between;
    }

    return size;
  }

  (int, int) _distribute(int freeMain, int count) => switch (mainAxisAlignment) {
    MainAxisAlignment.start => (0, 0),
    MainAxisAlignment.end => (freeMain, 0),
    MainAxisAlignment.center => (freeMain ~/ 2, 0),
    MainAxisAlignment.spaceBetween => (0, count > 1 ? freeMain ~/ (count - 1) : 0),
    MainAxisAlignment.spaceAround => (count > 0 ? (freeMain ~/ count) ~/ 2 : 0, count > 0 ? freeMain ~/ count : 0),
    MainAxisAlignment.spaceEvenly => (count > 0 ? freeMain ~/ (count + 1) : 0, count > 0 ? freeMain ~/ (count + 1) : 0),
  };
}

/// A horizontal [Flex].
class Row<S> extends Flex<S> {
  /// Lays [children] out left to right.
  Row({
    required super.children,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
  }) : super(direction: Axis.horizontal);
}

/// A vertical [Flex].
class Column<S> extends Flex<S> {
  /// Lays [children] out top to bottom.
  Column({
    required super.children,
    super.mainAxisAlignment,
    super.crossAxisAlignment,
    super.mainAxisSize,
  }) : super(direction: Axis.vertical);
}
