import 'dart:io';

import 'package:args/command_runner.dart';

import '../../config/errors.dart';
import '../../config/loader.dart';
import '../exit_codes.dart';
import '../project_files.dart';

/// Validates the YAML only. The fast loop for an agent editing rules.
class ValidateCommand extends Command<int> {
  ValidateCommand({required this.out, required this.err}) {
    argParser.addOption('config', help: 'Path to agent_lints.yaml.');
  }

  final StringSink out;
  final StringSink err;

  @override
  String get name => 'validate';

  @override
  String get description => 'Validate agent_lints.yaml without analyzing code.';

  @override
  Future<int> run() async {
    final project = Project.find(configPath: argResults!['config'] as String?);
    if (project == null) {
      err.writeln('agent_lints: no agent_lints.yaml found.');
      return ExitCodes.config;
    }
    final warnings = <ConfigError>[];
    try {
      final config = ConfigLoader(warnings: warnings.add).load(
        content: File(project.configPath).readAsStringSync(),
        configPath: project.configPath,
        rootPath: project.rootPath,
        packageName: project.packageName,
      );
      for (final w in warnings) {
        out.writeln('[warning] ${w.format()}');
      }
      final enabled = config.rules.where((r) => r.enabled).length;
      out.writeln(
        'agent_lints.yaml is valid: ${config.rules.length} rule'
        '${config.rules.length == 1 ? '' : 's'} ($enabled enabled), '
        '${config.values.length} values list${config.values.length == 1 ? '' : 's'}.',
      );
      return ExitCodes.ok;
    } on ConfigException catch (e) {
      for (final error in e.errors) {
        out.writeln('[config] ${error.format()}');
      }
      out.writeln();
      out.writeln(
        '${e.errors.length} error${e.errors.length == 1 ? '' : 's'} '
        'in agent_lints.yaml. Fix them and re-run: dart run agent_lints validate',
      );
      return ExitCodes.config;
    }
  }
}
