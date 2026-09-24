import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  const code = '''
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Text('x');
}
class Home extends StatelessWidget {
  Home({super.key});
  @override
  Widget build(BuildContext context) => const Text('x');
}
class Plain {}
const kTimeout = 3;
Future<void> load() async {}
void sync() {}
''';

  group('class', () {
    test('extends walks the superclass chain; name not-pattern', () async {
      final v = await lint(
        rule(
          'screens',
          '    class: { extends: Widget }\n    name: { not: "*Screen" }\n    message: "{{name}} ({{kind}})"\n',
        ),
        {'lib/screens/a.dart': code},
      );
      expect(v.map((x) => x.message), ['Home (class)']);
    });

    test('lacks / has member matchers', () async {
      final v = await lint(
        rule('const_ctor', '''
    class: { extends: StatelessWidget }
    lacks: { function: { kind: constructor, const: true } }
    message: "{{name}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['Home']);
      final has = await lint(
        rule(
          'r',
          '    class: any\n    has: { function: { name: build, override: true } }\n    message: "{{name}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(has.map((x) => x.message), ['HomeScreen', 'Home']);
    });
  });

  group('function', () {
    test('kind, async and returns', () async {
      final v = await lint(
        rule(
          'r',
          '    function: any\n    kind: function\n    async: true\n    returns: Future\n    message: "{{name}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['load']);
    });
  });

  group('variable', () {
    test('scope, const and type', () async {
      final v = await lint(
        rule(
          'r',
          '    variable: any\n    scope: top_level\n    const: true\n    type: int\n    message: "{{name}}:{{type}}"\n',
        ),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['kTimeout:int']);
    });

    test('initializer matcher', () async {
      final v = await lint(
        rule(
          'r',
          '    variable: any\n    initializer: { constructor: Text }\n    message: "{{name}} = {{found}}"\n',
        ),
        {
          'lib/a.dart':
              "import 'package:flutter/material.dart';\nfinal t = Text('x');\nfinal n = 1;\n",
        },
      );
      expect(v.single.message, "t = t = Text('x')");
    });
  });

  group('literal', () {
    test('string literals by source regex, skipping import uris', () async {
      final v = await lint(
        rule(
          'no_urls',
          '    literal: string\n    source: "/^\'https?:/"\n    message: "{{value}}"\n',
        ),
        {
          'lib/a.dart':
              "import 'package:http/http.dart';\nconst a = 'https://x.dev';\nconst b = 'nope';\nconst c = 'http://y';\n",
        },
      );
      expect(v.map((x) => x.message), ['https://x.dev', 'http://y']);
    });

    test('numeric literal ranges and kinds', () async {
      final v = await lint(
        rule(
          'r',
          '    literal: num\n    min: 100\n    message: "{{value}}:{{kind}}"\n',
        ),
        {'lib/a.dart': 'const a = 1;\nconst b = 250;\nconst c = 300.5;\n'},
      );
      expect(v.map((x) => x.message), ['250:int', '300.5:double']);
    });
  });

  group('file', () {
    test('matches by base name and reports line 1', () async {
      final v = await lint(
        rule('r', '    file: "/[A-Z]/"\n    message: "{{name}} in {{file}}"\n'),
        {
          'lib/HomeScreen.dart': 'class A {}\n',
          'lib/home_screen.dart': 'class B {}\n',
        },
      );
      expect(v.single.message, 'HomeScreen in lib/HomeScreen.dart');
      expect(v.single.line, 1);
    });
  });
}
