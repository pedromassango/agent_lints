import 'dart:io';

import 'package:path/path.dart' as p;

import '../cli/project_files.dart';
import '../config/config.dart';
import '../config/errors.dart';
import '../config/loader.dart';
import '../engine/engine.dart';

/// A loaded config plus the engine built from it, or the errors that
/// prevented loading.
class LoadedProject {
  LoadedProject({
    required this.configPath,
    required this.modified,
    this.config,
    this.engine,
    this.errors = const [],
  });

  final String configPath;
  final DateTime modified;
  final AgentLintsConfig? config;
  final Engine? engine;
  final List<ConfigError> errors;
}

/// Finds and caches `agent_lints.yaml` per project root for the plugin.
/// Reloads when the file's modification time changes.
class ConfigCache {
  final Map<String, LoadedProject?> _byRoot = {};

  /// All rule ids seen in any loaded config so far.
  final Set<String> knownRuleIds = {};

  /// Returns the project for the config that governs [filePath], walking up
  /// from its directory. Null when no config exists.
  LoadedProject? forFile(String filePath) {
    final project = Project.find(startDir: p.dirname(filePath));
    if (project == null) return null;
    return forRoot(project.rootPath, project);
  }

  LoadedProject? forRoot(String root, [Project? project]) {
    project ??= Project.find(startDir: root);
    if (project == null || project.rootPath != root) return null;
    final file = File(project.configPath);
    if (!file.existsSync()) {
      _byRoot.remove(root);
      return null;
    }
    final modified = file.lastModifiedSync();
    final cached = _byRoot[root];
    if (cached != null && cached.modified == modified) return cached;
    final loaded = _load(project, modified);
    _byRoot[root] = loaded;
    return loaded;
  }

  LoadedProject _load(Project project, DateTime modified) {
    try {
      final config = ConfigLoader().load(
        content: File(project.configPath).readAsStringSync(),
        configPath: project.configPath,
        rootPath: project.rootPath,
        packageName: project.packageName,
      );
      knownRuleIds.addAll(config.rules.map((r) => r.id));
      return LoadedProject(
        configPath: project.configPath,
        modified: modified,
        config: config,
        engine: Engine(config),
      );
    } on ConfigException catch (e) {
      return LoadedProject(
        configPath: project.configPath,
        modified: modified,
        errors: e.errors,
      );
    }
  }
}
