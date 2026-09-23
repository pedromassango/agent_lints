import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Locates `agent_lints.yaml` and the project it belongs to.
class Project {
  Project({required this.rootPath, required this.configPath, this.packageName});

  final String rootPath;
  final String configPath;
  final String? packageName;

  static const configFileName = 'agent_lints.yaml';

  /// Walks up from [startDir] until a config file is found.
  static Project? find({String? startDir, String? configPath}) {
    if (configPath != null) {
      final file = File(p.absolute(configPath));
      if (!file.existsSync()) return null;
      final root = file.parent.path;
      return Project(
        rootPath: root,
        configPath: file.path,
        packageName: readPackageName(root),
      );
    }
    var dir = Directory(p.absolute(startDir ?? Directory.current.path));
    while (true) {
      final candidate = File(p.join(dir.path, configFileName));
      if (candidate.existsSync()) {
        return Project(
          rootPath: dir.path,
          configPath: candidate.path,
          packageName: readPackageName(dir.path),
        );
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }

  static String? readPackageName(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    try {
      final doc = loadYaml(pubspec.readAsStringSync());
      if (doc is YamlMap) {
        final name = doc['name'];
        if (name is String) return name;
      }
    } on YamlException {
      return null;
    }
    return null;
  }
}
