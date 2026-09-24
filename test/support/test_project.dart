import 'dart:convert';
import 'dart:io';

import 'package:agent_lints/agent_lints.dart';
import 'package:agent_lints/src/engine/project_checker.dart';
import 'package:path/path.dart' as p;

import 'flutter_stub.dart';

/// A throwaway Dart project on disk with stub `flutter`, `material_ui` and
/// `http` packages, so resolution works without a Flutter SDK.
class TestProject {
  TestProject._(this.root);

  final Directory root;

  static Future<TestProject> create({
    required String yaml,
    required Map<String, String> files,
    String packageName = 'test_app',
  }) async {
    final root = await Directory.systemTemp.createTemp('agent_lints_test_');
    final project = TestProject._(root);
    await project.write(
      'pubspec.yaml',
      'name: $packageName\nenvironment:\n  sdk: ^3.11.0\n',
    );
    await project.write('agent_lints.yaml', yaml);
    for (final e in files.entries) {
      await project.write(e.key, e.value);
    }
    final packages = <String, Map<String, String>>{
      'flutter': flutterStub,
      'material_ui': materialUiStub,
      'http': httpStub,
    };
    for (final pkg in packages.entries) {
      for (final f in pkg.value.entries) {
        await project.write(p.join('packages', pkg.key, f.key), f.value);
      }
    }
    final config = {
      'configVersion': 2,
      'packages': [
        {
          'name': packageName,
          'rootUri': '../',
          'packageUri': 'lib/',
          'languageVersion': '3.11',
        },
        for (final pkg in packages.keys)
          {
            'name': pkg,
            'rootUri': '../packages/$pkg/',
            'packageUri': 'lib/',
            'languageVersion': '3.11',
          },
      ],
    };
    await project.write(
      p.join('.dart_tool', 'package_config.json'),
      jsonEncode(config),
    );
    return project;
  }

  Future<void> write(String relative, String content) async {
    final file = File(p.join(root.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  AgentLintsConfig loadConfig({List<ConfigError>? warnings}) {
    return ConfigLoader(warnings: warnings?.add).load(
      content: File(p.join(root.path, 'agent_lints.yaml')).readAsStringSync(),
      configPath: p.join(root.path, 'agent_lints.yaml'),
      rootPath: root.path,
      packageName: Project.readPackageName(root.path),
    );
  }

  Future<RunResult> check() => ProjectChecker(loadConfig()).run();

  Future<void> dispose() => root.delete(recursive: true);
}

/// Writes a project, checks it, tears it down, returns the violations.
Future<List<Violation>> lint(
  String yaml,
  Map<String, String> files, {
  String packageName = 'test_app',
}) async {
  final project = await TestProject.create(
    yaml: yaml,
    files: files,
    packageName: packageName,
  );
  try {
    return (await project.check()).violations;
  } finally {
    await project.dispose();
  }
}

/// Loads YAML only and returns the config errors (empty when valid).
List<ConfigError> configErrors(String yaml) {
  try {
    ConfigLoader().load(
      content: yaml,
      configPath: '/tmp/agent_lints.yaml',
      rootPath: '/tmp',
      packageName: 'test_app',
    );
    return const [];
  } on ConfigException catch (e) {
    return e.errors;
  }
}

/// A rule body wrapped in a valid config.
String rule(String id, String body) =>
    '''
version: 2
rules:
  $id:
$body
''';
