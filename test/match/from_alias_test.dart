import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  const code = '''
import 'package:material_ui/material_ui.dart' as mui;
import 'package:flutter/widgets.dart';
final a = mui.Scaffold(body: const Text('x'));
final b = Color(1);
final c = mui.Colors.red;
''';

  test('from: flutter covers material_ui and dart:ui', () async {
    final v = await lint(
      rule(
        'r',
        '    use: [Scaffold, Color, "Colors.*"]\n    from: flutter\n    message: "{{name}} ({{package}})"\n',
      ),
      {'lib/a.dart': code},
    );
    expect(v.map((x) => x.message), [
      'Scaffold (material_ui)',
      'Color (flutter)',
      'Colors.red (material_ui)',
    ]);
  });

  test('from and package are synonyms; both at once is an error', () async {
    final v = await lint(
      rule(
        'r',
        '    constructor: { name: Scaffold, package: material_ui }\n    message: "{{name}}"\n',
      ),
      {'lib/a.dart': code},
    );
    expect(v.single.message, 'Scaffold');
    final errors = configErrors(
      rule('r', '    use: Scaffold\n    from: flutter\n    package: flutter\n'),
    );
    expect(
      errors.single.message,
      contains('"from" and "package" mean the same thing'),
    );
  });

  test('type patterns and imports accept from', () async {
    final v = await lint(
      rule(
        'r',
        '    constructor: any\n    type: { name: Widget, from: flutter }\n    message: "{{name}}"\n',
      ),
      {'lib/a.dart': code},
    );
    expect(v.map((x) => x.message), ['Scaffold', 'Text']);
    final imports = await lint(
      rule('r', '    import: { from: flutter }\n    message: "{{uri}}"\n'),
      {'lib/a.dart': code},
    );
    expect(imports.map((x) => x.message), [
      'package:material_ui/material_ui.dart',
      'package:flutter/widgets.dart',
    ]);
  });
}
