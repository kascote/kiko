import 'package:kiko/kiko.dart';
import 'package:plume/plume.dart' as plume;
import 'package:test/test.dart';

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
}
