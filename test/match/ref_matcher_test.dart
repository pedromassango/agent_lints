import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('ref and use', () {
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

    test('ref matches static members by Class.* pattern', () async {
      final v = await lint(
        rule(
          'no_palette',
          '    ref: "Colors.*"\n    package: flutter\n    message: "{{name}}:{{type}}"\n',
        ),
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
        rule(
          'r',
          '    ref: primary\n    type: Color\n    message: "{{name}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(v.single.message, 'ColorScheme.primary');
    });

    test('use matches constructors, calls and references', () async {
      final v = await lint(
        rule('no_opacity', '''
    use: [Opacity, .withOpacity, Colors.red]
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

    test('except removes a sub-case', () async {
      final v = await lint(
        rule('no_palette', '''
    use: "Colors.*"
    package: flutter
    except: { use: Colors.transparent }
    message: "{{name}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['Colors.red', 'Colors.red']);
    });
  });
}
