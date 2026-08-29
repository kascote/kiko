import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

/// A stand-in activate event, the shape each widget's own action event
/// takes ([ListActivateEvent] and its siblings).
class _Activate extends WidgetEvent {
  const _Activate();

  @override
  String get id => 'x';
}

/// A minimal model mixing in [ScrollableModel] so [ScrollableModel.handleRowPointer]
/// can be exercised on its own, with recorders for the seams the helper drives.
class _BareScrollable with ScrollableModel {
  @override
  int scrollOffset = 0;

  @override
  int visibleCount = 3;

  @override
  int scrollBy(int rows) => 0;

  int? hover;
  int? cursorMovedTo;
}

PointerMsg _pointer(PointerAction action) =>
    PointerMsg(global: Position.origin, action: action, local: Position.origin, targetId: 'x');

void main() {
  group('RowRegion', () {
    test('is a Region and a RowScoped carrying its index', () {
      const region = RowRegion(3);

      expect(region, isA<Region>());
      expect(region, isA<RowScoped>());
      expect(region.index, 3);
    });

    test('has structural equality over its index', () {
      expect(const RowRegion(2), const RowRegion(2));
      expect(const RowRegion(2).hashCode, const RowRegion(2).hashCode);
      expect(const RowRegion(2), isNot(const RowRegion(3)));
    });

    test('reads as RowRegion(index)', () {
      expect(const RowRegion(4).toString(), 'RowRegion(4)');
    });
  });

  group('ScrollableModel.handleRowPointer', () {
    late _BareScrollable model;

    setUp(() => model = _BareScrollable());

    UpdateResult run(PointerAction action, int row) => model.handleRowPointer(
      _pointer(action),
      row,
      setHover: (r) => model.hover = r,
      moveCursorTo: (r) => model.cursorMovedTo = r,
      activate: () => const _Activate(),
    );

    test('a press hovers the row, moves the cursor to it, and activates', () {
      final result = run(PointerAction.down, 2);

      expect(model.hover, 2);
      expect(model.cursorMovedTo, 2);
      expect(result, isA<Handled>());
      expect((result as Handled).events, [isA<_Activate>()], reason: 'a click activates like Enter');
    });

    test('a move only refreshes the hover', () {
      final result = run(PointerAction.move, 1);

      expect(model.hover, 1);
      expect(model.cursorMovedTo, isNull, reason: 'a move never moves the cursor');
      expect(result, isA<Handled>());
      expect((result as Handled).events, isEmpty, reason: 'and carries no activate event');
    });

    test('a drag only refreshes the hover', () {
      final result = run(PointerAction.drag, 4);

      expect(model.hover, 4);
      expect(model.cursorMovedTo, isNull);
      expect((result as Handled).events, isEmpty);
    });

    test('the release half of a click only refreshes the hover', () {
      final result = run(PointerAction.up, 0);

      expect(model.hover, 0);
      expect(model.cursorMovedTo, isNull, reason: 'only the press half moves the cursor and activates');
      expect((result as Handled).events, isEmpty);
    });
  });
}
