import 'package:kiko/kiko.dart';
import 'package:kiko_widgets/kiko_widgets.dart';
import 'package:test/test.dart';

Frame _frame(int width, int height) {
  final buffer = Buffer.empty(Rect.create(x: 0, y: 0, width: width, height: height));
  return Frame(buffer.area, buffer, 0);
}

String _dump(Buffer buffer) {
  final out = StringBuffer();
  final area = buffer.area;
  for (var y = area.top; y < area.bottom; y++) {
    final row = StringBuffer();
    for (var x = area.left; x < area.right; x++) {
      final cell = buffer[(x: x, y: y)];
      if (cell.skip) continue;
      row.write(cell.symbol.isEmpty ? ' ' : cell.symbol);
    }
    out.writeln(row.toString().trimRight());
  }
  return out.toString();
}

void main() {
  group('modalDialog', () {
    test('tags the dialog with the given id', () {
      final dialog = modalDialog(id: 'confirm', content: (_) => Line('Sure?'), resolver: StyleResolver(Theme.dark));
      final frame = _frame(10, 3)..render(NodeView(dialog));
      expect(frame.hits.rectOf('confirm'), isNotNull);
    });
  });

  group('centeredRect', () {
    test('centres a fixed size within an origin-zero area', () {
      final rect = centeredRect(area: Rect.create(x: 0, y: 0, width: 20, height: 10), width: 6, height: 4);
      expect(rect, Rect.create(x: 7, y: 3, width: 6, height: 4));
    });

    test('offsets by the area origin, so the result is frame-absolute', () {
      final rect = centeredRect(area: Rect.create(x: 2, y: 5, width: 20, height: 10), width: 6, height: 4);
      expect(rect, Rect.create(x: 9, y: 8, width: 6, height: 4));
    });
  });

  group('renderModalOverlay', () {
    test('paints only the base when there is no dialog', () {
      final frame = _frame(10, 3);
      renderModalOverlay(
        frame,
        base: (_) => Line('base').build(),
        resolver: StyleResolver(Theme.dark),
        width: 4,
        height: 1,
      );
      expect(_dump(frame.buffer), contains('base'));
    });

    test('hands the base the plain resolver when no dialog is open', () {
      final resolver = StyleResolver(Theme.dark);
      StyleResolver? seen;
      renderModalOverlay(
        _frame(10, 3),
        base: (r) {
          seen = r;
          return Line('base').build();
        },
        resolver: resolver,
        width: 4,
        height: 1,
      );
      expect(seen, same(resolver));
      expect(seen!.isDeEmphasised, isFalse);
    });

    test('hands the base the de-emphasised resolver while a dialog is open', () {
      final resolver = StyleResolver(Theme.dark);
      final dialog = modalDialog(id: 'confirm', content: (_) => Line('Sure?'), resolver: resolver);
      StyleResolver? seen;
      renderModalOverlay(
        _frame(10, 3),
        base: (r) {
          seen = r;
          return Line('base').build();
        },
        resolver: resolver,
        width: 8,
        height: 3,
        dialog: dialog,
        id: 'confirm',
      );
      expect(seen!.isDeEmphasised, isTrue);
    });

    test('de-emphasises the host chrome and widgets behind an open dialog', () {
      final resolver = StyleResolver(Theme.dark);
      final button = ButtonModel(id: 'ok', label: Line(' OK '));
      Node host(StyleResolver r) => Container(
        border: BorderType.plain,
        borderStyle: r.border(const {}),
        child: Row(
          children: [Button(model: button, resolver: r)],
        ),
      ).build();

      Frame render({required bool open}) {
        final frame = _frame(20, 8);
        renderModalOverlay(
          frame,
          base: host,
          resolver: resolver,
          width: 10,
          height: 4,
          dialog: open ? modalDialog(id: 'confirm', content: (_) => Line('Sure?'), resolver: resolver) : null,
          id: open ? 'confirm' : null,
        );
        return frame;
      }

      final open = render(open: true);
      final closed = render(open: false);
      final quiet = resolver.deEmphasised;

      // The border at the corner, outside the dialog rect.
      expect(open.buffer[(x: 0, y: 0)].fg, quiet.border(const {}).fg);
      expect(open.buffer[(x: 0, y: 0)].fg, isNot(closed.buffer[(x: 0, y: 0)].fg));

      // The button face inside the border.
      final face = open.buffer[(x: 2, y: 1)];
      expect(face.bg, quiet.fill(resolver.tones.primary).bg);
      expect(face.bg, isNot(closed.buffer[(x: 2, y: 1)].bg));

      // The quiet colors sit between the plain ones and the ground.
      final ground = resolver.ground(resolver.tones.background).bg!.toOklab().l;
      final plain = closed.buffer[(x: 2, y: 1)].bg.toOklab().l;
      expect((face.bg.toOklab().l - ground).abs(), lessThan((plain - ground).abs()));
    });

    test('a press outside the dialog resolves to the modal, never to the base tree under the backdrop', () {
      // A tagged widget in the top-left corner of the base, well outside
      // the centred dialog.
      final resolver = StyleResolver(Theme.dark);
      final base = Column(children: [Tagged('ok', Line('OK'))]).build();
      final dialog = modalDialog(id: 'confirm', content: (_) => Line('Sure?'), resolver: resolver);
      final frame = _frame(20, 8);
      renderModalOverlay(
        frame,
        base: (_) => base,
        resolver: resolver,
        width: 10,
        height: 4,
        dialog: dialog,
        id: 'confirm',
      );

      final outside = frame.hits.hitId(0, 0);
      expect(outside, isNotNull, reason: 'the modal claims the whole frame');
      expect(outside, isNot('ok'), reason: 'the widget under the backdrop is unreachable while the modal is open');
      expect(
        HitTag.resolve(outside!, {'confirm'}),
        'confirm',
        reason: 'the outside press is addressed to the modal, so the app routes it like any other',
      );
      expect(
        frame.hits.regionAt(outside, 0, 0),
        const ModalBarrierRegion(),
        reason: 'the barrier marks itself, so the modal can tell an outside press from one on the dialog',
      );
    });
  });

  group('renderModalOverlay / layer compositing', () {
    const width = 20;
    const height = 8;
    const dialogWidth = 10;
    const dialogHeight = 4;

    Node buildDialog(StyleResolver resolver) =>
        modalDialog(id: 'confirm', content: (_) => Line('Sure?'), resolver: resolver);

    for (final policy in RenderPolicy.values) {
      test('the dialog replaces the base rect cleanly, never blended with it ($policy)', () {
        StyleResolver.defaultPolicy = policy;
        addTearDown(() => StyleResolver.defaultPolicy = RenderPolicy.color);
        final resolver = StyleResolver(Theme.dark, policy: policy);

        // A styled base: a colored (or reversed, under noColor) fill plus a
        // bold, reversed span, covering the whole frame under the dialog rect.
        final baseFill = resolver.fill(Theme.dark.selection);
        final spanStyle = resolver.ink(Theme.dark.error).incModifier(Modifier.bold | Modifier.reversed);
        Node buildBase() => Container(
          width: width,
          height: height,
          ground: baseFill,
          child: Column(children: [for (var i = 0; i < height; i++) Line('B' * width, style: spanStyle)]),
        ).build();

        final frame = _frame(width, height);
        renderModalOverlay(
          frame,
          base: (_) => buildBase(),
          resolver: resolver,
          width: dialogWidth,
          height: dialogHeight,
          dialog: buildDialog(resolver),
          id: 'confirm',
        );

        final rect = centeredRect(area: frame.area, width: dialogWidth, height: dialogHeight);

        // Render the same dialog alone into a buffer matching just the rect,
        // so we know exactly what a clean composite looks like.
        final isolated = Buffer.empty(rect);
        Frame(isolated.area, isolated, 0).render(NodeView(buildDialog(resolver)));

        for (var y = rect.top; y < rect.bottom; y++) {
          for (var x = rect.left; x < rect.right; x++) {
            final composited = frame.buffer[(x: x, y: y)];
            final alone = isolated[(x: x, y: y)];
            expect(
              composited,
              anyOf(equals(alone), equals(Cell.empty())),
              reason:
                  '($x,$y) inside the dialog rect must be dialog content or empty — never base '
                  'glyphs, backgrounds, or modifiers showing through',
            );
          }
        }
      });
    }

    test('the quiet host look never reaches the dialog layer', () {
      final resolver = StyleResolver(Theme.dark);
      final frame = _frame(width, height);
      renderModalOverlay(
        frame,
        base: (r) => Container(
          width: width,
          height: height,
          ground: r.ground(r.tones.background),
          child: const SizedBox(width: width, height: height),
        ).build(),
        resolver: resolver,
        width: dialogWidth,
        height: dialogHeight,
        dialog: buildDialog(resolver),
        id: 'confirm',
      );

      final rect = centeredRect(area: frame.area, width: dialogWidth, height: dialogHeight);

      // Inside the rect, the dialog matches a standalone render built from the
      // plain resolver.
      final isolated = Buffer.empty(rect);
      Frame(isolated.area, isolated, 0).render(NodeView(buildDialog(resolver)));
      for (var y = rect.top; y < rect.bottom; y++) {
        for (var x = rect.left; x < rect.right; x++) {
          expect(
            frame.buffer[(x: x, y: y)],
            isolated[(x: x, y: y)],
            reason: 'dialog cell ($x,$y) must match a plain render — the host look never reaches the layer',
          );
        }
      }
    });
  });
}
