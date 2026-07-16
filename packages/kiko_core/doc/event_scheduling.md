## Event Scheduling Architecture

### Overview

Unified event stream where all sources push to single FIFO queue. FrameTick drives rendering with coalescing support.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Terminal events ──────┐                                    │
│                        │                                    │
│  User Tick timer ──────┼──► Unified Queue ──┐               │
│                        │                    │               │
│  AsyncCmd results ─────┘                    │               │
│                                             ▼               │
│  FrameTick timer ──────────────────────► MAIN LOOP          │
│  (60fps, always on)                        │                │
│                                             ▼               │
│                                    ┌─────────────────┐      │
│                                    │ 1. Coalesce     │      │
│                                    │ 2. Drop stale   │      │
│                                    │ 3. Update model │      │
│                                    │ 4. Render       │      │
│                                    └─────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Event Sources

| Source          | Description                   | Coalesceable     | Droppable      |
| --------------- | ----------------------------- | ---------------- | -------------- |
| Terminal events | Keys, mouse, focus, paste     | Mouse moves only | No             |
| FrameTick       | Internal render timer (60fps) | No               | Yes (if stale) |
| Tick            | User timer for app logic      | No               | No             |
| AsyncCmd        | Async task completions        | No               | No             |

### Processing Flow

1. **Coalesce** - merge repeated mouse moves/drags (keep latest)
2. **Get message** - FIFO from unified queue
3. **Drop stale** - skip FrameTickMsg older than 2 frame intervals
4. **Update model** - process message through update function
5. **Render** - only on FrameTickMsg

### Key Types

**Msg properties:**

- `droppable` - can be skipped when stale (FrameTickMsg only)
- `coalesceable` - can be merged with same coalesceKey
- `coalesceKey` - grouping key for coalescing

**FrameTickMsg:**

- `delta` - time since last frame
- `frameNumber` - monotonic counter
- `timestamp` - for staleness check

### Configuration

```dart
Application(
  fps: 60,          // frame rate (default 60)
  eventTimeout: 10, // poll timeout in ms
)
```

### Implementation

- `MvuRuntime.coalesceQueue()` - merges coalesceable messages
- `MvuRuntime.isStale(msg, fps)` - checks if droppable message is stale
- `MvuRuntime.subscribeToEvents(stream)` - subscribes to terminal events
- `Terminal.events` - broadcast stream of parsed events

### Benefits

- True fairness: events processed in arrival order
- No starvation: fast ticks interleave with fast mouse
- Consistent frame rate with FrameTick
- Reduced processing via coalescing
- Graceful degradation via frame dropping

### Migration Guide

**New in this version:**

1. **`fps` parameter** - Control frame rate (default 60)

   ```dart
   Application(fps: 30)  // lower fps for less CPU usage
   ```

2. **FrameTickMsg** - Internal message driving render loop
   - Rendering now happens at consistent intervals
   - No need to handle in update function (unless you want delta timing)

3. **Mouse coalescing** - Automatic for moves/drags
   - High-frequency mouse events merged between frames
   - Only latest position processed

**No breaking changes** - existing code works unchanged:

- `eventTimeout` still works (poll fallback)
- `Tick` command unchanged (user timers)
- All existing Msg types unchanged
