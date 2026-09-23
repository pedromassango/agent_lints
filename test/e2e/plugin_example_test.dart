@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Runs `dart analyze` on example/, which enables agent_lints as an analyzer
/// plugin through `plugins: agent_lints: {path: ../}`.
void main() {
  final exampleDir = p.join(Directory.current.path, 'example');

  test('dart analyze reports every rule with the configured severity', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      '--format=machine',
    ], workingDirectory: exampleDir);
    // Machine format: SEVERITY|TYPE|CODE|FILE|LINE|COL|LEN|MESSAGE
    final rows = (result.stdout as String)
        .split('\n')
        .where((l) => l.contains('|'))
        .map((l) => l.split('|'))
        .where((f) => f.length >= 8)
        .map(
          (f) => (
            severity: f[0],
            code: f[2].toLowerCase(),
            file: p.relative(f[3], from: exampleDir),
            line: int.parse(f[4]),
          ),
        )
        .toList();
    final expected =
        (jsonDecode(
                  File(
                    p.join(exampleDir, 'expected_violations.json'),
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, Object?>>();
    for (final e in expected) {
      final hit = rows.where(
        (r) =>
            r.code == e['rule'] && r.file == e['file'] && r.line == e['line'],
      );
      expect(
        hit,
        isNotEmpty,
        reason:
            'missing ${e['rule']} at ${e['file']}:${e['line']} in:\n${result.stdout}',
      );
    }
    // Severities come from agent_lints.yaml, not from the plugin default.
    expect(rows.where((r) => r.code == 'no_print').single.severity, 'ERROR');
    expect(
      rows.where((r) => r.code == 'spacing_on_scale').single.severity,
      'WARNING',
    );
    // The ignore comment in cart_tile.dart is honoured by the plugin.
    expect(
      rows.where((r) => r.code == 'no_gesture_detector_for_taps'),
      isEmpty,
    );
  });
}
