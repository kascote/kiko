// coverage:ignore-file
//
import 'package:meta/meta.dart';
import 'package:plume/plume.dart' as plume;

import '../buffer.dart';
import '../layout/position.dart';
import '../layout/rect.dart';
import '../plume/buffer_surface.dart';
import '../plume/paint_token.dart';
import '../plume/view.dart';
import 'hit_map.dart';

/// A consistent view into the terminal state for rendering a single frame.
///
/// This is obtained via the closure argument of [Terminal.draw()]. It is used to
/// render widgets to the terminal and control the cursor position.
///
/// The changes drawn to the frame are applied only to the current [Buffer].
/// After the closure returns, the current buffer is compared to the previous
/// buffer and only the changes are applied to the terminal. This avoids
/// drawing redundant cells.
class Frame {
  /// Where should the cursor be after drawing this frame?
  ///
  /// If `null`, the cursor is hidden and its position is controlled by the
  /// backend. If has value, the cursor is shown and placed at `(x, y)` after
  /// the call to `Terminal.draw()`
  Position? cursorPosition;

  /// The area of the viewport
  final Rect area;

  /// The buffer that is used to draw the current frame
  final Buffer buffer;

  /// The frame count indicating the sequence number of this frame
  final int count;

  /// Cells the terminal wrote on the previous flush — the size of the last
  /// buffer diff.
  ///
  /// This frame's own diff is not known until it flushes, so this reports the
  /// frame currently on screen: how many cells the double buffer redrew to put
  /// it there. A small change is a handful of cells; a full repaint is the whole
  /// viewport. Zero on the first frame.
  final int lastDiffCount;

  /// The Plume trees rendered into this frame, in paint order.
  ///
  /// [renderNode] appends each laid-out root here so [hits] can address it after
  /// the fact; later roots paint on top, so they are searched first.
  final List<plume.RenderNode<PaintToken>> _nodeRoots = <plume.RenderNode<PaintToken>>[];

  HitMap? _hits;

  /// Creates a new frame with the given area and buffer.
  Frame(this.area, this.buffer, this.count, {this.lastDiffCount = 0});

  /// The tagged geometry of this frame, as far as it has been painted.
  ///
  /// Rendering a view adds to it, so a tag resolves only once its subtree has
  /// rendered — read this after the render that places what you are asking
  /// about. That ordering enforces itself: an unrendered node is not in the tree
  /// to be found.
  ///
  /// Use it inside `view` to anchor one widget against another painted before
  /// it. To route a mouse event, use the map the runtime hands `update` instead:
  /// that one describes the frame the pointer was actually over, where this one
  /// describes the frame being built now.
  HitMap get hits => _hits ??= HitMap.fromRoots(_nodeRoots);

  /// Renders a [view] into this frame — the entry point for drawing a UI.
  ///
  /// Pass the root view of your interface. It is inflated to a fresh plume node
  /// tree, laid out tight to [area], its text measured the way kiko paints it,
  /// and the result written into this frame's [buffer].
  ///
  /// Text is measured with [buffer]'s own [Buffer.measurer] — the ruler the
  /// owning `Terminal` settled on for this session — so layout and paint never
  /// disagree about how wide a glyph is.
  void render(View view) => renderNode(view.build());

  /// Renders a Plume layout [node] tree into this frame.
  ///
  /// Pass the root of a Plume tree whose leaves carry kiko [PaintToken]s. The
  /// tree is laid out tight to [area], its text measured the way kiko paints
  /// it, and the result written into this frame's [buffer].
  ///
  /// Text is measured with [buffer]'s own [Buffer.measurer]; see [render].
  ///
  /// The laid-out tree is retained so [hits] can address any node that carries a
  /// `tag` after this returns.
  ///
  /// This is the low-level seam behind [render]; compose [View]s and call
  /// [render] instead of building plume nodes and calling this directly.
  @internal
  void renderNode(plume.RenderNode<PaintToken> node) {
    final surface = _paint(node, buffer, area);
    _nodeRoots.add(node);
    _hits = null;
    // A focused text field painted through the surface reports where the cursor
    // belongs; carry it up to this frame.
    final cursor = surface.cursor;
    if (cursor != null) cursorPosition = cursor;
  }

  /// Renders [view] into its own scratch buffer, then composites it opaquely
  /// onto this frame over [rect].
  ///
  /// Use it for a popup, a modal, or anything else that must sit cleanly on top
  /// of what is already painted rather than blending with it: a plain
  /// [renderNode] paints through the base pass's cells directly, so a spot the
  /// view leaves unpainted still shows whatever the base drew there. A layer
  /// paints into a fresh, empty buffer first, so an unpainted spot inside
  /// [rect] comes out empty — the base is fully replaced, not shown through.
  ///
  /// [view] is laid out tight to [rect], not this frame's [area]; a rect that
  /// runs outside the frame is clipped where it composites. A standing
  /// [cursorPosition] inside [rect] is dropped before compositing, since the
  /// layer just replaced that cell — it is restored only if the layer's own
  /// content claims the cursor there.
  void renderLayer(View view, Rect rect) {
    final node = view.build();
    final scratch = Buffer.empty(rect, measurer: buffer.measurer);
    final surface = _paint(node, scratch, rect);
    buffer.blitFrom(scratch, rect);

    final standing = cursorPosition;
    if (standing != null && rect.contains(standing)) cursorPosition = null;
    final cursor = surface.cursor;
    if (cursor != null) cursorPosition = cursor;

    _nodeRoots.add(node);
    _hits = null;
  }

  /// Lays [node] out tight to [rect] and paints it into [target].
  ///
  /// The shared walk behind [renderNode] and [renderLayer]: both drive the same
  /// plume layout-and-paint pass, differing only in which buffer receives the
  /// cells and which rect the tree is laid out against.
  BufferSurface _paint(plume.RenderNode<PaintToken> node, Buffer target, Rect rect) {
    final surface = BufferSurface(target);
    plume.renderFrame(
      node,
      plume.Rect(rect.x, rect.y, rect.width, rect.height),
      surface,
      measurer: target.measurer,
    );
    return surface;
  }

  /// Dims all cell colors in the buffer toward black.
  ///
  /// Used to create a backdrop effect for modals.
  ///
  /// Note: This always performs the dim operation regardless of terminal
  /// profile. For noColor terminals, the dimmed RGB values are computed but
  /// ignored at render time. If this becomes a perf issue, could check
  /// `Platform.environment['NO_COLOR']` directly, but prefer letting termlib
  /// handle profile detection consistently.
  void dimBackdrop({double factor = 0.3}) {
    for (var i = 0; i < buffer.buf.length; i++) {
      final cell = buffer.buf[i];
      buffer.buf[i] = cell.copyWith(
        fg: cell.fg.dim(factor: factor),
        bg: cell.bg.dim(factor: factor, isBackground: true),
      );
    }
  }
}

/// [CompletedFrame] represents the state of the terminal after all changes
/// performed in the last [Terminal.draw()] call have been applied. Therefore,
/// it is only valid until the next call to [Terminal.draw()].
class CompletedFrame {
  /// The buffer that was used to draw the last frame
  final Buffer buffer;

  /// The area of the viewport the frame was drawn into, the same area the
  /// [Frame] carried. For a full screen viewport this is the whole terminal;
  /// for an inline or fixed one it is the part of it the application owns.
  final Rect area;

  /// The frame count indicating the sequence number of this frame
  final int count;

  /// The tagged geometry of the frame that was just committed.
  ///
  /// These are the pixels the user is looking at, so this is the map a mouse
  /// event arriving now should resolve against. The runtime keeps it for exactly
  /// that; an application rarely reads it here.
  final HitMap hits;

  /// Creates a new completed frame with the given area and buffer.
  const CompletedFrame(this.buffer, this.area, this.count, {required this.hits});
}
