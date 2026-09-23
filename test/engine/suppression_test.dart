import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  const yaml = '''
version: 1
rules:
  no_print:
    match: { call: { name: print, package: dart:core } }
    message: no print
''';

  group('ignore comments', () {
    test(
      'prefixed and unprefixed forms suppress the next line or same line',
      () async {
        final v = await lint(yaml, {
          'lib/a.dart': '''
void main() {
  // ignore: agent_lints/no_print -- debugging
  print(1);
  print(2); // ignore: no_print
  print(3);
}
''',
        });
        expect(v.map((x) => '${x.ruleId}:${x.line}'), ['no_print:5']);
      },
    );

    test('ignore_for_file silences the whole file', () async {
      final v = await lint(yaml, {
        'lib/a.dart':
            '// ignore_for_file: agent_lints/no_print\nvoid main() { print(1); print(2); }\n',
      });
      expect(v, isEmpty);
    });

    test('unused ignores are reported as info', () async {
      final v = await lint(yaml, {
        'lib/a.dart':
            'void main() {\n  // ignore: no_print\n  final x = 1;\n}\n',
      });
      expect(v.single.ruleId, 'unused_ignore');
      expect(v.single.line, 2);
      expect(v.single.message, contains('suppresses nothing'));
    });

    test('unknown rule ids in ignore comments are left alone', () async {
      final v = await lint(yaml, {
        'lib/a.dart':
            'void main() {\n  // ignore: avoid_print\n  print(1);\n}\n',
      });
      expect(v.map((x) => x.ruleId), ['no_print']);
    });

    test('require_ignore_reason flags bare ignores', () async {
      final v = await lint('$yaml\nrequire_ignore_reason: true\n', {
        'lib/a.dart': 'void main() {\n  // ignore: no_print\n  print(1);\n}\n',
      });
      expect(v.single.ruleId, 'ignore_without_reason');
    });
  });
}
