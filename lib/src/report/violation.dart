import '../config/config.dart';

/// One rule hit, fully rendered.
class Violation {
  Violation({
    required this.ruleId,
    required this.severity,
    required this.path,
    required this.relativePath,
    required this.offset,
    required this.length,
    required this.line,
    required this.column,
    required this.endLine,
    required this.endColumn,
    required this.found,
    required this.message,
    required this.shortMessage,
    this.description,
    this.hint,
    this.useInstead,
    this.docs,
    this.captures = const {},
  });

  final String ruleId;
  final Severity severity;
  final String path;
  final String relativePath;
  final int offset;
  final int length;
  final int line;
  final int column;
  final int endLine;
  final int endColumn;
  final String found;
  final String message;
  final String shortMessage;
  final String? description;
  final String? hint;
  final String? useInstead;
  final String? docs;
  final Map<String, String> captures;

  String get ignoreComment => '// ignore: agent_lints/$ruleId -- <reason>';

  Map<String, Object?> toJson() => {
    'rule': ruleId,
    'severity': severity.name,
    if (description != null) 'description': description,
    'file': relativePath,
    'range': {
      'start': {'line': line, 'column': column, 'offset': offset},
      'end': {'line': endLine, 'column': endColumn, 'offset': offset + length},
    },
    'found': found,
    'message': message,
    'short': shortMessage,
    if (useInstead != null) 'use_instead': useInstead,
    if (hint != null) 'hint': hint,
    if (docs != null) 'docs': docs,
    'ignore': ignoreComment,
    'context': {
      for (final e in captures.entries)
        if (!e.key.startsWith('args.')) e.key: e.value,
    },
  };
}
