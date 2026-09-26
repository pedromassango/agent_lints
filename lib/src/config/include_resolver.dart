import 'dart:convert';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

/// Result of expanding one `include:` entry.
class IncludeResolution {
  IncludeResolution({this.paths = const [], this.error, this.warning});

  /// Absolute paths, in a deterministic order.
  final List<String> paths;
  final String? error;
  final String? warning;
}

/// Expands an `include:` entry the way Dart's `analysis_options.yaml` does,
/// plus globs: a relative path, a glob (relative to the including file's
/// directory, results sorted), or a `package:name/path.yaml` URI resolved
/// through `.dart_tool/package_config.json` at the project root.
IncludeResolution resolveInclude(
  String entry, {
  required String fromDir,
  required String rootPath,
}) {
  if (entry.startsWith('package:')) {
    return _resolvePackage(entry, rootPath: rootPath);
  }
  if (entry.contains('*') || entry.contains('?') || entry.contains('{')) {
    final glob = Glob(entry, context: p.posix);
    final matches = <String>[];
    for (final e in glob.listSync(root: fromDir, followLinks: false)) {
      if (e is File) matches.add(p.normalize(e.path));
    }
    matches.sort();
    if (matches.isEmpty) {
      return IncludeResolution(warning: 'include "$entry" matched no files');
    }
    return IncludeResolution(paths: matches);
  }
  final path = p.normalize(p.join(fromDir, entry));
  if (!File(path).existsSync()) {
    return IncludeResolution(
      error: 'included file not found: $entry (looked in $fromDir)',
    );
  }
  return IncludeResolution(paths: [path]);
}

IncludeResolution _resolvePackage(String uri, {required String rootPath}) {
  final rest = uri.substring('package:'.length);
  final slash = rest.indexOf('/');
  if (slash <= 0 || slash == rest.length - 1) {
    return IncludeResolution(
      error: 'expected package:<name>/<path>.yaml, got $uri',
    );
  }
  final name = rest.substring(0, slash);
  final relative = rest.substring(slash + 1);
  final configFile = File(
    p.join(rootPath, '.dart_tool', 'package_config.json'),
  );
  if (!configFile.existsSync()) {
    return IncludeResolution(
      error:
          'cannot resolve $uri: .dart_tool/package_config.json is missing; '
          'run `dart pub get` (or `flutter pub get`)',
    );
  }
  final Object? json;
  try {
    json = jsonDecode(configFile.readAsStringSync());
  } on FormatException catch (e) {
    return IncludeResolution(
      error: 'cannot read package_config.json: ${e.message}',
    );
  }
  if (json is! Map || json['packages'] is! List) {
    return IncludeResolution(error: 'unexpected package_config.json format');
  }
  for (final entry in json['packages'] as List) {
    if (entry is! Map || entry['name'] != name) continue;
    final rootUri = Uri.parse(entry['rootUri'] as String);
    final packageUri = Uri.parse(entry['packageUri'] as String? ?? 'lib/');
    final base = rootUri.hasScheme
        ? rootUri
        : configFile.parent.uri.resolveUri(rootUri);
    final file = base.resolveUri(packageUri).resolve(relative);
    final path = p.normalize(file.toFilePath());
    if (!File(path).existsSync()) {
      return IncludeResolution(error: 'included file not found: $uri ($path)');
    }
    return IncludeResolution(paths: [path]);
  }
  return IncludeResolution(
    error: 'cannot resolve $uri: package "$name" is not a dependency',
  );
}
