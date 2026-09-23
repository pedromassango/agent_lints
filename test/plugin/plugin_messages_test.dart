import 'package:agent_lints/agent_lints.dart';
import 'package:agent_lints/src/plugin/plugin_messages.dart';
import 'package:test/test.dart';

Violation _v({
  String message = 'a. b.',
  String? useInstead,
  String? suggest,
  String? docs,
}) => Violation(
  ruleId: 'r',
  severity: Severity.warning,
  path: '/p/lib/a.dart',
  relativePath: 'lib/a.dart',
  offset: 0,
  length: 1,
  line: 1,
  column: 1,
  endLine: 1,
  endColumn: 2,
  found: 'x',
  message: message,
  shortMessage: 'a.',
  useInstead: useInstead,
  suggest: suggest,
  docs: docs,
);

void main() {
  test('problem keeps every sentence on one line', () {
    expect(
      PluginMessages.problem(_v(message: 'First.\n  Second   line.')),
      'First. Second line.',
    );
  });

  test('problem cuts very long messages at a word', () {
    final long = List.filled(120, 'word').join(' ');
    final out = PluginMessages.problem(_v(message: long));
    expect(out.length, lessThanOrEqualTo(PluginMessages.maxProblemLength + 1));
    expect(out, endsWith('word…'));
  });

  test('correction lists use_instead, suggest, docs and explain', () {
    expect(
      PluginMessages.correction(
        _v(useInstead: 'AppLog', suggest: 'AppLog.d(x)', docs: 'docs/log.md'),
      ),
      'Use AppLog.  Suggest: AppLog.d(x)  See docs/log.md.  Explain: dart run agent_lints explain r',
    );
    expect(
      PluginMessages.correction(_v()),
      'Explain: dart run agent_lints explain r',
    );
  });
}
