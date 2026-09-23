import 'package:agent_lint/src/cli/runner.dart';
import 'package:test/test.dart';

void main() {
  test('--version prints the version', () async {
    final out = StringBuffer();
    final code = await AgentLintRunner(
      out: out,
      err: StringBuffer(),
    ).run(['--version']);
    expect(code, 0);
    expect(out.toString(), startsWith('agent_lint '));
  });
}
