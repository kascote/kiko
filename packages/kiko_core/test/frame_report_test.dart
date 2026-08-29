import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

Buffer _buf(int w, int h) => Buffer.empty(Rect.create(x: 0, y: 0, width: w, height: h));

/// A report carrying one number: the shape a widget's own kind takes.
class _Rows extends FrameReport {
  const _Rows(super.id, this.rows);

  final int rows;
}

/// A second kind under the same id, to show the sink keys on type as well.
class _Cols extends FrameReport {
  const _Cols(super.id, this.cols);

  final int cols;
}

/// A one-row leaf that appends [reports] when painted.
///
/// A [Node] and its own [View] at once — the shape a self-painting widget
/// takes, minimal down to the report call.
class _Reporter extends Node implements View {
  _Reporter(this.reports);

  /// What this leaf reports each time it paints.
  final List<FrameReport> reports;

  @override
  Node build() => this;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) =>
      constraints.constrain(Size(constraints.biggest.w, 1));

  @override
  void paintSelf(Surface surface) {
    if (surface is BufferSurface) reports.forEach(surface.report);
  }
}

/// A one-row leaf tagged [id] that reports under the path the paint walk gives
/// it — the shape every windowed widget takes.
class _ScopedReporter extends Node implements View {
  _ScopedReporter(this.id) {
    tag = IdTag(id);
  }

  final String id;

  @override
  Node build() => this;

  @override
  Size performLayout(BoxConstraints constraints, LayoutContext context) =>
      constraints.constrain(Size(constraints.biggest.w, 1));

  @override
  void paintSelf(Surface surface) {
    if (surface is BufferSurface) surface.report(_Rows(HitTag.join(surface.scopePath, id), 1));
  }
}

/// The ids of [reports], in order.
List<String> _ids(List<FrameReport> reports) => [for (final r in reports) r.id];

/// The payloads of [reports], in order: rows for a [_Rows], cols for a [_Cols].
List<int> _values(List<FrameReport> reports) => [
  for (final r in reports)
    switch (r) {
      _Rows(:final rows) => rows,
      _Cols(:final cols) => cols,
      _ => throw StateError('unexpected report $r'),
    },
];

void main() {
  group('BufferSurface.report', () {
    test('a fresh surface holds no reports', () {
      expect(BufferSurface(_buf(4, 1)).reports, isEmpty);
    });

    test('appends in call order, every call kept', () {
      final s = BufferSurface(_buf(4, 1))
        ..report(const _Rows('list', 3))
        ..report(const _Rows('list', 5))
        ..report(const _Cols('list', 2));

      expect(_ids(s.reports), ['list', 'list', 'list']);
      expect(_values(s.reports), [3, 5, 2], reason: 'the surface collects; the frame dedupes');
    });

    test('reports is a read-only view', () {
      final s = BufferSurface(_buf(4, 1))..report(const _Rows('list', 3));

      expect(() => s.reports.add(const _Rows('other', 1)), throwsUnsupportedError);
    });
  });

  group('Frame.reports', () {
    test('a fresh frame holds no reports', () {
      final b = _buf(8, 4);
      expect(Frame(b.area, b, 0).reports, isEmpty);
    });

    test('a report appended during render reaches the frame with its id', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(_Reporter(const [_Rows('list', 3)]));

      expect(_ids(frame.reports), ['list']);
      expect(_values(frame.reports), [3]);
    });

    test('only the last report per id and type survives one frame', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(
          Column(
            children: [
              _Reporter(const [_Rows('list', 3)]),
              _Reporter(const [_Rows('list', 5)]),
            ],
          ),
        );

      expect(_ids(frame.reports), ['list']);
      expect(_values(frame.reports), [5]);
    });

    test('a different id or a different type is a different report', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(
          Column(
            children: [
              _Reporter(const [_Rows('list', 3), _Cols('list', 2)]),
              _Reporter(const [_Rows('table', 4)]),
            ],
          ),
        );

      expect(_ids(frame.reports), ['list', 'list', 'table']);
      expect(_values(frame.reports), [3, 2, 4]);
    });

    test('reports keep paint order, and a repeated key sits where it was painted last', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(
          Column(
            children: [
              _Reporter(const [_Rows('a', 1)]),
              _Reporter(const [_Rows('b', 2)]),
              _Reporter(const [_Rows('a', 3)]),
            ],
          ),
        );

      expect(_ids(frame.reports), ['b', 'a']);
      expect(_values(frame.reports), [2, 3]);
    });

    test('two renders into one frame accumulate', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(_Reporter(const [_Rows('a', 1)]))
        ..render(_Reporter(const [_Rows('b', 2)]));

      expect(_ids(frame.reports), ['a', 'b']);
    });

    test('reports is a read-only view', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(_Reporter(const [_Rows('a', 1)]));

      expect(() => frame.reports.add(const _Rows('other', 1)), throwsUnsupportedError);
    });
  });

  group('a report addressed through BufferSurface.scopePath', () {
    test('under no scope carries the bare id, the path the hit map records', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(_ScopedReporter('list'));

      expect(_ids(frame.reports), ['list']);
      expect(frame.hits.hitId(0, 0), 'list');
    });

    test('under one scope carries the scoped path, with nothing passed to the view', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)..render(Tagged.scope('combo', Column(children: [_ScopedReporter('list')])));

      expect(_ids(frame.reports), ['combo/list']);
      expect(frame.hits.hitId(0, 0), 'combo/list');
    });

    test('under two scopes carries both, outermost first', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(
          Tagged.scope(
            'a',
            Column(
              children: [
                Tagged.scope('b', Column(children: [_ScopedReporter('list')])),
              ],
            ),
          ),
        );

      expect(_ids(frame.reports), ['a/b/list']);
      expect(frame.hits.hitId(0, 0), 'a/b/list');
    });

    test("an untagged ancestor and a sibling's id add nothing to the path", () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(
          Tagged.scope(
            'a',
            Column(
              children: [
                const Tagged('other', SizedBox(width: 8, height: 1)),
                Container(child: Column(children: [_ScopedReporter('list')])),
              ],
            ),
          ),
        );

      expect(_ids(frame.reports), ['a/list']);
      expect(frame.hits.hitId(0, 1), 'a/list');
    });

    test("a layer pass starts from an empty chain: it reports the layer's own path", () {
      final b = _buf(8, 4);
      final layerRect = Rect.create(x: 0, y: 2, width: 8, height: 1);
      final frame = Frame(b.area, b, 0)
        ..render(Tagged.scope('base', Column(children: [_ScopedReporter('list')])))
        ..renderLayer(Tagged.scope('popup', Column(children: [_ScopedReporter('list')])), layerRect);

      expect(_ids(frame.reports), ['base/list', 'popup/list']);
      expect(frame.hits.hitId(0, 0), 'base/list');
      expect(frame.hits.hitId(0, 2), 'popup/list');
    });
  });

  group('Frame.renderLayer / reports', () {
    test('a report appended inside a layer paint is collected, after the base reports', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(_Reporter(const [_Rows('list', 3)]))
        ..renderLayer(_Reporter(const [_Rows('popup', 2)]), Rect.create(x: 2, y: 1, width: 4, height: 2));

      expect(_ids(frame.reports), ['list', 'popup']);
      expect(_values(frame.reports), [3, 2]);
    });

    test('a layer report replaces a base report with the same id and type', () {
      final b = _buf(8, 4);
      final frame = Frame(b.area, b, 0)
        ..render(_Reporter(const [_Rows('list', 3)]))
        ..renderLayer(_Reporter(const [_Rows('list', 7)]), Rect.create(x: 2, y: 1, width: 4, height: 2));

      expect(_ids(frame.reports), ['list']);
      expect(_values(frame.reports), [7]);
    });
  });
}
