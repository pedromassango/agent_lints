import 'package:test/test.dart';

import '../support/test_project.dart';

void main() {
  test('has / lacks match static fields inside a class', () async {
    final v = await lint(
      rule('declare_keys', '''
    class: any
    lacks: { variable: keys, static: true }
    message: "{{name}} lacks keys"
'''),
      {
        'lib/a.dart': '''
class WithKeys { static const keys = ['a']; }
class InstanceOnly { final keys = ['a']; }
class Without {}
''',
      },
    );
    expect(v.map((x) => x.message), [
      'InstanceOnly lacks keys',
      'Without lacks keys',
    ]);
  });

  test(
    'declarations are reported at their name token, not the whole body',
    () async {
      final v =
          await lint(rule('r', '    class: Long\n    message: "{{found}}"\n'), {
            'lib/a.dart': '''
/// Doc comment.
@Deprecated('x')
class Long {
  int a = 1;
}
''',
          });
      expect(v.single.line, 3);
      expect(v.single.column, 7);
      expect(v.single.length, 'Long'.length);
      expect(v.single.message, startsWith('class Long {'));
    },
  );
}
