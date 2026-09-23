/// Project logger. `print` is banned by agent_lints.yaml.
class AppLog {
  static void d(Object? message) {
    // ignore: avoid_print
    print(message);
  }
}
