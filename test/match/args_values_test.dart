import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('args value constraints and values lists', () {
    const yaml = '''
version: 2
values:
  spacing:
    - 4
    - { value: 8, name: AppSpacing.sm }
    - { value: 16, name: AppSpacing.md }
rules:
  spacing_on_scale:
    constructor: [EdgeInsets.all, EdgeInsets.symmetric, SizedBox]
    args: { "*": { literal: num, not_in: \$spacing } }
    message: "{{value}} to {{name}}({{arg}}) off scale. Allowed: {{allowed}}. Closest: {{closest}}."
    hint: "{{name}}({{arg}}: {{closest.name}})"
''';
    const code = '''
import 'package:flutter/material.dart';
class AppSpacing { static const sm = 8.0; static const md = 16.0; }
const kPad = 10.0;
final a = EdgeInsets.all(10);
final b = EdgeInsets.all(AppSpacing.sm);
final c = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
final d = SizedBox(height: kPad);
double dyn() => 3;
final e = SizedBox(width: dyn());
''';

    test('flags literals off the scale with closest hints', () async {
      final v = await lint(yaml, {'lib/a.dart': code});
      expect(v.map((x) => x.line), [4, 6]);
      expect(
        v.first.message,
        '10 to EdgeInsets.all(value) off scale. '
        'Allowed: 4, 8 (AppSpacing.sm), 16 (AppSpacing.md). '
        'Closest: 8 (AppSpacing.sm), 4.',
      );
      expect(v.first.hint, 'EdgeInsets.all(value: AppSpacing.sm)');
      expect(v[1].message, startsWith('12 to EdgeInsets.symmetric(vertical)'));
    });

    test(
      'const references count as values; non-const args never match',
      () async {
        final v = await lint(
          rule(
            'r',
            '    constructor: SizedBox\n    args: { height: { not_in: [4, 8] } }\n    message: "{{value}}"\n',
          ),
          {'lib/a.dart': code},
        );
        expect(v.single.message, '10');
      },
    );

    test('value, min, max, literal kinds and list shorthand', () async {
      final v = await lint(
        rule('r', '''
    constructor: EdgeInsets.symmetric
    args: { horizontal: 16, vertical: { min: 10, max: 14, literal: int } }
    message: ok
'''),
        {'lib/a.dart': code},
      );
      expect(v, hasLength(1));
      final list = await lint(
        rule(
          'r',
          '    constructor: EdgeInsets.symmetric\n    args: { horizontal: [8, 16] }\n    message: ok\n',
        ),
        {'lib/a.dart': code},
      );
      expect(list, hasLength(1));
    });

    test('positional args are addressable by parameter name or index', () async {
      final byName = await lint(
        rule(
          'r',
          '    constructor: Text\n    args: { data: { source: "/^\'x/" } }\n    message: "{{args.data}}"\n',
        ),
        {
          'lib/a.dart':
              "import 'package:flutter/material.dart';\nfinal t = Text('xy');\n",
        },
      );
      expect(byName.single.message, "'xy'");
      final byIndex = await lint(
        rule(
          'r',
          '    constructor: Text\n    args: { 0: { literal: string } }\n    message: "{{args.0}}"\n',
        ),
        {
          'lib/a.dart':
              "import 'package:flutter/material.dart';\nfinal t = Text('xy');\n",
        },
      );
      expect(byIndex.single.message, "'xy'");
    });
  });
}
