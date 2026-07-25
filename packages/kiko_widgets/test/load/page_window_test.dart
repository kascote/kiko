// The page window is shared load machinery, not table machinery: this suite
// imports it directly and constructs no widget.
import 'package:kiko_widgets/src/load/page_window.dart';
import 'package:test/test.dart';

/// Rows of a full page starting at [page] * [size], as `'r<index>'` strings.
List<String> pageRows(int page, int size, {int? count}) => [
  for (var i = 0; i < (count ?? size); i++) 'r${page * size + i}',
];

void main() {
  group('PageSpan', () {
    test('covers first..last inclusive, anchored at first by default', () {
      const span = PageSpan(2, 4);
      expect(span.length, 3);
      expect(span.pages, [2, 3, 4]);
      expect(span.anchor, 2);
      expect(span.contains(1), isFalse);
      expect(span.contains(4), isTrue);
      expect(span.contains(5), isFalse);
    });

    test('value equality and toString', () {
      expect(const PageSpan(1, 3, anchor: 2), equals(const PageSpan(1, 3, anchor: 2)));
      expect(const PageSpan(1, 3, anchor: 2), isNot(equals(const PageSpan(1, 3))));
      expect(const PageSpan(1, 3, anchor: 2).toString(), 'PageSpan(1..3, anchor: 2)');
    });
  });

  group('PageWindow reading', () {
    test('an empty window holds nothing and knows no end', () {
      final w = PageWindow<String>(pageSize: 10);
      expect(w.present, isEmpty);
      expect(w.pageCount, 0);
      expect(w.rowCount, 0);
      expect(w.has(0), isFalse);
      expect(w.rowAt(0), isNull);
      expect(w.lastPage, isNull);
      expect(w.exists(0), isTrue);
      expect(w.exists(9999), isTrue);
      expect(w.exists(-1), isFalse);
    });

    test('rows read by absolute index across held pages', () {
      final w = PageWindow<String>(pageSize: 10)
        ..install(0, pageRows(0, 10), demand: const PageSpan(0, 3))
        ..install(3, pageRows(3, 10), demand: const PageSpan(0, 3));
      expect(w.rowAt(0), 'r0');
      expect(w.rowAt(9), 'r9');
      expect(w.rowAt(30), 'r30');
      expect(w.rowAt(39), 'r39');
      expect(w.pageOf(35), 3);
      expect(w.rowCount, 20);
      expect(w.present, [0, 3]);
      expect(w.pageAt(0), pageRows(0, 10));
      expect(w.pageAt(1), isNull);
    });

    test('a row in an absent page — or past a short page — reads null', () {
      final w = PageWindow<String>(pageSize: 10)
        ..install(0, pageRows(0, 10), demand: const PageSpan(0, 2))
        ..install(2, pageRows(2, 10, count: 4), demand: const PageSpan(0, 2));
      // Page 1 was never loaded: a hole, not an error.
      expect(w.rowAt(15), isNull);
      // Page 2 holds rows 20..23 only.
      expect(w.rowAt(23), 'r23');
      expect(w.rowAt(24), isNull);
      expect(w.rowAt(-1), isNull);
    });

    test('installing the same page twice replaces it', () {
      final w = PageWindow<String>(pageSize: 4)
        ..install(0, ['a', 'b', 'c', 'd'], demand: const PageSpan(0, 0))
        ..install(0, ['w', 'x', 'y', 'z'], demand: const PageSpan(0, 0));
      expect(w.pageCount, 1);
      expect(w.rowAt(0), 'w');
    });
  });

  group('PageWindow.spanFor', () {
    final w = PageWindow<String>(pageSize: 50);

    test('a viewport inside one page spans that page', () {
      expect(w.spanFor(firstRow: 10, rowCount: 20), const PageSpan(0, 0));
    });

    test('a viewport straddling a boundary spans both pages', () {
      expect(w.spanFor(firstRow: 40, rowCount: 20), const PageSpan(0, 1));
    });

    test('the threshold reaches past both edges', () {
      expect(w.spanFor(firstRow: 50, rowCount: 20, threshold: 10), const PageSpan(0, 1, anchor: 1));
      expect(w.spanFor(firstRow: 60, rowCount: 20, threshold: 10), const PageSpan(1, 1, anchor: 1));
    });

    test('the span never reaches below page 0', () {
      expect(w.spanFor(firstRow: 0, rowCount: 20, threshold: 10), const PageSpan(0, 0));
    });

    test('a viewport of no rows still spans the page it starts in', () {
      expect(w.spanFor(firstRow: 0, rowCount: 0), const PageSpan(0, 0));
      expect(w.spanFor(firstRow: 200, rowCount: 0), const PageSpan(4, 4));
    });

    test('the anchor is the page holding the first visible row', () {
      expect(w.spanFor(firstRow: 120, rowCount: 20, threshold: 10).anchor, 2);
    });
  });

  group('PageWindow.missing', () {
    test('a jump asks for the destination page first', () {
      final w = PageWindow<String>(pageSize: 50)..install(0, pageRows(0, 50), demand: const PageSpan(0, 0));
      // The cursor jumps from row 20 to row 480: demand follows the viewport
      // rather than the edge of what is loaded, so page 9 is asked for and the
      // pages between are never requested at all.
      final span = w.spanFor(firstRow: 480, rowCount: 20, threshold: 10);
      expect(w.missing(span), [9, 10]);
      expect(w.missing(span, limit: 1), [9]);
    });

    test('the anchor page comes before the pages the threshold merely reaches', () {
      final w = PageWindow<String>(pageSize: 50);
      // Viewport at rows 100..119 with a 10-row threshold: pages 1..2, anchored
      // at 2. Under a cap of one, the page under the user is the one fetched.
      final span = w.spanFor(firstRow: 100, rowCount: 20, threshold: 10);
      expect(span, const PageSpan(1, 2, anchor: 2));
      expect(w.missing(span), [2, 1]);
      expect(w.missing(span, limit: 1), [2]);
    });

    test('at equal distance the page below the viewport goes first', () {
      final w = PageWindow<String>(pageSize: 50);
      expect(w.missing(const PageSpan(1, 3, anchor: 2)), [2, 3, 1]);
    });

    test('a hole in the middle of the cache is asked for again', () {
      // Pages 0 and 2 are held; the range they span is not contiguous, and the
      // gap is as visible as a page past the end would be.
      final w = PageWindow<String>(pageSize: 50)
        ..install(0, pageRows(0, 50), demand: const PageSpan(0, 2))
        ..install(2, pageRows(2, 50), demand: const PageSpan(0, 2));
      expect(w.present, [0, 2]);
      expect(w.missing(const PageSpan(0, 2)), [1]);
    });

    test('pages already on their way are skipped', () {
      final w = PageWindow<String>(pageSize: 50);
      const span = PageSpan(0, 3);
      expect(w.missing(span, pending: (p) => p == 1), [0, 2, 3]);
      expect(w.missing(span, pending: (p) => true), isEmpty);
    });

    test('the limit caps how many pages are asked for at once', () {
      final w = PageWindow<String>(pageSize: 50);
      expect(w.missing(const PageSpan(0, 5), limit: 3), [0, 1, 2]);
      expect(w.missing(const PageSpan(0, 5), limit: 0), isEmpty);
      expect(w.missing(const PageSpan(0, 5), limit: -1), isEmpty);
    });

    test('nothing is asked for when the span is fully held', () {
      final w = PageWindow<String>(pageSize: 10)
        ..install(0, pageRows(0, 10), demand: const PageSpan(0, 1))
        ..install(1, pageRows(1, 10), demand: const PageSpan(0, 1));
      expect(w.missing(const PageSpan(0, 1)), isEmpty);
    });
  });

  group('PageWindow end of data', () {
    test('a short page records where the data ends', () {
      final w = PageWindow<String>(pageSize: 50)
        ..install(0, pageRows(0, 50), demand: const PageSpan(0, 1))
        ..install(1, pageRows(1, 50, count: 20), demand: const PageSpan(0, 1));
      expect(w.lastPage, 1);
      expect(w.exists(1), isTrue);
      expect(w.exists(2), isFalse);
      expect(w.missing(const PageSpan(0, 4)), isEmpty);
    });

    test('an empty page ends the data one page earlier', () {
      final w = PageWindow<String>(pageSize: 50)
        ..install(0, pageRows(0, 50), demand: const PageSpan(0, 1))
        ..install(1, const [], demand: const PageSpan(0, 1));
      expect(w.lastPage, 0);
      expect(w.exists(1), isFalse);
      // The empty page is not kept as a page of nothing.
      expect(w.present, [0]);
    });

    test('an empty first page means the data is empty', () {
      final w = PageWindow<String>(pageSize: 50)..install(0, const [], demand: const PageSpan(0, 0));
      expect(w.lastPage, -1);
      expect(w.exists(0), isFalse);
      expect(w.missing(const PageSpan(0, 3)), isEmpty);
    });

    test('a recorded end does not suppress a page that does exist', () {
      final w = PageWindow<String>(pageSize: 50, keepPages: 0)
        ..install(0, pageRows(0, 50), demand: const PageSpan(0, 2))
        ..install(1, pageRows(1, 50), demand: const PageSpan(0, 2))
        ..install(2, pageRows(2, 50, count: 10), demand: const PageSpan(0, 2));
      expect(w.lastPage, 2);
      // The viewport moves onto page 2, so pages 0 and 1 are evicted; scrolling
      // back must be able to re-fetch them. End-of-data is knowledge about where
      // the data stops, never a gate on a page inside it.
      w.install(2, pageRows(2, 50, count: 10), demand: const PageSpan(2, 2, anchor: 2));
      expect(w.present, [2]);
      expect(w.missing(const PageSpan(0, 2, anchor: 1)), [1, 0]);
    });

    test('endAt records the end outright and drops what lies past it', () {
      final w = PageWindow<String>(pageSize: 10)
        ..install(0, pageRows(0, 10), demand: const PageSpan(0, 3))
        ..install(3, pageRows(3, 10), demand: const PageSpan(0, 3))
        ..endAt(1);
      expect(w.lastPage, 1);
      expect(w.present, [0]);
      expect(w.exists(2), isFalse);
    });

    test('a full page past a recorded end withdraws the record', () {
      final w = PageWindow<String>(pageSize: 10)..install(0, pageRows(0, 10, count: 4), demand: const PageSpan(0, 1));
      expect(w.lastPage, 0);
      // The source grew: page 1 is full, so where the data ends is unknown again.
      w.install(1, pageRows(1, 10), demand: const PageSpan(0, 1));
      expect(w.lastPage, isNull);
      expect(w.exists(5), isTrue);
    });

    test('clear forgets both the pages and the end', () {
      final w = PageWindow<String>(pageSize: 10)
        ..install(0, pageRows(0, 10, count: 2), demand: const PageSpan(0, 0))
        ..clear();
      expect(w.present, isEmpty);
      expect(w.lastPage, isNull);
      expect(w.exists(3), isTrue);
    });
  });

  group('PageWindow eviction', () {
    test('keeps the demand span plus keepPages on each side', () {
      final w = PageWindow<String>(pageSize: 10, keepPages: 1);
      for (var p = 0; p <= 6; p++) {
        w.install(p, pageRows(p, 10), demand: const PageSpan(3, 4, anchor: 3));
      }
      expect(w.present, [2, 3, 4, 5]);
    });

    test('spares the demand span at every keepPages value, including zero', () {
      for (final keep in [0, 1, 2, 4]) {
        final w = PageWindow<String>(pageSize: 10, keepPages: keep);
        const span = PageSpan(4, 6, anchor: 5);
        for (var p = 0; p <= 12; p++) {
          w.install(p, pageRows(p, 10), demand: span);
        }
        // Whatever the setting, every page the viewport is asking for survives:
        // eviction can never take one and force it to be fetched again.
        for (final page in span.pages) {
          expect(w.has(page), isTrue, reason: 'keepPages: $keep dropped page $page');
        }
        expect(w.present.first, 4 - keep < 0 ? 0 : 4 - keep);
        expect(w.present.last, 6 + keep > 12 ? 12 : 6 + keep);
      }
    });

    test('keepPages zero keeps exactly the demand span', () {
      final w = PageWindow<String>(pageSize: 10, keepPages: 0);
      for (var p = 0; p <= 4; p++) {
        w.install(p, pageRows(p, 10), demand: const PageSpan(1, 2));
      }
      expect(w.present, [1, 2]);
    });

    test('a page installed outside the retained band does not linger', () {
      final w = PageWindow<String>(pageSize: 10, keepPages: 0)
        ..install(0, pageRows(0, 10), demand: const PageSpan(0, 0))
        // A late result for a page the viewport has since left.
        ..install(0, pageRows(0, 10), demand: const PageSpan(5, 5));
      expect(w.present, isEmpty);
    });

    test('the window moving with the viewport drops what it leaves behind', () {
      final w = PageWindow<String>(pageSize: 10, keepPages: 1);
      // Walk the viewport down through eight pages, one install per step.
      for (var p = 0; p <= 7; p++) {
        w.install(p, pageRows(p, 10), demand: PageSpan(p, p, anchor: p));
      }
      expect(w.present, [6, 7]);
      expect(w.rowCount, 20);
    });
  });
}
