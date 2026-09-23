import '../run_result.dart';
import 'formatter.dart';

/// One line per violation, in the shape of `dart analyze`.
class HumanFormatter extends Formatter {
  @override
  String format(RunResult result) {
    final b = StringBuffer();
    for (final e in result.configErrors) {
      b.writeln('config error • ${e.format()}');
    }
    if (result.configErrors.isNotEmpty) return b.toString();
    for (final v in result.violations) {
      b.writeln(
        '${v.relativePath}:${v.line}:${v.column} • ${v.severity.name} • '
        '${v.shortMessage} • ${v.ruleId}',
      );
    }
    for (final w in result.configWarnings) {
      b.writeln('config warning • ${w.format()}');
    }
    final n = result.violations.length;
    b.writeln(
      n == 0
          ? 'No issues found.'
          : '$n issue${n == 1 ? '' : 's'} found. '
                'Run `dart run agent_lints --format agent` for suggestions.',
    );
    return b.toString();
  }
}
