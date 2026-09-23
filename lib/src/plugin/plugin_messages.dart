import '../report/violation.dart';

/// How a [Violation] is rendered for the analysis server, whose tooltips
/// show `problemMessage` then `correctionMessage`.
abstract final class PluginMessages {
  /// Longest problem message sent to the IDE; longer ones are cut at a word.
  static const maxProblemLength = 400;

  /// The whole rendered message on one line, so the "what to do" sentence
  /// survives in IDE tooltips.
  static String problem(Violation v) {
    final text = v.message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= maxProblemLength) return text;
    final cut = text.lastIndexOf(' ', maxProblemLength);
    return '${text.substring(0, cut > 0 ? cut : maxProblemLength)}…';
  }

  static String correction(Violation v) {
    final parts = <String>[
      if (v.useInstead != null) 'Use ${v.useInstead}.',
      if (v.suggest != null && v.suggest!.isNotEmpty) 'Suggest: ${v.suggest}',
      if (v.docs != null) 'See ${v.docs}.',
      'Run explain to learn more: dart run agent_lints explain ${v.ruleId}',
    ];
    return parts.join('  ');
  }
}
