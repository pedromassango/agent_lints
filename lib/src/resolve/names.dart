import 'package:analyzer/dart/element/element.dart';

/// Name forms of a resolved element, used to match `name:` patterns.
///
/// A pattern matches when it matches any of [candidates]:
/// - constructors: `Class` and `Class.ctor` (`Class.new` for unnamed)
/// - members: `member`, `Class.member` and `.member`
/// - top-level / classes: `name`
class ResolvedName {
  ResolvedName({
    required this.qualified,
    required this.short,
    required this.candidates,
    this.libraryUri,
  });

  final String qualified;
  final String short;
  final List<String> candidates;
  final String? libraryUri;

  String? get package => packageOfUri(libraryUri);

  static ResolvedName? of(Element? element) {
    if (element == null) return null;
    final uri = _libraryUri(element);
    if (element is ConstructorElement) {
      final cls = element.enclosingElement.name ?? '';
      final ctor = element.name ?? 'new';
      final qualified = ctor == 'new' ? cls : '$cls.$ctor';
      return ResolvedName(
        qualified: qualified,
        short: ctor == 'new' ? cls : ctor,
        candidates: [cls, '$cls.$ctor'],
        libraryUri: uri,
      );
    }
    final name = element.name;
    if (name == null || name.isEmpty) return null;
    final owner = element.enclosingElement;
    if (element is! LibraryElement &&
        (owner is InterfaceElement || owner is ExtensionElement) &&
        owner!.name != null) {
      final cls = owner.name!;
      return ResolvedName(
        qualified: '$cls.$name',
        short: name,
        candidates: [name, '$cls.$name', '.$name'],
        libraryUri: uri,
      );
    }
    return ResolvedName(
      qualified: name,
      short: name,
      candidates: [name],
      libraryUri: uri,
    );
  }

  /// A name for an unresolved reference (dynamic calls, broken imports).
  static ResolvedName unresolved(String name) =>
      ResolvedName(qualified: name, short: name, candidates: [name]);

  static String? _libraryUri(Element element) {
    final lib = element.library ?? element.enclosingElement?.library;
    return lib?.uri.toString();
  }
}

/// `package:flutter/src/widgets/text.dart` -> `flutter`; `dart:core` -> `dart:core`.
String? packageOfUri(String? uri) {
  if (uri == null) return null;
  if (uri.startsWith('package:')) {
    final rest = uri.substring('package:'.length);
    final slash = rest.indexOf('/');
    return slash == -1 ? rest : rest.substring(0, slash);
  }
  if (uri.startsWith('dart:')) return uri;
  return null;
}
