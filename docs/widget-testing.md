# Widget Testing

Visual testing for widget authors. Test what renders, not buffer internals.

## Quickstart

```dart
import 'package:kiko/kiko.dart';
import 'package:kiko/testing.dart';
import 'package:test/test.dart';

void main() {
  test('paragraph renders', () {
    final p = Paragraph(content: 'Hello World');

    expect(
      capture(p, width: 20, height: 1),
      equals('Hello World'),
    );
  });
}
```

## Choosing an API

| API              | Use When                          |
| ---------------- | --------------------------------- |
| `capture()`      | Simple one-off captures           |
| `rendersAs()`    | Clean inline assertions           |
| `WidgetTester`   | Multiple tests with shared config |
| `CaptureBuilder` | Async setup (data loading)        |
| `captureWith()`  | Complex sync setup                |

### capture() vs rendersAs()

**capture() + equals():**

```dart
final result = capture(widget, width: 20, height: 2);
expect(result, equals('Hello\nWorld'));
```

- More explicit
- Easier to debug (print `result`)
- Good for complex assertions

**rendersAs():**

```dart
expect(widget, rendersAs('Hello\nWorld', width: 20, height: 2));
```

- More readable intent
- Less boilerplate
- Better failure messages with line numbers

Both are valid. Use what reads best for your test.

## WidgetTester

Recommended for test files. Create one tester with shared defaults:

```dart
void main() {
  final tester = WidgetTester(
    defaultWidth: 40,
    defaultHeight: 10,
  );

  test('renders title', () {
    expect(
      tester.capture(MyWidget()),
      equals('Expected output'),
    );
  });

  test('with custom size', () {
    expect(
      tester.capture(MyWidget(), width: 80, height: 24),
      equals('...'),
    );
  });
}
```

### Configuration

```dart
WidgetTester(
  defaultWidth: 80,           // default capture width
  defaultHeight: 24,          // default capture height
  emptyCellMarker: '.',       // char for empty cells (default '·')
  trimTrailingWhitespace: true,
  stripBlankLines: true,
)
```

### WidgetTester Methods

```dart
// Sync capture
String capture(Widget, {width, height, showBorder, showEmptyCells})
CaptureResult captureResult(Widget, {...})

// With callback
String captureWith(void Function(CaptureTester), {...})
CaptureResult captureWithResult(void Function(CaptureTester), {...})

// Async
Future<String> captureAsync(FutureOr<void> Function(CaptureTester), {...})
Future<CaptureResult> captureAsyncResult(..., {...})

// Matcher
Matcher rendersAs(String expected, {width, height, ...})
```

## CaptureBuilder (Async)

For async setup like loading data before rendering:

```dart
test('tree with loaded data', () async {
  final result = await CaptureBuilder(width: 30, height: 5)
    .setup((t) async {
      final model = TreeViewModel(dataSource: source);
      await model.loadRoots();
      await model.expand('/parent');
      t.render(TreeView(model: model));
    })
    .capture();

  expect(result, equals('''
▼ Parent
   Child 1
   Child 2
▶ Other
'''));
});
```

Primary use: waiting for `await model.load()` calls before capture.

## Setting Up Widget State

### 1. Methods Before Capture

```dart
test('selected item highlighted', () {
  final model = ListViewModel(items: ['A', 'B', 'C']);
  model.selectIndex(1);  // set state before capture

  expect(
    capture(ListView(model: model), width: 10, height: 3),
    equals('  A\n> B\n  C'),
  );
});
```

### 2. Builder Pattern

```dart
test('tree expanded', () async {
  final result = await CaptureBuilder(width: 30, height: 5)
    .setup((t) async {
      final model = TreeViewModel(dataSource: source);
      await model.loadRoots();
      model.expand('/a');  // state manipulation in setup
      t.render(TreeView(model: model));
    })
    .capture();

  expect(result, contains('▼ a'));
});
```

### 3. Inject Pre-Configured Model

```dart
TreeViewModel createExpandedTree() {
  final model = TreeViewModel(dataSource: TestDataSource());
  model.forceRoots([...]);  // test helper
  model.expandAll();
  return model;
}

test('fully expanded tree', () {
  final model = createExpandedTree();
  expect(
    TreeView(model: model),
    rendersAs('...', width: 40, height: 10),
  );
});
```

## Dimension Strategies

### Tight Dimensions

Match capture size to expected content:

```dart
test('renders 3 items', () {
  expect(
    capture(widget, width: 10, height: 3),  // exactly 3 lines
    equals('''
Item 1
Item 2
Item 3'''),
  );
});
```

Good for: simple widgets, exact output verification.

### Loose Dimensions

Larger capture area, let whitespace trimming handle rest:

```dart
test('layout adapts', () {
  final result = capture(widget, width: 80, height: 24);
  expect(result, contains('Expected content'));
});
```

Good for: layout testing, widgets that expand to fill.

### Visualize Bounds

Use `showBorder` to see exact widget area:

```dart
test('verify widget bounds', () {
  expect(
    capture(widget, width: 10, height: 3, showBorder: true),
    equals('''
+----------+
|  Hello   |
|  World   |
|          |
+----------+'''),
  );
});
```

Border is outside dimensions (10x3 content, 12x5 total output).

## Debugging Failed Tests

### 1. Check Failure Output

Matcher shows line-by-line comparison:

```
Expected:
  1: ▼ Parent
  2:    Child 1
  3:    Child 2

Actual:
  1: ▼ Parent
  2:   Child 1    <- differs
  3:    Child 2
```

- Line numbers are 1-indexed
- `<- differs` marks mismatched lines
- Look at column alignment (spaces matter)

### 2. Use showBorder

See if widget is rendering in expected area:

```dart
print(capture(widget, width: 20, height: 5, showBorder: true));
```

If content is clipped or offset, bounds are wrong.

### 3. Use showEmptyCells

Reveal whitespace vs empty cells:

```dart
print(capture(widget, width: 20, height: 1, showEmptyCells: true));
// Output: "Hello···············"
```

Helps identify:

- Trailing space issues
- Unexpected gaps
- Empty vs space-filled areas

### 4. Print Actual Output

When using `capture()`, print the result:

```dart
final result = capture(widget, width: 20, height: 5);
print('---');
print(result);
print('---');
expect(result, equals('...'));
```

## Common Pitfalls

### Trailing Whitespace

By default, trailing whitespace is trimmed per line:

```dart
capture(Paragraph(content: 'Hi'), width: 20, height: 1)
// Returns "Hi", not "Hi                  "
```

To preserve trailing spaces:

```dart
capture(widget, width: 20, height: 1, trimTrailingWhitespace: false)
```

### Dart Multiline String Quirks

Dart's `'''` strings add newlines:

```dart
// This has a leading newline after ''' and trailing before closing '''
expect(widget, rendersAs('''
Hello
World
''', width: 10, height: 2));
```

The library normalizes this automatically:

- Strips leading newline after opening `'''`
- Strips trailing newline before closing `'''`

### Blank Lines Stripped

By default, leading/trailing blank lines are stripped from both actual and expected:

```dart
// These are equivalent:
capture(widget, width: 10, height: 5)

// Actual buffer has 5 lines, but if last 2 are blank:
// Output is only 3 lines (blank lines stripped)
```

To preserve blank lines:

```dart
capture(widget, width: 10, height: 5, stripBlankLines: false)
```

### Widget Larger Than Area

If widget renders beyond capture dimensions, content is clipped:

```dart
// Widget renders 5 lines, capture is only 3
capture(LongWidget(), width: 20, height: 3)
// Only first 3 lines captured
```

Use larger dimensions or `showBorder` to verify.

### Tab Characters

Tabs in expected strings may not match. Widget likely renders as spaces:

```dart
// May fail - tab vs spaces mismatch
expect(result, equals("Name:\tValue"));

// Use spaces explicitly
expect(result, equals("Name:    Value"));
```

### Empty Cells vs Spaces

Empty cells (never written to) and spaces (explicitly written) both appear as spaces:

```dart
// Can't tell if widget wrote spaces or left cells empty
capture(widget, width: 10, height: 1)
// Returns "Hello     " or "Hello" (trimmed)
```

Use `showEmptyCells: true` to distinguish:

```dart
capture(widget, width: 10, height: 1, showEmptyCells: true)
// "Hello·····" - dots show empty cells
// "Hello     " - spaces were written explicitly
```

## Unicode Considerations

### Wide Characters

CJK characters and some emoji take 2 terminal columns:

```dart
// "你好" takes 4 columns (2 chars × 2 width)
capture(Paragraph(content: '你好'), width: 10, height: 1)
```

Width calculation uses `termunicode`. Generally accurate but some terminals differ.

### Combining Characters

Diacritics (é = e + combining acute) may not render correctly:

```dart
// "café" might appear as 5 chars if combining char handled wrong
capture(Paragraph(content: 'café'), width: 10, height: 1)
```

Use precomposed forms (é) when possible.

### Emoji

Complex emoji (skin tones, ZWJ sequences) may have inconsistent width:

```dart
// 👨‍👩‍👧‍👦 is one "grapheme" but width varies by terminal
capture(Paragraph(content: '👨‍👩‍👧‍👦'), width: 10, height: 1)
```

Test on your target terminal. Simple emoji (😀) work reliably.

## API Reference

### capture()

Render widget to string.

```dart
String capture(
  Widget widget, {
  required int width,
  required int height,
  bool showBorder = false,        // ASCII border around content
  bool showEmptyCells = false,    // Replace empty cells with marker
  String emptyCellMarker = '·',   // Marker character
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,    // Strip surrounding blank lines
})
```

### captureResult()

Render widget with metadata.

```dart
CaptureResult captureResult(
  Widget widget, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = '·',
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
})
```

Returns `CaptureResult`:

```dart
class CaptureResult {
  final String content;      // rendered string
  final int width;
  final int height;
  List<String> get lines;    // content.split('\n')

  String toString() => content;
}
```

### captureWith()

Render with callback for complex setup.

```dart
String captureWith(
  void Function(CaptureTester) callback, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = '·',
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
})
```

`CaptureTester` provides:

```dart
class CaptureTester {
  Rect get area;
  Frame get frame;
  Buffer get buffer;

  void render(Widget widget, [Rect? area]);
}
```

### CaptureBuilder

Builder for async setup.

```dart
final result = await CaptureBuilder(
  width: 40,
  height: 10,
  showBorder: false,
  showEmptyCells: false,
  emptyCellMarker: '·',
  trimTrailingWhitespace: true,
  stripBlankLines: true,
)
  .setup((CaptureTester t) async {
    // async setup here
    t.render(widget);
  })
  .capture();         // Future<String>
  // or .captureResult()  // Future<CaptureResult>
```

### rendersAs()

Matcher for widget assertions.

```dart
Matcher rendersAs(
  String expected, {
  required int width,
  required int height,
  bool showBorder = false,
  bool showEmptyCells = false,
  String emptyCellMarker = '·',
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
})
```

Usage:

```dart
expect(widget, rendersAs('Hello', width: 10, height: 1));
```

### WidgetTester

Configurable tester for multiple captures.

```dart
WidgetTester({
  int defaultWidth = 80,
  int defaultHeight = 24,
  String emptyCellMarker = '·',
  bool trimTrailingWhitespace = true,
  bool stripBlankLines = true,
  bool includeStyles = false,    // reserved for future
})
```

Methods:

```dart
// Sync
String capture(Widget, {int? width, int? height, bool showBorder, bool showEmptyCells})
CaptureResult captureResult(Widget, {...})
String captureWith(void Function(CaptureTester), {...})
CaptureResult captureWithResult(void Function(CaptureTester), {...})

// Async
Future<String> captureAsync(FutureOr<void> Function(CaptureTester), {...})
Future<CaptureResult> captureAsyncResult(..., {...})

// Matcher
Matcher rendersAs(String expected, {int? width, int? height, ...})
```
