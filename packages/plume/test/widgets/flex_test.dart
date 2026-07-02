import 'package:plume/plume.dart';
import 'package:test/test.dart';

const _ctx = LayoutContext(measurer: MonospaceMeasurer());

/// Lays [root] out under [constraints] and dumps each node's type and rect.
String _golden(RenderNode<String> root, BoxConstraints constraints) {
  root
    ..layout(constraints, _ctx)
    ..place(Offset.zero);
  final buffer = StringBuffer();
  void walk(RenderNode<String> node, int depth) {
    buffer.writeln('${'  ' * depth}${node.runtimeType.toString().split('<').first} ${node.rect}');
    node.visitChildren((child) => walk(child, depth + 1));
  }

  walk(root, 0);
  return buffer.toString().trimRight();
}

SizedBox<String> _box(int w, int h) => SizedBox<String>(width: w, height: h);

void main() {
  group('Row', () {
    test('mainAxisSize.max fills the main axis, start-aligned', () {
      final golden = _golden(
        Row<String>(children: [_box(2, 1), _box(3, 2)]),
        const BoxConstraints(maxW: 20, maxH: 10),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 20, 2)',
          '  SizedBox Rect(0, 0, 2, 1)',
          '  SizedBox Rect(2, 0, 3, 2)',
        ].join('\n'),
      );
    });

    test('mainAxisAlignment.center packs children in the middle', () {
      final golden = _golden(
        Row<String>(mainAxisAlignment: MainAxisAlignment.center, children: [_box(2, 1), _box(2, 1)]),
        const BoxConstraints(maxW: 10, maxH: 1),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 10, 1)',
          '  SizedBox Rect(3, 0, 2, 1)',
          '  SizedBox Rect(5, 0, 2, 1)',
        ].join('\n'),
      );
    });

    test('mainAxisAlignment.spaceBetween pushes children to the ends', () {
      final golden = _golden(
        Row<String>(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_box(2, 1), _box(2, 1)]),
        const BoxConstraints(maxW: 10, maxH: 1),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 10, 1)',
          '  SizedBox Rect(0, 0, 2, 1)',
          '  SizedBox Rect(8, 0, 2, 1)',
        ].join('\n'),
      );
    });

    test('crossAxisAlignment.stretch fills the cross axis', () {
      final golden = _golden(
        Row<String>(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_box(2, 1)]),
        const BoxConstraints(maxW: 10, maxH: 4),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 10, 4)',
          '  SizedBox Rect(0, 0, 2, 4)',
        ].join('\n'),
      );
    });
  });

  group('Column', () {
    test('mainAxisSize.min shrink-wraps the children', () {
      final golden = _golden(
        Column<String>(mainAxisSize: MainAxisSize.min, children: [_box(3, 1), _box(2, 2)]),
        const BoxConstraints(maxW: 20, maxH: 20),
      );
      expect(
        golden,
        [
          'Column Rect(0, 0, 3, 3)',
          '  SizedBox Rect(0, 0, 3, 1)',
          '  SizedBox Rect(0, 1, 2, 2)',
        ].join('\n'),
      );
    });
  });

  group('flex', () {
    test('Expanded takes the leftover main-axis space', () {
      final golden = _golden(
        Row<String>(
          children: [
            _box(4, 1),
            Expanded<String>(child: _box(0, 1)),
          ],
        ),
        const BoxConstraints(maxW: 10, maxH: 5),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 10, 1)',
          '  SizedBox Rect(0, 0, 4, 1)',
          '  Expanded Rect(4, 0, 6, 1)',
          '    SizedBox Rect(4, 0, 6, 1)',
        ].join('\n'),
      );
    });

    test('two Expandeds split the space by flex factor', () {
      final golden = _golden(
        Row<String>(
          children: [
            Expanded<String>(child: _box(0, 1)),
            Expanded<String>(flex: 2, child: _box(0, 1)),
          ],
        ),
        const BoxConstraints(maxW: 9, maxH: 1),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 9, 1)',
          '  Expanded Rect(0, 0, 3, 1)',
          '    SizedBox Rect(0, 0, 3, 1)',
          '  Expanded Rect(3, 0, 6, 1)',
          '    SizedBox Rect(3, 0, 6, 1)',
        ].join('\n'),
      );
    });

    test('Flexible with a loose fit may stay smaller than its share', () {
      final golden = _golden(
        Row<String>(children: [Flexible<String>(flex: 1, child: _box(3, 1))]),
        const BoxConstraints(maxW: 10, maxH: 1),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 10, 1)',
          '  Flexible Rect(0, 0, 3, 1)',
          '    SizedBox Rect(0, 0, 3, 1)',
        ].join('\n'),
      );
    });
  });

  group('flex validation', () {
    test('rejects a zero or negative flex factor', () {
      expect(() => Flexible<String>(flex: 0, child: _box(1, 1)), throwsA(isA<AssertionError>()));
      expect(() => Flexible<String>(flex: -1, child: _box(1, 1)), throwsA(isA<AssertionError>()));
    });

    test('asserts a flexible child under an unbounded main axis', () {
      final row = Row<String>(children: [Expanded<String>(child: _box(0, 1))]);
      expect(() => row.layout(const BoxConstraints(maxH: 5), _ctx), throwsA(isA<AssertionError>()));
    });

    test('an unbounded main axis is fine when no child is flexible', () {
      final golden = _golden(
        Row<String>(mainAxisSize: MainAxisSize.min, children: [_box(2, 1), _box(3, 1)]),
        const BoxConstraints(maxH: 5),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 5, 1)',
          '  SizedBox Rect(0, 0, 2, 1)',
          '  SizedBox Rect(2, 0, 3, 1)',
        ].join('\n'),
      );
    });

    test('mixes a flexible child with inflexible ones under a bounded axis', () {
      final golden = _golden(
        Row<String>(
          children: [
            _box(3, 1),
            Expanded<String>(child: _box(0, 1)),
            _box(2, 1),
          ],
        ),
        const BoxConstraints(maxW: 10, maxH: 1),
      );
      expect(
        golden,
        [
          'Row Rect(0, 0, 10, 1)',
          '  SizedBox Rect(0, 0, 3, 1)',
          '  Expanded Rect(3, 0, 5, 1)',
          '    SizedBox Rect(3, 0, 5, 1)',
          '  SizedBox Rect(8, 0, 2, 1)',
        ].join('\n'),
      );
    });
  });

  group('space distribution remainder', () {
    // Three unit-wide children in a 14-wide row leave free = 11, an odd split
    // for every space-* mode. The remainder goes to the leading gaps, so the
    // last child reaches the trailing edge exactly.
    List<int> childXs(MainAxisAlignment alignment) {
      final children = [_box(1, 1), _box(1, 1), _box(1, 1)];
      Row<String>(mainAxisAlignment: alignment, children: children)
        ..layout(const BoxConstraints(maxW: 14, maxH: 1), _ctx)
        ..place(Offset.zero);
      return [for (final child in children) child.rect.x];
    }

    test('spaceBetween biases the remainder to the leading gap', () {
      // gaps [6, 5]: last child at 13 ends flush against the 14-wide edge.
      expect(childXs(MainAxisAlignment.spaceBetween), [0, 7, 13]);
    });

    test('spaceAround biases the remainder to the leading half-gaps', () {
      expect(childXs(MainAxisAlignment.spaceAround), [2, 7, 12]);
    });

    test('spaceEvenly biases the remainder to the leading gaps', () {
      expect(childXs(MainAxisAlignment.spaceEvenly), [3, 7, 11]);
    });

    test('an even split leaves no remainder to bias', () {
      // free = 12 over the same three children divides cleanly for spaceBetween.
      final children = [_box(1, 1), _box(1, 1), _box(1, 1)];
      Row<String>(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: children)
        ..layout(const BoxConstraints(maxW: 15, maxH: 1), _ctx)
        ..place(Offset.zero);
      expect([for (final child in children) child.rect.x], [0, 7, 14]);
    });
  });

  group('grow-to-fit modal (0037 worked example)', () {
    Center<String> buildModal() => Center<String>(
      child: ConstrainedBox<String>(
        additionalConstraints: const BoxConstraints(maxW: 24),
        child: Container<String>(
          border: 'border',
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Column<String>(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text<String>(
                [const TextRun('please confirm this action', 'body')],
                softWrap: true,
                align: TextAlign.center,
              ),
              SizedBox<String>(height: 1),
              Row<String>(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_box(6, 1), _box(1, 1), _box(8, 1)],
              ),
            ],
          ),
        ),
      ),
    );

    test('centers a box that grew to hold wrapped text and right-aligned buttons', () {
      expect(
        _golden(buildModal(), BoxConstraints.tight(const Size(40, 12))),
        [
          'Center Rect(0, 0, 40, 12)',
          '  ConstrainedBox Rect(8, 3, 24, 6)',
          '    Container Rect(8, 3, 24, 6)',
          '      Column Rect(10, 4, 20, 4)',
          '        Text Rect(10, 4, 20, 2)',
          '        SizedBox Rect(10, 6, 20, 1)',
          '        Row Rect(10, 7, 20, 1)',
          '          SizedBox Rect(15, 7, 6, 1)',
          '          SizedBox Rect(21, 7, 1, 1)',
          '          SizedBox Rect(22, 7, 8, 1)',
        ].join('\n'),
      );
    });
  });
}
