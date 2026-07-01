import 'package:plume/plume.dart';
import 'package:test/test.dart';

import 'golden.dart';

/// A container that parks each child at a fixed offset and fills its space.
class _Group<S> extends RenderNode<S> {
  _Group(this._children, this._offsets);

  final List<RenderNode<S>> _children;
  final List<Offset> _offsets;

  @override
  List<RenderNode<S>> get children => _children;

  @override
  Size performLayout(BoxConstraints constraints) {
    for (var i = 0; i < _children.length; i++) {
      _children[i].layout(constraints.loosen());
      _children[i].offset = _offsets[i];
    }
    return constraints.biggest;
  }
}

/// A leaf that fills its rect, so it emits a paint intent.
class _Dot<S> extends RenderNode<S> {
  _Dot(this.style, {this.w = 1, this.h = 1});

  final S style;
  final int w;
  final int h;

  @override
  Size performLayout(BoxConstraints constraints) => constraints.constrain(Size(w, h));

  @override
  void paintSelf(Surface<S> surface) => surface.fillRect(rect, style);
}

_Group<String> _tree() => _Group<String>(
  [_Dot('a', w: 2, h: 2), _Dot('b', w: 3, h: 3)],
  const [Offset(1, 1), Offset(4, 0)],
);

void main() {
  group('layoutGolden', () {
    test('dumps each node type and rect, indented by depth', () {
      const expected =
          '_Group Rect(0, 0, 10, 5)\n'
          '  _Dot Rect(1, 1, 2, 2)\n'
          '  _Dot Rect(4, 0, 3, 3)';
      expect(layoutGolden(_tree(), const Size(10, 5)), expected);
    });
  });

  group('paintGolden', () {
    test('lists the intents each leaf emits, in paint order', () {
      expect(paintGolden(_tree(), const Size(10, 5)), [
        'fillRect(Rect(1, 1, 2, 2), a)',
        'fillRect(Rect(4, 0, 3, 3), b)',
      ]);
    });

    test('a bare SizedBox emits nothing', () {
      expect(paintGolden(SizedBox<String>(width: 3, height: 1), const Size(3, 1)), isEmpty);
    });
  });
}
