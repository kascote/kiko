import 'package:kiko/kiko.dart';
import 'package:test/test.dart';

/// A frame over a fresh [width]×[height] buffer.
Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

/// A bordered box holding [label].
View _box(String label) => Container(border: BorderType.plain, child: Line(label));

/// A widget that tags its own root node, like a self-tagging built-in widget
/// (e.g. `TextInputView`'s `..tag = IdTag(model.id)`).
final class _SelfTagging implements View {
  const _SelfTagging(this.id);

  final String id;

  @override
  Node build() => _box('').build()..tag = IdTag(id);
}

void main() {
  group('Tagged', () {
    test('makes its child addressable after render', () {
      final frame = _frame(4, 3)..render(Tagged('ok', _box('')));

      expect(frame.hits.hitId(0, 0), 'ok');
      expect(frame.hits.hitId(2, 1), 'ok');
      expect(frame.hits.rectOf('ok'), Rect.create(x: 0, y: 0, width: 4, height: 3));
    });

    test('tags the node its child builds, so the rect is where the child landed', () {
      final frame = _frame(8, 5)
        ..render(
          Center(
            child: ConstrainedBox(
              additionalConstraints: const BoxConstraints(minW: 4, maxW: 4, minH: 3, maxH: 3),
              child: Tagged('inner', _box('')),
            ),
          ),
        );

      expect(frame.hits.rectOf('inner'), Rect.create(x: 2, y: 1, width: 4, height: 3));
    });

    test('nesting resolves the innermost tag', () {
      final frame = _frame(6, 5)
        ..render(
          Tagged(
            'outer',
            Container(
              border: BorderType.plain,
              child: Tagged('inner', _box('')),
            ),
          ),
        );

      expect(frame.hits.hitId(0, 0), 'outer'); // the outer border
      expect(frame.hits.hitId(2, 2), 'inner'); // inside the inner box
    });

    test('nesting reports both tags on the hit path, outermost first', () {
      final frame = _frame(6, 5)
        ..render(
          Tagged(
            'outer',
            Container(
              border: BorderType.plain,
              child: Tagged('inner', _box('')),
            ),
          ),
        );

      expect(frame.hits.hitPath(2, 2).map((h) => h.id), ['outer', 'inner']);
    });

    test('changes neither layout nor painted cells', () {
      final plain = _frame(6, 3)..render(_box('hi'));
      final tagged = _frame(6, 3)..render(Tagged('t', _box('hi')));

      expect(tagged.buffer.buf, plain.buffer.buf);
      expect(tagged.hits.rectOf('t'), Rect.create(x: 0, y: 0, width: 6, height: 3));
    });

    test('two Tagged siblings sharing an id trip the hit map assert', () {
      // Uniqueness is enforced where every tag is visible — a Tagged cannot see
      // what its siblings tagged.
      final frame = _frame(6, 3)
        ..render(
          Row(
            children: [
              Expanded(child: Tagged('dup', _box(''))),
              Expanded(child: Tagged('dup', _box(''))),
            ],
          ),
        );

      expect(() => frame.hits, throwsA(isA<AssertionError>()));
    });

    test('asserts against wrapping a child that already tags itself', () {
      final frame = _frame(4, 3);

      expect(
        () => frame.render(const Tagged('outer', _SelfTagging('inner'))),
        throwsA(isA<AssertionError>()),
      );
    });

    test('still works when wrapped around an untagged child', () {
      final frame = _frame(4, 3)..render(Tagged('t', _box('')));

      expect(frame.hits.hitId(0, 0), 't');
    });
  });
}
