import 'package:http/http.dart' as http;

class ApiClient {
  Future<String> fetch(Uri uri) async => (await http.get(uri)).body;
}
