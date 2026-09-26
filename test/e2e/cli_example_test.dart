@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Runs the real CLI against example/ (needs `flutter pub get` there).
void main() {
  final exampleDir = p.join(Directory.current.path, 'example');

  Future<ProcessResult> runCli(List<String> args) => Process.run(
    Platform.resolvedExecutable,
    ['run', p.join(Directory.current.path, 'bin', 'agent_lints.dart'), ...args],
    workingDirectory: exampleDir,
  );

  test('check --format json reports exactly the expected violations', () async {
    final result = await runCli(['check', '--format', 'json']);
    expect(result.exitCode, 1, reason: result.stderr.toString());
    final json = jsonDecode(result.stdout as String) as Map<String, Object?>;
    final actual = (json['violations'] as List)
        .map((v) => v as Map<String, Object?>)
        .map(
          (v) => {
            'rule': v['rule'],
            'file': v['file'],
            'line': (v['range'] as Map)['start']['line'],
          },
        )
        .toList();
    final expected =
        jsonDecode(
              File(
                p.join(exampleDir, 'expected_violations.json'),
              ).readAsStringSync(),
            )
            as List;
    expect(actual, expected);
  });

  test('agent format renders blocks with suggestions', () async {
    final result = await runCli(['--format', 'agent']);
    final out = result.stdout as String;
    expect(
      out,
      contains('[error] no_print  lib/features/home/home_screen.dart:20:5'),
    );
    expect(out, contains("hint     AppLog.d('home loaded')"));
    expect(out, contains('Closest: 8 (AppSpacing.sm)'));
    expect(
      out,
      contains('ignore   // ignore: agent_lints/no_print -- <reason>'),
    );
    expect(out, contains('exit 1  (fail_on: warning)'));
  });

  test('test runs the rules\' examples against the real Flutter SDK', () async {
    final result = await runCli(['test']);
    expect(result.exitCode, 0, reason: result.stdout.toString());
    expect(
      result.stdout,
      contains('PASS  no_gesture_detector_for_taps  (1 bad, 1 good)'),
    );
    expect(result.stdout, contains('3 of 3 rules pass their examples.'));
  });

  test('explain prints the compiled contract', () async {
    final result = await runCli(['explain', 'no_print']);
    expect(result.exitCode, 0);
    expect(
      result.stdout,
      contains('matches     call name=print from=dart:core'),
    );
  });

  test('validate reports the config as valid', () async {
    final result = await runCli(['validate']);
    expect(result.exitCode, 0);
    expect(
      result.stdout,
      contains('agent_lints.yaml is valid: 10 rules (10 enabled) from 2 files'),
    );
  });
}
