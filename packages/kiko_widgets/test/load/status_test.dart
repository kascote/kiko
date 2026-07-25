// The slice status is shared load machinery, not table machinery: this suite
// imports it directly and constructs no widget.
import 'package:kiko_widgets/src/load/load.dart';
import 'package:test/test.dart';

void main() {
  group('statusFor', () {
    /// A tracker over page keys, with [loading] begun and [failed] recorded.
    LoadTracker<TablePageKey> tracker({List<int> loading = const [], List<int> failed = const []}) {
      final loads = LoadTracker<TablePageKey>();
      for (final page in loading) {
        loads.begin(TablePageKey(page));
      }
      for (final page in failed) {
        loads.fail(TablePageKey(page), 'boom');
      }
      return loads;
    }

    /// The status of pages [pages], where [held] are the ones present.
    SliceStatus status(
      List<int> pages, {
      List<int> held = const [],
      List<int> loading = const [],
      List<int> failed = const [],
    }) => statusFor(
      pages.map(TablePageKey.new),
      tracker(loading: loading, failed: failed),
      (key) => held.contains(key.page),
    );

    test('everything present is ready, whatever else is in flight', () {
      expect(status([1, 2], held: [1, 2]), SliceStatus.ready);
      expect(status([1, 2], held: [1, 2], loading: [7]), SliceStatus.ready);
      expect(status([1, 2], held: [1, 2], failed: [7]), SliceStatus.ready);
    });

    test('no keys at all is ready', () {
      expect(status(const []), SliceStatus.ready);
    });

    test('missing with a fetch in flight is filling', () {
      expect(status([1, 2], held: [1], loading: [2]), SliceStatus.filling);
    });

    test('missing with nothing coming is stalled', () {
      expect(status([1, 2], held: [1]), SliceStatus.stalled);
      expect(status([1, 2]), SliceStatus.stalled);
      // A fetch for some *other* page does not make this slice fill.
      expect(status([1, 2], held: [1], loading: [9]), SliceStatus.stalled);
    });

    test('a failure outranks a fetch in flight', () {
      // Reporting "filling" here would promise page 2 is coming; it is not.
      expect(status([1, 2], loading: [1], failed: [2]), SliceStatus.failed);
      expect(status([1, 2], failed: [1], loading: [2]), SliceStatus.failed);
    });

    test('a failure for a page that is present does not count', () {
      // The rows are here; whatever failed earlier no longer decides the paint.
      expect(status([1], held: [1], failed: [1]), SliceStatus.ready);
    });

    test('the status is key-shaped, so any key type works', () {
      final loads = LoadTracker<TreeLoadKey>()..begin(const PathKey('/b'));
      expect(
        statusFor<TreeLoadKey>(
          const [PathKey('/a'), PathKey('/b')],
          loads,
          (key) => key == const PathKey('/a'),
        ),
        SliceStatus.filling,
      );
    });
  });
}
