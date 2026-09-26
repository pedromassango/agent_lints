import 'package:source_span/source_span.dart';

/// One problem found while reading `agent_lints.yaml`.
class ConfigError {
  ConfigError(this.message, {this.span, this.path, this.hint});

  /// What is wrong.
  final String message;

  /// Where in the YAML file, when known.
  final SourceSpan? span;

  /// Dotted path inside the document, e.g. `rules.no_print.match.call`.
  final String? path;

  /// A suggestion, e.g. `did you mean "name"?`.
  final String? hint;

  String format({String? fileName}) {
    final buffer = StringBuffer();
    final span = this.span;
    if (span != null) {
      final url = span.sourceUrl;
      final file =
          fileName ??
          (url == null
              ? 'agent_lints.yaml'
              : url.isScheme('file')
              ? url.toFilePath()
              : url.toString());
      buffer.write('$file:${span.start.line + 1}:${span.start.column + 1}');
    } else {
      buffer.write(fileName ?? 'agent_lints.yaml');
    }
    if (path != null && path!.isNotEmpty) buffer.write(' $path');
    buffer.write(': $message');
    if (hint != null) buffer.write(' ($hint)');
    return buffer.toString();
  }

  @override
  String toString() => format();
}

/// Thrown when the config cannot be used. Carries every error found.
class ConfigException implements Exception {
  ConfigException(this.errors, {this.sourcePaths = const []});

  final List<ConfigError> errors;

  /// Config files that were read before the failure, so callers can watch
  /// them for changes.
  final List<String> sourcePaths;

  @override
  String toString() => errors.map((e) => e.format()).join('\n');
}

/// Collects [ConfigError]s during loading.
class ConfigErrors {
  final List<ConfigError> errors = [];
  final List<ConfigError> warnings = [];

  bool get hasErrors => errors.isNotEmpty;

  void add(String message, {SourceSpan? span, String? path, String? hint}) {
    errors.add(ConfigError(message, span: span, path: path, hint: hint));
  }

  void warn(String message, {SourceSpan? span, String? path, String? hint}) {
    warnings.add(ConfigError(message, span: span, path: path, hint: hint));
  }

  void throwIfAny({List<String> sourcePaths = const []}) {
    if (hasErrors) {
      throw ConfigException(
        List.unmodifiable(errors),
        sourcePaths: sourcePaths,
      );
    }
  }
}
