import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

/// Renders [node] onto a fresh [width]×[height] buffer and dumps it to text —
/// one line per row, empty cells as spaces, trailing blanks trimmed.
String _render(plume.RenderNode<PaintToken> node, int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  plume.renderFrame(node, plume.Rect(0, 0, width, height), BufferSurface(buffer));

  final out = StringBuffer();
  for (var y = 0; y < height; y++) {
    final row = StringBuffer();
    for (var x = 0; x < width; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

void main() {
  group('container views build plume nodes', () {
    test('Column inflates its children in order', () {
      final node = const Column(
        children: [Text('a'), Text('b')],
        mainAxis: MainAxisAlignment.center,
        crossAxis: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
      ).build();

      expect(node, isA<plume.Column<PaintToken>>());
      final column = node as plume.Column<PaintToken>;
      expect(column.children, hasLength(2));
      expect(column.children.every((c) => c is plume.Text<PaintToken>), isTrue);
      expect(column.mainAxisAlignment, MainAxisAlignment.center);
      expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
      expect(column.mainAxisSize, MainAxisSize.min);
    });

    test('Row inflates its children in order', () {
      final node = const Row(children: [Text('a'), Text('b'), Text('c')]).build();

      expect(node, isA<plume.Row<PaintToken>>());
      expect((node as plume.Row<PaintToken>).children, hasLength(3));
    });

    test('Expanded wraps its child with a flex share', () {
      final node = const Expanded(flex: 3, child: Text('x')).build();

      expect(node, isA<plume.Expanded<PaintToken>>());
      final expanded = node as plume.Expanded<PaintToken>;
      expect(expanded.flex, 3);
      expect(expanded.fit, plume.FlexFit.tight);
      expect(expanded.child, isA<plume.Text<PaintToken>>());
    });

    test('Flexible wraps its child, defaulting to a loose fit', () {
      final node = const Flexible(flex: 2, child: Text('x')).build();

      expect(node, isA<plume.Flexible<PaintToken>>());
      final flexible = node as plume.Flexible<PaintToken>;
      expect(flexible.flex, 2);
      expect(flexible.fit, plume.FlexFit.loose);
    });

    test('SizedBox builds a fixed box with no child', () {
      final node = const SizedBox(width: 4, height: 2).build();

      expect(node, isA<plume.SizedBox<PaintToken>>());
      final box = node as plume.SizedBox<PaintToken>;
      expect(box.width, 4);
      expect(box.height, 2);
    });

    test('Padding insets its child', () {
      final node = const Padding(insets: EdgeInsets.all(1), child: Text('x')).build();

      expect(node, isA<plume.Padding<PaintToken>>());
      final padding = node as plume.Padding<PaintToken>;
      expect(padding.insets, const EdgeInsets.all(1));
      expect(padding.child, isA<plume.Text<PaintToken>>());
    });

    test('Center centers its child', () {
      final node = const Center(child: Text('x')).build();

      expect(node, isA<plume.Center<PaintToken>>());
      expect((node as plume.Center<PaintToken>).alignment, plume.Alignment.center);
    });

    test('Align positions its child by a 2D alignment', () {
      final node = const Align(alignment: Alignment.bottomRight, child: Text('x')).build();

      expect(node, isA<plume.Align<PaintToken>>());
      expect((node as plume.Align<PaintToken>).alignment, Alignment.bottomRight);
    });

    test('Stack layers its children with an alignment and fit', () {
      final node = const Stack(
        children: [Text('a'), Text('b')],
        alignment: Alignment.center,
        fit: StackFit.expand,
      ).build();

      expect(node, isA<plume.Stack<PaintToken>>());
      final stack = node as plume.Stack<PaintToken>;
      expect(stack.children, hasLength(2));
      expect(stack.alignment, Alignment.center);
      expect(stack.fit, StackFit.expand);
    });

    test('Offstage wraps its child untouched', () {
      final node = const Offstage(child: Text('x')).build();

      expect(node, isA<plume.Offstage<PaintToken>>());
      expect((node as plume.Offstage<PaintToken>).child, isA<plume.Text<PaintToken>>());
    });

    test('a Stack sizes to an Offstage alternate larger than the visible child', () {
      final node =
          const Stack(
                  children: [
                    Offstage(child: SizedBox(width: 8, height: 4)),
                    SizedBox(width: 2, height: 1),
                  ],
                ).build()
                as plume.Stack<PaintToken>
            ..layout(
              plume.BoxConstraints.loose(const Size(20, 10)),
              const plume.LayoutContext(measurer: TermUnicodeMeasurer()),
            )
            ..place(plume.Offset.zero);

      expect(node.size, const Size(8, 4));
    });

    test('Positioned pins its child to edges', () {
      final node = const Positioned(left: 1, top: 2, child: Text('x')).build();

      expect(node, isA<plume.Positioned<PaintToken>>());
      final positioned = node as plume.Positioned<PaintToken>;
      expect(positioned.left, 1);
      expect(positioned.top, 2);
      expect(positioned.right, isNull);
    });

    test('ConstrainedBox imposes extra constraints on its child', () {
      const constraints = BoxConstraints(minW: 2, maxW: 8);
      final node = const ConstrainedBox(additionalConstraints: constraints, child: Text('x')).build();

      expect(node, isA<plume.ConstrainedBox<PaintToken>>());
      expect((node as plume.ConstrainedBox<PaintToken>).additionalConstraints, constraints);
    });

    test('Container carries sizing and builds its decoration tokens', () {
      final node = const Container(
        width: 6,
        height: 3,
        background: Style(bg: Color.blue),
        border: BorderType.plain,
        borderStyle: Style(fg: Color.red),
        child: Text('x'),
      ).build();

      expect(node, isA<plume.Container<PaintToken>>());
      final container = node as plume.Container<PaintToken>;
      expect(container.width, 6);
      expect(container.height, 3);
      expect(container.background, const PaintToken(Style(bg: Color.blue)));
      expect(container.border, PaintToken(const Style(fg: Color.red), border: BorderType.plain.symbols));
    });

    test('a bordered Container always carries the glyphs its border needs', () {
      final node = const Container(border: BorderType.rounded, child: Text('x')).build() as plume.Container<PaintToken>;

      // A border token reserves an edge cell in layout, so one without glyphs
      // would leave a hole rather than a frame.
      expect(node.border?.border, isNotNull);
      expect(node.border?.border, BorderType.rounded.symbols);
    });

    test('an empty style and BorderType.none leave the decoration tokens off', () {
      final node = const Container(child: Text('x')).build() as plume.Container<PaintToken>;

      expect(node.background, isNull);
      expect(node.border, isNull);
    });

    test('nested containers inflate the whole tree', () {
      final node = const Column(
        children: [
          Expanded(child: Center(child: Text('hi'))),
          Row(children: [Text('a'), SizedBox(width: 1), Text('b')]),
        ],
      ).build();

      final column = node as plume.Column<PaintToken>;
      expect(column.children.first, isA<plume.Expanded<PaintToken>>());
      final row = column.children[1] as plume.Row<PaintToken>;
      expect(row.children[1], isA<plume.SizedBox<PaintToken>>());
    });
  });

  group('id: tags the built node the same way Tagged does', () {
    test('Container: id: and Tagged stamp the same tag on the same tree', () {
      final direct = const Container(id: 'x', child: Text('hi')).build();
      final wrapped = const Tagged('x', Container(child: Text('hi'))).build();

      expect(direct.tag, IdTag('x'));
      expect(direct.runtimeType, wrapped.runtimeType);
      expect(_render(direct, 8, 1), _render(wrapped, 8, 1));
    });

    test('Column: id: and Tagged stamp the same tag on the same tree', () {
      final direct = const Column(id: 'x', children: [Text('a'), Text('b')]).build();
      final wrapped = const Tagged('x', Column(children: [Text('a'), Text('b')])).build();

      expect(direct.tag, IdTag('x'));
      expect(direct.runtimeType, wrapped.runtimeType);
      expect(_render(direct, 4, 2), _render(wrapped, 4, 2));
    });

    test('Row: id: and Tagged stamp the same tag on the same tree', () {
      final direct = const Row(id: 'x', children: [Text('a'), Text('b')]).build();
      final wrapped = const Tagged('x', Row(children: [Text('a'), Text('b')])).build();

      expect(direct.tag, IdTag('x'));
      expect(direct.runtimeType, wrapped.runtimeType);
      expect(_render(direct, 4, 1), _render(wrapped, 4, 1));
    });

    test('Stack: id: and Tagged stamp the same tag on the same tree', () {
      final direct = const Stack(id: 'x', children: [Text('a')]).build();
      final wrapped = const Tagged('x', Stack(children: [Text('a')])).build();

      expect(direct.tag, IdTag('x'));
      expect(direct.runtimeType, wrapped.runtimeType);
      expect(_render(direct, 4, 1), _render(wrapped, 4, 1));
    });

    test("omitting id: leaves the tag null, byte for byte today's behavior", () {
      expect(const Container(child: Text('a')).build().tag, isNull);
      expect(const Column(children: [Text('a')]).build().tag, isNull);
      expect(const Row(children: [Text('a')]).build().tag, isNull);
      expect(const Stack(children: [Text('a')]).build().tag, isNull);
    });

    test('id: composes with an outer Tagged, which trips the no-overwrite assert', () {
      expect(
        () => const Tagged('outer', Container(id: 'inner', child: Text('a'))).build(),
        throwsA(isA<AssertionError>()),
      );
    });

    test('id: composes with an outer Tagged.scope, which trips the no-overwrite assert', () {
      expect(
        () => const Tagged.scope('outer', Column(id: 'inner', children: [Text('a')])).build(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Container titles', () {
    test('titles become edge labels at the start of their edge', () {
      final node =
          Container(
                topTitles: <Line>[Line('Top')],
                bottomTitles: <Line>[Line('Bot')],
                child: const SizedBox(width: 1, height: 1),
              ).build()
              as plume.Container<PaintToken>;

      expect(node.labels, hasLength(2));
      expect(node.labels[0].side, plume.EdgeSide.top);
      expect(node.labels[0].align, plume.LabelAlign.start);
      expect(node.labels[1].side, plume.EdgeSide.bottom);
      expect(node.labels[1].align, plume.LabelAlign.start);
    });

    test('draws a bordered frame with a start-aligned title and body text', () {
      final node = Container(
        border: BorderType.plain,
        topTitles: <Line>[Line('Hi')],
        child: Line('body'),
      ).build();

      expect(_render(node, 10, 4), '''
┌Hi──────┐
│body    │
│        │
└────────┘
''');
    });
  });
}
