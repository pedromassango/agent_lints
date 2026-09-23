/// Process exit codes used by the CLI.
abstract final class ExitCodes {
  /// No violations at or above `fail_on`.
  static const ok = 0;

  /// Violations at or above `fail_on` were found.
  static const violations = 1;

  /// `agent_lints.yaml` is invalid; nothing was checked.
  static const config = 2;

  /// The project could not be analyzed (missing pubspec, pub get needed, ...).
  static const analysis = 3;

  /// Unexpected internal error.
  static const internal = 4;

  /// Bad command-line usage.
  static const usage = 64;
}
