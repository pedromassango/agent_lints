import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';

/// One `// ignore:` comment.
class IgnoreComment {
  IgnoreComment({
    required this.rules,
    required this.line,
    required this.offset,
    required this.forFile,
    required this.reason,
    required this.ownLine,
  });

  /// Rule ids, or `all`.
  final Set<String> rules;
  final int line;
  final int offset;
  final bool forFile;
  final String? reason;

  /// True when nothing but whitespace precedes the comment on its line; such
  /// a comment applies to the next line. A trailing comment applies to its
  /// own line.
  final bool ownLine;
  bool used = false;

  bool covers(String ruleId, int violationLine) {
    if (!rules.contains(ruleId) && !rules.contains('all')) return false;
    if (forFile) return true;
    return ownLine ? violationLine == line + 1 : violationLine == line;
  }
}

/// Parses analyzer-style ignore comments for agent_lints rules:
///
/// ```dart
/// // ignore: agent_lints/no_print -- reason
/// // ignore: no_print, no_http
/// // ignore_for_file: agent_lints/no_print
/// ```
///
/// The `agent_lints/` prefix is what the analyzer plugin requires; the CLI
/// accepts both forms so one comment works everywhere.
class Suppressions {
  Suppressions(this.comments);

  final List<IgnoreComment> comments;

  static final _pattern = RegExp(
    r'^//\s*(ignore|ignore_for_file):\s*(.*?)\s*(?:--\s*(.*?)\s*)?$',
  );

  static Suppressions parse(
    CompilationUnit unit,
    LineInfo lineInfo,
    Set<String> knownRules, {
    required String content,
  }) {
    final out = <IgnoreComment>[];
    Token? token = unit.beginToken;
    while (token != null) {
      for (Token? c = token.precedingComments; c != null; c = c.next) {
        final m = _pattern.firstMatch(c.lexeme);
        if (m == null) continue;
        final ids = m
            .group(2)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.startsWith('agent_lints/') ? s.substring(12) : s)
            .where((s) => s == 'all' || knownRules.contains(s))
            .toSet();
        if (ids.isEmpty) continue;
        final lineNumber = lineInfo.getLocation(c.offset).lineNumber;
        final lineStart = lineInfo.getOffsetOfLine(lineNumber - 1);
        out.add(
          IgnoreComment(
            rules: ids,
            ownLine: content.substring(lineStart, c.offset).trim().isEmpty,
            line: lineNumber,
            offset: c.offset,
            forFile: m.group(1) == 'ignore_for_file',
            reason: m.group(3),
          ),
        );
      }
      if (token.type == TokenType.EOF) break;
      token = token.next;
    }
    return Suppressions(out);
  }

  /// Returns the comment that suppresses [ruleId] at [line], marking it used.
  IgnoreComment? find(String ruleId, int line) {
    for (final c in comments) {
      if (c.covers(ruleId, line)) {
        c.used = true;
        return c;
      }
    }
    return null;
  }

  Iterable<IgnoreComment> get unused => comments.where((c) => !c.used);
}
