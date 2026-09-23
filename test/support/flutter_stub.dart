/// Minimal stand-ins for Flutter, material_ui and http so matcher tests can
/// resolve real elements without a Flutter SDK.
const flutterStub = <String, String>{
  'lib/widgets.dart': '''
export 'src/widgets/framework.dart';
export 'src/widgets/basic.dart';
export 'src/painting/edge_insets.dart';
export 'src/painting/color.dart';
''',
  'lib/material.dart': '''
export 'widgets.dart';
export 'src/material/material.dart';
''',
  'lib/src/widgets/framework.dart': '''
class Key { const Key(this.value); final String value; }
abstract class Widget { const Widget({this.key}); final Key? key; }
abstract class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
}
abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
}
abstract class State<T extends StatefulWidget> {
  void setState(void Function() fn) {}
  void initState() {}
  Widget build(BuildContext context);
  BuildContext get context => throw UnimplementedError();
}
''',
  'lib/src/widgets/basic.dart': '''
import 'framework.dart';
import '../painting/color.dart';
import '../painting/edge_insets.dart';

class BoxDecoration {
  const BoxDecoration({this.color, this.borderRadius});
  final Color? color;
  final double? borderRadius;
}
class TextStyle {
  const TextStyle({this.fontSize, this.color});
  final double? fontSize;
  final Color? color;
}
class Container extends Widget {
  const Container({super.key, this.child, this.color, this.padding,
      this.decoration, this.width, this.height});
  final Widget? child;
  final Color? color;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;
  final double? width;
  final double? height;
}
class Text extends Widget {
  const Text(this.data, {super.key, this.style});
  final String data;
  final TextStyle? style;
}
class Padding extends Widget {
  const Padding({super.key, required this.padding, this.child});
  final EdgeInsets padding;
  final Widget? child;
}
class SizedBox extends Widget {
  const SizedBox({super.key, this.width, this.height, this.child});
  final double? width;
  final double? height;
  final Widget? child;
}
class Column extends Widget {
  const Column({super.key, this.children = const []});
  final List<Widget> children;
}
class ListView extends Widget {
  const ListView({super.key, this.children = const [], this.shrinkWrap = false});
  ListView.builder({super.key, required Widget Function(BuildContext, int) itemBuilder,
      this.shrinkWrap = false}) : children = const [];
  final List<Widget> children;
  final bool shrinkWrap;
}
class GestureDetector extends Widget {
  const GestureDetector({super.key, this.onTap, this.onPanUpdate, this.child});
  final void Function()? onTap;
  final void Function(Object)? onPanUpdate;
  final Widget? child;
}
class Opacity extends Widget {
  const Opacity({super.key, required this.opacity, this.child});
  final double opacity;
  final Widget? child;
}
class Builder extends Widget {
  const Builder({super.key, required this.builder});
  final Widget Function(BuildContext) builder;
}
''',
  'lib/src/painting/edge_insets.dart': '''
class EdgeInsets {
  const EdgeInsets.all(double value)
      : left = value, top = value, right = value, bottom = value;
  const EdgeInsets.symmetric({double horizontal = 0, double vertical = 0})
      : left = horizontal, right = horizontal, top = vertical, bottom = vertical;
  const EdgeInsets.only({this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});
  static const EdgeInsets zero = EdgeInsets.all(0);
  final double left;
  final double top;
  final double right;
  final double bottom;
}
''',
  'lib/src/painting/color.dart': '''
class Color {
  const Color(this.value);
  const Color.fromARGB(int a, int r, int g, int b) : value = a;
  final int value;
  Color withOpacity(double opacity) => this;
}
''',
  'lib/src/material/material.dart': '''
import '../painting/color.dart';
import '../widgets/framework.dart';

class MaterialColor extends Color {
  const MaterialColor(super.value, this.shade300);
  final Color shade300;
}
class Colors {
  static const MaterialColor red = MaterialColor(0xFFFF0000, Color(0xFFFF8888));
  static const MaterialColor blue = MaterialColor(0xFF0000FF, Color(0xFF8888FF));
  static const Color transparent = Color(0);
}
class InkWell extends Widget {
  const InkWell({super.key, this.onTap, this.child});
  final void Function()? onTap;
  final Widget? child;
}
class Scaffold extends Widget {
  const Scaffold({super.key, this.body});
  final Widget? body;
}
class SafeArea extends Widget {
  const SafeArea({super.key, this.child});
  final Widget? child;
}
class MaterialApp extends Widget {
  const MaterialApp({super.key, this.home});
  final Widget? home;
}
class NavigatorState {
  Future<T?> push<T>(Object route) async => null;
}
class Navigator {
  static NavigatorState of(BuildContext context) => NavigatorState();
}
class ColorScheme {
  const ColorScheme();
  Color get primary => const Color(1);
}
class ThemeData {
  const ThemeData();
  ColorScheme get colorScheme => const ColorScheme();
}
class Theme {
  static ThemeData of(BuildContext context) => const ThemeData();
}
''',
};

const materialUiStub = <String, String>{
  'lib/material_ui.dart': '''
export 'package:flutter/widgets.dart';
export 'src/material.dart';
''',
  'lib/src/material.dart': '''
import 'package:flutter/widgets.dart';

class Scaffold extends Widget {
  const Scaffold({super.key, this.body});
  final Widget? body;
}
class InkWell extends Widget {
  const InkWell({super.key, this.onTap, this.child});
  final void Function()? onTap;
  final Widget? child;
}
class Colors {
  static const Color red = Color(0xFFFF0000);
}
''',
};

const httpStub = <String, String>{
  'lib/http.dart': '''
Future<String> get(Uri url) async => '';
class Client {
  Future<String> get(Uri url) async => '';
}
''',
};
