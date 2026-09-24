import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('new', () {
    const widgets = '''
import 'package:flutter/material.dart';
Widget build() {
  return Container(
    padding: const EdgeInsets.all(10),
    child: GestureDetector(onTap: () {}, child: const Text('x')),
  );
}
Widget other() => GestureDetector(onTap: () {}, onPanUpdate: (_) {}, child: const Text('y'));
''';

    test('matches by class name across any constructor', () async {
      final v = await lint(
        rule(
          'r',
          '    new: EdgeInsets\n    message: "{{name}} {{short_name}} {{package}}"\n',
        ),
        {'lib/a.dart': widgets},
      );
      expect(v.single.message, 'EdgeInsets.all all flutter');
      expect(v.single.found, 'const EdgeInsets.all(10)');
    });

    test('named constructor and glob patterns', () async {
      final all = await lint(
        rule('r', '    new: EdgeInsets.symmetric\n    message: x\n'),
        {'lib/a.dart': widgets},
      );
      expect(all, isEmpty);
      final glob = await lint(
        rule(
          'r',
          '    new: "EdgeInsets.*"\n    package: [flutter, material_ui]\n    message: x\n',
        ),
        {'lib/a.dart': widgets},
      );
      expect(glob, hasLength(1));
    });

    test('args present / absent shorthands', () async {
      final v = await lint(
        rule('taps', '''
    new: GestureDetector
    args: { onTap: present, onPanUpdate: absent }
    message: "line {{line}} {{args.onTap}}"
'''),
        {'lib/a.dart': widgets},
      );
      expect(v.single.message, 'line 5 () {}');
    });

    test('type subtype check and const filter', () async {
      final v = await lint(
        rule(
          'r',
          '    new: "*"\n    type: Widget\n    const: true\n    message: "{{name}}"\n',
        ),
        {'lib/a.dart': widgets},
      );
      expect(v.map((x) => x.message), ['Text', 'Text']);
    });

    test('nested expr and ref constraints on arguments', () async {
      final v = await lint(
        rule('adhoc_card', '''
    new: Container
    args:
      decoration:
        expr: { new: BoxDecoration, args: { color: present } }
    message: "found {{found}}"
'''),
        {
          'lib/a.dart': '''
import 'package:flutter/material.dart';
final a = Container(decoration: BoxDecoration(color: Colors.red));
final b = Container(decoration: BoxDecoration(borderRadius: 4));
final c = Container(color: Colors.red);
''',
        },
      );
      expect(v.single.line, 2);
      final ref = await lint(
        rule('raw_color_ref', '''
    new: Container
    args: { color: { ref: { name: "Colors.*", package: flutter } } }
    message: "{{args.color}} -> {{name}}"
'''),
        {
          'lib/a.dart': '''
import 'package:flutter/material.dart';
const mine = Color(1);
final a = Container(color: Colors.red);
final b = Container(color: mine);
''',
        },
      );
      expect(ref.single.message, 'Colors.red -> Colors.red');
    });
  });
}
