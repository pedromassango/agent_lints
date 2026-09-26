import 'package:glob/glob.dart';

import '../config/config.dart';
import '../report/message_template.dart';
import 'matcher.dart';

/// A rule from `agent_lints.yaml`, compiled and ready to run.
class CompiledRule {
  CompiledRule({
    required this.id,
    required this.kind,
    required this.severity,
    required this.matcher,
    required this.message,
    this.description,
    this.hint,
    this.useInstead,
    this.docs,
    this.vars = const {},
    this.files = const [],
    this.exclude = const [],
    this.examplesBad = const [],
    this.examplesGood = const [],
    this.sourcePath,
  });

  final String id;

  /// `match`, `banned`, `imports` or `naming`.
  final String kind;
  final Severity severity;
  final Matcher matcher;
  final MessageTemplate message;
  final String? description;
  final MessageTemplate? hint;
  final String? useInstead;
  final String? docs;
  final Map<String, String> vars;
  final List<Glob> files;
  final List<Glob> exclude;
  final List<String> examplesBad;
  final List<String> examplesGood;

  /// Absolute path of the config file the rule was defined in.
  final String? sourcePath;

  bool get enabled => severity != Severity.off;

  CompiledRule copyWith({
    List<Glob>? files,
    List<Glob>? exclude,
    String? sourcePath,
  }) => CompiledRule(
    id: id,
    kind: kind,
    severity: severity,
    matcher: matcher,
    message: message,
    description: description,
    hint: hint,
    useInstead: useInstead,
    docs: docs,
    vars: vars,
    files: files ?? this.files,
    exclude: exclude ?? this.exclude,
    examplesBad: examplesBad,
    examplesGood: examplesGood,
    sourcePath: sourcePath ?? this.sourcePath,
  );

  /// Whether the rule runs on a project-relative posix path.
  bool appliesTo(String relativePath) {
    if (files.isNotEmpty && !files.any((g) => g.matches(relativePath))) {
      return false;
    }
    if (exclude.any((g) => g.matches(relativePath))) return false;
    return true;
  }
}
