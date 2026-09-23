import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'agent_lints_rule.dart';

/// The analyzer plugin front end. Enable it in the root
/// `analysis_options.yaml`:
///
/// ```yaml
/// plugins:
///   agent_lints: ^0.1.0
/// ```
class AgentLintsPlugin extends Plugin {
  AgentLintsPlugin() : rule = AgentLintsRule();

  final AgentLintsRule rule;

  @override
  String get name => 'agent_lints';

  @override
  void register(PluginRegistry registry) {
    // A warning rule is enabled by default; the YAML decides what runs.
    registry.registerWarningRule(rule);
  }
}
