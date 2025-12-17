import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:kiko_widgets/src/widgets/text_area/selection.dart';
import 'package:test/test.dart';

void main() {
  group('SelectedBlock', () {
    late SelectedBlock selection;

    setUp(() {
      selection = SelectedBlock();
    });

    test('Initial state is empty', () {
      expect(selection.isEmpty, isTrue);
      expect(selection.isNotEmpty, isFalse);
      expect(selection.getNormalizedSelection(), isNull);
    });

    test('Initialization sets correct values', () {
      selection.initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty());
      expect(selection.isEmpty, isFalse);
      expect(selection.isNotEmpty, isTrue);
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 10, endRow: 5, endCol: 10)));
    });

    test('Clear selection resets to empty state', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..clearSelection();
      expect(selection.isEmpty, isTrue);
      expect(selection.isNotEmpty, isFalse);
      expect(selection.getNormalizedSelection(), isNull);
    });

    test('Move right expands selection', () {
      selection
        ..initializeSelection(5, 10, (row: 5, offset: 0), LineInfo.empty())
        ..moveRight((row: 5, offset: 0), LineInfo.empty());
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 10, endRow: 5, endCol: 11)));
    });

    test('Move left shrinks and flips selection', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..moveRight((row: 0, offset: 0), LineInfo.empty())
        ..moveLeft((row: 0, offset: 0), LineInfo.empty(), 2);
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 9, endRow: 5, endCol: 10)));
    });

    test('Move down', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..moveDown(7, 15, (row: 0, offset: 0), LineInfo.empty());
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 10, endRow: 7, endCol: 15)));
    });

    test('Move up', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..moveDown(7, 15, (row: 0, offset: 0), LineInfo.empty())
        ..moveUp(4, 8, (row: 0, offset: 0), LineInfo.empty());
      expect(selection.getNormalizedSelection(), equals((startRow: 4, startCol: 8, endRow: 5, endCol: 10)));
    });

    test('Move in soft wrap scenario', () {
      selection
        ..initializeSelection(5, 80, (row: 0, offset: 0), LineInfo.empty())
        // Move to visual next line, same buffer line
        ..moveDown(5, 10, (row: 0, offset: 0), LineInfo.empty());
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 10, endRow: 5, endCol: 80)));
    });

    test('Move left stops at column 0', () {
      selection
        ..initializeSelection(5, 2, (row: 0, offset: 0), LineInfo.empty())
        ..moveLeft((row: 0, offset: 0), LineInfo.empty(), 5);
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 0, endRow: 5, endCol: 2)));
    });

    test('Normalized selection with anchor after head', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..moveUp(3, 5, (row: 0, offset: 0), LineInfo.empty());
      expect(selection.getNormalizedSelection(), equals((startRow: 3, startCol: 5, endRow: 5, endCol: 10)));
    });

    test('Normalized selection with anchor and head on same row', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..moveLeft((row: 0, offset: 0), LineInfo.empty(), 5);
      expect(selection.getNormalizedSelection(), equals((startRow: 5, startCol: 5, endRow: 5, endCol: 10)));
    });

    test('toString provides correct representation', () {
      selection
        ..initializeSelection(5, 10, (row: 0, offset: 0), LineInfo.empty())
        ..moveRight((row: 0, offset: 0), LineInfo.empty())
        ..moveDown(6, 13, (row: 0, offset: 0), LineInfo.empty());
      expect(selection.toString(), equals('SelectedBlock(anchor: (5, 10), head: (6, 13))'));
    });
  });
}
