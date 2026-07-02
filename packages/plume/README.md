# Plume

A Flutter-style, solver-free layout engine for cell grids (TUIs).

Plume owns **geometry only**: it lays a tree of nodes out — constraints flow
down, sizes flow up — and emits draw intents against an injected surface. It has
no dependency on any terminal backend or styling system, so the same engine can
render to a terminal buffer, a test recorder, or anything else. If you know
Flutter's box model, you already know Plume: `BoxConstraints` down, `Size` up,
parents place children, leaves paint.

## The mental model

A frame builds a fresh tree, then drives it through the same passes every time:

1. **`layout(constraints)`** — each node sizes itself within the constraints its
   parent handed it, laying out and sizing its own children along the way.
   Constraints flow down; sizes flow up.
2. **`place(origin)`** — each node's absolute rect is fixed from its parent's
   origin plus the offset assigned during layout.
3. **`paint(surface)`** — each node emits its draw intents, then its children on
   top. A node is clipped to its own rect (intersected with every ancestor's),
   so it can only paint within the box layout gave it.
4. **`hitTest(point)`** — finds the top-most node under a point. Runs per input
   event, not per frame, and is deliberately **not** clipped.

Two things are injected so the engine never touches a terminal:

- a **`TextMeasurer`** — how wide a string is in cells (the only
  backend-specific primitive; tests use `MonospaceMeasurer`);
- a **`Surface`** — the sink draw intents go to (`RecordingSurface` for tests, a
  buffer-backed one for a real terminal).

Appearance (style, color, charset) rides in an **opaque paint token** (`T`)
carried straight through to the surface; the engine never looks inside it.

## A minimal frame

`renderFrame` runs `layout → place → paint` in one call. This is the whole
example (`example/main.dart`):

```dart
import 'package:plume/plume.dart';

void main() {
  // The paint token is opaque — the engine carries it but never inspects it;
  // here plain strings; a terminal backend would use its own token type.
  final tree = Container<String>(
    border: 'grey',
    child: Column<String>(
      children: [
        Text<String>([const TextRun('Hello, Plume', 'title')]),
        Text<String>([const TextRun('layout without a solver', 'body')]),
      ],
    ),
  );

  final surface = RecordingSurface<String>();
  renderFrame(tree, const Rect(0, 0, 27, 4), surface);

  surface.intents.forEach(print);
}
```

It prints the draw intents the tree emits, in paint order:

```
drawBorder(Rect(0, 0, 27, 4), grey)
drawText(1, 1, "Hello, Plume", title)
drawText(1, 2, "layout without a solver", body)
```

A real backend swaps `RecordingSurface` for one that writes into a terminal
buffer; nothing else about the tree changes.

## What's here

- **Geometry** — `Rect`, `Size`, `Offset`, `EdgeInsets`, and `BoxConstraints`
  (the down-the-tree bounds).
- **Layout widgets** — `Row`/`Column` (`Flex`), `Stack`/`Positioned`, `Overlay`,
  `Container`, `Padding`, `Align`, `ConstrainedBox`, `SizedBox`.
- **Text** — a `Text` leaf with wrapping, `maxLines`, alignment, and overflow.
- **Painting** — the `Surface` sink, the `ClippingSurface` base that enforces
  the paint-side clip, `RecordingSurface`, and the `DrawIntent` types.

Clipping is a paint-side guarantee: after a frame, no cell is written outside the
intersection of a node's rect with all its ancestors'.
