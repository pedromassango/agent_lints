import 'dart:io';

import 'package:args/command_runner.dart';

import 'exit_codes.dart';
import 'version.dart';

/// Entry point shared by `bin/agent_lint.dart` and tests.
class AgentLintRunner {
  AgentLintRunner({StringSink? out, StringSink? err})
    : out = out ?? stdout,
      err = err ?? stderr;

  final StringSink out;
  final StringSink err;

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>(
      'agent_lint',
      'Agent-first custom lint for Dart and Flutter. Rules live in agent_lint.yaml.',
    )..argParser.addFlag('version', negatable: false, help: 'Print the version.');
    try {
      final results = runner.parse(args);
      if (results['version'] == true) {
        out.writeln('agent_lint $packageVersion');
        return ExitCodes.ok;
      }
      return await runner.runCommand(results) ?? ExitCodes.ok;
    } on UsageException catch (e) {
      err.writeln(e);
      return ExitCodes.usage;
    }
  }
}
