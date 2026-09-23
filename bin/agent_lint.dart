import 'dart:io';

import 'package:agent_lint/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  exitCode = await AgentLintRunner().run(args);
}
