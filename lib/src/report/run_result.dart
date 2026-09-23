import '../config/config.dart';
import '../config/errors.dart';
import 'violation.dart';

/// Everything a formatter needs to print a `check` run.
class RunResult {
  RunResult({
    required this.violations,
    required this.filesChecked,
    required this.duration,
    required this.failOn,
    required this.configPath,
    this.configErrors = const [],
    this.configWarnings = const [],
    this.suppressed = const [],
    this.showSuppressed = false,
  });

  final List<Violation> violations;
  final int filesChecked;
  final Duration duration;
  final Severity failOn;
  final String configPath;
  final List<ConfigError> configErrors;
  final List<ConfigError> configWarnings;

  /// Violations silenced by `// ignore:` comments.
  final List<Violation> suppressed;

  /// Whether formatters should list [suppressed].
  final bool showSuppressed;

  int get errors =>
      violations.where((v) => v.severity == Severity.error).length;
  int get warnings =>
      violations.where((v) => v.severity == Severity.warning).length;
  int get infos => violations.where((v) => v.severity == Severity.info).length;
  int get filesWithIssues =>
      violations.map((v) => v.relativePath).toSet().length;

  bool get failed =>
      configErrors.isNotEmpty || violations.any((v) => v.severity >= failOn);

  int get exitCode {
    if (configErrors.isNotEmpty) return 2;
    return violations.any((v) => v.severity >= failOn) ? 1 : 0;
  }
}
