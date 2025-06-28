import 'dart:math' as math;

import '../../buffer.dart';
import '../../extensions/integer.dart';
import '../../layout/alignment.dart';
import '../../layout/rect.dart';
import '../../style.dart';
import '../../text/line.dart';
import '../../widgets/frame.dart';
import '../borders.dart';
import 'padding.dart';

/// The type of border to display around a block.
enum BorderType {
  /// No border
  none,

  /// Custom defined border
  custom,

  /// A plain, simple border.
  ///
  /// This is the default
  ///
  /// # Example
  ///
  /// ```plain
  /// ┌───────┐
  /// │       │
  /// └───────┘
  /// ```
  plain,

  /// A plain border with rounded corners.
  ///
  /// # Example
  ///
  /// ```plain
  /// ╭───────╮
  /// │       │
  /// ╰───────╯
  /// ```
  rounded,

  /// A doubled border.
  ///
  /// Note this uses one character that draws two lines.
  ///
  /// # Example
  ///
  /// ```plain
  /// ╔═══════╗
  /// ║       ║
  /// ╚═══════╝
  /// ```
  double,

  /// A thick border.
  ///
  /// # Example
  ///
  /// ```plain
  /// ┏━━━━━━━┓
  /// ┃       ┃
  /// ┗━━━━━━━┛
  /// ```
  thick,

  /// A border with a single line on the inside of a half block.
  ///
  /// # Example
  ///
  /// ```plain
  /// ▗▄▄▄▄▄▄▄▖
  /// ▐       ▌
  /// ▐       ▌
  /// ▝▀▀▀▀▀▀▀▘
  quadrantInside,

  /// A border with a single line on the outside of a half block.
  ///
  /// # Example
  ///
  /// ```plain
  /// ▛▀▀▀▀▀▀▀▜
  /// ▌       ▐
  /// ▌       ▐
  /// ▙▄▄▄▄▄▄▄▟
  quadrantOutside,
}

/// A set of border characters to use when rendering a block.
typedef BorderSet = ({
  String topLeft,
  String topRight,
  String bottomLeft,
  String bottomRight,
  String left,
  String right,
  String top,
  String bottom,
});

/// The position of a title within a block.
enum TitlePosition {
  /// Defines top position
  top,

  /// Defines bottom position
  bottom
}

/// Base widget to be used to display a box border around all upper level one
/// widgets.
///
/// The borders can be configured with [Block.borders] and others. A block can
/// have multiple title using [Block.title]. It can also be styled and
/// padded.
///
/// You can call the title methods multiple times to add multiple titles. Each
/// title will be rendered with a single space separating titles that are in
/// the same position or alignment. When both centered and non-centered titles
/// are rendered, the centered space is calculated based on the full width of
/// the block, rather than the leftover width.
///
/// Titles are not rendered in the corners of the block unless there is no
/// border on that edge. If the block is too small and multiple titles overlap,
/// the border may get cut off at a corner.
class Block implements Widget {
  final List<Line> _topTitles;
  final List<Line> _bottomTitles;

  /// Style to use for the titles if they do not define their own style.
  final Style titlesStyle;

  /// Border style to apply to the block.
  Borders borders;

  /// Border [Style] to apply to the block's border.
  Style borderStyle;

  /// Border type to use when rendering the block.
  BorderType borderType;

  /// Style to apply to the block when rendered
  Style style;

  /// Padding to apply to the block.
  Padding padding;

  /// Border set to use when rendering the block. This will be used when
  /// [borderType] is set to [BorderType.custom].
  BorderSet? borderSet;

  /// Creates a new block widget.
  Block({
    this.borders = Borders.none,
    this.borderStyle = const Style(),
    this.borderType = BorderType.plain,
    this.style = const Style(),
    this.titlesStyle = const Style(),
    this.padding = const Padding.zero(),
    this.borderSet,
  })  : _topTitles = [],
        _bottomTitles = [];

  /// Compute the inner area of a block based on its border visibility rules.
  ///
  /// Examples:
  ///
  /// Draw a block nested within another block
  /// ```dart
  /// # fn renderNestedBlock(Frame frame) {
  /// let outerBlock = Block()..borders = Borders.all..titleTop(Line(content: "Outer"));
  /// let innerBlock = Block()..borders = Borders.all..title(Line.(content: "Inner"));
  ///
  /// let outerArea = frame.area();
  /// let innerArea = outerBlock.inner(outerArea);
  ///
  /// frame.renderWidget(outerBlock, outerArea);
  /// frame.renderWidget(innerBlock, innerArea);
  /// # } ///
  ///
  /// // Renders
  /// // ┌Outer────────┐
  /// // │┌Inner──────┐│
  /// // ││           ││
  /// // │└───────────┘│
  /// // └─────────────┘
  /// ```
  Rect inner(Rect area) {
    var inner = area;
    if (borders.has(Borders.left)) {
      inner = inner.copyWith(
        x: math.min(inner.x.saturatingAdd(1), inner.right),
        width: inner.width.saturatingSub(1),
      );
    }
    if (borders.has(Borders.top) || _topTitles.isNotEmpty) {
      inner = inner.copyWith(
        y: math.min(inner.y.saturatingAdd(1), inner.bottom),
        height: inner.height.saturatingSub(1),
      );
    }
    if (borders.has(Borders.right)) {
      inner = inner.copyWith(width: inner.width.saturatingSub(1));
    }
    if (borders.has(Borders.bottom) || _bottomTitles.isNotEmpty) {
      inner = inner.copyWith(height: inner.height.saturatingSub(1));
    }

    return inner.copyWith(
      x: inner.x.saturatingAdd(padding.left),
      y: inner.y.saturatingAdd(padding.top),
      width: inner.width.saturatingSub(padding.left + padding.right),
      height: inner.height.saturatingSub(padding.top + padding.bottom),
    );
  }

  /// Adds a title to the block in the specified position.
  void title(Line content, TitlePosition position) {
    if (position == TitlePosition.top) {
      _topTitles.add(content);
    } else {
      _bottomTitles.add(content);
    }
  }

  /// Adds a title to the top of the block.
  ///
  /// # Example
  ///
  /// ```dart
  /// Block()
  ///   ..borders = Borders.all
  ///   .titleTop(Line(content: "Left1")) // By default in the top left corner
  ///   .titleTop(Line(content: "Left2", alignment: Alignment.left)
  ///   .titleTop(Line(content: "Right", alignment: Alignment.right)
  ///   .titleTop(Line(content: "Center", alignment: Alignment.center);
  ///
  /// // Renders
  /// // ┌Left1─Left2───Center─────────Right┐
  /// // │                                  │
  /// // └──────────────────────────────────┘
  /// ```
  void titleTop(Line content) => _topTitles.add(content);

  /// Adds a title to the bottom of the block.
  ///
  /// # Example
  ///
  /// ```dart
  /// Block()
  ///   ..borders = Borders.all
  ///   .titleBottom(Line(content: "Left1")) // By default in the top left corner
  ///   .titleBottom(Line(content: "Left2", alignment: Alignment.left)
  ///   .titleBottom(Line(content: "Right", alignment: Alignment.right)
  ///   .titleBottom(Line(content: "Center", alignment: Alignment.center);
  ///
  /// // Renders
  /// // ┌──────────────────────────────────┐
  /// // │                                  │
  /// // └Left1─Left2───Center─────────Right┘
  /// ```
  void titleBottom(Line content) => _bottomTitles.add(content);

  /// Calculate the left, and right space the [Block] will take up.
  ///
  /// The result takes the [Block]'s, [Borders], and [Padding] into account.
  (int, int) horizontalSpace() {
    final left = padding.left.saturatingAdd(borders.has(Borders.left) ? 1 : 0);
    final right = padding.right.saturatingAdd(borders.has(Borders.right) ? 1 : 0);
    return (left, right);
  }

  /// Calculate the top, and bottom space that the [Block] will take up.
  ///
  /// Takes the [Padding], title's position, and the [Borders] that are
  /// selected into account when calculating the result.
  (int, int) verticalSpace() {
    final hasTop = borders.has(Borders.top) || _topTitles.isNotEmpty ? 1 : 0;
    final top = padding.top + hasTop;
    final hasBottom = borders.has(Borders.bottom) || _bottomTitles.isNotEmpty ? 1 : 0;
    final bottom = padding.bottom + hasBottom;
    return (top, bottom);
  }

  /// Returns `true` if the block has a title at the top.
  bool get hasTitleAtTop => _topTitles.isNotEmpty;

  /// Returns `true` if the block has a title at the bottom.
  bool get hasTitleAtBottom => _bottomTitles.isNotEmpty;

  @override
  void render(Rect area, Buffer buffer) {
    final renderArea = area.intersection(buffer.area);
    if (renderArea.isEmpty) return;

    buffer.setStyle(renderArea, style);
    _renderBorders(renderArea, buffer);
    _renderTitles(renderArea, buffer);
  }

  void _renderBorders(Rect area, Buffer buffer) {
    if (borderType == BorderType.custom && borderSet == null) {
      throw ArgumentError('BorderType set to "custom" but no BorderSet provided');
    }
    final borderLines = borderType == BorderType.custom ? borderSet! : borderType.symbols(borderType);

    if (borders.has(Borders.left)) {
      for (var y = area.top; y < area.bottom; y++) {
        buffer[(x: area.left, y: y)] =
            buffer[(x: area.left, y: y)].copyWith(char: borderLines.left).setStyle(borderStyle);
      }
    }
    if (borders.has(Borders.top)) {
      for (var x = area.left; x < area.right; x++) {
        buffer[(x: x, y: area.top)] = buffer[(x: x, y: area.top)].copyWith(char: borderLines.top).setStyle(borderStyle);
      }
    }
    if (borders.has(Borders.right)) {
      final x = area.right - 1;
      for (var y = area.top; y < area.bottom; y++) {
        buffer[(x: x, y: y)] = buffer[(x: x, y: y)].copyWith(char: borderLines.right).setStyle(borderStyle);
      }
    }
    if (borders.has(Borders.bottom)) {
      final y = area.bottom - 1;
      for (var x = area.left; x < area.right; x++) {
        buffer[(x: x, y: y)] = buffer[(x: x, y: y)].copyWith(char: borderLines.bottom).setStyle(borderStyle);
      }
    }
    if (borders.has(Borders.right) && borders.has(Borders.bottom)) {
      buffer[(x: area.right - 1, y: area.bottom - 1)] =
          buffer[(x: area.right - 1, y: area.bottom - 1)].copyWith(char: borderLines.bottomRight).setStyle(borderStyle);
    }
    if (borders.has(Borders.right) && borders.has(Borders.top)) {
      buffer[(x: area.right - 1, y: area.top)] =
          buffer[(x: area.right - 1, y: area.top)].copyWith(char: borderLines.topRight).setStyle(borderStyle);
    }
    if (borders.has(Borders.left) && borders.has(Borders.bottom)) {
      buffer[(x: area.left, y: area.bottom - 1)] =
          buffer[(x: area.left, y: area.bottom - 1)].copyWith(char: borderLines.bottomLeft).setStyle(borderStyle);
    }
    if (borders.has(Borders.left) && borders.has(Borders.top)) {
      buffer[(x: area.left, y: area.top)] =
          buffer[(x: area.left, y: area.top)].copyWith(char: borderLines.topLeft).setStyle(borderStyle);
    }
  }

  void _renderTitles(Rect area, Buffer buffer) {
    if (hasTitleAtTop) {
      _renderRightTitles(TitlePosition.top, area, buffer);
      _renderCenterTitles(TitlePosition.top, area, buffer);
      _renderLeftTitles(TitlePosition.top, area, buffer);
    }

    if (hasTitleAtBottom) {
      _renderRightTitles(TitlePosition.bottom, area, buffer);
      _renderCenterTitles(TitlePosition.bottom, area, buffer);
      _renderLeftTitles(TitlePosition.bottom, area, buffer);
    }
  }

  void _renderRightTitles(TitlePosition position, Rect area, Buffer buffer) {
    final titles = _getTitlesAtPos(position, Alignment.right);
    var titlesArea = _getTitlesAreas(area, position);

    for (final title in titles) {
      if (titlesArea.isEmpty) return;

      final titleWidth = title.width;
      titlesArea = titlesArea.copyWith(
        x: math.max(titlesArea.right.saturatingSub(titleWidth), titlesArea.left),
        width: math.min(titleWidth, titlesArea.width),
      );

      buffer.setStyle(titlesArea, titlesStyle);
      title.render(titlesArea, buffer);
      titlesArea = titlesArea.copyWith(width: titlesArea.width.saturatingSub(titleWidth + 1));
    }
  }

  void _renderCenterTitles(TitlePosition position, Rect area, Buffer buffer) {
    final titles = _getTitlesAtPos(position, Alignment.center);
    // +1 spaces between each title, -1 remove last one
    final totalWidth = titles.fold(0, (acc, title) => acc + title.width + 1).saturatingSub(1);
    var titlesArea = _getTitlesAreas(area, position);
    titlesArea = titlesArea.copyWith(
      x: titlesArea.left + (titlesArea.width.saturatingSub(totalWidth) ~/ 2),
    );

    for (final title in titles) {
      if (titlesArea.isEmpty) break;

      final titleWidth = title.width;
      final titleArea = titlesArea.copyWith(
        width: math.min(titleWidth, titlesArea.width),
      );
      buffer.setStyle(titleArea, titlesStyle);
      title.render(titleArea, buffer);

      titlesArea = titlesArea.copyWith(
        x: titlesArea.x.saturatingAdd(titleWidth + 1),
        width: titlesArea.width.saturatingSub(titleWidth + 1),
      );
    }
  }

  void _renderLeftTitles(TitlePosition position, Rect area, Buffer buffer) {
    final titles = _getTitlesAtPos(position, Alignment.left);
    var titlesArea = _getTitlesAreas(area, position);

    for (final title in titles) {
      if (titlesArea.isEmpty) return;

      final titleWidth = title.width;
      final titleArea = titlesArea.copyWith(
        width: math.min(titleWidth, titlesArea.width),
      );

      buffer.setStyle(titleArea, titlesStyle);
      title.render(titleArea, buffer);
      titlesArea = titlesArea.copyWith(
        x: titlesArea.x.saturatingAdd(titleWidth + 1),
        width: titlesArea.width.saturatingSub(titleWidth + 1),
      );
    }
  }

  Iterable<Line> _getTitlesAtPos(TitlePosition position, Alignment alignment) {
    final titles = position == TitlePosition.top ? _topTitles : _bottomTitles;
    // if the Line.alignment is null by default is left
    return titles.reversed
        .where((title) => title.alignment == alignment || (alignment == Alignment.left && title.alignment == null));
  }

  Rect _getTitlesAreas(Rect area, TitlePosition position) {
    final leftBorder = borders.has(Borders.left) ? 1 : 0;
    final rightBorder = borders.has(Borders.right) ? 1 : 0;

    return Rect.create(
      x: area.left + leftBorder,
      y: position == TitlePosition.top ? area.top : area.bottom - 1,
      width: area.width.saturatingSub(leftBorder).saturatingSub(rightBorder),
      height: 1,
    );
  }
}

const _quadrantTopLeft = '▘';
const _quadrantTopRight = '▝';
const _quadrantBottomLeft = '▖';
const _quadrantBottomRight = '▗';
const _quadrantTopHalf = '▀';
const _quadrantBottomHalf = '▄';
const _quadrantLeftHalf = '▌';
const _quadrantRightHalf = '▐';
const _quadrantTopLeftBottomLeftBottomRight = '▙';
const _quadrantTopLeftTopRightBottomLeft = '▛';
const _quadrantTopLeftTopRightBottomRight = '▜';
const _quadrantTopRightBottomLeftBottomRight = '▟';

/// Utility functions for [BorderType].
extension BorderTypeUtils on BorderType {
  /// Returns the symbols to use for the given [BorderType].
  BorderSet symbols(BorderType type) => switch (type) {
        BorderType.none => (
            top: ' ',
            bottom: ' ',
            left: ' ',
            right: ' ',
            topLeft: ' ',
            topRight: ' ',
            bottomLeft: ' ',
            bottomRight: ' ',
          ),
        BorderType.plain => (
            top: '─',
            bottom: '─',
            left: '│',
            right: '│',
            topLeft: '┌',
            topRight: '┐',
            bottomLeft: '└',
            bottomRight: '┘',
          ),
        BorderType.rounded => (
            top: '─',
            bottom: '─',
            left: '│',
            right: '│',
            topLeft: '╭',
            topRight: '╮',
            bottomLeft: '╰',
            bottomRight: '╯',
          ),
        BorderType.double => (
            top: '═',
            bottom: '═',
            left: '║',
            right: '║',
            topLeft: '╔',
            topRight: '╗',
            bottomLeft: '╚',
            bottomRight: '╝',
          ),
        BorderType.thick => (
            top: '━',
            bottom: '━',
            left: '┃',
            right: '┃',
            topLeft: '┏',
            topRight: '┓',
            bottomLeft: '┗',
            bottomRight: '┛',
          ),
        BorderType.quadrantInside => (
            topRight: _quadrantBottomLeft,
            topLeft: _quadrantBottomRight,
            bottomRight: _quadrantTopLeft,
            bottomLeft: _quadrantTopRight,
            left: _quadrantRightHalf,
            right: _quadrantLeftHalf,
            top: _quadrantBottomHalf,
            bottom: _quadrantTopHalf,
          ),
        BorderType.quadrantOutside => (
            topLeft: _quadrantTopLeftTopRightBottomLeft,
            topRight: _quadrantTopLeftTopRightBottomRight,
            bottomLeft: _quadrantTopLeftBottomLeftBottomRight,
            bottomRight: _quadrantTopRightBottomLeftBottomRight,
            left: _quadrantLeftHalf,
            right: _quadrantRightHalf,
            top: _quadrantTopHalf,
            bottom: _quadrantBottomHalf,
          ),
        _ => throw ArgumentError('Invalid border type: $type'),
      };
}
