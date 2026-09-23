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

  group('class matcher', () {
    test('extends walks the superclass chain; name not-pattern', () async {
      final v = await lint(
        rule('screens', '''
    match: { class: { extends: Widget, name: { not: "*Screen" } } }
    message: "{{name}} ({{kind}})"
'''),
        {'lib/screens/a.dart': code},
      );
      expect(v.map((x) => x.message), ['Home (class)']);
    });

    test('lacks / has member matchers', () async {
      final v = await lint(
        rule('const_ctor', '''
    match: { class: { extends: StatelessWidget, lacks: { function: { kind: constructor, const: true } } } }
    message: "{{name}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['Home']);
      final has = await lint(
        rule('r', '''
    match: { class: { has: { function: { name: build, override: true } } } }
    message: "{{name}}"
'''),
        {'lib/a.dart': code},
      );
      expect(has.map((x) => x.message), ['HomeScreen', 'Home']);
    });
  });

  group('function matcher', () {
    test('kind, async and returns', () async {
      final v = await lint(
        rule('r', '''
    match: { function: { kind: function, async: true, returns: Future } }
    message: "{{name}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['load']);
    });
  });

  group('variable matcher', () {
    test('scope, const and type', () async {
      final v = await lint(
        rule('r', '''
    match: { variable: { scope: top_level, const: true, type: int } }
    message: "{{name}}:{{type}}"
'''),
        {'lib/a.dart': code},
      );
      expect(v.map((x) => x.message), ['kTimeout:int']);
    });

    test('initializer matcher', () async {
      final v = await lint(
        rule('r', '''
    match: { variable: { initializer: { new: { name: Text } } } }
    message: "{{name}} = {{found}}"
'''),
        {
          'lib/a.dart':
              "import 'package:flutter/material.dart';\nfinal t = Text('x');\nfinal n = 1;\n",
        },
      );
      expect(v.single.message, "t = t = Text('x')");
    });
  });

  group('literal matcher', () {
    test('string literals by source regex, skipping import uris', () async {
      final v = await lint(
        rule('no_urls', '''
    match: { literal: { kind: string, source: "/^'https?:/" } }
    message: "{{value}}"
'''),
        {
          'lib/a.dart':
              "import 'package:http/http.dart';\nconst a = 'https://x.dev';\nconst b = 'nope';\nconst c = 'http://y';\n",
        },
      );
      expect(v.map((x) => x.message), ['https://x.dev', 'http://y']);
    });

    test('numeric literal ranges and kinds', () async {
      final v = await lint(
        rule('r', '''
    match: { literal: { kind: num, min: 100 } }
    message: "{{value}}:{{kind}}"
'''),
        {'lib/a.dart': 'const a = 1;\nconst b = 250;\nconst c = 300.5;\n'},
      );
      expect(v.map((x) => x.message), ['250:int', '300.5:double']);
    });
  });

  group('file matcher', () {
    test('matches by base name and reports line 1', () async {
      final v = await lint(
        rule('r', '''
    match: { file: { name: "/[A-Z]/" } }
    message: "{{name}} in {{file}}"
'''),
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
