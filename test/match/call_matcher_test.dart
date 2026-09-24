import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  group('call', () {
    test('matches a top-level function by name and package', () async {
      final v = await lint(
        rule('no_print', '''
    call: print
    package: dart:core
    message: "no print in {{file}} ({{enclosing_function}})"
'''),
        {
          'lib/a.dart':
              'void main() {\n  print("x");\n  myPrint();\n}\nvoid myPrint() {}\n',
        },
      );
      expect(v, hasLength(1));
      expect(v.single.line, 2);
      expect(v.single.message, 'no print in lib/a.dart (main)');
      expect(v.single.found, 'print("x")');
    });

    test(
      'matches an instance method by Class.member and captures names',
      () async {
        final v = await lint(
          rule('no_setstate_in_build', '''
    call: State.setState
    inside: { function: build }
    message: "{{name}} inside {{enclosing_class}}.{{enclosing_function}}"
'''),
          {
            'lib/a.dart': '''
import 'package:flutter/widgets.dart';
class W extends StatefulWidget { const W({super.key}); @override State createState() => _S(); }
class _S extends State<W> {
  @override
  void initState() { setState(() {}); }
  @override
  Widget build(BuildContext context) {
    setState(() {});
    return const Text('x');
  }
}
''',
          },
        );
        expect(v, hasLength(1));
        expect(v.single.line, 8);
        expect(v.single.message, 'State.setState inside _S.build');
      },
    );

    test('short name matches any receiver; on.type narrows it', () async {
      const code = '''
import 'package:flutter/material.dart';
void f(BuildContext c, List<int> list) {
  Navigator.of(c).push(1);
  list.add(2);
}
''';
      final any = await lint(
        rule('r', '    call: push\n    message: "{{name}}"\n'),
        {'lib/a.dart': code},
      );
      expect(any.map((v) => v.message), ['NavigatorState.push']);
      final onType = await lint(
        rule(
          'r',
          '    call: add\n    on: { type: List }\n    message: "{{name}} on {{receiver}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(onType.single.message, 'List.add on list');
    });

    test('package: project matches the analyzed package', () async {
      final v = await lint(
        rule(
          'r',
          '    call: helper\n    package: project\n    message: "{{package}}"\n',
        ),
        {
          'lib/a.dart':
              "import 'b.dart';\nvoid main() { helper(); print(1); }\n",
          'lib/b.dart': 'void helper() {}\n',
        },
      );
      expect(v.single.message, 'test_app');
    });

    test('static and await filters', () async {
      const code = '''
import 'package:http/http.dart' as http;
class Api { static Future<void> load() async {} }
Future<void> f() async {
  await Api.load();
  Api.load();
  await http.get(Uri.parse('x'));
}
''';
      final notAwaited = await lint(
        rule(
          'r',
          '    call: Api.load\n    await: false\n    message: "{{line}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(notAwaited.map((v) => v.line), [5]);
      final httpGet = await lint(
        rule(
          'r',
          '    call: get\n    package: http\n    message: "{{name}} from {{package}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(httpGet.single.message, 'get from http');
    });
  });
}
