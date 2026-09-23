import '../run_result.dart';
import '../violation.dart';
import 'formatter.dart';

/// Block-per-violation output written for LLM agents: fixed keys, stable
/// order, no colour, nothing empty.
class AgentFormatter extends Formatter {
  @override
  String format(RunResult result) {
    final b = StringBuffer();
    for (final e in result.configErrors) {
      b.writeln('[config] ${e.format()}');
    }
    if (result.configErrors.isNotEmpty) {
      b.writeln();
      b.writeln('agent_lints: config invalid, nothing was checked (exit 2).');
      b.writeln(
        'Fix the errors above, then run: dart run agent_lints validate',
      );
      return b.toString();
    }
    for (final v in result.violations) {
      _block(b, v);
      b.writeln();
    }
    if (result.showSuppressed && result.suppressed.isNotEmpty) {
      b.writeln('suppressed by // ignore comments:');
      for (final v in result.suppressed) {
        b.writeln('  ${v.ruleId}  ${v.relativePath}:${v.line}  ${v.found}');
      }
      b.writeln();
    }
    for (final w in result.configWarnings) {
      b.writeln('[warning] ${w.format()}');
    }
    final secs = (result.duration.inMilliseconds / 1000).toStringAsFixed(1);
    b.writeln(
      'agent_lints: ${result.errors} error${_s(result.errors)}, '
      '${result.warnings} warning${_s(result.warnings)}, '
      '${result.infos} info in ${result.filesWithIssues} file${_s(result.filesWithIssues)}'
      '  (${result.filesChecked} files checked, ${secs}s)',
    );
    if (result.violations.isNotEmpty) {
      b.writeln(
        'exit ${result.exitCode}  (fail_on: ${result.failOn.name}). '
        'Run `dart run agent_lints explain <rule>` for the full contract.',
      );
    }
    return b.toString();
  }

  void _block(StringBuffer b, Violation v) {
    b.writeln(
      '[${v.severity.name}] ${v.ruleId}  ${v.relativePath}:${v.line}:${v.column}',
    );
    _line(b, 'found', v.found);
    _multi(b, 'why', v.message);
    if (v.suggest != null && v.suggest!.isNotEmpty) {
      _line(b, 'suggest', v.suggest!);
    }
    if (v.docs != null) _line(b, 'docs', v.docs!);
    _line(b, 'ignore', v.ignoreComment);
  }

  static void _line(StringBuffer b, String key, String value) {
    b.writeln('  ${key.padRight(9)}$value');
  }

  static void _multi(StringBuffer b, String key, String value) {
    final lines = value.trim().split('\n');
    _line(b, key, lines.first.trim());
    for (final l in lines.skip(1)) {
      b.writeln('  ${''.padRight(9)}${l.trim()}');
    }
  }

  static String _s(int n) => n == 1 ? '' : 's';
}
