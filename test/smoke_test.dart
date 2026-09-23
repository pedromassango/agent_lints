import 'package:agent_lints/src/cli/runner.dart';
import 'package:test/test.dart';

void main() {
  test('--version prints the version', () async {
    final out = StringBuffer();
    final code = await AgentLintsRunner(
      out: out,
      err: StringBuffer(),
    ).run(['--version']);
    expect(code, 0);
    expect(out.toString(), startsWith('agent_lints '));
  });
}
