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

  /// Directories never descended into by [discover].
  static const skippedDirs = {
    '.dart_tool',
    'build',
    'node_modules',
    '.git',
    '.idea',
    '.vscode',
    'ios',
    'android',
    'macos',
    'linux',
    'windows',
    'web',
    '.symlinks',
  };

  /// Loads every `agent_lints.yaml` reachable from [startDir]: the nearest
  /// one walking up, plus any within [maxDepth] levels below. The analysis
  /// server reads a rule's diagnostic codes before it hands the rule a file,
  /// so configs must be known before the first library is analyzed.
  List<LoadedProject> discover(String startDir, {int maxDepth = 4}) {
    final found = <LoadedProject>[];
    final above = Project.find(startDir: startDir);
    if (above != null) {
      final loaded = forRoot(above.rootPath, above);
      if (loaded != null) found.add(loaded);
    }
    void walk(Directory dir, int depth) {
      if (depth > maxDepth) return;
      final List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } on FileSystemException {
        return;
      }
      for (final e in entries) {
        final name = p.basename(e.path);
        if (e is File && name == Project.configFileName) {
          final loaded = forRoot(dir.path);
          if (loaded != null && !found.contains(loaded)) found.add(loaded);
        } else if (e is Directory &&
            !name.startsWith('.') &&
            !skippedDirs.contains(name)) {
          walk(e, depth + 1);
        }
      }
    }

    walk(Directory(startDir), 0);
    return found;
  }

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
