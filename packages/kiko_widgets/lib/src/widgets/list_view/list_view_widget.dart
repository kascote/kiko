import 'package:kiko/kiko.dart';

import 'list_view_model.dart';
import 'types.dart';

/// A scrollable list widget with keyboard navigation and selection.
///
/// Renders items from a [ListViewModel] using [itemBuilder].
/// Supports separators, empty placeholders, and multi-line items.
///
/// ```dart
/// // Simple - ignore state
/// ListView(
///   model: listModel,
///   itemBuilder: (item, index, _) => Line(item),
/// )
///
/// // With state - destructure what you need
/// ListView(
///   model: listModel,
///   itemBuilder: (item, index, (:focused, :checked, :disabled)) =>
///       Line('${focused ? '>' : ' '} $item'),
/// )
/// ```
class ListView<T, K> extends Widget {
  /// The model containing list state.
  final ListViewModel<T, K> model;

  /// Builds widget for each item.
  ///
  /// Parameters:
  /// - `item`: The data item
  /// - `index`: Item index in data source
  /// - `state`: Item state (checked, focused, disabled) - use `_` to ignore
  final Widget Function(T item, int index, ItemState state) itemBuilder;

  /// Optional separator between items (1 line height).
  ///
  /// When defined, effective row height = itemHeight + 1.
  final Line Function()? separatorBuilder;

  /// Shown when dataSource is empty.
  final Widget? emptyPlaceholder;

  /// Creates a ListView widget.
  ListView({
    required this.model,
    required this.itemBuilder,
    this.separatorBuilder,
    this.emptyPlaceholder,
  });

  @override
  void render(Rect area, Frame frame) {
    if (area.isEmpty) return;

    final renderArea = area.intersection(frame.buffer.area);
    if (renderArea.isEmpty) return;

    final m = model;
    final dataSource = m.dataSource;
    final itemCount = dataSource.length ?? 0;

    // 1. If empty, render placeholder and return
    if (itemCount == 0) {
      if (emptyPlaceholder != null) {
        emptyPlaceholder!.render(renderArea, frame);
      }
      return;
    }

    // 2. Calculate effective row height
    final hasSeparator = separatorBuilder != null;
    final effectiveRowHeight = m.itemHeight + (hasSeparator ? 1 : 0);

    // 3. Calculate visible count
    // Last item doesn't need separator, so we can fit one more if space allows
    final visibleCount = hasSeparator
        ? (renderArea.height + 1) ~/ effectiveRowHeight
        : renderArea.height ~/ effectiveRowHeight;
    if (visibleCount <= 0) return;

    // 4. Update model's visible count
    m.setVisibleCount(visibleCount);

    // 5. Get scroll offset (model adjusts internally when cursor moves)
    final scrollOffset = m.scrollOffset;

    // 6. Calculate visible range
    final startIndex = scrollOffset;
    final endIndex = (startIndex + visibleCount).clamp(0, itemCount);

    // 7. Render visible items
    var y = renderArea.y;

    for (var i = startIndex; i < endIndex; i++) {
      final item = dataSource.itemAt(i);
      final isFocused = i == m.cursor;
      final isChecked = m.isChecked(i);
      final isDisabled = m.isDisabled?.call(i) ?? false;

      // Item area (clipped to renderArea to prevent overflow)
      final itemArea = Rect.create(
        x: renderArea.x,
        y: y,
        width: renderArea.width,
        height: m.itemHeight,
      ).intersection(renderArea);
      if (itemArea.isEmpty) break;

      // Render item via builder
      final state = (
        checked: isChecked,
        focused: isFocused,
        disabled: isDisabled,
      );
      itemBuilder(item, i, state).render(itemArea, frame);

      y += m.itemHeight;

      // Render separator (except after last visible item)
      if (hasSeparator && i < endIndex - 1) {
        final separatorArea = Rect.create(
          x: renderArea.x,
          y: y,
          width: renderArea.width,
          height: 1,
        );
        separatorBuilder!().render(separatorArea, frame);
        y += 1;
      }
    }
  }
}
