import 'dart:io';

import 'package:args/command_runner.dart';

import 'exit_codes.dart';
import 'version.dart';

/// Entry point shared by `bin/agent_lints.dart` and tests.
class AgentLintsRunner {
  AgentLintsRunner({StringSink? out, StringSink? err})
    : out = out ?? stdout,
      err = err ?? stderr;

  final StringSink out;
  final StringSink err;

  Future<int> run(List<String> args) async {
    final runner = CommandRunner<int>(
      'agent_lints',
      'Agent-first custom lint for Dart and Flutter. Rules live in agent_lints.yaml.',
    )..argParser.addFlag('version', negatable: false, help: 'Print the version.');
    try {
      final results = runner.parse(args);
      if (results['version'] == true) {
        out.writeln('agent_lints $packageVersion');
        return ExitCodes.ok;
      }
      return await runner.runCommand(results) ?? ExitCodes.ok;
    } on UsageException catch (e) {
      err.writeln(e);
      return ExitCodes.usage;
    }
  }
}
