import 'package:http/http.dart' as http; // http_only_in_network
import 'cart_repo.dart'; // ignore: no_relative_imports -- self import, demo of a trailing ignore

class CartRepo {
  Future<int> count() async {
    final res = await http.get(Uri.parse('https://example.com/cart'));
    return res.body.length;
  }
}
