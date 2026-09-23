import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

/// The analyzer plugin front end. Rules are registered in M3.
class AgentLintsPlugin extends Plugin {
  @override
  String get name => 'agent_lints';

  @override
  void register(PluginRegistry registry) {}
}
