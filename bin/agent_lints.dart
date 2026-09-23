import 'dart:io';

import 'package:agent_lints/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  exitCode = await AgentLintsRunner().run(args);
}
