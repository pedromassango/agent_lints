import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('ref matcher', () {
    const code = '''
import 'package:flutter/material.dart';
const a = Colors.red;
final b = Colors.red.shade300;
final c = Colors.transparent;
void f(BuildContext ctx) {
  final d = Theme.of(ctx).colorScheme.primary;
  final e = Colors;
}
''';

    test('matches static members by Class.* pattern', () async {
      final v = await lint(
        rule('no_palette', '''
    match: { ref: { name: "Colors.*", package: flutter } }
    message: "{{name}}:{{type}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), [
        'Colors.red:MaterialColor',
        'Colors.red:MaterialColor',
        'Colors.transparent:Color',
      ]);
    });

    test('type filter and property access chains', () async {
      final v = await lint(
        rule('r', '''
    match: { ref: { name: primary, type: Color } }
    message: "{{name}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.single.message, 'ColorScheme.primary');
    });

    test('banned expands to new, call and ref', () async {
      final v = await lint(
        rule('no_opacity', '''
    banned: [Opacity, .withOpacity, Colors.red]
    use_instead: AppFade
    message: "{{name}} is banned; use {{use_instead}}"
'''),
        {
          'lib/a.dart': '''
import 'package:flutter/material.dart';
final w = Opacity(opacity: 0.5);
final c = Colors.blue.withOpacity(0.1);
const r = Colors.red;
''',
        },
      );
      expect(v.map((x) => x.message), [
        'Opacity is banned; use AppFade',
        'Color.withOpacity is banned; use AppFade',
        'Colors.red is banned; use AppFade',
      ]);
    });
  });
}
