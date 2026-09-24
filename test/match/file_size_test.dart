import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  const widget = '''
import 'package:flutter/material.dart';

/// A widget.
class Big extends StatelessWidget {
  const Big({super.key});

  // comment only
  @override
  Widget build(BuildContext context) {
    return const Text(\'\'\'multi
line
string\'\'\');
  }
}
''';

  test(
    'max_code_lines counts lines with tokens, excluding blanks and comments',
    () async {
      final v = await lint(
        rule('small_widget_files', '''
    file: { max_code_lines: 8 }
    contains: { class: { extends: Widget } }
    message: "{{file}}: {{code_lines}} code lines, {{lines}} total"
'''),
        {
          'lib/big.dart': widget,
          'lib/plain.dart': widget.replaceAll('extends StatelessWidget', ''),
        },
      );
      // 14 lines total, 4 blank or comment-only -> 10 code lines; only the widget file is reported.
      expect(v.map((x) => x.message), [
        'lib/big.dart: 10 code lines, 14 total',
      ]);
      expect(v.single.line, 1);
    },
  );

  test('files within the bound do not match; min bounds work', () async {
    final ok = await lint(
      rule('r', '    file: any\n    max_lines: 14\n    message: x\n'),
      {'lib/big.dart': widget},
    );
    expect(ok, isEmpty);
    final tiny = await lint(
      rule(
        'r',
        '    file: any\n    min_code_lines: 3\n    message: "{{code_lines}}"\n',
      ),
      {'lib/a.dart': 'class A {}\n', 'lib/b.dart': widget},
    );
    expect(tiny.single.message, '1');
  });
}
