import 'dart:convert';

import '../../cli/version.dart';
import '../../config/config.dart';
import '../../match/compiled_rule.dart';
import '../run_result.dart';
import 'formatter.dart';

/// SARIF 2.1.0 for GitHub code scanning and IDE importers.
class SarifFormatter extends Formatter {
  SarifFormatter({this.rules = const []});

  /// Rules to describe in `tool.driver.rules`; violations reference them.
  final List<CompiledRule> rules;

  @override
  String format(RunResult result) {
    final ruleIds = <String>{
      for (final r in rules) r.id,
      for (final v in result.violations) v.ruleId,
    }.toList();
    final byId = {for (final r in rules) r.id: r};
    final sarif = {
      r'$schema':
          'https://docs.oasis-open.org/sarif/sarif/v2.1.0/errata01/os/schemas/sarif-schema-2.1.0.json',
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'agent_lints',
              'version': packageVersion,
              'informationUri': 'https://github.com/pedromassango/agent_lints',
              'rules': [
                for (final id in ruleIds)
                  {
                    'id': id,
                    if (byId[id]?.description != null)
                      'shortDescription': {'text': byId[id]!.description},
                    'fullDescription': {'text': byId[id]?.message.source ?? id},
                    if (byId[id]?.docs != null) 'helpUri': byId[id]!.docs,
                    'defaultConfiguration': {
                      'level': _level(byId[id]?.severity ?? Severity.warning),
                    },
                  },
              ],
            },
          },
          'results': [
            for (final v in result.violations)
              {
                'ruleId': v.ruleId,
                'ruleIndex': ruleIds.indexOf(v.ruleId),
                'level': _level(v.severity),
                'message': {
                  'text': [
                    v.message,
                    if (v.suggest != null) 'Suggest: ${v.suggest}',
                  ].join('\n'),
                },
                'locations': [
                  {
                    'physicalLocation': {
                      'artifactLocation': {
                        'uri': v.relativePath,
                        'uriBaseId': '%SRCROOT%',
                      },
                      'region': {
                        'startLine': v.line,
                        'startColumn': v.column,
                        'endLine': v.endLine,
                        'endColumn': v.endColumn,
                      },
                    },
                  },
                ],
                'partialFingerprints': {
                  'primaryLocationLineHash':
                      '${v.ruleId}:${v.relativePath}:${v.found.hashCode}',
                },
                if (v.suggest != null)
                  'properties': {
                    'suggest': v.suggest,
                    'ignore': v.ignoreComment,
                  },
              },
          ],
        },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(sarif);
  }

  static String _level(Severity s) => switch (s) {
    Severity.error => 'error',
    Severity.warning => 'warning',
    _ => 'note',
  };
}
