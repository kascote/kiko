import 'package:kiko/kiko.dart';

// Page 3: the contrast audit. A placeholder for now — it renders only the
// page title.

/// Page 3 of the theme viewer: a placeholder for the contrast audit.
///
/// Renders only the page title. A later task fills this page with a
/// contrast comparison, one row per pair that matters.
View contrastPage(StyleResolver resolver) => Line('Contrast', style: resolver.ink(resolver.tones.secondary));
