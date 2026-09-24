import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('parent / inside / contains', () {
    const code = '''
import 'package:flutter/material.dart';
Widget a() => Column(children: [ListView(children: const [])]);
Widget b() => Column(children: [ListView(shrinkWrap: true)]);
Widget c() => Column(children: [Padding(padding: EdgeInsets.zero, child: ListView())]);
Widget d() => Builder(builder: (_) => ListView());
Widget e() => Scaffold(body: SafeArea(child: Text('x')));
Widget f() => Scaffold(body: Text('y'));
''';

    test(
      'parent: direct ancestor through argument lists and list literals',
      () async {
        final v = await lint(
          rule('listview_in_column', '''
    constructor: ListView
    args: { shrinkWrap: absent }
    parent: { constructor: Column }
    message: "line {{line}} in {{ancestor}}"
'''),
          {'lib/a.dart': code},
        );
        expect(v.map((x) => x.message), ['line 2 in Column']);
      },
    );

    test('inside anywhere and not_inside', () async {
      final anywhere = await lint(
        rule(
          'r',
          '    constructor: ListView\n    inside: { constructor: Column }\n    message: "{{line}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(anywhere.map((x) => x.message), ['2', '3', '4']);
      final notInside = await lint(
        rule(
          'r',
          '    constructor: ListView\n    not_inside: { constructor: Column }\n    message: "{{line}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(notInside.map((x) => x.message), ['5']);
    });

    test('inside a function by name', () async {
      final v = await lint(
        rule(
          'r',
          '    constructor: ListView\n    inside: { function: d }\n    message: "{{line}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['5']);
    });

    test('not_contains and expr: not', () async {
      final v = await lint(
        rule('scaffold_body_safearea', '''
    constructor: Scaffold
    args: { body: { expr: { not: { constructor: SafeArea } } } }
    message: "{{line}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['7']);
      final contains = await lint(
        rule(
          'r',
          '    constructor: Scaffold\n    not_contains: { constructor: SafeArea }\n    message: "{{line}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(contains.map((x) => x.message), ['7']);
    });
  });
}
