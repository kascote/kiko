import 'dart:math' as math;

import 'package:characters/characters.dart';

import './extensions/int.dart';
import './textarea.dart';

/// Key type for LineInfo
typedef RowKey = ({int row, int offset});

/// Parts of a selection
typedef SelectionPart = ({Characters part, PartKind kind});

/// Selection parts
enum PartKind {
  /// Regular text
  text,

  /// Selected Block
  selection,
}

/// Represents a block selection in a text editor.
///
/// This class manages a rectangular selection area defined by an anchor point
/// (where the selection starts) and a head point (where the selection currently ends).
class SelectedBlock {
  int _anchorRow;
  int _anchorColumn;
  int _headRow;
  int _headColumn;
  final _rowInfo = <RowKey, LineInfo>{};

  /// Creates an empty selection.
  ///
  /// All coordinates are initialized to -1, indicating no selection.
  SelectedBlock() : _anchorRow = -1, _anchorColumn = -1, _headRow = -1, _headColumn = -1;

  /// Gets the row info
  LineInfo? getRowInfo(RowKey key) => _rowInfo[key];

  /// Initializes the selection at the specified position.
  ///
  /// Both the anchor and head of the selection are set to the given coordinates.
  ///
  /// [row]: The row index to start the selection.
  /// [column]: The column index to start the selection.
  void initializeSelection(int row, int column, RowKey key, LineInfo info) {
    _anchorRow = _headRow = row;
    _anchorColumn = _headColumn = column;
    _rowInfo[key] = info;
  }

  /// Clears the current selection.
  ///
  /// Resets all coordinates to -1, indicating no selection.
  void clearSelection() {
    _anchorRow = _anchorColumn = _headRow = _headColumn = -1;
    _rowInfo.clear();
  }

  /// Checks if the selection is empty.
  ///
  /// Returns true if there is no active selection (all coordinates are -1).
  bool get isEmpty => _anchorRow == -1 && _anchorColumn == -1 && _headRow == -1 && _headColumn == -1;

  /// Checks if the selection is not empty.
  ///
  /// Returns true if there is an active selection.
  bool get isNotEmpty => !isEmpty;

  /// Moves the head of the selection left by the specified number of columns.
  ///
  /// If the selection is empty, this method does nothing.
  ///
  /// [columns]: The number of columns to move left. Must be non-negative.
  /// Defaults to 1 if not specified.
  void moveLeft(RowKey key, LineInfo info, [int columns = 1]) {
    if (isEmpty) return;
    _headColumn = math.max(0, _headColumn - columns);
    _rowInfo[key] = info;
  }

  /// Moves the head of the selection right by the specified number of columns.
  ///
  /// If the selection is empty, this method does nothing.
  ///
  /// [columns]: The number of columns to move right. Must be non-negative.
  /// Defaults to 1 if not specified.
  void moveRight(RowKey key, LineInfo info, [int columns = 1]) {
    if (isEmpty) return;
    _headColumn += columns;
    _rowInfo[key] = info;
  }

  /// Moves the head of the selection up to the specified row and column.
  ///
  /// If the selection is empty, this method does nothing.
  /// The column position is adjusted based on the target position.
  ///
  /// [targetRow]: The target row to move to.
  /// [targetColumn]: The target column to move to.
  void moveUp(int targetRow, int targetColumn, RowKey key, LineInfo info) {
    if (isEmpty) return;
    _headRow = targetRow;
    _headColumn = targetColumn;
    _rowInfo[key] = info;
  }

  /// Moves the head of the selection down to the specified row and column.
  ///
  /// If the selection is empty, this method does nothing.
  /// The column position is adjusted based on the target position.
  ///
  /// [targetRow]: The target row to move to.
  /// [targetColumn]: The target column to move to.
  void moveDown(int targetRow, int targetColumn, RowKey key, LineInfo info) {
    if (isEmpty) return;
    _headRow = targetRow;
    _headColumn = targetColumn;
    _rowInfo[key] = info;
  }

  /// Returns a normalized representation of the selection area.
  ///
  /// The returned record always has the start coordinates (top-left)
  /// as startRow and startCol, and the end coordinates (bottom-right)
  /// as endRow and endCol, regardless of the actual positions of
  /// the anchor and head.
  ///
  /// Returns null if the selection is empty.
  ({int startRow, int startCol, int endRow, int endCol})? getNormalizedSelection() {
    if (isEmpty) return null;

    final isAnchorFirst = _anchorRow < _headRow || (_anchorRow == _headRow && _anchorColumn <= _headColumn);

    return isAnchorFirst
        ? (startRow: _anchorRow, startCol: _anchorColumn, endRow: _headRow, endCol: _headColumn)
        : (startRow: _headRow, startCol: _headColumn, endRow: _anchorRow, endCol: _anchorColumn);
  }

  /// Returns the lineParts of the selection
  List<SelectionPart>? getLineParts(int row, int offset, Characters line) {
    final n = getNormalizedSelection();
    final rowInfo = getRowInfo((row: row, offset: offset));

    if (n == null || rowInfo == null) return null;
    if (row < n.startRow || row > n.endRow) return null;

    final parts = <SelectionPart>[];
    final lhs = math.max(rowInfo.startColumn, n.startCol).saturatingSubI32(rowInfo.startColumn);
    final rhs = math.min(rowInfo.startColumn + rowInfo.width, n.endCol).saturatingSubI32(rowInfo.startColumn);

    if (row == n.startRow && row == n.endRow) {
      if (rowInfo.rowOffset < offset || rowInfo.rowOffset > offset) {
        parts.add((part: line, kind: PartKind.text));
      } else {
        if (lhs == rowInfo.startColumn) {
          if (rhs >= rowInfo.startColumn + rowInfo.width) {
            parts.add((part: line, kind: PartKind.selection));
          } else {
            parts
              ..add((part: line.getRange(0, rhs), kind: PartKind.selection))
              ..add((part: line.getRange(rhs), kind: PartKind.text));
          }
        } else {
          parts.add((part: line.getRange(0, lhs), kind: PartKind.text));
          if (rhs >= rowInfo.startColumn + rowInfo.width) {
            parts.add((part: line.getRange(lhs), kind: PartKind.selection));
          } else {
            parts
              ..add((part: line.getRange(lhs, rhs), kind: PartKind.selection))
              ..add((part: line.getRange(rhs), kind: PartKind.text));
          }
        }
      }
    } else if (row == n.startRow) {
      parts
        ..add((part: line.getRange(0, lhs), kind: PartKind.text))
        ..add((part: line.getRange(lhs), kind: PartKind.selection));
    } else if (row == n.endRow) {
      parts
        ..add((part: line.getRange(0, rhs), kind: PartKind.selection))
        ..add((part: line.getRange(rhs), kind: PartKind.text));
    } else if (row < n.endRow && rowInfo.rowOffset == offset) {
      parts.add((part: line, kind: PartKind.selection));
    }

    return parts;
  }

  /// Returns a string representation of the selection.
  ///
  /// Useful for debugging purposes.
  @override
  String toString() {
    return 'SelectedBlock(anchor: ($_anchorRow, $_anchorColumn), head: ($_headRow, $_headColumn))';
  }
}
