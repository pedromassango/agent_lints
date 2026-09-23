import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../match/compiled_rule.dart';
import 'values.dart';

enum Severity {
  info,
  warning,
  error,
  off;

  static const byName = {
    'info': Severity.info,
    'warning': Severity.warning,
    'error': Severity.error,
    'off': Severity.off,
  };

  bool operator >=(Severity other) => index >= other.index;
}

/// Fully loaded and compiled `agent_lints.yaml`.
class AgentLintsConfig {
  AgentLintsConfig({
    required this.rootPath,
    required this.configPath,
    required this.packageName,
    required this.include,
    required this.exclude,
    required this.failOn,
    required this.requireIgnoreReason,
    required this.docs,
    required this.values,
    required this.rules,
  });

  /// Absolute directory that holds the config file. All globs are relative.
  final String rootPath;
  final String configPath;

  /// The analyzed package's name (from pubspec.yaml), or null when unknown.
  final String? packageName;
  final List<Glob> include;
  final List<Glob> exclude;
  final Severity failOn;
  final bool requireIgnoreReason;
  final String? docs;
  final Map<String, ValueList> values;
  final List<CompiledRule> rules;

  static const defaultInclude = ['lib/**'];

  static const alwaysExcluded = [
    '**/*.g.dart',
    '**/*.freezed.dart',
    '**/*.gr.dart',
    '**/*.pb.dart',
    '**/*.pbenum.dart',
    '**/*.pbjson.dart',
    '**/*.pbserver.dart',
    '**/*.mocks.dart',
    'build/**',
    '.dart_tool/**',
    'agent_lints_examples_tmp/**',
  ];

  /// Whether [absolutePath] is inside the project and selected by include/exclude.
  bool includesFile(String absolutePath) {
    final rel = relativePath(absolutePath);
    if (rel == null) return false;
    if (!include.any((g) => g.matches(rel))) return false;
    if (exclude.any((g) => g.matches(rel))) return false;
    return true;
  }

  /// Project-relative posix path, or null if the file is outside [rootPath].
  String? relativePath(String absolutePath) {
    if (!p.isWithin(rootPath, absolutePath)) return null;
    return p.posix.joinAll(p.split(p.relative(absolutePath, from: rootPath)));
  }
}

Glob compileGlob(String pattern) =>
    Glob(pattern, context: p.posix, caseSensitive: true);
