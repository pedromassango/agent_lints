import 'dart:convert';

import 'package:agent_lints/agent_lints.dart';
import 'package:test/test.dart';

Violation _violation({
  String rule = 'no_print',
  Severity severity = Severity.error,
  String? suggest = "AppLog.d('x')",
  String? docs,
}) => Violation(
  ruleId: rule,
  severity: severity,
  path: '/p/lib/a.dart',
  relativePath: 'lib/a.dart',
  offset: 10,
  length: 8,
  line: 2,
  column: 3,
  endLine: 2,
  endColumn: 11,
  found: "print('x')",
  message: '`print` ships to release logs.\nUse AppLog.d instead.',
  shortMessage: '`print` ships to release logs.',
  suggest: suggest,
  docs: docs,
  captures: const {'name': 'print', 'args.0': "'x'"},
);

RunResult _result(
  List<Violation> violations, {
  List<ConfigError> errors = const [],
}) => RunResult(
  violations: violations,
  filesChecked: 12,
  duration: const Duration(milliseconds: 1234),
  failOn: Severity.warning,
  configPath: '/p/agent_lints.yaml',
  configErrors: errors,
);

void main() {
  group('AgentFormatter', () {
    test('renders a block per violation and a summary', () {
      final out = AgentFormatter().format(
        _result([
          _violation(docs: 'docs/logging.md'),
          _violation(rule: 'other', severity: Severity.warning, suggest: null),
        ]),
      );
      expect(out, '''
[error] no_print  lib/a.dart:2:3
  found    print('x')
  why      `print` ships to release logs.
           Use AppLog.d instead.
  suggest  AppLog.d('x')
  docs     docs/logging.md
  ignore   // ignore: agent_lints/no_print -- <reason>

[warning] other  lib/a.dart:2:3
  found    print('x')
  why      `print` ships to release logs.
           Use AppLog.d instead.
  ignore   // ignore: agent_lints/other -- <reason>

agent_lints: 1 error, 1 warning, 0 info in 1 file  (12 files checked, 1.2s)
exit 1  (fail_on: warning). Run `dart run agent_lints explain <rule>` for the full contract.
''');
    });

    test('prints config errors and nothing else', () {
      final out = AgentFormatter().format(
        _result(
          const [],
          errors: [
            ConfigError(
              'unknown key "rulez"',
              path: 'rulez',
              hint: 'did you mean "rules"?',
            ),
          ],
        ),
      );
      expect(
        out,
        contains(
          '[config] agent_lints.yaml rulez: unknown key "rulez" (did you mean "rules"?)',
        ),
      );
      expect(out, contains('nothing was checked (exit 2)'));
    });

    test('clean run', () {
      final out = AgentFormatter().format(_result(const []));
      expect(
        out,
        'agent_lints: 0 errors, 0 warnings, 0 info in 0 files  (12 files checked, 1.2s)\n',
      );
    });
  });

  test('HumanFormatter is one line per violation', () {
    final out = HumanFormatter().format(_result([_violation()]));
    expect(out, '''
lib/a.dart:2:3 • error • `print` ships to release logs. • no_print
1 issue found. Run `dart run agent_lints --format agent` for suggestions.
''');
  });

  test('JsonFormatter emits summary and violations', () {
    final out = JsonFormatter().format(_result([_violation()]));
    final json = jsonDecode(out) as Map<String, Object?>;
    expect(json['summary'], {
      'errors': 1,
      'warnings': 0,
      'infos': 0,
      'files_checked': 12,
      'files_with_issues': 1,
      'duration_ms': 1234,
      'exit_code': 1,
      'suppressed': 0,
    });
    final v = (json['violations'] as List).single as Map<String, Object?>;
    expect(v['rule'], 'no_print');
    expect(v['range'], {
      'start': {'line': 2, 'column': 3, 'offset': 10},
      'end': {'line': 2, 'column': 11, 'offset': 18},
    });
    expect(v['suggest'], "AppLog.d('x')");
    expect((v['context'] as Map).containsKey('args.0'), isFalse);
  });

  test('RunResult exit codes honour fail_on', () {
    final warningOnly = RunResult(
      violations: [_violation(severity: Severity.warning)],
      filesChecked: 1,
      duration: Duration.zero,
      failOn: Severity.error,
      configPath: 'x',
    );
    expect(warningOnly.exitCode, 0);
    expect(warningOnly.failed, isFalse);
  });
}
