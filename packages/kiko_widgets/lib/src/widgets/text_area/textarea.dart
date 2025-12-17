import 'dart:convert';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';
import 'package:termunicode/termunicode.dart';

import 'line_cache.dart';
import 'sanitizer.dart';
import 'selection.dart';

final Characters _lf = '\n'.characters;
final Characters _spc = ''.characters;

/// LineInfo holds information about a line in the buffer.
class LineInfo {
  /// Width is the number of columns in the line.
  final int width;

  /// CharWidth is the number of characters in the line to account for
  /// double-width runes.
  final int visualWidth;

  /// Height is the number of rows in the line.
  final int height;

  /// StartColumn is the index of the first column of the line.
  final int startColumn;

  /// ColumnOffset is the number of columns that the cursor is offset from the
  /// start of the line.
  final int columnOffset;

  /// RowOffset is the number of rows that the cursor is offset from the start
  /// of the line.
  final int rowOffset;

  /// visualOffset is the number of characters that the cursor is offset
  /// from the start of the line. This will generally be equivalent to
  /// ColumnOffset, but will be different there are double-width runes before
  /// the cursor.
  final int visualOffset;

  /// Creates a new LineInfo object
  LineInfo({
    required this.width,
    required this.visualWidth,
    required this.height,
    required this.startColumn,
    required this.columnOffset,
    required this.rowOffset,
    required this.visualOffset,
  });

  /// Returns an empty object
  factory LineInfo.empty() {
    return LineInfo(
      width: 0,
      visualWidth: 0,
      height: 0,
      startColumn: 0,
      columnOffset: 0,
      rowOffset: 0,
      visualOffset: 0,
    );
  }

  @override
  String toString() {
    return 'LineInfo{width: $width, visualWidth: $visualWidth, height: $height, startColumn: $startColumn, columnOffset: $columnOffset, rowOffset: $rowOffset, visualOffset: $visualOffset}';
  }
}

/// The type of the buffer
typedef RowLine = Characters;

/// The type of the wrapped line
typedef WrappedLine = List<RowLine>;

/// The type of the line item used for cache
typedef LineItem = ({RowLine line, int width});

/// Holds the buffer of characters
class TextArea {
  /// The buffer of characters
  final List<RowLine> _buffer = [_spc];

  /// The cache of wrapped lines
  late final LineCache<WrapLine, WrappedLine> _lineCache;

  /// The selected block
  final selectedBlock = SelectedBlock();

  /// The maximum number of characters that the buffer can hold.
  /// If this value is 0, then the buffer can hold an infinite number of characters.
  final int maxCharacters;

  /// The maximum number of lines that the buffer can hold.
  /// If this value is 0, then the buffer can hold an infinite number of lines.
  final int maxLines;

  /// The maximum number of columns that the buffer can hold.
  /// If this value is 0, then the buffer can hold an infinite number of columns.
  final int maxColumns;

  /// The visual width of the buffer.
  ///
  /// The visual width is the width of the line when displayed on the screen.
  /// This width could be less that the line width and is used to determine
  /// the soft-wrapped lines. Updated dynamically by the widget during render.
  int visualWidth;

  int _lastVisualOffset = 0;

  /// Creates a new Buffer object
  TextArea({
    this.maxCharacters = 1000,
    this.maxLines = 10,
    this.maxColumns = 80,
    this.visualWidth = 80,
  }) {
    _lineCache = LineCache(maxLines);
  }

  /// The current column of the cursor
  var _column = 0;

  /// The current row of the cursor
  var _row = 0;

  /// Returns the current row of the cursor
  int get row => _row;

  /// Returns the current column of the cursor
  int get column => _column;

  /// Sets the cursor column position
  set column(int value) {
    _column = value.clamp(0, _buffer[_row].length);
    // Any time that we move the cursor horizontally we need to reset the last
    // offset so that the horizontal position when navigating is adjusted.
    _lastVisualOffset = 0;
  }

  /// Sets the cursor row position
  set row(int value) => _row = value.clamp(0, _buffer.length - 1);

  /// Moves the cursor to the start of the line
  void setCursorStart() => column = 0;

  /// Moves the cursor to the end of the line
  void setCursorEnd() => column = _buffer[_row].length;

  /// Return the length of the buffer
  int length() => _buffer.fold(0, (prev, element) => prev + element.length);

  /// Returns the number of lines in the buffer
  int get lineCount => _buffer.length;

  /// Reset buffer state
  void reset() {
    _buffer
      ..clear()
      ..add(_spc);
    _row = 0;
    _column = 0;
    column = 0;
  }

  /// Initialize the buffer with a string. Any previous state is reset.
  void initBuffer(String value) => initBufferChars(value.characters);

  /// Initialize the buffer with a Characters object. Any previous state is reset.
  void initBufferChars(Characters value) {
    reset();
    insertChars(value);
  }

  /// Insert a string to the buffer at the cursor position
  void insert(String value) => insertChars(value.characters);

  /// Insert a character to the buffer at the cursor position
  void insertChars(Characters value) {
    if (selectedBlock.isNotEmpty) deleteSelectedBlock();
    var toInsert = sanitizer(value);

    if (maxCharacters > 0) {
      final currentLength = length();
      final availableSpace = maxCharacters - currentLength;
      if (availableSpace <= 0) return;
      if (availableSpace < value.length) {
        toInsert = value.getRange(0, availableSpace);
      }
    }

    final lines = toInsert.split(_lf).toList();

    if (maxLines > 0) {
      final availableLines = maxLines - _buffer.length + 1;
      if (availableLines < lines.length) {
        lines.length = availableLines;
      }
    }

    if (lines.isEmpty) return;

    final currentLine = _buffer[_row];
    final newFirstLine = currentLine.getRange(0, _column) + lines[0];
    final tail = currentLine.getRange(_column);
    _column += lines[0].length;

    if (lines.length == 1) {
      _buffer[_row] = newFirstLine + tail;
    } else {
      _buffer[_row] = newFirstLine;
      _buffer.insertAll(_row + 1, lines.sublist(1));
      _row += lines.length - 1;
      _column = lines.last.length;
      _buffer[_row] = _buffer[_row] + tail;
    }

    column = _column;
  }

  /// Delete the selected block for the buffer
  void deleteSelectedBlock() {
    final n = selectedBlock.getNormalizedSelection();
    if (n == null) return;
    final toRemove = <int>[];

    if (n.startRow == n.endRow) {
      final line = _buffer[n.startRow];
      _buffer[n.startRow] = line.getRange(0, n.startCol) + line.getRange(n.endCol);
    } else {
      for (var row = n.startRow; row <= n.endRow; row++) {
        if (row == n.startRow) {
          _buffer[row] = _buffer[row].getRange(0, n.startCol);
        } else if (row == n.endRow) {
          _buffer[row] = _buffer[row].getRange(n.endCol);
        } else {
          toRemove.add(row);
        }
      }
    }
    toRemove
      ..sort((a, b) => b - a)
      ..forEach(_buffer.removeAt);

    _row = n.startRow;
    column = n.startCol;
    selectedBlock.clearSelection();
  }

  /// Return the content of the buffer
  Characters get content {
    final sb = StringBuffer();
    _buffer.forEach(sb.writeln);
    var contentString = sb.toString();
    // Check if the last character is a newline and remove it if _buffer is not empty
    if (_buffer.isNotEmpty && contentString.endsWith('\n')) {
      contentString = contentString.substring(0, contentString.length - 1);
    }
    return Characters(contentString);
  }

  /// Returns an iterable that returns each line in the buffer wrapped at the
  /// visual width. The list returned represent each wrapped line.
  Iterable<List<Characters>> wrappedLines(int start, [int? end]) sync* {
    final startLine = start.clamp(0, _buffer.length);
    final endLine = math.max(end ?? _buffer.length, _buffer.length);

    for (var i = startLine; i < endLine; i++) {
      yield lineCache(_buffer[i], visualWidth);
    }
  }

  /// Moves the cursor to the init of the buffer.
  void setCursorStartBuffer() {
    _row = 0;
    column = 0;
  }

  /// Moves the cursor to the end of the buffer.
  void setCursorEndBuffer() {
    _row = _buffer.length - 1;
    column = _buffer[_row].length;
  }

  /// Returns the line number the cursor is on.
  /// This takes into account soft wrapped lines
  int cursorLineNumber() {
    var line = 0;
    for (var i = 0; i < _row; i++) {
      line += lineCache(_buffer[_row], visualWidth).length;
    }
    return line += lineInfo().rowOffset;
  }

  /// Moved the cursor one line down my default or the value specified.
  /// If the cursor is at the last line, or the value exceeds the line height
  /// it will stay at the last row.
  void moveCursorDown({bool isSelecting = false}) {
    final li = lineInfo();
    final vOffset = math.max(_lastVisualOffset, li.visualOffset);
    _lastVisualOffset = vOffset;

    if (isSelecting) {
      if (selectedBlock.isEmpty) {
        selectedBlock.initializeSelection(_row, _column, (row: _row, offset: li.rowOffset), li);
      }
    } else {
      selectedBlock.clearSelection();
    }

    if (li.rowOffset + 1 >= li.height && _row < _buffer.length - 1) {
      _row++;
      _column = 0;
    } else {
      _column = math.min(li.startColumn + li.width + 2, _buffer[_row].length - 1);
    }

    final nli = lineInfo();
    _column = nli.startColumn;
    if (nli.width <= 0) {
      if (isSelecting) selectedBlock.moveDown(_row, _column, (row: _row, offset: nli.rowOffset), nli);
      return;
    }

    var offset = 0;
    while (offset < vOffset) {
      if (_row > _buffer.length || _column >= _buffer[_row].length || offset >= nli.visualWidth - 1) {
        break;
      }
      offset += widthString(_buffer[_row].characterAt(_column).toString());
      _column++;
    }

    if (isSelecting) selectedBlock.moveDown(_row, _column, (row: _row, offset: nli.rowOffset), nli);
    return;
  }

  /// Moved the cursor one line up my default or the value specified.
  /// If the cursor is at the first line, or the value exceeds the first line
  /// it will stay at the first row.
  void moveCursorUp({bool isSelecting = false}) {
    final li = lineInfo();
    final vOffset = math.max(_lastVisualOffset, li.visualOffset);
    _lastVisualOffset = vOffset;

    if (isSelecting) {
      if (selectedBlock.isEmpty) {
        selectedBlock.initializeSelection(_row, _column, (row: _row, offset: li.rowOffset), li);
      }
    } else {
      selectedBlock.clearSelection();
    }

    if (li.rowOffset <= 0 && _row > 0) {
      _row--;
      _column = _buffer[_row].length;
    } else {
      // Move the cursor to the end of the previous line.
      // This can be done by moving the cursor to the start of the line and
      // then subtracting 2 to account for the trailing space we keep on
      // soft-wrapped lines.
      _column = li.startColumn - 2;
    }

    final nli = lineInfo();
    _column = nli.startColumn;

    if (nli.width <= 0) {
      if (isSelecting) selectedBlock.moveUp(_row, _column, (row: _row, offset: nli.rowOffset), nli);
      return;
    }

    var offset = 0;
    while (offset < vOffset) {
      if (_column >= _buffer[_row].length || offset >= nli.visualWidth - 1) {
        break;
      }
      offset += widthString(_buffer[_row].characterAt(_column).toString());
      _column++;
    }

    if (isSelecting) selectedBlock.moveUp(_row, _column, (row: _row, offset: nli.rowOffset), nli);
  }

  /// Moves the cursor one column to the right by default or the value specified.
  /// If the cursor is at the last column, or the value exceeds the column width
  /// it will stay at the last column.
  void moveCursorRight({bool isSelecting = false}) {
    final li = lineInfo();
    if (isSelecting) {
      if (selectedBlock.isEmpty) {
        selectedBlock.initializeSelection(_row, _column, (row: _row, offset: li.rowOffset), li);
      }
    } else {
      selectedBlock.clearSelection();
    }

    if (_column < _buffer[_row].length) {
      column = _column + 1;
      if (isSelecting) {
        selectedBlock.moveRight((row: _row, offset: li.rowOffset), li);
      }
    } else {
      if (_row < _buffer.length - 1) {
        _row++;
        setCursorStart();
        if (isSelecting) {
          final nli = lineInfo();
          selectedBlock.moveDown(_row, _column, (row: _row, offset: nli.rowOffset), nli);
        }
      }
    }
  }

  /// Moves the cursor one column to the left by default or the value specified.
  /// If the cursor is at the first column, or the value exceeds the first column
  /// it will stay at the first column.
  void moveCursorLeft({bool isSelecting = false}) {
    final li = lineInfo();
    if (isSelecting) {
      if (selectedBlock.isEmpty) {
        selectedBlock.initializeSelection(_row, _column, (row: _row, offset: li.rowOffset), li);
      }
    } else {
      selectedBlock.clearSelection();
    }

    if (_column == 0 && _row != 0) {
      _row--;
      setCursorEnd();
      final nli = lineInfo();
      selectedBlock.moveUp(_row, _column, (row: _row, offset: nli.rowOffset), nli);
    } else {
      if (_column > 0) {
        column = _column - 1;
        if (isSelecting) selectedBlock.moveLeft((row: _row, offset: li.rowOffset), li);
      }
    }
  }

  /// Deletes all the characters before the cursor.
  void deleteBeforeCursor() {
    selectedBlock.clearSelection();
    _buffer[_row] = _buffer[_row].getRange(_column);
    column = 0;
  }

  /// Deletes all the characters after the cursor.
  void deleteAfterCursor() {
    selectedBlock.clearSelection();
    _buffer[_row] = _buffer[_row].getRange(0, _column);
    column = _buffer[_row].length;
  }

  /// Deletes the character before the cursor.
  void deleteCharBackward() {
    if (selectedBlock.isNotEmpty) deleteSelectedBlock();
    _column = _column.clamp(0, _buffer[_row].length);
    if (_column <= 0) {
      mergeLineAbove(_row);
    } else if (_buffer[_row].isNotEmpty) {
      _buffer[_row] = _buffer[_row].getRange(0, math.max(0, _column - 1)) + _buffer[_row].getRange(_column);
      if (_column > 0) column = _column - 1;
    }
  }

  /// Deletes the character after the cursor.
  void deleteCharForward() {
    if (selectedBlock.isNotEmpty) deleteSelectedBlock();
    if (_column == _buffer[_row].length) {
      if (_row == _buffer.length - 1) return;
      mergeLineBelow(_row);
    } else {
      _buffer[_row] = _buffer[_row].getRange(0, _column) + _buffer[_row].getRange(_column + 1);
    }
  }

  /// Delete the word to the left of the cursor.
  void deleteWordLeft() {
    selectedBlock.clearSelection();
    if (_column == 0 || _buffer[_row].isEmpty) return;

    final oldColumn = _column;
    column = _column - 1;

    while (_positionIsSpace()) {
      if (_column <= 0) break;
      column = _column - 1;
    }

    while (_column > 0) {
      if (_positionIsNotSpace()) {
        column = _column - 1;
      } else {
        if (_column > 0) column = _column + 1;
        break;
      }
    }

    if (oldColumn > _buffer[_row].length) {
      _buffer[_row] = _buffer[_row].getRange(0, _column);
    } else {
      _buffer[_row] = _buffer[_row].getRange(0, _column) + _buffer[_row].getRange(oldColumn);
    }
  }

  /// Delete the word the right of the cursor
  void deleteWordRight() {
    selectedBlock.clearSelection();
    if (_column >= _buffer[_row].length || _buffer[_row].isEmpty) {
      return;
    }

    final oldColumn = _column;

    while (_column < _buffer[_row].length && _positionIsSpace()) {
      column = _column + 1;
    }

    while (_column < _buffer[_row].length) {
      if (_positionIsNotSpace()) {
        column = _column + 1;
      } else {
        break;
      }
    }

    if (_column > _buffer[_row].length) {
      _buffer[_row] = _buffer[_row].getRange(0, oldColumn);
    } else {
      _buffer[_row] = _buffer[_row].getRange(0, oldColumn) + _buffer[_row].getRange(_column);
    }

    column = oldColumn;
  }

  /// Merges the current line the cursor is on with the line below.
  void mergeLineBelow(int rowLine) {
    selectedBlock.clearSelection();
    if (rowLine > _buffer.length - 1) return;
    _buffer[rowLine] = _buffer[rowLine] + _buffer[rowLine + 1];

    // shift all lines by one
    for (var i = rowLine + 1; i < _buffer.length - 1; i++) {
      _buffer[i] = _buffer[i + 1];
    }

    if (_buffer.isNotEmpty) _buffer.removeLast();
  }

  /// Merges the current line the cursor is on with the line above.
  void mergeLineAbove(int rowLine) {
    selectedBlock.clearSelection();
    if (rowLine <= 0) return;
    _column = _buffer[rowLine - 1].length;
    _row = rowLine - 1;
    _buffer[rowLine - 1] = _buffer[rowLine - 1] + _buffer[rowLine];

    // shift all lines by one
    for (var i = rowLine; i < _buffer.length - 1; i++) {
      _buffer[i] = _buffer[i + 1];
    }

    if (_buffer.isNotEmpty) _buffer.removeLast();
  }

  /// Split the line at the given row and column.
  void splitLine(int rowLine, int columnLine) {
    selectedBlock.clearSelection();
    if (rowLine >= _buffer.length || columnLine >= _buffer[rowLine].length) {
      return;
    }

    final line = _buffer[rowLine];
    final tail = line.getRange(columnLine);
    _buffer[rowLine] = line.getRange(0, columnLine);
    _buffer.insert(rowLine + 1, tail);

    _row = rowLine + 1;
    _column = 0;
  }

  /// Returns information about the requested line. If [rowInfo] is not
  /// provided, it will return the current line.
  LineInfo lineInfo({int? rowInfo}) {
    if (rowInfo != null) rowInfo = rowInfo.clamp(0, _buffer.length - 1);
    final vLine = lineCache(_buffer[rowInfo ?? _row], visualWidth);
    var counter = 0;

    for (var i = 0; i < vLine.length; i++) {
      if (counter + vLine[i].length == _column && i + 1 < vLine.length) {
        return LineInfo(
          visualOffset: 0,
          columnOffset: 0,
          height: vLine.length,
          rowOffset: i + 1,
          startColumn: _column,
          width: vLine[i + 1].length,
          visualWidth: widthString(vLine[i].toString()),
        );
      }

      if (counter + vLine[i].length >= _column) {
        return LineInfo(
          visualOffset: widthString(
            vLine[i].take(math.max(0, _column - counter)).toString(),
          ),
          columnOffset: _column - counter,
          height: vLine.length,
          rowOffset: i,
          startColumn: counter,
          width: vLine[i].length,
          visualWidth: widthString(vLine[i].toString()),
        );
      }

      counter += vLine[i].length;
    }

    return LineInfo.empty();
  }

  /// Cache the wrapped line
  WrappedLine lineCache(RowLine line, int width) {
    final wl = WrapLine((line: line, width: width));
    return _lineCache.upsert(wl, () => _wrap(line, width));
  }

  /// Wrap the line to the specified width
  WrappedLine _wrap(RowLine line, int width) {
    var spaces = 0;
    final wrappedLines = <StringBuffer>[StringBuffer()];
    final word = StringBuffer();

    for (final chr in line) {
      if (_isSpace(chr)) {
        spaces++;
      } else {
        word.write(chr);
      }

      if (spaces > 0) {
        final wc = wrappedLines.last.isEmpty ? 0 : widthString(wrappedLines.last.toString());
        word.write(_genSpaces(spaces));
        if (wc + widthString(word.toString()) > width) wrappedLines.add(StringBuffer());
        wrappedLines.last.write(word);
        spaces = 0;
        word.clear();
      } else {
        final wordStr = word.toString();
        // If the last character is a double-width rune, then we may not be able
        // to add it to this line as it might cause us to go past the width.
        final lastCharLength = widthString(wordStr.characters.last);
        if (widthString(wordStr) + lastCharLength > width) {
          // If the current line has any content, let's move to the next
          // line because the current word fills up the entire line.
          if (wrappedLines.last.isNotEmpty) wrappedLines.add(StringBuffer());
          wrappedLines.last.write(word.toString());
          word.clear();
        }
      }
    }

    if (widthString(wrappedLines.last.toString()) + widthString(word.toString()) + spaces >= width) {
      wrappedLines.add(StringBuffer());
    }
    // We add an extra space at the end of the line to account for the
    // trailing space at the end of the previous soft-wrapped lines so that
    // behavior when navigating is consistent and so that we don't need to
    // continually add edges to handle the last line of the wrapped input.
    wrappedLines.last.write(word..write(_genSpaces(++spaces)));

    return wrappedLines.fold(
      <RowLine>[],
      (acc, ele) => acc..add(ele.toString().characters),
    );
  }

  bool _positionIsSpace() {
    return _buffer[_row].elementAt(_column) == ' ';
  }

  bool _positionIsNotSpace() => !_positionIsSpace();
}

/// Helper class to cache the wrapped lines
class WrapLine extends CacheItem {
  /// The line item to cache
  LineItem lineItem;

  /// Creates a new WrapLine object
  WrapLine(this.lineItem);

  @override
  String get digest {
    return sha256.convert(utf8.encode(lineItem.line.toString())).toString();
  }
}

String _genSpaces(int length) => ' ' * length;

bool _isSpace(String chr) => chr == ' ';
