import 'dart:convert';

import '../../cli/version.dart';
import '../run_result.dart';
import 'formatter.dart';

class JsonFormatter extends Formatter {
  @override
  String format(RunResult result) {
    final map = {
      'version': 1,
      'tool': {'name': 'agent_lints', 'version': packageVersion},
      'summary': {
        'errors': result.errors,
        'warnings': result.warnings,
        'infos': result.infos,
        'files_checked': result.filesChecked,
        'files_with_issues': result.filesWithIssues,
        'duration_ms': result.duration.inMilliseconds,
        'exit_code': result.exitCode,
      },
      'config_errors': [
        for (final e in result.configErrors)
          {
            'message': e.message,
            if (e.path != null) 'path': e.path,
            if (e.hint != null) 'hint': e.hint,
            if (e.span != null) 'line': e.span!.start.line + 1,
            if (e.span != null) 'column': e.span!.start.column + 1,
          },
      ],
      'violations': [for (final v in result.violations) v.toJson()],
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}
