import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

// The whole wheel path, driven through a real application: a backend delivers a
// wheel event, the runtime routes it to the tagged widget, `update` forwards the
// resolved PointerMsg to the model, and the model scrolls and — at the viewport
// edge — asks for the next page. Nothing here hand-routes or hand-sets geometry.

List<Map<String, Object?>> rows(int n) => List.generate(n, (i) => {'id': 'r$i', 'name': 'Name $i'});

/// Runs a real application over [backend], feeding it [notches] one per
/// committed frame. Every routed [PointerMsg] is handed to [forward] (the
/// widget's own `update`), and any [LoadRequest] it emits is collected and
/// returned.
Future<List<LoadRequest>> _driveWheel(
  TestBackend backend,
  List<ScriptStep> notches,
  UpdateResult Function(Msg msg) forward,
  Render<int> view,
) async {
  final requests = <LoadRequest>[];
  final script = FrameScript(backend, steps: (_) => notches);

  await Application(backend: backend, fps: 120, onFrame: script.onFrame).run<int>(
    init: 0,
    update: script.wrap((model, msg, _) {
      if (msg is PointerMsg) {
        if (forward(msg) case Handled(events: [final LoadRequest r])) requests.add(r);
      }
      return (model, null);
    }),
    view: view,
  );

  expect(script.completed, isTrue, reason: 'every wheel notch went out');
  return requests;
}

void main() {
  test('a wheel to the bottom edge loads the next page (list, end-to-end)', () async {
    final backend = TestBackend(size: const TermSize(12, 6));
    final list = ListViewModel<String, String>(
      items: List.generate(10, (i) => 'item$i'),
      totalCount: 30,
      pageSize: 10,
      loadThreshold: 2,
      id: 'list',
    );

    final requests = await _driveWheel(
      backend,
      List.filled(4, (b) => b.emitWheel(2, 3, deltaY: 1)),
      list.update,
      (step, frame) => frame.render(
        ListView<String, String>(
          model: list,
          theme: Theme.dark,
          itemBuilder: (item, index, state) => [Line(item)],
        ),
      ),
    );

    expect(requests, isNotEmpty, reason: 'wheel alone should page the next batch in');
    expect(requests.first.id, equals('list'));
    expect(requests.first.key, equals(const PageKey(1)));
  });

  test('a wheel to the bottom edge loads the next page (table, end-to-end)', () async {
    final backend = TestBackend(size: const TermSize(20, 7));
    final table = TableViewModel(
      totalCount: 120,
      keyField: 'id',
      columns: [
        TableColumn(field: 'id', label: Line('ID')),
        TableColumn(field: 'name', label: Line('Name')),
      ],
      pageSize: 10,
      loadThreshold: 3,
      id: 'table',
    )..insertRows(rows(10), 0);

    final requests = await _driveWheel(
      backend,
      List.filled(6, (b) => b.emitWheel(3, 3, deltaY: 1)),
      table.update,
      (step, frame) => frame.render(TableView(model: table, theme: Theme.dark)),
    );

    expect(requests, isNotEmpty, reason: 'wheel alone should page the next batch in');
    expect(requests.first.id, equals('table'));
    expect(requests.first.key, equals(const PageKey(1)));
  });
}
