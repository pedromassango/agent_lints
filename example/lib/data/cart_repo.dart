import 'package:http/http.dart' as http; // http_only_in_network

class CartRepo {
  Future<int> count() async {
    final res = await http.get(Uri.parse('https://example.com/cart'));
    return res.body.length;
  }
}
