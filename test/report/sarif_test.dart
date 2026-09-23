import 'dart:convert';

import 'package:agent_lints/agent_lints.dart';
import 'package:test/test.dart';

void main() {
  test('SarifFormatter emits rules and results', () {
    final config = ConfigLoader().load(
      content: '''
version: 1
rules:
  no_print:
    severity: error
    description: no print
    docs: https://example.com/no-print
    match: { call: print }
    message: "no print"
''',
      configPath: '/p/agent_lints.yaml',
      rootPath: '/p',
    );
    final v = Violation(
      ruleId: 'no_print',
      severity: Severity.error,
      path: '/p/lib/a.dart',
      relativePath: 'lib/a.dart',
      offset: 0,
      length: 5,
      line: 1,
      column: 1,
      endLine: 1,
      endColumn: 6,
      found: 'print',
      message: 'no print',
      shortMessage: 'no print',
      suggest: 'log()',
    );
    final out = SarifFormatter(rules: config.rules).format(
      RunResult(
        violations: [v],
        filesChecked: 1,
        duration: Duration.zero,
        failOn: Severity.warning,
        configPath: '/p/agent_lints.yaml',
      ),
    );
    final sarif = jsonDecode(out) as Map<String, Object?>;
    final run = (sarif['runs'] as List).single as Map<String, Object?>;
    final driver = ((run['tool'] as Map)['driver'] as Map);
    expect(driver['name'], 'agent_lints');
    final rule = (driver['rules'] as List).single as Map;
    expect(rule['id'], 'no_print');
    expect(rule['helpUri'], 'https://example.com/no-print');
    expect((rule['defaultConfiguration'] as Map)['level'], 'error');
    final result = (run['results'] as List).single as Map;
    expect(result['ruleId'], 'no_print');
    expect(result['level'], 'error');
    expect((result['message'] as Map)['text'], 'no print\nSuggest: log()');
    final loc =
        ((result['locations'] as List).single as Map)['physicalLocation']
            as Map;
    expect((loc['artifactLocation'] as Map)['uri'], 'lib/a.dart');
    expect((loc['region'] as Map)['startLine'], 1);
  });
}
