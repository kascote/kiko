import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

import '../../../example/table_view_paginated.dart' as example;

// The paginated table example, booted through a real application over a
// TestBackend. The example's update has no `LoadResult` case: each page's
// result reaches the table through the same `update` call every other
// message takes, and the table installs it itself.

/// The key the example quits on.
const _quitKey = 'ctrl+q';

/// The index of the last row: the example's `ProductApi` serves 500 products.
const _lastRow = 499;

void main() {
  test('pages load end to end with no LoadResult handling in the app', () async {
    final backend = TestBackend();
    final model = example.AppModel();
    final table = model.table;
    var jumped = false;
    var quitSent = false;
    Object? firstRowId;

    await Application(
      backend: backend,
      fps: 120,
      onFrame: (_) {
        // The first page is the app's own InitMsg fetch. Once it has landed —
        // through the table's update, not through the app — jump to the end,
        // which demands the last pages.
        if (!jumped) {
          if (table.cachedRowCount == 0) return;
          jumped = true;
          // Read now: the window evicts page 0 once the viewport leaves it.
          firstRowId = table.getRow(0)?['id'];
          backend.emitKey('end');
          return;
        }
        if (quitSent || table.getRow(_lastRow) == null) return;
        quitSent = true;
        backend.emitKey(_quitKey);
      },
    ).run<example.AppModel>(init: model, update: example.appUpdate, view: example.appView);

    expect(jumped, isTrue, reason: 'the first page landed');
    expect(quitSent, isTrue, reason: 'the last page landed after the jump');
    expect(firstRowId, 'P0001');
    expect(table.getRow(_lastRow)?['id'], 'P0500');
    expect(table.isLoading(), isFalse);
    expect(table.viewportStatus, SliceStatus.ready);
  });

  test('a taller terminal loads the rows it reveals, with no frame-tick case in the app', () async {
    final backend = TestBackend(size: const TermSize(80, 12));
    final model = example.AppModel();
    final table = model.table;
    var resized = false;
    var quitSent = false;
    int? rowsBeforeResize;

    await Application(
      backend: backend,
      fps: 120,
      onFrame: (_) {
        // Once the init fetch has landed, grow the terminal past page 0. The
        // resize reaches the table only through its viewport report: nothing
        // in the example's update mentions the frame or the viewport.
        if (!resized) {
          if (table.cachedRowCount == 0) return;
          resized = true;
          rowsBeforeResize = table.cachedRowCount;
          backend.emitResize(const TermSize(80, 150));
          return;
        }
        if (quitSent || table.getRow(120) == null) return;
        quitSent = true;
        backend.emitKey(_quitKey);
      },
    ).run<example.AppModel>(init: model, update: example.appUpdate, view: example.appView);

    expect(rowsBeforeResize, 50, reason: 'a 12-row terminal needs page 0 only');
    expect(quitSent, isTrue, reason: 'the rows the taller terminal revealed landed');
    expect(table.getRow(120)?['id'], 'P0121');
    expect(table.viewportStatus, SliceStatus.ready);
  });
}
