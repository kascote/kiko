import 'package:meta/meta.dart';

/// Single shared monotonic counter backing [autoId].
int _autoIdCounter = 0;

/// Generates a globally-unique, human-readable id of the form `'<prefix>-<n>'`.
///
/// Backed by a single shared monotonic counter, so ids are unique across *all*
/// prefixes (`autoId('tableview')` → `'tableview-1'`, then `autoId('listview')`
/// → `'listview-2'`). Used to address widget models in widget→app commands when
/// the author does not supply an explicit id.
///
/// The type prefix keeps logs readable; the shared counter keeps ids unique
/// across types. Because the counter is monotonic, an omitted id is always a
/// *safe* address — it just is not a *memorable* one, so pass an explicit id
/// when the app matches against a literal (`id == 'usersTable'`).
///
/// Auto ids are **not stable across runs and not unique across isolates** — the
/// counter is per-isolate and resets each run. That is fine, because ids never
/// cross isolates by design. Pass an explicit id when matching must survive a
/// restart.
String autoId(String prefix) => '$prefix-${++_autoIdCounter}';

/// Resets the [autoId] counter to zero.
///
/// Test-only: lets a test assert on exact auto-id values (`'tableview-1'`)
/// without other tests perturbing the shared counter.
@visibleForTesting
void resetAutoIdCounter() => _autoIdCounter = 0;
