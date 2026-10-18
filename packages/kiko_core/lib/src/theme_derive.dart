import 'package:meta/meta.dart';

import 'colors.dart';
import 'theme.dart';
import 'tone.dart';

/// The WCAG 2 contrast ratios `deriveTheme` holds a theme to.
///
/// Read them to state the same targets in your own checks. Ratios come from
/// [Color.contrastRatio].
abstract final class ContrastTargets {
  /// What `Theme.muted` needs against `background` and `surface`.
  static const double muted = 4.5;

  /// What `Theme.disabled` needs against `background` and `surface`.
  static const double disabled = 3;

  /// What `Theme.border` needs against `background` and `surface`.
  static const double border = 1.5;

  /// What a role's `on` color needs against its own `color`.
  static const double onFill = 4.5;

  /// What an intent color used as ink needs against `background`, `surface`
  /// and `selection`.
  static const double ink = 3;
}

/// One color that `deriveTheme` replaced.
///
/// [name] is the theme field: `border`, `muted` or `disabled`. [failedGrounds]
/// lists the grounds where [from] missed [target]. [before] is the worst ratio
/// [from] reached. [after] is the worst ratio [to] reaches; it is below
/// [target] only when no color of that hue and chroma can meet it.
@immutable
class RungChange {
  /// Creates a record of one replaced color.
  const RungChange({
    required this.name,
    required this.from,
    required this.to,
    required this.failedGrounds,
    required this.before,
    required this.after,
    required this.target,
  });

  /// The theme field that changed.
  final String name;

  /// The published color.
  final Color from;

  /// The color that replaced it.
  final Color to;

  /// The grounds, `background` or `surface`, where [from] missed [target].
  final List<String> failedGrounds;

  /// The worst contrast ratio [from] reached on either ground.
  final double before;

  /// The worst contrast ratio [to] reaches on either ground.
  final double after;

  /// The ratio the color needed.
  final double target;

  @override
  bool operator ==(Object other) =>
      other is RungChange &&
      other.name == name &&
      other.from == from &&
      other.to == to &&
      _sameList(other.failedGrounds, failedGrounds) &&
      other.before == before &&
      other.after == after &&
      other.target == target;

  @override
  int get hashCode => Object.hash(name, from, to, Object.hashAll(failedGrounds), before, after, target);

  @override
  String toString() =>
      '$name ${_hex(from)} reads ${_ratio(before)} on ${failedGrounds.join(' and ')} '
      '(needs ${_ratio(target)}); changed to ${_hex(to)}, which reads ${_ratio(after)}';
}

/// One published color that fails a check and stays as published.
///
/// A role color belongs to the palette, so `deriveTheme` reports it and does
/// not change it.
@immutable
class KeptFailure {
  /// Creates a record of one failing check.
  const KeptFailure({required this.name, required this.check, required this.ratio, required this.target});

  /// The theme field that fails: `primary`, `error`, `selection` and so on.
  final String name;

  /// What was measured: `text on its fill`, `ink on background`, `ink on
  /// surface` or `ink on selection`.
  final String check;

  /// The contrast ratio the check measured.
  final double ratio;

  /// The ratio the check needed.
  final double target;

  @override
  bool operator ==(Object other) =>
      other is KeptFailure &&
      other.name == name &&
      other.check == check &&
      other.ratio == ratio &&
      other.target == target;

  @override
  int get hashCode => Object.hash(name, check, ratio, target);

  @override
  String toString() => '$name $check reads ${_ratio(ratio)} (needs ${_ratio(target)}); kept as published';
}

/// What `deriveTheme` did to a theme.
///
/// [changes] lists the colors it replaced. [leftAlone] lists the published
/// role colors that fail a check and stay as published. Print the report with
/// `toString()`.
@immutable
class DerivationReport {
  /// Creates a report from its two lists.
  const DerivationReport({this.changes = const [], this.leftAlone = const []});

  /// The colors `deriveTheme` replaced.
  final List<RungChange> changes;

  /// The published role colors that fail a check and were kept.
  final List<KeptFailure> leftAlone;

  /// Whether `deriveTheme` replaced any color.
  bool get hasChanges => changes.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is DerivationReport && _sameList(other.changes, changes) && _sameList(other.leftAlone, leftAlone);

  @override
  int get hashCode => Object.hash(Object.hashAll(changes), Object.hashAll(leftAlone));

  @override
  String toString() {
    final lines = <String>[
      if (changes.isEmpty)
        'No color changed.'
      else ...[
        'Changed ${changes.length} ${changes.length == 1 ? 'color' : 'colors'}:',
        for (final change in changes) '  $change',
      ],
      if (leftAlone.isEmpty)
        'No published color fails a check.'
      else ...[
        'Kept ${leftAlone.length} failing ${leftAlone.length == 1 ? 'check' : 'checks'} as published:',
        for (final kept in leftAlone) '  $kept',
      ],
    ];
    return lines.join('\n');
  }
}

/// Returns [source] with `border`, `muted` and `disabled` made readable, and a
/// report of what changed.
///
/// Call it on a theme you build. Every published role color stays as
/// published. A rung changes only when it misses its target on `background`
/// or on `surface` (see [ContrastTargets]). The new color keeps the rung's hue
/// and chroma and moves in OKLab lightness, away from `background`, until it
/// meets the target on both grounds.
///
/// A role color that fails a check goes in [DerivationReport.leftAlone]: each
/// role's `on` against its own color, and each intent color as ink against
/// `background`, `surface` and `selection`. The framework never calls this
/// for you. A theme that needs no change comes back equal to [source].
///
/// `Theme.background` must carry a color.
(Theme, DerivationReport) deriveTheme(Theme source) {
  final background = source.background.color;
  assert(background != null, 'A theme needs a background color.');
  final grounds = [
    ('background', background!),
    if (source.surface.color != null) ('surface', source.surface.color!),
  ];

  final changes = <RungChange>[];
  Tone rung(String name, Tone published, double target) {
    final change = _solveRung(name, published.color, grounds, target);
    if (change == null) return published;
    changes.add(change);
    return Tone(color: change.to);
  }

  final border = rung('border', source.border, ContrastTargets.border);
  final disabled = rung('disabled', source.disabled, ContrastTargets.disabled);
  final muted = rung('muted', source.muted, ContrastTargets.muted);

  final theme = source.copyWith(
    border: identical(border, source.border) ? null : border,
    muted: identical(muted, source.muted) ? null : muted,
    disabled: identical(disabled, source.disabled) ? null : disabled,
    tones16: source.tones16,
  );
  return (theme, DerivationReport(changes: changes, leftAlone: _keptFailures(source)));
}

RungChange? _solveRung(String name, Color? published, List<(String, Color)> grounds, double target) {
  if (published == null) return null;
  final failed = [
    for (final (groundName, ground) in grounds)
      if (published.contrastRatio(ground) < target) groundName,
  ];
  if (failed.isEmpty) return null;
  final colors = [for (final (_, ground) in grounds) ground];
  final solved = solveReadable(published, away: colors.first, grounds: colors, target: target);
  return RungChange(
    name: name,
    from: published,
    to: solved,
    failedGrounds: failed,
    before: _worst(published, colors),
    after: _worst(solved, colors),
    target: target,
  );
}

List<KeptFailure> _keptFailures(Theme theme) {
  final kept = <KeptFailure>[];
  final inkGrounds = [
    ('background', theme.background.color),
    ('surface', theme.surface.color),
    ('selection', theme.selection.color),
  ];
  void check(String name, String check, Color a, Color b, double target) {
    final ratio = a.contrastRatio(b);
    if (ratio < target) kept.add(KeptFailure(name: name, check: check, ratio: ratio, target: target));
  }

  final intents = [
    ('primary', theme.primary),
    ('secondary', theme.secondary),
    ('accent', theme.accent),
    ('error', theme.error),
    ('warning', theme.warning),
    ('success', theme.success),
  ];
  for (final (name, tone) in [...intents, ('selection', theme.selection)]) {
    final color = tone.color;
    if (color == null) continue;
    check(name, 'text on its fill', tone.on, color, ContrastTargets.onFill);
  }
  for (final (name, tone) in intents) {
    final color = tone.color;
    if (color == null) continue;
    for (final (groundName, ground) in inkGrounds) {
      if (ground != null) check(name, 'ink on $groundName', color, ground, ContrastTargets.ink);
    }
  }
  return kept;
}

/// The color with [published]'s hue and chroma whose lightness is the closest
/// one that reads at [target] on every color in [grounds].
///
/// Lightness moves away from [away] in steps of 0.005: lighter when [away] is
/// dark, darker when it is light. A [published] color that already meets the
/// target comes back unchanged. When the walk reaches black or white without
/// meeting the target, the best color found comes back.
Color solveReadable(Color published, {required Color away, required List<Color> grounds, required double target}) {
  if (_worst(published, grounds) >= target) return published;
  const stepSize = 0.005;
  final lab = published.toOklab();
  final direction = away.toOklab().l < 0.5 ? 1 : -1;
  var best = published;
  var bestRatio = _worst(published, grounds);
  for (var i = 1; i <= 200; i++) {
    final l = lab.l + direction * stepSize * i;
    final candidate = Oklab(l.clamp(0.0, 1.0), lab.a, lab.b).toColor();
    final ratio = _worst(candidate, grounds);
    if (ratio > bestRatio) {
      best = candidate;
      bestRatio = ratio;
    }
    if (ratio >= target) return candidate;
    if (l <= 0 || l >= 1) break;
  }
  return best;
}

double _worst(Color color, List<Color> grounds) => grounds.map(color.contrastRatio).reduce((a, b) => a < b ? a : b);

/// The ratio `Theme.system` gives its text and intent colors on both grounds.
const double _systemTarget = 4.5;

/// Builds `Theme.system`; see that method.
Theme deriveSystemTheme(Color? probed) {
  if (probed == null) return Theme.dark;
  const base = Theme.dark;
  final lightens = probed.toOklab().l < 0.5;
  final sign = lightens ? 1 : -1;
  final surfaceColor = probed.shiftLightness(sign * Theme.step);
  final grounds = [probed, surfaceColor];

  final text = solveReadable(
    base.background.on,
    away: probed,
    grounds: grounds,
    target: _systemTarget,
  );
  SurfaceTone intent(SurfaceTone published) {
    final color = solveReadable(published.color!, away: probed, grounds: grounds, target: _systemTarget);
    final on = color.contrastRatio(probed) >= color.contrastRatio(text) ? probed : text;
    return SurfaceTone(color: color, on: on);
  }

  final selectionLab = base.selection.color!.toOklab();
  final selectionColor = Oklab(
    (probed.toOklab().l + sign * 2 * Theme.step).clamp(0.0, 1.0),
    selectionLab.a,
    selectionLab.b,
  ).toColor();

  final system = base.copyWith(
    name: 'System',
    primary: intent(base.primary),
    secondary: intent(base.secondary),
    accent: intent(base.accent),
    error: intent(base.error),
    warning: intent(base.warning),
    success: intent(base.success),
    background: SurfaceTone(color: probed, on: text),
    surface: SurfaceTone(color: surfaceColor, on: text),
    selection: SurfaceTone(color: selectionColor, on: text),
  );
  return deriveTheme(system).$1;
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(Color color) => '#${color.toRgb().value.toRadixString(16).padLeft(6, '0')}';

String _ratio(double value) => value.toStringAsFixed(2);
